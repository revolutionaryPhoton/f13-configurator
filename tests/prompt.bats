#!/usr/bin/env bats
# Tests for lib/prompt.sh
# Requires bats >= 1.5.0 for --separate-stderr support on interactive tests
# (prompts go to stderr; captured separately so $output contains only the
# variable value printed to stdout).

bats_require_minimum_version 1.5.0

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/prompt.sh sources without error" {
  run bash -c "source '${LIB_DIR}/prompt.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/prompt.sh defines prompt::ask function" {
  run bash -c "source '${LIB_DIR}/prompt.sh'; declare -f prompt::ask > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/prompt.sh defines all required functions" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    for fn in prompt::ask prompt::yesno prompt::pickone prompt::secret; do
      declare -f \"\$fn\" > /dev/null || { echo \"MISSING: \$fn\"; exit 1; }
    done
  "
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# prompt::ask — interactive (redirect applied inside bash -c)
# --separate-stderr keeps prompts out of $output
# ---------------------------------------------------------------------------

@test "prompt::ask stores stdin input in variable" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::ask RESULT 'Enter value' <<< 'hello'
    printf '%s' \"\$RESULT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "prompt::ask uses default when input is empty" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::ask RESULT 'Enter value' 'mydefault' < /dev/null
    printf '%s' \"\$RESULT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "mydefault" ]
}

@test "prompt::ask explicit input overrides default" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::ask RESULT 'Enter value' 'mydefault' <<< 'override'
    printf '%s' \"\$RESULT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "override" ]
}

# ---------------------------------------------------------------------------
# prompt::ask — noninteractive (no tty needed)
# ---------------------------------------------------------------------------

@test "prompt::ask noninteractive uses env var matching VAR name" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    export RESULT='from_env'
    source '${LIB_DIR}/prompt.sh'
    prompt::ask RESULT 'Enter value' 'default'
    printf '%s' \"\$RESULT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "from_env" ]
}

@test "prompt::ask noninteractive falls back to default when env var unset" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    source '${LIB_DIR}/prompt.sh'
    unset RESULT
    prompt::ask RESULT 'Enter value' 'fallback'
    printf '%s' \"\$RESULT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

# ---------------------------------------------------------------------------
# prompt::yesno — interactive
# ---------------------------------------------------------------------------

@test "prompt::yesno returns 0 for y" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' <<< 'y'
  "
  [ "$status" -eq 0 ]
}

@test "prompt::yesno returns 0 for yes" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' <<< 'yes'
  "
  [ "$status" -eq 0 ]
}

@test "prompt::yesno returns 1 for n" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' <<< 'n'
  "
  [ "$status" -eq 1 ]
}

@test "prompt::yesno returns 1 for no" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' <<< 'no'
  "
  [ "$status" -eq 1 ]
}

@test "prompt::yesno uses default y on EOF" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' y < /dev/null
  "
  [ "$status" -eq 0 ]
}

@test "prompt::yesno uses default n on EOF" {
  run bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' n < /dev/null
  "
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# prompt::yesno — noninteractive
# ---------------------------------------------------------------------------

@test "prompt::yesno noninteractive default y returns 0" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' y
  "
  [ "$status" -eq 0 ]
}

@test "prompt::yesno noninteractive default n returns 1" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    source '${LIB_DIR}/prompt.sh'
    prompt::yesno 'Continue?' n
  "
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# prompt::pickone — interactive
# ---------------------------------------------------------------------------

@test "prompt::pickone sets var to first option when choice is 1" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::pickone CHOICE 'Pick one' alpha beta gamma <<< '1'
    printf '%s' \"\$CHOICE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "alpha" ]
}

@test "prompt::pickone sets var to second option when choice is 2" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::pickone CHOICE 'Pick one' alpha beta gamma <<< '2'
    printf '%s' \"\$CHOICE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "beta" ]
}

@test "prompt::pickone falls back to first option on EOF" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::pickone CHOICE 'Pick one' alpha beta gamma < /dev/null
    printf '%s' \"\$CHOICE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "alpha" ]
}

# ---------------------------------------------------------------------------
# prompt::pickone — noninteractive
# ---------------------------------------------------------------------------

@test "prompt::pickone noninteractive uses env var" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    export CHOICE='gamma'
    source '${LIB_DIR}/prompt.sh'
    prompt::pickone CHOICE 'Pick one' alpha beta gamma
    printf '%s' \"\$CHOICE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "gamma" ]
}

@test "prompt::pickone noninteractive uses first option when env var unset" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    source '${LIB_DIR}/prompt.sh'
    unset CHOICE
    prompt::pickone CHOICE 'Pick one' alpha beta gamma
    printf '%s' \"\$CHOICE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "alpha" ]
}

# ---------------------------------------------------------------------------
# prompt::secret
# ---------------------------------------------------------------------------

@test "prompt::secret reads value from stdin" {
  run --separate-stderr bash -c "
    source '${LIB_DIR}/prompt.sh'
    prompt::secret PASS 'Enter password' <<< 'secretword'
    printf '%s' \"\$PASS\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "secretword" ]
}

@test "prompt::secret noninteractive uses env var" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    export PASS='mysecret'
    source '${LIB_DIR}/prompt.sh'
    prompt::secret PASS 'Enter password'
    printf '%s' \"\$PASS\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "mysecret" ]
}

@test "prompt::secret noninteractive empty string when env var unset" {
  run bash -c "
    export F13_CONFIG_NONINTERACTIVE=1
    source '${LIB_DIR}/prompt.sh'
    unset PASS
    prompt::secret PASS 'Enter password'
    printf 'len=%d' \"\${#PASS}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "len=0" ]
}
