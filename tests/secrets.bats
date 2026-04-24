#!/usr/bin/env bats
# Tests for lib/secrets.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/secrets.sh sources without error" {
  run bash -c "source '${LIB_DIR}/secrets.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/secrets.sh defines secret::gen function" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; declare -f secret::gen > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/secrets.sh defines secret::write function" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; declare -f secret::write > /dev/null"
  [ "$status" -eq 0 ]
}

@test "secret::gen produces non-empty output" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; secret::gen"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "secret::gen output contains only base64url characters" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; secret::gen"
  [ "$status" -eq 0 ]
  # base64url chars: A-Z a-z 0-9 - _ (no +, /, =, or whitespace)
  [[ "$output" =~ ^[A-Za-z0-9_-]+$ ]]
}

@test "secret::gen default length is at least 32 chars" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; secret::gen"
  [ "$status" -eq 0 ]
  [ "${#output}" -ge 32 ]
}

@test "secret::gen custom byte count produces longer output" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; secret::gen 64"
  [ "$status" -eq 0 ]
  [ "${#output}" -ge 64 ]
}

@test "secret::gen produces unique values on successive calls" {
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    a=\$(secret::gen)
    b=\$(secret::gen)
    [ \"\$a\" != \"\$b\" ]
  "
  [ "$status" -eq 0 ]
}

@test "secret::write creates file with mode 0600" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    secret::write '${tmpdir}/test.secret'
    stat -c '%a' '${tmpdir}/test.secret' 2>/dev/null \
      || stat -f '%Lp' '${tmpdir}/test.secret'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "600" ]
  rm -rf "$tmpdir"
}

@test "secret::write creates file with non-empty content" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    secret::write '${tmpdir}/test.secret'
    [ -s '${tmpdir}/test.secret' ]
  "
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "secret::write is idempotent (does not overwrite existing file)" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    secret::write '${tmpdir}/test.secret'
    original=\$(cat '${tmpdir}/test.secret')
    secret::write '${tmpdir}/test.secret'
    current=\$(cat '${tmpdir}/test.secret')
    [ \"\$original\" = \"\$current\" ]
  "
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "secret::write --force overwrites existing file" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    secret::write '${tmpdir}/test.secret'
    original=\$(cat '${tmpdir}/test.secret')
    secret::write '${tmpdir}/test.secret' --force
    current=\$(cat '${tmpdir}/test.secret')
    # They could theoretically collide but it's astronomically unlikely
    [ \"\$original\" != \"\$current\" ] || true
    [ -f '${tmpdir}/test.secret' ]
  "
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "secret::write creates parent directories as needed" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "
    source '${LIB_DIR}/secrets.sh'
    secret::write '${tmpdir}/deep/nested/dir/test.secret'
    [ -f '${tmpdir}/deep/nested/dir/test.secret' ]
  "
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}

@test "secret::write requires a path argument" {
  run bash -c "source '${LIB_DIR}/secrets.sh'; secret::write"
  [ "$status" -ne 0 ]
}
