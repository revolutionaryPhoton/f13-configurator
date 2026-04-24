#!/usr/bin/env bash
# F13 ASCII art banner
# Requires lib/ui.sh to be sourced before use.
set -euo pipefail

# Block/box-drawing art for "F13"
_BANNER_ART=(
  '███████╗  ██╗  ██████╗ '
  '██╔════╝ ███║ ╚════██╗'
  '█████╗   ╚██║  █████╔╝'
  '██╔══╝    ██║  ╚═══██╔╝'
  '██║       ██║  ██████╔╝'
  '╚═╝       ╚═╝  ╚═════╝ '
)

ui::banner() {
  local width="${COLUMNS:-80}"
  local line pad

  for line in "${_BANNER_ART[@]}"; do
    # Use byte length as proxy for display width (all chars are 1-col wide)
    local visible
    # strip any accidental escapes to count display cols
    visible=$(printf '%s' "$line" | sed 's/\x1b\[[0-9;]*m//g')
    pad=$(( (width - ${#visible}) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s' "$pad" ''
    ui::cyan "$line"
    printf '\n'
  done

  local subtitle="F13 · minimal configurator · v1"
  pad=$(( (width - ${#subtitle}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s' "$pad" ''
  ui::dim "$subtitle"
  printf '\n'
}
