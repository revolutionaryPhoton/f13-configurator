#!/usr/bin/env bats
# Tests for lib/compose.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/compose.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/compose.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::up" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    declare -f compose::up > /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::wait_healthy" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    declare -f compose::wait_healthy > /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::down" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    declare -f compose::down > /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::_docker_compose helper" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    declare -f compose::_docker_compose > /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "lib/compose.sh defines compose::_curl_health helper" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    declare -f compose::_curl_health > /dev/null
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# compose::wait_healthy — mocked
# ---------------------------------------------------------------------------

@test "compose::wait_healthy returns 0 when health endpoint responds immediately" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    compose::_curl_health() { return 0; }
    export CORE_PORT=8000
    export NO_COLOR=1
    compose::wait_healthy
  "
  [ "$status" -eq 0 ]
}

@test "compose::wait_healthy returns 1 when endpoint never responds (short timeout)" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    compose::_curl_health() { return 1; }
    # Override sleep to avoid real delays
    sleep() { :; }
    export CORE_PORT=8000
    export _COMPOSE_WAIT_MAX=2
    export NO_COLOR=1
    compose::wait_healthy
  "
  [ "$status" -eq 1 ]
}

@test "compose::wait_healthy output contains 'healthy' on success" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    compose::_curl_health() { return 0; }
    export CORE_PORT=8000
    export NO_COLOR=1
    compose::wait_healthy
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"healthy"* ]]
}

@test "compose::wait_healthy uses CORE_PORT env var" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    # Record the URL that _curl_health receives
    compose::_curl_health() {
      echo \"URL=\$1\"
      return 0
    }
    export CORE_PORT=12345
    export NO_COLOR=1
    compose::wait_healthy
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"12345"* ]]
}

# ---------------------------------------------------------------------------
# compose::up — mocked docker compose
# ---------------------------------------------------------------------------

@test "compose::up calls docker compose up -d" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    CALLED_ARGS=''
    compose::_docker_compose() { CALLED_ARGS=\"\$*\"; }
    compose::wait_healthy()    { return 0; }
    export GEN_DIR='/tmp/fake-gen'
    export CORE_PORT=8000
    export FRONTEND_PORT=9999
    export NO_COLOR=1
    # Create fake compose files so the function proceeds
    mkdir -p /tmp/fake-gen
    touch /tmp/fake-gen/docker-compose.yml /tmp/fake-gen/.env
    compose::up 2>/dev/null || true
    echo \"ARGS=\${CALLED_ARGS}\"
    rm -rf /tmp/fake-gen
  "
  [[ "$output" == *"up"* ]]
  [[ "$output" == *"-d"* ]]
}

@test "compose::up prints success box with Frontend URL" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    compose::_docker_compose() { :; }
    compose::wait_healthy()    { return 0; }
    export GEN_DIR='/tmp/fake-gen2'
    export CORE_PORT=8000
    export FRONTEND_PORT=9999
    export NO_COLOR=1
    mkdir -p /tmp/fake-gen2
    touch /tmp/fake-gen2/docker-compose.yml /tmp/fake-gen2/.env
    compose::up
    rm -rf /tmp/fake-gen2
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Frontend"* ]]
  [[ "$output" == *"9999"* ]]
}

@test "compose::up prints success box with API URL" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    compose::_docker_compose() { :; }
    compose::wait_healthy()    { return 0; }
    export GEN_DIR='/tmp/fake-gen3'
    export CORE_PORT=8000
    export FRONTEND_PORT=9999
    export NO_COLOR=1
    mkdir -p /tmp/fake-gen3
    touch /tmp/fake-gen3/docker-compose.yml /tmp/fake-gen3/.env
    compose::up
    rm -rf /tmp/fake-gen3
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"API"* ]]
  [[ "$output" == *"8000"* ]]
}

# ---------------------------------------------------------------------------
# HF3: compose::up frontend-image precondition
# ---------------------------------------------------------------------------

@test "compose::up errors out if frontend image is missing locally" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    set +e   # AFTER sourcing — compose.sh's top-level 'set -e' would
             # otherwise re-enable itself and abort on the return 1.
    compose::_docker_compose()      { echo 'should not reach compose'; exit 99; }
    compose::wait_healthy()         { return 0; }
    compose::_docker_image_inspect() { return 1; }  # image missing
    export GEN_DIR='/tmp/fake-hf3-missing'
    export NO_COLOR=1
    mkdir -p /tmp/fake-hf3-missing
    touch /tmp/fake-hf3-missing/docker-compose.yml
    printf 'FRONTEND_IMAGE=f13-frontend:v2.0.0_based\n' \
      > /tmp/fake-hf3-missing/.env
    compose::up 2>&1
    echo \"STATUS=\$?\"
    rm -rf /tmp/fake-hf3-missing
  "
  [[ "$output" == *"Frontend image"* ]]
  [[ "$output" == *"missing locally"* ]]
  [[ "$output" == *"STATUS=1"* ]]
  [[ "$output" != *"should not reach compose"* ]]
}

@test "compose::up proceeds when frontend image is present" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    REACHED_COMPOSE=0
    compose::_docker_compose()      { REACHED_COMPOSE=1; }
    compose::wait_healthy()         { return 0; }
    compose::_docker_image_inspect() { return 0; }  # image present
    export GEN_DIR='/tmp/fake-hf3-present'
    export CORE_PORT=8000
    export FRONTEND_PORT=9999
    export NO_COLOR=1
    mkdir -p /tmp/fake-hf3-present
    touch /tmp/fake-hf3-present/docker-compose.yml
    printf 'FRONTEND_IMAGE=f13-frontend:v2.0.0_based\n' \
      > /tmp/fake-hf3-present/.env
    compose::up
    echo \"REACHED=\${REACHED_COMPOSE}\"
    rm -rf /tmp/fake-hf3-present
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"REACHED=1"* ]]
}

@test "compose::up sets COMPOSE_ERROR_MESSAGE when image is missing (HF3)" {
  # The bin/f13-config --compose-up handler reads COMPOSE_ERROR_MESSAGE
  # to surface the specific reason in the done event the GUI consumes.
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    set +e
    compose::_docker_compose()      { :; }
    compose::wait_healthy()         { return 0; }
    compose::_docker_image_inspect() { return 1; }
    export GEN_DIR='/tmp/fake-hf3-msg'
    export NO_COLOR=1
    mkdir -p /tmp/fake-hf3-msg
    touch /tmp/fake-hf3-msg/docker-compose.yml
    printf 'FRONTEND_IMAGE=f13-frontend:v2.0.0_based\n' > /tmp/fake-hf3-msg/.env
    compose::up >/dev/null 2>&1
    printf 'MSG=%s' \"\${COMPOSE_ERROR_MESSAGE:-}\"
    rm -rf /tmp/fake-hf3-msg
  "
  [[ "$output" == *"MSG=Frontend image 'f13-frontend:v2.0.0_based' is missing locally"* ]]
}

@test "compose::up skips precondition when FRONTEND_IMAGE not in .env" {
  # Defensive: if someone hand-edits the env file and removes the var,
  # don't block them — let compose handle the resulting error.
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    REACHED_COMPOSE=0
    compose::_docker_compose()      { REACHED_COMPOSE=1; }
    compose::wait_healthy()         { return 0; }
    compose::_docker_image_inspect() { return 1; }  # would say missing
    export GEN_DIR='/tmp/fake-hf3-noenv'
    export CORE_PORT=8000
    export FRONTEND_PORT=9999
    export NO_COLOR=1
    mkdir -p /tmp/fake-hf3-noenv
    touch /tmp/fake-hf3-noenv/docker-compose.yml
    : > /tmp/fake-hf3-noenv/.env
    compose::up
    echo \"REACHED=\${REACHED_COMPOSE}\"
    rm -rf /tmp/fake-hf3-noenv
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"REACHED=1"* ]]
}

# ---------------------------------------------------------------------------
# compose::down — mocked
# ---------------------------------------------------------------------------

@test "compose::down calls docker compose down" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    CALLED_ARGS=''
    compose::_docker_compose() { CALLED_ARGS=\"\$*\"; echo \"ARGS=\${CALLED_ARGS}\"; }
    export GEN_DIR='/tmp/fake-down'
    mkdir -p /tmp/fake-down
    touch /tmp/fake-down/docker-compose.yml
    compose::down
    rm -rf /tmp/fake-down
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"down"* ]]
}

# ---------------------------------------------------------------------------
# Integration test (requires docker)
# ---------------------------------------------------------------------------

@test "compose::up and compose::down integration (docker required)" {
  if ! docker info >/dev/null 2>&1; then
    skip "docker not available"
  fi
  # Just verify the commands don't error on a trivial compose file
  local tmp
  tmp="$(mktemp -d)"
  cat > "${tmp}/docker-compose.yml" <<'COMPOSE'
services:
  hello:
    image: hello-world
COMPOSE
  printf '' > "${tmp}/.env"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/compose.sh'
    export GEN_DIR='${tmp}'
    export CORE_PORT=19999
    export FRONTEND_PORT=19998
    export NO_COLOR=1
    # Override wait_healthy to skip actual health poll
    compose::wait_healthy() { return 0; }
    compose::up
  "
  docker compose -f "${tmp}/docker-compose.yml" down --remove-orphans 2>/dev/null || true
  rm -rf "${tmp}"
  [ "$status" -eq 0 ]
}
