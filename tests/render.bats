#!/usr/bin/env bats
# Tests for lib/render.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# _service_block FILE SERVICE
# Print one compose service block, from "  <service>:" to the next top-level
# service key. Use this instead of `grep -A<n>`: a fixed window silently stops
# asserting anything the moment a comment is added to the template, which has
# already produced three false failures.
_service_block() {
  awk -v svc="  $2:" '
    $0 == svc { inblk = 1; print; next }
    inblk && /^  [a-z0-9_-]+:$/ { exit }
    inblk { print }
  ' "$1"
}

setup() {
  TMPDIR_WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_WORK"
}

# ---------------------------------------------------------------------------
# Source / function existence
# ---------------------------------------------------------------------------

@test "lib/render.sh sources without error" {
  run bash -c "source '${LIB_DIR}/render.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/render.sh defines render::file function" {
  run bash -c "source '${LIB_DIR}/render.sh'; declare -f render::file > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/render.sh defines render::tree function" {
  run bash -c "source '${LIB_DIR}/render.sh'; declare -f render::tree > /dev/null"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# render::file basic substitution
# ---------------------------------------------------------------------------

@test "render::file substitutes a single variable" {
  local tmpl="${TMPDIR_WORK}/simple.tmpl"
  local out="${TMPDIR_WORK}/simple.txt"
  printf 'port: ${MYPORT}\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export MYPORT=9999
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  run cat "$out"
  [ "$output" = "port: 9999" ]
}

@test "render::file substitutes multiple variables" {
  local tmpl="${TMPDIR_WORK}/multi.tmpl"
  local out="${TMPDIR_WORK}/multi.txt"
  printf 'frontend: ${FRONTEND_PORT}\ncore: ${CORE_PORT}\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  run cat "$out"
  [ "${lines[0]}" = "frontend: 9999" ]
  [ "${lines[1]}" = "core: 8000" ]
}

@test "render::file handles \${VAR} brace syntax" {
  local tmpl="${TMPDIR_WORK}/brace.tmpl"
  local out="${TMPDIR_WORK}/brace.txt"
  printf 'value: ${MYVAL}\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export MYVAL=hello
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  run cat "$out"
  [ "$output" = "value: hello" ]
}

# ---------------------------------------------------------------------------
# Allow-list safety: only template vars substituted
# ---------------------------------------------------------------------------

@test "render::file does not leak env vars absent from the template" {
  local tmpl="${TMPDIR_WORK}/safe.tmpl"
  local out="${TMPDIR_WORK}/safe.txt"
  # Template only references MYVAR; SUPERSECRET is in the env but not the template.
  printf 'var: ${MYVAR}\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export MYVAR=ok SUPERSECRET=mustnotappear
    render::file '${tmpl}' '${out}'
    grep -q 'mustnotappear' '${out}' && exit 1 || exit 0
  "
  [ "$status" -eq 0 ]
  run cat "$out"
  [ "$output" = "var: ok" ]
}

@test "render::file allows lowercase-named vars when present in template" {
  # Even though F13 convention is uppercase, we must not break templates that
  # happen to contain mixed-case vars — they just won't be in the allow-list
  # and remain unexpanded (which is the safe default).
  local tmpl="${TMPDIR_WORK}/lower.tmpl"
  local out="${TMPDIR_WORK}/lower.txt"
  printf 'upper: ${UPPER_VAR}\nlower: ${lower_var}\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export UPPER_VAR=yes lower_var=no
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  run grep '^upper:' "$out"
  [ "$output" = "upper: yes" ]
  # lower_var is NOT uppercase — render.sh allow-list only picks [A-Z_][A-Z0-9_]*
  run grep '^lower:' "$out"
  [ "$output" = 'lower: ${lower_var}' ]
}

# ---------------------------------------------------------------------------
# render::file: destination directory creation
# ---------------------------------------------------------------------------

@test "render::file creates missing destination directories" {
  local tmpl="${TMPDIR_WORK}/src.tmpl"
  local out="${TMPDIR_WORK}/a/b/c/out.txt"
  printf 'hello\n' > "$tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  [ -f "$out" ]
}

# ---------------------------------------------------------------------------
# render::file: error cases
# ---------------------------------------------------------------------------

@test "render::file fails when source does not exist" {
  run bash -c "
    source '${LIB_DIR}/render.sh'
    render::file '${TMPDIR_WORK}/nonexistent.tmpl' '${TMPDIR_WORK}/out.txt'
  "
  [ "$status" -ne 0 ]
}

@test "render::file fails when SRC argument is missing" {
  run bash -c "
    source '${LIB_DIR}/render.sh'
    render::file
  "
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# render::tree
# ---------------------------------------------------------------------------

@test "render::tree renders all .tmpl files" {
  local src="${TMPDIR_WORK}/tpls"
  local dst="${TMPDIR_WORK}/out"
  mkdir -p "${src}/sub"
  printf 'port: ${PORT}\n' > "${src}/a.txt.tmpl"
  printf 'name: ${NAME}\n' > "${src}/sub/b.yml.tmpl"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export PORT=1234 NAME=f13
    render::tree '${src}' '${dst}'
  "
  [ "$status" -eq 0 ]
  [ -f "${dst}/a.txt" ]
  [ -f "${dst}/sub/b.yml" ]
}

@test "render::tree strips .tmpl extension from output files" {
  local src="${TMPDIR_WORK}/tpls"
  local dst="${TMPDIR_WORK}/out"
  mkdir -p "$src"
  printf 'x: ${X}\n' > "${src}/config.yml.tmpl"

  bash -c "
    source '${LIB_DIR}/render.sh'
    export X=42
    render::tree '${src}' '${dst}'
  "
  [ -f "${dst}/config.yml" ]
  [ ! -f "${dst}/config.yml.tmpl" ]
}

@test "render::tree renders correct content" {
  local src="${TMPDIR_WORK}/tpls"
  local dst="${TMPDIR_WORK}/out"
  mkdir -p "$src"
  printf 'backend: ${CHAT_BACKEND}\nmodel: ${OLLAMA_MODEL}\n' > "${src}/env.tmpl"

  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_BACKEND=ollama OLLAMA_MODEL=gemma4:31b-cloud
    render::tree '${src}' '${dst}'
  "
  run cat "${dst}/env"
  [ "${lines[0]}" = "backend: ollama" ]
  [ "${lines[1]}" = "model: gemma4:31b-cloud" ]
}

@test "render::tree fails when source dir does not exist" {
  run bash -c "
    source '${LIB_DIR}/render.sh'
    render::tree '${TMPDIR_WORK}/nosuchdir' '${TMPDIR_WORK}/out'
  "
  [ "$status" -ne 0 ]
}

@test "render::tree handles empty template directory" {
  local src="${TMPDIR_WORK}/empty"
  local dst="${TMPDIR_WORK}/out"
  mkdir -p "$src"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    render::tree '${src}' '${dst}'
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Fixture diff test: env.tmpl matches expected output
# ---------------------------------------------------------------------------

@test "render::file renders env.tmpl fixture to expected output" {
  local tmpl="${BATS_TEST_DIRNAME}/../templates/env.tmpl"
  local out="${TMPDIR_WORK}/rendered.env"

  run bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 CHAT_BACKEND=mock \
           OLLAMA_MODEL='' CHAT_MODEL_ID=test_model_mock FEEDBACK_DB_PASSWORD=secret123 \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           CHAT_BASE_URL=http://ollama-mock:11434/v1 CHAT_MODEL_NAME=test_model:mock \
           CHAT_CONTEXT_LENGTH=4096 COMPOSE_PROFILES=mock
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  run grep 'FRONTEND_PORT=9999' "$out"
  [ "$status" -eq 0 ]
  run grep 'CORE_PORT=8000' "$out"
  [ "$status" -eq 0 ]
  run grep 'OPA_PORT=8181' "$out"
  [ "$status" -eq 0 ]
  run grep 'CHAT_BACKEND=mock' "$out"
  [ "$status" -eq 0 ]
  run grep 'CHAT_CONTEXT_LENGTH=4096' "$out"
  [ "$status" -eq 0 ]
}

@test "render::file renders env.tmpl fixture with no CHAT_MAX_CONTEXT_TOKENS reference" {
  local tmpl="${BATS_TEST_DIRNAME}/../templates/env.tmpl"
  run grep -c 'CHAT_MAX_CONTEXT_TOKENS' "$tmpl"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
}

@test "S127: no CHAT_MAX_CONTEXT_TOKENS= assignment/reference remains in bin/, lib/, templates/, tests/" {
  # Matches the var used as a shell/envsubst token (CHAT_MAX_CONTEXT_TOKENS=
  # or \${CHAT_MAX_CONTEXT_TOKENS}), not English prose mentioning the old
  # name in a test title (like this one). docs/upstream is the vendored v3
  # reference and legitimately never used this var name — excluded because
  # it must survive untouched.
  run grep -rlE --exclude=render.bats 'CHAT_MAX_CONTEXT_TOKENS[=}]' \
    "${BATS_TEST_DIRNAME}/../bin" \
    "${BATS_TEST_DIRNAME}/../lib" \
    "${BATS_TEST_DIRNAME}/../templates" \
    "${BATS_TEST_DIRNAME}"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# S09: template content tests
# ---------------------------------------------------------------------------

@test "templates/docker-compose.yml.tmpl exists and is non-empty" {
  [ -s "${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl" ]
}

@test "render docker-compose.yml.tmpl substitutes FRONTEND_PORT and CORE_PORT" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=mock
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep '9999:9999' "$out"
  [ "$status" -eq 0 ]
  run grep '8000:8000' "$out"
  [ "$status" -eq 0 ]
}

@test "render docker-compose.yml.tmpl contains ollama-mock under mock profile" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=mock
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'ollama-mock' "$out"
  [ "$status" -eq 0 ]
  run grep -A3 'ollama-mock:' "$out"
  [[ "$output" == *"profiles"* ]]
}

@test "render docker-compose.yml.tmpl contains feedback-db pg_isready healthcheck" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'pg_isready' "$out"
  [ "$status" -eq 0 ]
}

@test "render docker-compose.yml.tmpl bumps feedback-db to postgres:18-alpine" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'image: postgres:18-alpine' "$out"
  [ "$status" -eq 0 ]
  run grep 'postgres:17-alpine' "$out"
  [ "$status" -ne 0 ]
}

@test "render docker-compose.yml.tmpl corrects ollama-mock path and tag" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=mock
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'image: registry.opencode.de/f13/microservices/builder-images/ollama-mock:v1.2.2' "$out"
  [ "$status" -eq 0 ]
  run grep 'base-images/ollama-mock-f13' "$out"
  [ "$status" -ne 0 ]
}

@test "render docker-compose.yml.tmpl contains the feedback service" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'image: registry.opencode.de/f13/microservices/feedback:v1.0.1' "$out"
  [ "$status" -eq 0 ]
  run _service_block "$out" feedback
  [ "$status" -eq 0 ]
  [[ "$output" == *"feedback-db"* ]]
  [[ "$output" == *"service_healthy"* ]]
}

@test "render docker-compose.yml.tmpl mounts feedback-db at the postgres 18 path" {
  # Regression guard. postgres 18 expects a single mount at
  # /var/lib/postgresql, not the pre-18 /var/lib/postgresql/data. Mounting the
  # old path makes the container refuse to start ("PostgreSQL data in ...
  # (unused mount/volume)") and every dependant then fails with "dependency
  # failed to start". Nothing else in the suite catches this -- it only shows
  # up when a stack is actually launched, which is how it reached S130.
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep -- '- feedback-db-data:/var/lib/postgresql$' "$out"
  [ "$status" -eq 0 ]
  run grep -- '- feedback-db-data:/var/lib/postgresql/data' "$out"
  [ "$status" -ne 0 ]
  run grep 'start_period:' "$out"
  [ "$status" -eq 0 ]
}

@test "render docker-compose.yml.tmpl mounts feedback_db.secret and ./configs into feedback" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run _service_block "$out" feedback
  [ "$status" -eq 0 ]
  [[ "$output" == *"source: feedback_db.secret"* ]]
  [[ "$output" == *"target: /core/secrets/feedback_db.secret"* ]]
  [[ "$output" == *"./configs/core:/feedback/configs:ro"* ]]

  run grep -A2 '^secrets:$' "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feedback_db.secret:"* ]]
  [[ "$output" == *"file: ./secrets/feedback_db.secret"* ]]
}

@test "render docker-compose.yml.tmpl contains extra_hosts for chat" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'host.docker.internal' "$out"
  [ "$status" -eq 0 ]
}

@test "render core/general.yml.tmpl has guest_mode: true and CHAT_MODEL_ID" {
  local out="${TMPDIR_WORK}/core-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock FRONTEND_PORT=9999
    render::file '${BATS_TEST_DIRNAME}/../templates/core/general.yml.tmpl' '${out}'
  "
  run grep 'guest_mode: true' "$out"
  [ "$status" -eq 0 ]
  run grep 'test_model_mock' "$out"
  [ "$status" -eq 0 ]
}

@test "render core/general.yml.tmpl adds llm_api_timeout: 180 (v3 schema)" {
  local out="${TMPDIR_WORK}/core-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock FRONTEND_PORT=9999 CORE_PORT=8000
    render::file '${BATS_TEST_DIRNAME}/../templates/core/general.yml.tmpl' '${out}'
  "
  run grep -c 'llm_api_timeout: 180' "$out"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "render core/general.yml.tmpl has no active_llms.embedding or transcription_inference (v3 minimal stack)" {
  local out="${TMPDIR_WORK}/core-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock FRONTEND_PORT=9999 CORE_PORT=8000
    render::file '${BATS_TEST_DIRNAME}/../templates/core/general.yml.tmpl' '${out}'
  "
  run grep -c 'embedding' "$out"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
  run grep -c 'transcription_inference' "$out"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
}

@test "every top-level key in rendered core/general.yml exists in the vendored v3 reference" {
  local out="${TMPDIR_WORK}/core-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock FRONTEND_PORT=9999 CORE_PORT=8000
    render::file '${BATS_TEST_DIRNAME}/../templates/core/general.yml.tmpl' '${out}'
  "
  local ref="${BATS_TEST_DIRNAME}/../docs/upstream/v3/core/general.yml"
  local rendered_keys
  rendered_keys=$(grep -oE '^[A-Za-z_]+:' "$out" | sed 's/:$//' | sort -u)
  local key
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    run grep -qE "^${key}:" "$ref"
    [ "$status" -eq 0 ]
  done <<< "$rendered_keys"
}

@test "render chat/llm_models.yml.tmpl substitutes backend-specific vars" {
  local out="${TMPDIR_WORK}/chat-llm.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=local_ollama \
           CHAT_BASE_URL=http://host.docker.internal:11434/v1 \
           CHAT_MODEL_NAME=gemma4:31b-cloud \
           CHAT_CONTEXT_LENGTH=8192
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/llm_models.yml.tmpl' '${out}'
  "
  run grep 'local_ollama' "$out"
  [ "$status" -eq 0 ]
  run grep 'host.docker.internal' "$out"
  [ "$status" -eq 0 ]
  run grep '8192' "$out"
  [ "$status" -eq 0 ]
}

@test "render chat/llm_models.yml.tmpl uses context_length, not max_context_tokens" {
  local out="${TMPDIR_WORK}/chat-llm.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock \
           CHAT_BASE_URL=http://ollama-mock:11434/v1 \
           CHAT_MODEL_NAME=test_model:mock \
           CHAT_CONTEXT_LENGTH=4096
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/llm_models.yml.tmpl' '${out}'
  "
  run grep -c 'context_length' "$out"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c 'max_context_tokens' "$out"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
}

@test "render chat/general.yml.tmpl includes the mandatory opa service endpoint" {
  local out="${TMPDIR_WORK}/chat-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock OPA_PORT=8181
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/general.yml.tmpl' '${out}'
  "
  run grep -A1 'service_endpoints:' "$out"
  [ "$status" -eq 0 ]
  run grep 'opa: http://opa:8181/' "$out"
  [ "$status" -eq 0 ]
}

@test "render chat/general.yml.tmpl opa endpoint follows OPA_PORT, not a hardcoded 8181" {
  local out="${TMPDIR_WORK}/chat-general-altport.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock OPA_PORT=9191
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/general.yml.tmpl' '${out}'
  "
  run grep 'opa: http://opa:9191/' "$out"
  [ "$status" -eq 0 ]
  run grep 'opa: http://opa:8181/' "$out"
  [ "$status" -eq 1 ]
}

@test "render chat/agentic_chat.yml.tmpl has zero tools.<tool>.role entries" {
  local out="${TMPDIR_WORK}/agentic-chat.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/agentic_chat.yml.tmpl' '${out}'
  "
  [ -f "$out" ]
  run grep -c '^\s*role:' "$out"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
  run grep 'mcp_endpoints' "$out"
  [ "$status" -eq 0 ]
}

@test "chat/prompt_maps.yml uses the v3 generate/generate_tools schema" {
  local f="${BATS_TEST_DIRNAME}/../templates/chat/prompt_maps.yml"
  run grep -c 'generate:' "$f"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
  run grep -c 'generate_tools:' "$f"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
  run grep -c '^    system:' "$f"
  [ "$status" -eq 1 ]
  [ "$output" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl is valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 OPA_PORT=8181 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=mock
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}

@test "rendered core/general.yml.tmpl is valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out="${TMPDIR_WORK}/core-general.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock FRONTEND_PORT=9999
    render::file '${BATS_TEST_DIRNAME}/../templates/core/general.yml.tmpl' '${out}'
  "
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}

@test "rendered chat/llm_models.yml.tmpl is valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out="${TMPDIR_WORK}/chat-llm.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=test_model_mock \
           CHAT_BASE_URL=http://ollama-mock:11434/v1 \
           CHAT_MODEL_NAME=test_model:mock \
           CHAT_CONTEXT_LENGTH=4096
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/llm_models.yml.tmpl' '${out}'
  "
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}

@test "GUI status screen image list matches the compose template" {
  # The Status screen's `services` array is display-only: it is what the GUI
  # PRINTS, not what the stack runs, so it can drift from
  # templates/docker-compose.yml.tmpl without anything failing. It drifted once
  # during Phase 17 (feedback v1.0.0 shown while the template shipped v1.0.1)
  # and was caught by eye rather than by a test.
  local gui="${BATS_TEST_DIRNAME}/../gui/src/routes/status/+page.svelte"
  local tmpl="${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl"
  local fe_lib="${BATS_TEST_DIRNAME}/../lib/frontend.sh"
  [ -f "$gui" ] && [ -f "$tmpl" ]

  local img base
  while read -r img; do
    [ -n "$img" ] || continue
    case "$img" in
      # Two images reach compose through variables rather than literals:
      # FRONTEND_IMAGE (built by lib/frontend.sh) and CHAT_IMAGE (chosen by the
      # wizard per backend). Check those against their real source instead.
      f13-frontend:*)
        grep -q "${img#f13-frontend:}" "$fe_lib"
        continue
        ;;
      chat:*)
        grep -q "chat:${img##*:}" "${BATS_TEST_DIRNAME}/../bin/f13-config"
        continue
        ;;
    esac
    # Every other displayed image must appear verbatim in the template.
    base="${img%%:*}"
    grep -q "${base}:${img##*:}" "$tmpl"
  done < <(grep -oE 'image: "[^"]+"' "$gui" | sed 's/image: "//; s/"$//')
}
