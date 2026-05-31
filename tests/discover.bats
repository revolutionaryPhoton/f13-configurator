#!/usr/bin/env bats
# Tests for lib/discover.sh (S52)

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

setup() {
  TMPDIR_WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "${TMPDIR_WORK}"
}

# ---------------------------------------------------------------------------
# F13_GENERATED_DIR override
# ---------------------------------------------------------------------------

@test "returns F13_GENERATED_DIR unconditionally when set" {
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    F13_GENERATED_DIR='${TMPDIR_WORK}/custom' discover::generated_dir ''
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${TMPDIR_WORK}/custom" ]
}

@test "F13_GENERATED_DIR wins over dev path even when dev compose file present" {
  local gen="${TMPDIR_WORK}/project/generated"
  mkdir -p "${gen}"
  touch "${gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    F13_GENERATED_DIR='${TMPDIR_WORK}/override' \
      discover::generated_dir '${TMPDIR_WORK}/project/bin'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${TMPDIR_WORK}/override" ]
}

# ---------------------------------------------------------------------------
# Dev mode (SCRIPT_DIR/../generated)
# ---------------------------------------------------------------------------

@test "returns dev path when SCRIPT_DIR/../generated has docker-compose.yml" {
  local fake_bin="${TMPDIR_WORK}/project/bin"
  local gen="${TMPDIR_WORK}/project/generated"
  mkdir -p "${fake_bin}" "${gen}"
  touch "${gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/nomacos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/nolinux' \
      discover::generated_dir '${fake_bin}'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${gen}" ]
}

@test "dev path takes priority over bundled paths when compose file present" {
  local fake_bin="${TMPDIR_WORK}/project/bin"
  local gen="${TMPDIR_WORK}/project/generated"
  local macos_gen="${TMPDIR_WORK}/macos/generated"
  mkdir -p "${fake_bin}" "${gen}" "${macos_gen}"
  touch "${gen}/docker-compose.yml" "${macos_gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/macos' \
      discover::generated_dir '${fake_bin}'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${gen}" ]
}

@test "skips dev path when docker-compose.yml absent and falls through to macOS" {
  local fake_bin="${TMPDIR_WORK}/project/bin"
  mkdir -p "${fake_bin}" "${TMPDIR_WORK}/project/generated"
  # No docker-compose.yml in dev path
  local macos_gen="${TMPDIR_WORK}/macos/generated"
  mkdir -p "${macos_gen}"
  touch "${macos_gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/macos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/nolinux' \
      discover::generated_dir '${fake_bin}'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${macos_gen}" ]
}

# ---------------------------------------------------------------------------
# macOS bundled path
# ---------------------------------------------------------------------------

@test "returns macOS bundled path when docker-compose.yml found there" {
  local macos_gen="${TMPDIR_WORK}/macos/generated"
  mkdir -p "${macos_gen}"
  touch "${macos_gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/macos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/nolinux' \
      discover::generated_dir '${TMPDIR_WORK}/nobin'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${macos_gen}" ]
}

@test "macOS path takes priority over Linux path" {
  local macos_gen="${TMPDIR_WORK}/macos/generated"
  local linux_gen="${TMPDIR_WORK}/linux/generated"
  mkdir -p "${macos_gen}" "${linux_gen}"
  touch "${macos_gen}/docker-compose.yml" "${linux_gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/macos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/linux' \
      discover::generated_dir '${TMPDIR_WORK}/nobin'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${macos_gen}" ]
}

# ---------------------------------------------------------------------------
# Linux bundled path
# ---------------------------------------------------------------------------

@test "returns Linux bundled path when macOS path absent" {
  local linux_gen="${TMPDIR_WORK}/linux/generated"
  mkdir -p "${linux_gen}"
  touch "${linux_gen}/docker-compose.yml"
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/nomacos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/linux' \
      discover::generated_dir '${TMPDIR_WORK}/nobin'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${linux_gen}" ]
}

# ---------------------------------------------------------------------------
# No candidate found
# ---------------------------------------------------------------------------

@test "returns 1 when no candidate has docker-compose.yml" {
  run bash -c "
    source '${LIB_DIR}/discover.sh'
    _F13_MACOS_DATA_DIR='${TMPDIR_WORK}/nomacos' \
    _F13_LINUX_DATA_DIR='${TMPDIR_WORK}/nolinux' \
      discover::generated_dir '${TMPDIR_WORK}/nobin'
  "
  [ "$status" -eq 1 ]
}
