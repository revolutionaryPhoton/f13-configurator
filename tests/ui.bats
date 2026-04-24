#!/usr/bin/env bats
# Smoke tests for lib/ui.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/ui.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/ui.sh defines ui::ok function" {
  run bash -c "source '${LIB_DIR}/ui.sh'; declare -f ui::ok > /dev/null"
  [ "$status" -eq 0 ]
}
