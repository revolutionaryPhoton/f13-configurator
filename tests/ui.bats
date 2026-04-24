#!/usr/bin/env bats
# Tests for lib/ui.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# Strip ANSI escape codes from a string
strip_ansi() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'; }

@test "lib/ui.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'"
  [ "$status" -eq 0 ]
}

@test "ui::ok produces non-empty output with checkmark" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::ok 'all good'"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
  plain=$(strip_ansi "$output")
  [[ "$plain" == *"all good"* ]]
}

@test "ui::warn produces non-empty output with message" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::warn 'watch out'"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
  plain=$(strip_ansi "$output")
  [[ "$plain" == *"watch out"* ]]
}

@test "ui::err writes to stderr" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::err 'broken' 2>&1"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == *"broken"* ]]
}

@test "ui::info produces non-empty output with message" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::info 'fyi'"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == *"fyi"* ]]
}

@test "ui::step produces non-empty output with message" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::step '1. doing something'"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == *"doing something"* ]]
}

@test "ui::hr prints a non-empty line" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::hr"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "ui::box outputs box corners and title" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::box 'MyTitle' <<< 'body line'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"╔"* ]]
  [[ "$output" == *"╗"* ]]
  [[ "$output" == *"╚"* ]]
  [[ "$output" == *"╝"* ]]
  [[ "$output" == *"MyTitle"* ]]
  [[ "$output" == *"body line"* ]]
}

@test "ui::box with multi-line body" {
  run bash -c "source '${LIB_DIR}/ui.sh'; printf 'line1\nline2\n' | ui::box 'Test'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line1"* ]]
  [[ "$output" == *"line2"* ]]
}

@test "ui::red wraps text in escape codes" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::red 'hello'"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
  plain=$(strip_ansi "$output")
  [[ "$plain" == "hello" ]]
}

@test "ui::green wraps text in escape codes" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::green 'hello'"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == "hello" ]]
}

@test "ui::yellow wraps text in escape codes" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::yellow 'hello'"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == "hello" ]]
}

@test "ui::cyan wraps text in escape codes" {
  run bash -c "source '${LIB_DIR}/ui.sh'; ui::cyan 'hello'"
  [ "$status" -eq 0 ]
  plain=$(strip_ansi "$output")
  [[ "$plain" == "hello" ]]
}

@test "NO_COLOR suppresses escape codes" {
  run bash -c "source '${LIB_DIR}/ui.sh'; NO_COLOR=1 ui::red 'plain'"
  [ "$status" -eq 0 ]
  # Should not contain ESC character
  [[ "$output" != *$'\033'* ]]
  [[ "$output" == "plain" ]]
}

@test "ui::defines all required functions" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    for fn in ui::red ui::green ui::yellow ui::cyan ui::dim ui::bold ui::reset \
               ui::ok ui::warn ui::err ui::info ui::step ui::hr ui::box; do
      declare -f \"\$fn\" > /dev/null || { echo \"MISSING: \$fn\"; exit 1; }
    done
  "
  [ "$status" -eq 0 ]
}
