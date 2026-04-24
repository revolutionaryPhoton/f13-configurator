#!/usr/bin/env bats
# Smoke tests for lib/prompt.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/prompt.sh sources without error" {
  run bash -c "source '${LIB_DIR}/prompt.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/prompt.sh defines prompt::ask function" {
  run bash -c "source '${LIB_DIR}/prompt.sh'; declare -f prompt::ask > /dev/null"
  [ "$status" -eq 0 ]
}
