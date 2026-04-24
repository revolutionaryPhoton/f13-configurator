#!/usr/bin/env bats
# Smoke tests for lib/secrets.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/secrets.sh sources without error" {
  run bash -c "source '${LIB_DIR}/secrets.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/secrets.sh defines secret::gen function" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; declare -f secret::gen > /dev/null"
  [ "$status" -eq 0 ]
}
