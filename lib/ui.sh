#!/usr/bin/env bash
# Colors, emoji, and box-drawing UI helpers
# Respects NO_COLOR env var (https://no-color.org/)
set -euo pipefail

# ---------------------------------------------------------------------------
# Color escape-code helpers
# Each wraps its argument(s) in the given ANSI code and resets after.
# With NO_COLOR set, the functions just echo the text unchanged.
# ---------------------------------------------------------------------------

_ui_color() {
  local code="$1"; shift
  if [[ -n "${NO_COLOR:-}" ]]; then
    printf '%s' "$*"
  else
    printf '\033[%sm%s\033[0m' "$code" "$*"
  fi
}

ui::red()    { _ui_color "31" "$@"; }
ui::green()  { _ui_color "32" "$@"; }
ui::yellow() { _ui_color "33" "$@"; }
ui::cyan()   { _ui_color "36" "$@"; }
ui::dim()    { _ui_color "2"  "$@"; }
ui::bold()   { _ui_color "1"  "$@"; }
ui::reset()  { if [[ -z "${NO_COLOR:-}" ]]; then printf '\033[0m'; fi; }

# ---------------------------------------------------------------------------
# One-liner status lines
# ---------------------------------------------------------------------------

ui::ok()   { printf '%s %s\n' "$(ui::green "✅")" "$*"; }
ui::warn() { printf '%s %s\n' "$(ui::yellow "⚠️ ")" "$*"; }
ui::err()  { printf '%s %s\n' "$(ui::red "❌")" "$*" >&2; }
ui::info() { printf '%s %s\n' "$(ui::cyan "ℹ️ ")" "$*"; }
ui::step() { printf '%s %s\n' "$(ui::bold "🔧")" "$*"; }

# ---------------------------------------------------------------------------
# Horizontal rule
# ---------------------------------------------------------------------------

ui::hr() {
  local width="${COLUMNS:-80}"
  local line
  printf -v line '%*s' "$width" ''
  printf '%s\n' "${line// /─}"
}

# ---------------------------------------------------------------------------
# Bordered box
# Usage: ui::box "Title" <<< "body text"
#        printf "line1\nline2\n" | ui::box "Title"
# ---------------------------------------------------------------------------

ui::box() {
  local title="${1:-}"
  local -a lines=()
  local line
  while IFS= read -r line; do
    lines+=("$line")
  done

  # Determine inner width: max of title length and longest body line
  local max_len=${#title}
  for line in "${lines[@]}"; do
    (( ${#line} > max_len )) && max_len=${#line}
  done
  local inner=$(( max_len + 2 ))

  # Build horizontal bars
  local bar
  printf -v bar '%*s' "$inner" ''
  bar="${bar// /═}"

  printf '╔%s╗\n' "$bar"
  if [[ -n "$title" ]]; then
    local pad=$(( inner - ${#title} - 1 ))
    printf '║ %s%*s║\n' "$title" "$pad" ''
    printf '╠%s╣\n' "$bar"
  fi
  for line in "${lines[@]}"; do
    local pad=$(( inner - ${#line} - 1 ))
    printf '║ %s%*s║\n' "$line" "$pad" ''
  done
  printf '╚%s╝\n' "$bar"
}
