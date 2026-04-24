#!/usr/bin/env bats
# Tests for lib/ports.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/ports.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ports.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/ports.sh defines ports::is_free function" {
  run bash -c "source '${LIB_DIR}/ports.sh'; declare -f ports::is_free > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/ports.sh defines ports::pick_free function" {
  run bash -c "source '${LIB_DIR}/ports.sh'; declare -f ports::pick_free > /dev/null"
  [ "$status" -eq 0 ]
}

@test "ports::is_free returns 1 for privileged port 1" {
  run bash -c "source '${LIB_DIR}/ports.sh'; ports::is_free 1"
  [ "$status" -eq 1 ]
}

@test "ports::is_free returns 1 for privileged port 80" {
  run bash -c "source '${LIB_DIR}/ports.sh'; ports::is_free 80"
  [ "$status" -eq 1 ]
}

@test "ports::is_free returns 1 for privileged port 443" {
  run bash -c "source '${LIB_DIR}/ports.sh'; ports::is_free 443"
  [ "$status" -eq 1 ]
}

@test "ports::is_free requires a port argument" {
  run bash -c "source '${LIB_DIR}/ports.sh'; ports::is_free"
  [ "$status" -ne 0 ]
}

@test "ports::pick_free requires a preferred port argument" {
  run bash -c "source '${LIB_DIR}/ports.sh'; ports::pick_free"
  [ "$status" -ne 0 ]
}

@test "ports::pick_free returns preferred port when free" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { return 0; }
    ports::pick_free 9999 8080
  "
  [ "$status" -eq 0 ]
  [ "$output" = "9999" ]
}

@test "ports::pick_free falls back when preferred is taken" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { [[ \"\$1\" != \"9999\" ]]; }
    ports::pick_free 9999 8080 8081
  "
  [ "$status" -eq 0 ]
  [ "$output" = "8080" ]
}

@test "ports::pick_free skips to next fallback when first fallback taken" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { [[ \"\$1\" != \"9999\" && \"\$1\" != \"8080\" ]]; }
    ports::pick_free 9999 8080 8081
  "
  [ "$status" -eq 0 ]
  [ "$output" = "8081" ]
}

@test "ports::pick_free returns 1 when all ports are taken" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { return 1; }
    ports::pick_free 9999 8080 8081
  "
  [ "$status" -eq 1 ]
}

@test "ports::pick_free works with no fallbacks when preferred is free" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { return 0; }
    ports::pick_free 9999
  "
  [ "$status" -eq 0 ]
  [ "$output" = "9999" ]
}

@test "ports::pick_free returns 1 with no fallbacks when preferred is taken" {
  run bash -c "
    source '${LIB_DIR}/ports.sh'
    ports::is_free() { return 1; }
    ports::pick_free 9999
  "
  [ "$status" -eq 1 ]
}
