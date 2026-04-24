#!/usr/bin/env bats
# Tests for lib/banner.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

@test "lib/banner.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/banner.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/banner.sh defines ui::banner function" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/banner.sh'; declare -f ui::banner > /dev/null"
  [ "$status" -eq 0 ]
}

@test "ui::banner prints at least 5 lines" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/banner.sh'; ui::banner"
  [ "$status" -eq 0 ]
  line_count=$(printf '%s' "$output" | wc -l)
  [ "$line_count" -ge 5 ]
}

@test "ui::banner output contains F13" {
  run bash -c "NO_COLOR=1 source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/banner.sh'; NO_COLOR=1 ui::banner"
  [ "$status" -eq 0 ]
  [[ "$output" == *"F13"* ]]
}

@test "ui::banner output contains subtitle text" {
  run bash -c "NO_COLOR=1 source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/banner.sh'; NO_COLOR=1 ui::banner"
  [ "$status" -eq 0 ]
  [[ "$output" == *"minimal configurator"* ]]
}
