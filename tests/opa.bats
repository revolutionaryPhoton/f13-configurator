#!/usr/bin/env bats
# Tests for S123 — mandatory OPA sidecar for chat v3.

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"
TMPL_DIR="${BATS_TEST_DIRNAME}/../templates"
BIN="${BATS_TEST_DIRNAME}/../bin/f13-config"

NI_ENV=(
  F13_CONFIG_NONINTERACTIVE=1
  F13_SKIP_PREFLIGHT=1
  CHAT_BACKEND=mock
  FRONTEND_PORT=9999
  CORE_PORT=8000
)

setup() {
  TMPDIR_WORK="$(mktemp -d)"
  NI_ENV+=("F13_GENERATED_DIR=${TMPDIR_WORK}/gen")
}

teardown() {
  rm -rf "${TMPDIR_WORK}"
}

_render_compose() {
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  echo "${out}"
}

# ---------------------------------------------------------------------------
# Vendored template files present
# ---------------------------------------------------------------------------

@test "templates/chat/opa/policies ships the vendored rego files" {
  [ -s "${TMPL_DIR}/chat/opa/policies/permissions.rego" ]
  [ -s "${TMPL_DIR}/chat/opa/policies/test_permissions.rego" ]
}

# ---------------------------------------------------------------------------
# Rendered compose — opa service
# ---------------------------------------------------------------------------

@test "rendered docker-compose.yml.tmpl has an opa service with the pinned image" {
  local out
  out="$(_render_compose)"
  run grep 'registry.opencode.de/f13/devops-tools/dockerhub-images/opa:1.18.1-debug' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl mounts the opa policies volume read-only" {
  local out
  out="$(_render_compose)"
  run grep -- '- ./opa/policies:/policies:ro' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl opa service has the eval healthcheck" {
  local out
  out="$(_render_compose)"
  run grep -- '\["CMD", "/opa", "eval", "1"\]' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl opa service listens on OPA_PORT, not a hardcoded 8181" {
  local out
  out="$(_render_compose)"
  run grep -- '"--addr=:8181"' "$out"
  [ "$status" -eq 0 ]

  # S127: re-render with a different OPA_PORT and confirm the addr follows it
  # (proves the value is templated, not a hardcoded literal).
  local out2="${TMPDIR_WORK}/compose-altport.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=9191 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out2}'
  "
  run grep -- '"--addr=:9191"' "${out2}"
  [ "$status" -eq 0 ]
  run grep -- '"--addr=:8181"' "${out2}"
  [ "$status" -eq 1 ]
}

@test "rendered docker-compose.yml.tmpl chat service depends_on opa service_healthy" {
  local out
  out="$(_render_compose)"
  # chat's depends_on block must name opa with condition: service_healthy
  # before the next top-level service starts.
  run awk '/^  chat:/{f=1} f && /^  opa:/{exit} f' "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"opa:"* ]]
  [[ "$output" == *"condition: service_healthy"* ]]
}

@test "rendered docker-compose.yml.tmpl is still valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out
  out="$(_render_compose)"
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Wizard dry-run — generated/opa/policies
# ---------------------------------------------------------------------------

@test "non-interactive dry-run produces the generated/opa/policies files" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -s "${TMPDIR_WORK}/gen/opa/policies/permissions.rego" ]
  [ -s "${TMPDIR_WORK}/gen/opa/policies/test_permissions.rego" ]
}

@test "generated permissions.rego matches the vendored reference byte-for-byte" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run diff "${TMPL_DIR}/chat/opa/policies/permissions.rego" \
    "${TMPDIR_WORK}/gen/opa/policies/permissions.rego"
  [ "$status" -eq 0 ]
}
