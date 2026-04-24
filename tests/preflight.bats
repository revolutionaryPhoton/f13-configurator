#!/usr/bin/env bats
# Tests for lib/preflight.sh
# Internal helpers (preflight::_has_cmd etc.) are overridden per test to
# avoid real docker/command-not-found issues in the CI environment.

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/preflight.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/preflight.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/preflight.sh defines preflight::run function" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    declare -f preflight::run > /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "lib/preflight.sh defines all internal helpers" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    for fn in preflight::_has_cmd preflight::_docker_info \
              preflight::_docker_compose_ver preflight::_disk_free_kb; do
      declare -f \"\$fn\" > /dev/null || { echo \"MISSING: \$fn\"; exit 1; }
    done
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# All checks passing (all helpers stubbed to succeed)
# ---------------------------------------------------------------------------

@test "preflight::run passes when all checks succeed" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 0 ]
}

@test "preflight::run output lists docker as ok when passing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker"* ]]
}

# ---------------------------------------------------------------------------
# docker checks
# ---------------------------------------------------------------------------

@test "preflight::run fails when docker is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      [[ \"\$1\" == 'docker' ]] && return 1
      return 0
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker not found"* ]]
}

@test "preflight::run fails when docker is not running" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 1; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"not running"* ]]
}

@test "preflight::run fails when docker compose is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 1; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"docker compose not found"* ]]
}

@test "preflight::run skips compose check when docker is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      [[ \"\$1\" == 'docker' ]] && return 1
      return 0
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 1; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  # Only one failure counted (docker), not two (docker + compose)
  [[ "$output" == *"1 preflight check"* ]]
}

# ---------------------------------------------------------------------------
# bash version check
# ---------------------------------------------------------------------------

@test "preflight::run fails when bash major version is 3" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=3
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"bash < 4.0"* ]]
}

@test "preflight::run passes when bash major version is 4" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    preflight::run
  "
  [ "$status" -eq 0 ]
}

@test "preflight::run passes when bash major version is 5" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=5
    preflight::run
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Required tool checks
# ---------------------------------------------------------------------------

@test "preflight::run fails when curl is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      [[ \"\$1\" == 'curl' ]] && return 1
      return 0
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl not found"* ]]
}

@test "preflight::run fails when envsubst is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      [[ \"\$1\" == 'envsubst' ]] && return 1
      return 0
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"envsubst not found"* ]]
}

@test "preflight::run fails when awk is missing" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      [[ \"\$1\" == 'awk' ]] && return 1
      return 0
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"awk not found"* ]]
}

# ---------------------------------------------------------------------------
# Disk space check
# ---------------------------------------------------------------------------

@test "preflight::run fails when disk space is below 2 GB" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '524288'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"free"* ]]
}

@test "preflight::run passes when disk space equals exactly 2 GB (not strictly less)" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '2097152'; }
    export _PREFLIGHT_BASH_MAJOR=4
    preflight::run
  "
  # Exactly 2 GB: check uses -lt so this passes (>= threshold)
  [ "$status" -eq 0 ]
}

@test "preflight::run passes when disk space is above 2 GB" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd()            { return 0; }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '3145728'; }
    export _PREFLIGHT_BASH_MAJOR=4
    preflight::run
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Multiple failures
# ---------------------------------------------------------------------------

@test "preflight::run counts multiple failures correctly" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/preflight.sh'
    preflight::_has_cmd() {
      case \"\$1\" in
        curl|envsubst) return 1 ;;
        *) return 0 ;;
      esac
    }
    preflight::_docker_info()        { return 0; }
    preflight::_docker_compose_ver() { return 0; }
    preflight::_disk_free_kb()       { printf '524288'; }
    export _PREFLIGHT_BASH_MAJOR=4
    export NO_COLOR=1
    preflight::run
  "
  [ "$status" -eq 1 ]
  # 3 failures: curl, envsubst, disk
  [[ "$output" == *"3 preflight check"* ]]
}
