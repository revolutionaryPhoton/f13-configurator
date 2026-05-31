#!/usr/bin/env bats
# Tests for bin/f13-reset and bin/f13-stop — F13_GENERATED_DIR (S32) + discovery (S52)

RESET_BIN="${BATS_TEST_DIRNAME}/../bin/f13-reset"
STOP_BIN="${BATS_TEST_DIRNAME}/../bin/f13-stop"

setup() {
  TMPDIR_WORK="$(mktemp -d)"

  # Fake docker binary that always exits 0 — we test dir plumbing, not docker.
  mkdir -p "${TMPDIR_WORK}/fakebin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${TMPDIR_WORK}/fakebin/docker"
  chmod +x "${TMPDIR_WORK}/fakebin/docker"
  export PATH="${TMPDIR_WORK}/fakebin:${PATH}"

  # Minimal generated dir that satisfies the existence guard.
  GEN_DIR="${TMPDIR_WORK}/generated"
  mkdir -p "${GEN_DIR}"
  touch "${GEN_DIR}/docker-compose.yml"
  touch "${GEN_DIR}/.env"
}

teardown() {
  rm -rf "${TMPDIR_WORK}"
}

# ---------------------------------------------------------------------------
# f13-reset
# ---------------------------------------------------------------------------

@test "f13-reset honours F13_GENERATED_DIR and removes the directory" {
  run env F13_GENERATED_DIR="${GEN_DIR}" "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [ ! -d "${GEN_DIR}" ]
}

@test "f13-reset exits 1 when custom dir has no docker-compose.yml" {
  local empty_dir="${TMPDIR_WORK}/empty"
  mkdir -p "${empty_dir}"
  run env F13_GENERATED_DIR="${empty_dir}" "${RESET_BIN}"
  [ "$status" -eq 1 ]
}

@test "f13-reset emits compose reset events when F13_EMIT_EVENTS=1" {
  run env F13_GENERATED_DIR="${GEN_DIR}" F13_EMIT_EVENTS=1 "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"compose"'* ]]
  [[ "$output" == *'"action":"reset"'* ]]
}

@test "f13-reset emits done ok event when F13_EMIT_EVENTS=1" {
  run env F13_GENERATED_DIR="${GEN_DIR}" F13_EMIT_EVENTS=1 "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"done"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
}

@test "f13-reset leaves other temp dirs untouched" {
  local other_dir="${TMPDIR_WORK}/other"
  mkdir -p "${other_dir}"
  run env F13_GENERATED_DIR="${GEN_DIR}" "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [ -d "${other_dir}" ]
}

# ---------------------------------------------------------------------------
# f13-stop
# ---------------------------------------------------------------------------

@test "f13-stop honours F13_GENERATED_DIR and exits 0" {
  run env F13_GENERATED_DIR="${GEN_DIR}" "${STOP_BIN}"
  [ "$status" -eq 0 ]
}

@test "f13-stop does not remove the generated directory" {
  run env F13_GENERATED_DIR="${GEN_DIR}" "${STOP_BIN}"
  [ "$status" -eq 0 ]
  [ -d "${GEN_DIR}" ]
}

@test "f13-stop exits 1 when custom dir has no docker-compose.yml" {
  local empty_dir="${TMPDIR_WORK}/empty"
  mkdir -p "${empty_dir}"
  run env F13_GENERATED_DIR="${empty_dir}" "${STOP_BIN}"
  [ "$status" -eq 1 ]
}

@test "f13-stop emits compose down events when F13_EMIT_EVENTS=1" {
  run env F13_GENERATED_DIR="${GEN_DIR}" F13_EMIT_EVENTS=1 "${STOP_BIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"compose"'* ]]
  [[ "$output" == *'"action":"down"'* ]]
}

@test "f13-stop emits done ok event when F13_EMIT_EVENTS=1" {
  run env F13_GENERATED_DIR="${GEN_DIR}" F13_EMIT_EVENTS=1 "${STOP_BIN}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"done"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
}

# ---------------------------------------------------------------------------
# S52: bundled path discovery (macOS + Linux appLocalDataDir)
# Rely on no generated/ dir existing at the binary's dev path
# (/workspace/configurator_v1/generated) — verified in Docker loop.
# ---------------------------------------------------------------------------

@test "f13-reset discovers macOS bundled path when dev path absent" {
  local macos_gen="${TMPDIR_WORK}/macos_data/generated"
  mkdir -p "${macos_gen}"
  touch "${macos_gen}/docker-compose.yml"
  touch "${macos_gen}/.env"
  run env \
    "_F13_MACOS_DATA_DIR=${TMPDIR_WORK}/macos_data" \
    "_F13_LINUX_DATA_DIR=${TMPDIR_WORK}/no_linux" \
    "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [ ! -d "${macos_gen}" ]
}

@test "f13-stop discovers macOS bundled path when dev path absent" {
  local macos_gen="${TMPDIR_WORK}/macos_data/generated"
  mkdir -p "${macos_gen}"
  touch "${macos_gen}/docker-compose.yml"
  touch "${macos_gen}/.env"
  run env \
    "_F13_MACOS_DATA_DIR=${TMPDIR_WORK}/macos_data" \
    "_F13_LINUX_DATA_DIR=${TMPDIR_WORK}/no_linux" \
    "${STOP_BIN}"
  [ "$status" -eq 0 ]
  [ -d "${macos_gen}" ]
}

@test "f13-reset discovers Linux bundled path when dev and macOS paths absent" {
  local linux_gen="${TMPDIR_WORK}/linux_data/generated"
  mkdir -p "${linux_gen}"
  touch "${linux_gen}/docker-compose.yml"
  touch "${linux_gen}/.env"
  run env \
    "_F13_MACOS_DATA_DIR=${TMPDIR_WORK}/no_macos" \
    "_F13_LINUX_DATA_DIR=${TMPDIR_WORK}/linux_data" \
    "${RESET_BIN}"
  [ "$status" -eq 0 ]
  [ ! -d "${linux_gen}" ]
}

@test "f13-reset exits 1 with helpful message when no stack found anywhere" {
  run env \
    "_F13_MACOS_DATA_DIR=${TMPDIR_WORK}/no_macos" \
    "_F13_LINUX_DATA_DIR=${TMPDIR_WORK}/no_linux" \
    "${RESET_BIN}"
  [ "$status" -eq 1 ]
  [[ "${output}" == *"No generated stack found"* ]]
}
