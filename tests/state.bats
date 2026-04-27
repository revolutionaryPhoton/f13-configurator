#!/usr/bin/env bats
# Tests for lib/state.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMPDIR_TEST}"
}

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/state.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/state.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/state.sh defines state::read function" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/state.sh'; declare -f state::read > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/state.sh defines state::write function" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/state.sh'; declare -f state::write > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/state.sh defines state::check function" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/state.sh'; declare -f state::check > /dev/null"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# state::write
# ---------------------------------------------------------------------------

@test "state::write creates file with CHAT_BACKEND" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='mock'
    OLLAMA_MODEL=''
    FRONTEND_PORT='9999'
    CORE_PORT='8000'
    state::write '${TMPDIR_TEST}/.state'
    grep -q '^CHAT_BACKEND=mock' '${TMPDIR_TEST}/.state'
  "
  [ "$status" -eq 0 ]
}

@test "state::write creates file with FRONTEND_PORT" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='mock'
    OLLAMA_MODEL=''
    FRONTEND_PORT='7777'
    CORE_PORT='8000'
    state::write '${TMPDIR_TEST}/.state'
    grep -q '^FRONTEND_PORT=7777' '${TMPDIR_TEST}/.state'
  "
  [ "$status" -eq 0 ]
}

@test "state::write creates file with TIMESTAMP" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='mock'
    OLLAMA_MODEL=''
    FRONTEND_PORT='9999'
    CORE_PORT='8000'
    state::write '${TMPDIR_TEST}/.state'
    grep -q '^TIMESTAMP=' '${TMPDIR_TEST}/.state'
  "
  [ "$status" -eq 0 ]
}

@test "state::write creates file with OLLAMA_MODEL for ollama backend" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='ollama'
    OLLAMA_MODEL='gemma4:31b-cloud'
    FRONTEND_PORT='9999'
    CORE_PORT='8000'
    state::write '${TMPDIR_TEST}/.state'
    grep -q '^OLLAMA_MODEL=gemma4:31b-cloud' '${TMPDIR_TEST}/.state'
  "
  [ "$status" -eq 0 ]
}

@test "state::write sets file permissions to 600" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='mock'
    OLLAMA_MODEL=''
    FRONTEND_PORT='9999'
    CORE_PORT='8000'
    state::write '${TMPDIR_TEST}/.state'
    stat -c '%a' '${TMPDIR_TEST}/.state' 2>/dev/null \
      || stat -f '%Lp' '${TMPDIR_TEST}/.state'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "600" ]
}

# ---------------------------------------------------------------------------
# state::read
# ---------------------------------------------------------------------------

@test "state::read returns 1 for missing file" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::read '${TMPDIR_TEST}/nonexistent/.state'
  "
  [ "$status" -eq 1 ]
}

@test "state::read loads CHAT_BACKEND" {
  printf 'CHAT_BACKEND=ollama\nFRONTEND_PORT=8888\nCORE_PORT=9000\n' > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    CHAT_BACKEND=''
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${CHAT_BACKEND}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "ollama" ]
}

@test "state::read loads FRONTEND_PORT" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=7654\nCORE_PORT=8000\n' > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    FRONTEND_PORT=''
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${FRONTEND_PORT}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "7654" ]
}

@test "state::read loads CORE_PORT" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=7777\n' > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    CORE_PORT=''
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${CORE_PORT}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "7777" ]
}

@test "state::read does not clobber env-set CHAT_BACKEND (HF4 regression)" {
  # GUI reconfigure passes CHAT_BACKEND=ollama via env. state::read must
  # not overwrite it with the previously-saved 'mock' from disk.
  printf 'CHAT_BACKEND=mock\nOLLAMA_MODEL=\nFRONTEND_PORT=9999\nCORE_PORT=8000\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    CHAT_BACKEND='ollama'
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${CHAT_BACKEND}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "ollama" ]
}

@test "state::read does not clobber env-set OLLAMA_MODEL (HF4 regression)" {
  printf 'CHAT_BACKEND=ollama\nOLLAMA_MODEL=llama3.2:3b\nFRONTEND_PORT=9999\nCORE_PORT=8000\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    OLLAMA_MODEL='gemma4:31b-cloud'
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${OLLAMA_MODEL}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "gemma4:31b-cloud" ]
}

@test "state::read does not clobber env-set FRONTEND_PORT (HF4 regression)" {
  printf 'CHAT_BACKEND=mock\nOLLAMA_MODEL=\nFRONTEND_PORT=9999\nCORE_PORT=8000\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    FRONTEND_PORT='7777'
    state::read '${TMPDIR_TEST}/.state'
    printf '%s' \"\${FRONTEND_PORT}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "7777" ]
}

@test "state::read still loads from disk when env var is empty" {
  # Interactive `edit` flow: no env vars pre-set, state values must
  # become the prompt defaults.
  printf 'CHAT_BACKEND=ollama\nOLLAMA_MODEL=llama3.2:3b\nFRONTEND_PORT=8888\nCORE_PORT=8000\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    CHAT_BACKEND=''
    OLLAMA_MODEL=''
    FRONTEND_PORT=''
    state::read '${TMPDIR_TEST}/.state'
    printf 'b=%s m=%s p=%s' \"\${CHAT_BACKEND}\" \"\${OLLAMA_MODEL}\" \"\${FRONTEND_PORT}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"b=ollama"* ]]
  [[ "$output" == *"m=llama3.2:3b"* ]]
  [[ "$output" == *"p=8888"* ]]
}

@test "state::read round-trips with state::write" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    PRESET='core+frontend+chat'
    CHAT_BACKEND='ollama'
    OLLAMA_MODEL='llama3.2'
    FRONTEND_PORT='9998'
    CORE_PORT='8001'
    state::write '${TMPDIR_TEST}/.state'
    CHAT_BACKEND=''
    FRONTEND_PORT=''
    state::read '${TMPDIR_TEST}/.state'
    printf 'backend=%s port=%s model=%s' \"\${CHAT_BACKEND}\" \"\${FRONTEND_PORT}\" \"\${OLLAMA_MODEL}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"backend=ollama"* ]]
  [[ "$output" == *"port=9998"* ]]
  [[ "$output" == *"model=llama3.2"* ]]
}

# ---------------------------------------------------------------------------
# state::check
# ---------------------------------------------------------------------------

@test "state::check returns 1 when state file does not exist" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::check '${TMPDIR_TEST}'
  "
  [ "$status" -eq 1 ]
}

@test "state::check returns 0 when state file exists" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    F13_CONFIG_NONINTERACTIVE=1
    state::check '${TMPDIR_TEST}'
  "
  [ "$status" -eq 0 ]
}

@test "state::check sets F13_STATE_ACTION=keep in noninteractive mode (default)" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    F13_CONFIG_NONINTERACTIVE=1
    F13_STATE_ACTION=''
    state::check '${TMPDIR_TEST}'
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=keep"* ]]
}

@test "state::check respects F13_STATE_ACTION=edit in noninteractive mode" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    F13_CONFIG_NONINTERACTIVE=1
    F13_STATE_ACTION='edit'
    state::check '${TMPDIR_TEST}'
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=edit"* ]]
}

@test "state::check sets F13_STATE_ACTION=keep with 'k' input" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::check '${TMPDIR_TEST}' <<< 'k'
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=keep"* ]]
}

@test "state::check sets F13_STATE_ACTION=edit with 'e' input" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::check '${TMPDIR_TEST}' <<< 'e'
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=edit"* ]]
}

@test "state::check sets F13_STATE_ACTION=reset with 'r' input" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::check '${TMPDIR_TEST}' <<< 'r'
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=reset"* ]]
}

@test "state::check output contains backend info" {
  printf 'CHAT_BACKEND=ollama\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    F13_CONFIG_NONINTERACTIVE=1
    state::check '${TMPDIR_TEST}'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ollama"* ]]
}

@test "state::check handles EOF on stdin (defaults to keep)" {
  printf 'CHAT_BACKEND=mock\nFRONTEND_PORT=9999\nCORE_PORT=8000\nTIMESTAMP=2026-01-01T00:00:00Z\n' \
    > "${TMPDIR_TEST}/.state"
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/state.sh'
    state::check '${TMPDIR_TEST}' < /dev/null
    printf 'action=%s' \"\${F13_STATE_ACTION}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"action=keep"* ]]
}
