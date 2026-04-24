#!/usr/bin/env bats
# Smoke tests for lib/ollama.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/ollama.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ollama.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/ollama.sh defines ollama::is_running function" {
  run bash -c "source '${LIB_DIR}/ollama.sh'; declare -f ollama::is_running > /dev/null"
  [ "$status" -eq 0 ]
}
