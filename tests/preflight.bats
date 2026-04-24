#!/usr/bin/env bats
# Smoke tests for lib/preflight.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/preflight.sh sources without error" {
  run bash -c "source '${LIB_DIR}/preflight.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/preflight.sh defines preflight::run function" {
  run bash -c "source '${LIB_DIR}/preflight.sh'; declare -f preflight::run > /dev/null"
  [ "$status" -eq 0 ]
}
