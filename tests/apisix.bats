#!/usr/bin/env bats
# Tests for S122 — core becomes an APISIX gateway.

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

# ---------------------------------------------------------------------------
# Vendored template files present
# ---------------------------------------------------------------------------

@test "templates/core/apisix ships the four vendored yaml files" {
  [ -s "${TMPL_DIR}/core/apisix/apisix.yaml" ]
  [ -s "${TMPL_DIR}/core/apisix/apisix-guest.yaml" ]
  [ -s "${TMPL_DIR}/core/apisix/config.yaml" ]
  [ -s "${TMPL_DIR}/core/apisix/config-guest.yaml" ]
}

# ---------------------------------------------------------------------------
# Rendered compose — core service
# ---------------------------------------------------------------------------

@test "rendered docker-compose.yml.tmpl has no microservices/core reference" {
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  run grep -c 'microservices/core' "$out"
  [ "$status" -ne 0 ]
  [ "$output" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl uses apache/apisix image for core" {
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'apache/apisix:3.15.0-ubuntu' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl sets CORS_ALLOW_ORIGINS from FRONTEND_PORT" {
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'CORS_ALLOW_ORIGINS: "http://localhost:9999"' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl mounts all four apisix config files" {
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  run grep -c './configs/apisix/' "$out"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]
}

@test "rendered docker-compose.yml.tmpl is still valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out="${TMPDIR_WORK}/compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat:v1.2.0 \
           COMPOSE_PROFILES=mock
    render::file '${TMPL_DIR}/docker-compose.yml.tmpl' '${out}'
  "
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Wizard dry-run — generated/configs/apisix
# ---------------------------------------------------------------------------

@test "non-interactive dry-run produces the four generated/configs/apisix files" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -s "${TMPDIR_WORK}/gen/configs/apisix/apisix.yaml" ]
  [ -s "${TMPDIR_WORK}/gen/configs/apisix/apisix-guest.yaml" ]
  [ -s "${TMPDIR_WORK}/gen/configs/apisix/config.yaml" ]
  [ -s "${TMPDIR_WORK}/gen/configs/apisix/config-guest.yaml" ]
}

@test "generated apisix-guest.yaml matches the vendored reference byte-for-byte" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run diff "${TMPL_DIR}/core/apisix/apisix-guest.yaml" \
    "${TMPDIR_WORK}/gen/configs/apisix/apisix-guest.yaml"
  [ "$status" -eq 0 ]
}

@test "generated apisix config files parse as valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  for f in apisix.yaml apisix-guest.yaml config.yaml config-guest.yaml; do
    run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' \
      < "${TMPDIR_WORK}/gen/configs/apisix/${f}"
    [ "$status" -eq 0 ]
  done
}
