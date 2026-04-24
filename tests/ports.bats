#!/usr/bin/env bats
# Smoke tests for lib/ports.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/ports.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ports.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/ports.sh defines ports::is_free function" {
  run bash -c "source '${LIB_DIR}/ports.sh'; declare -f ports::is_free > /dev/null"
  [ "$status" -eq 0 ]
}
