#!/usr/bin/env bats
# Smoke tests for lib/state.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/state.sh sources without error" {
  run bash -c "source '${LIB_DIR}/state.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/state.sh defines state::read function" {
  run bash -c "source '${LIB_DIR}/state.sh'; declare -f state::read > /dev/null"
  [ "$status" -eq 0 ]
}
