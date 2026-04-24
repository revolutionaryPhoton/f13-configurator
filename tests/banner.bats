#!/usr/bin/env bats
# Smoke tests for lib/banner.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/banner.sh sources without error" {
  run bash -c "source '${LIB_DIR}/banner.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/banner.sh defines ui::banner function" {
  run bash -c "source '${LIB_DIR}/banner.sh'; declare -f ui::banner > /dev/null"
  [ "$status" -eq 0 ]
}
