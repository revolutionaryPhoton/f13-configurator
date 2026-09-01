#!/usr/bin/env bats
# Tests for lib/render.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

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
    export FRONTEND_PORT=9999 CORE_PORT=8000 CHAT_BACKEND=mock \
           OLLAMA_MODEL='' CHAT_MODEL_ID=test_model_mock FEEDBACK_DB_PASSWORD=secret123 \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           CHAT_BASE_URL=http://ollama-mock:11434/v1 CHAT_MODEL_NAME=test_model:mock \
           CHAT_MAX_CONTEXT_TOKENS=4096 COMPOSE_PROFILES=mock
    render::file '${tmpl}' '${out}'
  "
  [ "$status" -eq 0 ]
  [ -f "$out" ]
  run grep 'FRONTEND_PORT=9999' "$out"
  [ "$status" -eq 0 ]
  run grep 'CORE_PORT=8000' "$out"
  [ "$status" -eq 0 ]
  run grep 'CHAT_BACKEND=mock' "$out"
  [ "$status" -eq 0 ]
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep 'image: registry.opencode.de/f13/microservices/feedback:v1.0.0' "$out"
  [ "$status" -eq 0 ]
  run grep -A5 '^  feedback:$' "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feedback-db"* ]]
  [[ "$output" == *"service_healthy"* ]]
}

@test "render docker-compose.yml.tmpl mounts feedback_db.secret and ./configs into feedback" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
           CHAT_IMAGE=registry.opencode.de/f13/microservices/chat/main:latest \
           COMPOSE_PROFILES=
    render::file '${BATS_TEST_DIRNAME}/../templates/docker-compose.yml.tmpl' '${out}'
  "
  run grep -A10 '^  feedback:$' "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"source: feedback_db.secret"* ]]
  [[ "$output" == *"target: /core/secrets/feedback_db.secret"* ]]
  [[ "$output" == *"./configs:/feedback/configs:ro"* ]]

  run grep -A2 '^secrets:$' "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *"feedback_db.secret:"* ]]
  [[ "$output" == *"file: ./secrets/feedback_db.secret"* ]]
}

@test "render docker-compose.yml.tmpl contains extra_hosts for chat" {
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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

@test "render chat/llm_models.yml.tmpl substitutes backend-specific vars" {
  local out="${TMPDIR_WORK}/chat-llm.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export CHAT_MODEL_ID=local_ollama \
           CHAT_BASE_URL=http://host.docker.internal:11434/v1 \
           CHAT_MODEL_NAME=gemma4:31b-cloud \
           CHAT_MAX_CONTEXT_TOKENS=8192
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/llm_models.yml.tmpl' '${out}'
  "
  run grep 'local_ollama' "$out"
  [ "$status" -eq 0 ]
  run grep 'host.docker.internal' "$out"
  [ "$status" -eq 0 ]
  run grep '8192' "$out"
  [ "$status" -eq 0 ]
}

@test "rendered docker-compose.yml.tmpl is valid YAML" {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    skip "python3 with yaml not available"
  fi
  local out="${TMPDIR_WORK}/docker-compose.yml"
  bash -c "
    source '${LIB_DIR}/render.sh'
    export FRONTEND_PORT=9999 CORE_PORT=8000 FEEDBACK_DB_PASSWORD=pw \
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
           CHAT_MAX_CONTEXT_TOKENS=4096
    render::file '${BATS_TEST_DIRNAME}/../templates/chat/llm_models.yml.tmpl' '${out}'
  "
  run python3 -c 'import yaml,sys; yaml.safe_load(sys.stdin)' < "$out"
  [ "$status" -eq 0 ]
}
