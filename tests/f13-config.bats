#!/usr/bin/env bats
# Tests for bin/f13-config (S10)

BIN="${BATS_TEST_DIRNAME}/../bin/f13-config"

# Common env for non-interactive, skip-preflight runs
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
# --help
# ---------------------------------------------------------------------------

@test "bin/f13-config --help exits 0" {
  run "${BIN}" --help
  [ "$status" -eq 0 ]
}

@test "bin/f13-config --help prints usage" {
  run "${BIN}" --help
  [[ "$output" == *"Usage:"* ]]
}

@test "bin/f13-config --help documents CHAT_BACKEND" {
  run "${BIN}" --help
  [[ "$output" == *"CHAT_BACKEND"* ]]
}

# ---------------------------------------------------------------------------
# Unknown flag
# ---------------------------------------------------------------------------

@test "unknown flag exits 1" {
  run "${BIN}" --bogus-flag
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Non-interactive dry-run (mock backend) — file existence
# ---------------------------------------------------------------------------

_run_mock_dry() {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
}

@test "non-interactive dry-run exits 0" {
  run env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ "$status" -eq 0 ]
}

@test "non-interactive dry-run produces docker-compose.yml" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/docker-compose.yml" ]
}

@test "non-interactive dry-run produces .env" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/.env" ]
}

@test "non-interactive dry-run produces configs/core/general.yml" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/configs/core/general.yml" ]
}

@test "non-interactive dry-run produces configs/core/llm_models.yml" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/configs/core/llm_models.yml" ]
}

@test "non-interactive dry-run produces configs/chat/general.yml" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/configs/chat/general.yml" ]
}

@test "non-interactive dry-run produces configs/chat/llm_models.yml" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/configs/chat/llm_models.yml" ]
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------

@test "non-interactive dry-run generates secrets/llm_api.secret" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/secrets/llm_api.secret" ]
}

@test "non-interactive dry-run generates secrets/transcription_db.secret" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/secrets/transcription_db.secret" ]
}

@test "non-interactive dry-run generates secrets/rabbitmq.secret" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/secrets/rabbitmq.secret" ]
}

@test "non-interactive dry-run generates secrets/rustfs.secret" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/secrets/rustfs.secret" ]
}

@test "non-interactive dry-run generates secrets/huggingface_token.secret" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/secrets/huggingface_token.secret" ]
}

# ---------------------------------------------------------------------------
# Rendered content — mock backend
# ---------------------------------------------------------------------------

@test "docker-compose.yml contains FRONTEND_PORT substitution" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep '9999:9999' "${TMPDIR_WORK}/gen/docker-compose.yml"
  [ "$status" -eq 0 ]
}

@test "docker-compose.yml contains CORE_PORT substitution" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep '8000:8000' "${TMPDIR_WORK}/gen/docker-compose.yml"
  [ "$status" -eq 0 ]
}

@test ".env contains FRONTEND_PORT=9999" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep 'FRONTEND_PORT=9999' "${TMPDIR_WORK}/gen/.env"
  [ "$status" -eq 0 ]
}

@test ".env contains CHAT_BACKEND=mock" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep 'CHAT_BACKEND=mock' "${TMPDIR_WORK}/gen/.env"
  [ "$status" -eq 0 ]
}

@test "core/general.yml has guest_mode: true" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep 'guest_mode: true' "${TMPDIR_WORK}/gen/configs/core/general.yml"
  [ "$status" -eq 0 ]
}

@test "chat/llm_models.yml uses test_model_mock for mock backend" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep 'test_model_mock' "${TMPDIR_WORK}/gen/configs/chat/llm_models.yml"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Rendered content — ollama backend
# ---------------------------------------------------------------------------

@test "ollama backend: chat/llm_models.yml uses local_ollama" {
  env F13_CONFIG_NONINTERACTIVE=1 F13_SKIP_PREFLIGHT=1 \
    "F13_GENERATED_DIR=${TMPDIR_WORK}/gen" \
    CHAT_BACKEND=ollama OLLAMA_MODEL=gemma4:31b-cloud \
    FRONTEND_PORT=9999 CORE_PORT=8000 \
    "${BIN}" --dry-run
  run grep 'local_ollama' "${TMPDIR_WORK}/gen/configs/chat/llm_models.yml"
  [ "$status" -eq 0 ]
}

@test "ollama backend: chat/llm_models.yml contains model name" {
  env F13_CONFIG_NONINTERACTIVE=1 F13_SKIP_PREFLIGHT=1 \
    "F13_GENERATED_DIR=${TMPDIR_WORK}/gen" \
    CHAT_BACKEND=ollama OLLAMA_MODEL=gemma4:31b-cloud \
    FRONTEND_PORT=9999 CORE_PORT=8000 \
    "${BIN}" --dry-run
  run grep 'gemma4:31b-cloud' "${TMPDIR_WORK}/gen/configs/chat/llm_models.yml"
  [ "$status" -eq 0 ]
}

@test "ollama backend: .env contains CHAT_BACKEND=ollama" {
  env F13_CONFIG_NONINTERACTIVE=1 F13_SKIP_PREFLIGHT=1 \
    "F13_GENERATED_DIR=${TMPDIR_WORK}/gen" \
    CHAT_BACKEND=ollama OLLAMA_MODEL=gemma4:31b-cloud \
    FRONTEND_PORT=9999 CORE_PORT=8000 \
    "${BIN}" --dry-run
  run grep 'CHAT_BACKEND=ollama' "${TMPDIR_WORK}/gen/.env"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# --reset
# ---------------------------------------------------------------------------

@test "--reset when generated/ is absent prints info and continues" {
  run env F13_CONFIG_NONINTERACTIVE=1 F13_SKIP_PREFLIGHT=1 \
    "F13_GENERATED_DIR=${TMPDIR_WORK}/nosuchdir" \
    CHAT_BACKEND=mock FRONTEND_PORT=9999 CORE_PORT=8000 \
    "${BIN}" --reset --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to reset"* ]]
}

@test "--reset wipes generated/ in non-interactive mode (default=n → skip reset)" {
  mkdir -p "${TMPDIR_WORK}/gen/configs"
  touch "${TMPDIR_WORK}/gen/docker-compose.yml"
  # Default for "Delete?" prompt is "n", so in noninteractive mode reset is skipped
  # and the wizard proceeds; the existing file should still be there (or overwritten)
  run env F13_CONFIG_NONINTERACTIVE=1 F13_SKIP_PREFLIGHT=1 \
    "F13_GENERATED_DIR=${TMPDIR_WORK}/gen" \
    CHAT_BACKEND=mock FRONTEND_PORT=9999 CORE_PORT=8000 \
    "${BIN}" --reset --dry-run
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Dry-run flag
# ---------------------------------------------------------------------------

@test "dry-run output contains 'Dry-run mode'" {
  run env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry-run"* ]]
}

# ---------------------------------------------------------------------------
# Output contains summary
# ---------------------------------------------------------------------------

@test "summary box shows Frontend URL" {
  run env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost:9999"* ]]
}

@test "summary box shows API URL" {
  run env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost:8000"* ]]
}

# ---------------------------------------------------------------------------
# Idempotency / re-run (S12)
# ---------------------------------------------------------------------------

@test "dry-run creates a .state file" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  [ -f "${TMPDIR_WORK}/gen/.state" ]
}

@test ".state file contains CHAT_BACKEND" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run grep '^CHAT_BACKEND=mock' "${TMPDIR_WORK}/gen/.state"
  [ "$status" -eq 0 ]
}

@test "re-run with keep action succeeds" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=keep "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"localhost:9999"* ]]
}

@test "re-run with edit action re-renders config" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=edit "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [ -f "${TMPDIR_WORK}/gen/docker-compose.yml" ]
}

@test "re-run with edit preserves feedback_db.secret (postgres volume stays in sync)" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  local _orig
  _orig="$(< "${TMPDIR_WORK}/gen/secrets/feedback_db.secret")"
  [ -n "${_orig}" ]

  env "${NI_ENV[@]}" F13_STATE_ACTION=edit "${BIN}" --dry-run

  local _after
  _after="$(< "${TMPDIR_WORK}/gen/secrets/feedback_db.secret")"
  [ "${_orig}" = "${_after}" ]
}

@test "re-run with reset action wipes and re-generates" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=reset "${BIN}" --dry-run
  [ "$status" -eq 0 ]
  [ -f "${TMPDIR_WORK}/gen/docker-compose.yml" ]
}

# ---------------------------------------------------------------------------
# --emit-events mode (S18)
# ---------------------------------------------------------------------------

@test "--detect-state emits state exists=false when no .state file" {
  run env F13_GENERATED_DIR="${TMPDIR_WORK}/gen" \
      "${BIN}" --non-interactive --emit-events --detect-state
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"state"'* ]]
  [[ "$output" == *'"exists":"false"'* ]]
}

@test "--detect-state emits state exists=true when .state file present" {
  mkdir -p "${TMPDIR_WORK}/gen"
  cat > "${TMPDIR_WORK}/gen/.state" <<'STATEOF'
PRESET=core+frontend+chat
CHAT_BACKEND=mock
OLLAMA_MODEL=
FRONTEND_PORT=9999
CORE_PORT=8000
TIMESTAMP=2024-01-01T00:00:00Z
STATEOF
  run env F13_GENERATED_DIR="${TMPDIR_WORK}/gen" \
      "${BIN}" --non-interactive --emit-events --detect-state
  [ "$status" -eq 0 ]
  [[ "$output" == *'"exists":"true"'* ]]
  [[ "$output" == *'"backend":"mock"'* ]]
  [[ "$output" == *'"frontend_port":"9999"'* ]]
}

@test "--check-port emits free for an unbound high port" {
  run "${BIN}" --non-interactive --emit-events --check-port 59876
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"port"'* ]]
  [[ "$output" == *'"port":"59876"'* ]]
  # port 59876 is almost certainly free in CI
  [[ "$output" == *'"status":"free"'* ]]
}

@test "--list-models emits not-running when Ollama unreachable" {
  # In CI there is no Ollama server; ollama::is_running returns 1.
  run "${BIN}" --non-interactive --emit-events --list-models
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"models"'* ]]
  [[ "$output" == *'"status":"not-running"'* ]]
}

@test "--emit-events dry-run emits done status=ok" {
  run env "${NI_ENV[@]}" "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"done"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
}

@test "--emit-events dry-run emits step events for render" {
  run env "${NI_ENV[@]}" "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"render"'* ]]
}

# ---------------------------------------------------------------------------
# keep path emits skipped events (S34)
# ---------------------------------------------------------------------------

@test "keep path with --emit-events emits skipped:true for secrets" {
  # First run to create .state file
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  # Second run (keep) — emit-events + dry-run to skip compose::up
  run env "${NI_ENV[@]}" F13_STATE_ACTION=keep "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"secrets"'* ]]
  [[ "$output" == *'"skipped":"true"'* ]]
}

@test "keep path with --emit-events emits skipped:true for render" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=keep "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"render"'* ]]
  [[ "$output" == *'"skipped":"true"'* ]]
}

@test "keep path with --emit-events emits skipped:true for build" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=keep "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"build"'* ]]
  [[ "$output" == *'"skipped":"true"'* ]]
}

@test "keep path with --emit-events emits done status=ok" {
  env "${NI_ENV[@]}" "${BIN}" --dry-run
  run env "${NI_ENV[@]}" F13_STATE_ACTION=keep "${BIN}" --emit-events --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"done"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
}
