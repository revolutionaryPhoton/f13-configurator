#!/usr/bin/env bats
# Smoke tests for lib/compose.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/compose.sh sources without error" {
  run bash -c "source '${LIB_DIR}/compose.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::up function" {
  run bash -c "source '${LIB_DIR}/compose.sh'; declare -f compose::up > /dev/null"
  [ "$status" -eq 0 ]
}
