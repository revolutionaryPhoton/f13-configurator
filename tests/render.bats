#!/usr/bin/env bats
# Smoke tests for lib/render.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/render.sh sources without error" {
  run bash -c "source '${LIB_DIR}/render.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/render.sh defines render::file function" {
  run bash -c "source '${LIB_DIR}/render.sh'; declare -f render::file > /dev/null"
  [ "$status" -eq 0 ]
}
