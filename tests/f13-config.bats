#!/usr/bin/env bats
# Smoke tests for bin/f13-config

BIN="${BATS_TEST_DIRNAME}/../bin/f13-config"

@test "bin/f13-config --help exits 0" {
  run "${BIN}" --help
  [ "$status" -eq 0 ]
}

@test "bin/f13-config --help prints usage" {
  run "${BIN}" --help
  [[ "$output" == *"Usage:"* ]]
}
