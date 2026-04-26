#!/usr/bin/env bats
# Tests for lib/events.sh (S18)

LIB="${BATS_TEST_DIRNAME}/../lib/events.sh"

setup() {
  source "${LIB}"
}

# ---------------------------------------------------------------------------
# No-op when F13_EMIT_EVENTS is unset
# ---------------------------------------------------------------------------

@test "events::emit is silent when F13_EMIT_EVENTS is unset" {
  unset F13_EMIT_EVENTS
  run events::emit preflight "name=docker" "status=ok"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "events::emit is silent when F13_EMIT_EVENTS is empty string" {
  F13_EMIT_EVENTS="" run events::emit preflight "name=docker" "status=ok"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# JSON output when F13_EMIT_EVENTS=1
# ---------------------------------------------------------------------------

@test "events::emit outputs JSON when F13_EMIT_EVENTS=1" {
  F13_EMIT_EVENTS=1 run events::emit preflight "name=docker" "status=ok"
  [ "$status" -eq 0 ]
  [ "$output" = '{"type":"preflight","name":"docker","status":"ok"}' ]
}

@test "events::emit type-only emits minimal JSON" {
  F13_EMIT_EVENTS=1 run events::emit done
  [ "$status" -eq 0 ]
  [ "$output" = '{"type":"done"}' ]
}

@test "events::emit handles multiple key=value pairs" {
  F13_EMIT_EVENTS=1 run events::emit state \
    "exists=true" "backend=mock" "frontend_port=9999"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"state"'* ]]
  [[ "$output" == *'"exists":"true"'* ]]
  [[ "$output" == *'"backend":"mock"'* ]]
  [[ "$output" == *'"frontend_port":"9999"'* ]]
}

@test "events::emit escapes double quotes in values" {
  F13_EMIT_EVENTS=1 run events::emit preflight 'detail=say "hello"'
  [ "$status" -eq 0 ]
  [[ "$output" == *'\"hello\"'* ]]
}

@test "events::emit escapes backslashes in values" {
  F13_EMIT_EVENTS=1 run events::emit preflight 'detail=C:\path'
  [ "$status" -eq 0 ]
  [[ "$output" == *'C:\\path'* ]]
}

@test "events::emit handles value containing = sign" {
  F13_EMIT_EVENTS=1 run events::emit preflight "detail=url=http://localhost:11434"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"detail":"url=http://localhost:11434"'* ]]
}

@test "events::emit output is a single line" {
  F13_EMIT_EVENTS=1 run events::emit step "name=render" "status=done"
  [ "$status" -eq 0 ]
  # output should have exactly one line
  local count
  count="$(printf '%s\n' "$output" | wc -l)"
  [ "$count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# events::emit_skipped (S34)
# ---------------------------------------------------------------------------

@test "events::emit_skipped emits step done+skipped JSON" {
  F13_EMIT_EVENTS=1 run events::emit_skipped secrets
  [ "$status" -eq 0 ]
  [ "$output" = '{"type":"step","name":"secrets","status":"done","skipped":"true"}' ]
}

@test "events::emit_skipped is silent when F13_EMIT_EVENTS is unset" {
  unset F13_EMIT_EVENTS
  run events::emit_skipped render
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "events::emit_skipped requires a name argument" {
  F13_EMIT_EVENTS=1 run events::emit_skipped
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# Preflight events integration
# ---------------------------------------------------------------------------

@test "preflight emits JSON events when F13_EMIT_EVENTS=1" {
  # Source libs first; override helpers after so they aren't clobbered by source
  source "${BATS_TEST_DIRNAME}/../lib/ui.sh"
  source "${BATS_TEST_DIRNAME}/../lib/ollama.sh"
  source "${BATS_TEST_DIRNAME}/../lib/preflight.sh"
  preflight::_has_cmd()            { return 0; }
  preflight::_docker_info()        { return 0; }
  preflight::_docker_compose_ver() { return 0; }
  preflight::_disk_free_kb()       { printf '4194304'; }
  ollama::is_running()             { return 1; }

  F13_EMIT_EVENTS=1 run preflight::run
  [ "$status" -eq 0 ]
  [[ "$output" == *'"type":"preflight"'* ]]
  [[ "$output" == *'"name":"docker"'* ]]
  [[ "$output" == *'"status":"ok"'* ]]
}

@test "preflight emits fail event when docker not found" {
  source "${BATS_TEST_DIRNAME}/../lib/ui.sh"
  source "${BATS_TEST_DIRNAME}/../lib/ollama.sh"
  source "${BATS_TEST_DIRNAME}/../lib/preflight.sh"
  preflight::_has_cmd()            { return 1; }
  preflight::_docker_info()        { return 1; }
  preflight::_docker_compose_ver() { return 1; }
  preflight::_disk_free_kb()       { printf '4194304'; }
  ollama::is_running()             { return 1; }

  F13_EMIT_EVENTS=1 run preflight::run
  [ "$status" -eq 1 ]
  [[ "$output" == *'"name":"docker"'* ]]
  [[ "$output" == *'"status":"fail"'* ]]
}
