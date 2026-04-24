#!/usr/bin/env bats
# Tests for lib/ollama.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/ollama.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ollama.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/ollama.sh defines ollama::is_running" {
  run bash -c "source '${LIB_DIR}/ollama.sh'; declare -f ollama::is_running > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/ollama.sh defines ollama::list_models" {
  run bash -c "source '${LIB_DIR}/ollama.sh'; declare -f ollama::list_models > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/ollama.sh defines ollama::host_url_for_docker" {
  run bash -c "source '${LIB_DIR}/ollama.sh'; declare -f ollama::host_url_for_docker > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/ollama.sh defines ollama::_curl_tags internal helper" {
  run bash -c "source '${LIB_DIR}/ollama.sh'; declare -f ollama::_curl_tags > /dev/null"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# ollama::is_running
# ---------------------------------------------------------------------------

@test "ollama::is_running returns 0 when curl stub succeeds" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '{\"models\":[]}'; }
    ollama::is_running
  "
  [ "$status" -eq 0 ]
}

@test "ollama::is_running returns 1 when curl stub fails" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { return 1; }
    ollama::is_running
  "
  [ "$status" -eq 1 ]
}

@test "ollama::is_running produces no stdout output" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '{\"models\":[]}'; }
    ollama::is_running
  "
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ollama::is_running suppresses curl stderr" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf 'error msg' >&2; return 1; }
    ollama::is_running
  " 2>/dev/null
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# ollama::list_models — happy path
# ---------------------------------------------------------------------------

@test "ollama::list_models returns 0 with valid response" {
  export MOCK_TAGS='{"models":[{"name":"llama2:7b","size":123}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
}

@test "ollama::list_models prints model name for single-model response" {
  export MOCK_TAGS='{"models":[{"name":"mistral:7b","size":123}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"mistral:7b"* ]]
}

@test "ollama::list_models prints two lines for two-model response" {
  export MOCK_TAGS='{"models":[{"name":"llama2:7b","size":1},{"name":"gemma4:31b-cloud","size":2}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "ollama::list_models output contains first model name" {
  export MOCK_TAGS='{"models":[{"name":"llama2:7b","size":1},{"name":"gemma4:31b-cloud","size":2}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"llama2:7b"* ]]
}

@test "ollama::list_models output contains second model name" {
  export MOCK_TAGS='{"models":[{"name":"llama2:7b","size":1},{"name":"gemma4:31b-cloud","size":2}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"gemma4:31b-cloud"* ]]
}

@test "ollama::list_models strips JSON syntax from output" {
  export MOCK_TAGS='{"models":[{"name":"phi3:mini","size":1}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *'"name"'* ]]
  [[ "$output" != *'{'* ]]
}

@test "ollama::list_models handles model with no tag suffix" {
  export MOCK_TAGS='{"models":[{"name":"llama2","size":1}]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"llama2"* ]]
}

# ---------------------------------------------------------------------------
# ollama::list_models — empty / error cases
# ---------------------------------------------------------------------------

@test "ollama::list_models returns 1 when curl stub fails" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { return 1; }
    ollama::list_models
  "
  [ "$status" -eq 1 ]
}

@test "ollama::list_models produces no output when curl fails" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { return 1; }
    ollama::list_models
  "
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "ollama::list_models produces empty output for empty models array" {
  export MOCK_TAGS='{"models":[]}'
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::_curl_tags() { printf '%s' \"\${MOCK_TAGS}\"; }
    ollama::list_models
  "
  [ "$status" -eq 0 ]
  [[ -z "$(printf '%s' "${output}" | tr -d '[:space:]')" ]]
}

# ---------------------------------------------------------------------------
# ollama::host_url_for_docker
# ---------------------------------------------------------------------------

@test "ollama::host_url_for_docker prints a non-empty URL" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::host_url_for_docker
  "
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "ollama::host_url_for_docker URL contains host.docker.internal" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::host_url_for_docker
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"host.docker.internal"* ]]
}

@test "ollama::host_url_for_docker URL contains port 11434" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::host_url_for_docker
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"11434"* ]]
}

@test "ollama::host_url_for_docker URL ends with /v1" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::host_url_for_docker
  "
  [ "$status" -eq 0 ]
  [[ "$output" == */v1 ]]
}

@test "ollama::host_url_for_docker URL starts with http" {
  run bash -c "
    source '${LIB_DIR}/ollama.sh'
    ollama::host_url_for_docker
  "
  [ "$status" -eq 0 ]
  [[ "$output" == http* ]]
}
