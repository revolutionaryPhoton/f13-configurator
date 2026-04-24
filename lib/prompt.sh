#!/usr/bin/env bash
# Interactive prompt helpers.
# Respects F13_CONFIG_NONINTERACTIVE=1 for scripted / tested runs.
# In noninteractive mode each VAR-based prompt reads ${!VAR} from the
# environment first, then the supplied default; prompt::yesno uses its
# default argument directly.
set -euo pipefail

# shellcheck source=lib/ui.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ui.sh"

# prompt::ask VAR "Question" [default]
# Stores user's answer in $VAR via printf -v (bash 4+).
prompt::ask() {
  local var="$1"
  local question="$2"
  local default="${3:-}"

  if [[ -n "${F13_CONFIG_NONINTERACTIVE:-}" ]]; then
    printf -v "$var" '%s' "${!var:-$default}"
    return 0
  fi

  local hint=""
  [[ -n "$default" ]] && hint=" [$(ui::dim "$default")]"
  printf '%s%s: ' "$question" "$hint" >&2

  local input=""
  IFS= read -r input || true
  printf -v "$var" '%s' "${input:-$default}"
}

# prompt::yesno "Question" [y|n]
# Returns 0 for yes, 1 for no.
# Loops on invalid input; exits loop on EOF using default.
prompt::yesno() {
  local question="$1"
  local default="${2:-n}"

  if [[ -n "${F13_CONFIG_NONINTERACTIVE:-}" ]]; then
    [[ "${default,,}" == "y" ]] && return 0 || return 1
  fi

  local hint
  [[ "${default,,}" == "y" ]] && hint="[Y/n]" || hint="[y/N]"

  local input
  while true; do
    printf '%s %s: ' "$question" "$hint" >&2
    IFS= read -r input || input="$default"
    input="${input:-$default}"
    case "${input,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     printf 'Please enter y or n.\n' >&2 ;;
    esac
  done
}

# prompt::pickone VAR "Prompt" "opt1" "opt2" …
# Prints a numbered menu; stores chosen option text in $VAR.
# Noninteractive: uses ${!VAR} from env, then first option.
# On EOF in interactive mode: falls back to first option.
prompt::pickone() {
  local var="$1"
  local question="$2"
  shift 2
  local -a options=("$@")

  if [[ -n "${F13_CONFIG_NONINTERACTIVE:-}" ]]; then
    printf -v "$var" '%s' "${!var:-${options[0]}}"
    return 0
  fi

  local i choice
  while true; do
    printf '%s\n' "$question" >&2
    for (( i=0; i<${#options[@]}; i++ )); do
      printf '  %d) %s\n' "$((i+1))" "${options[$i]}" >&2
    done
    printf 'Choice [1-%d]: ' "${#options[@]}" >&2
    IFS= read -r choice || choice="1"
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf -v "$var" '%s' "${options[$((choice-1))]}"
      return 0
    fi
    printf 'Invalid choice — enter 1 to %d.\n' "${#options[@]}" >&2
  done
}

# prompt::secret VAR "Prompt"
# Reads a line without echo; stores result in $VAR.
# Noninteractive: uses ${!VAR} from env (empty string is valid).
prompt::secret() {
  local var="$1"
  local question="$2"

  if [[ -n "${F13_CONFIG_NONINTERACTIVE:-}" ]]; then
    printf -v "$var" '%s' "${!var:-}"
    return 0
  fi

  local input=""
  printf '%s: ' "$question" >&2
  IFS= read -rs input || true
  printf '\n' >&2
  printf -v "$var" '%s' "$input"
}
