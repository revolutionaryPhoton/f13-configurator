#!/usr/bin/env bash
# State file management for idempotent re-runs
set -euo pipefail

# state::write STATE_FILE — persist current wizard vars to a KEY=VALUE file
# Reads globals: PRESET, CHAT_BACKEND, OLLAMA_MODEL, FRONTEND_PORT, CORE_PORT
state::write() {
  local state_file="$1"
  cat > "${state_file}" <<EOF
PRESET=${PRESET:-core+frontend+chat}
CHAT_BACKEND=${CHAT_BACKEND:-mock}
OLLAMA_MODEL=${OLLAMA_MODEL:-}
FRONTEND_PORT=${FRONTEND_PORT:-9999}
CORE_PORT=${CORE_PORT:-8000}
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  chmod 600 "${state_file}"
}

# state::read STATE_FILE — load state into wizard globals
# Sets: PRESET, CHAT_BACKEND, OLLAMA_MODEL, FRONTEND_PORT, CORE_PORT, STATE_TIMESTAMP
# Returns 1 if file does not exist
state::read() {
  local state_file="$1"
  [[ -f "${state_file}" ]] || return 1

  local _val
  _val="$(grep '^PRESET='        "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  [[ -n "${_val}" ]] && PRESET="${_val}"

  _val="$(grep '^CHAT_BACKEND='  "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  [[ -n "${_val}" ]] && CHAT_BACKEND="${_val}"

  _val="$(grep '^OLLAMA_MODEL='  "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  OLLAMA_MODEL="${_val}"

  _val="$(grep '^FRONTEND_PORT=' "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  [[ -n "${_val}" ]] && FRONTEND_PORT="${_val}"

  _val="$(grep '^CORE_PORT='     "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  [[ -n "${_val}" ]] && CORE_PORT="${_val}"

  _val="$(grep '^TIMESTAMP='     "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  export STATE_TIMESTAMP="${_val:-}"
}

# state::check GEN_DIR — display current config and prompt for action
# Sets F13_STATE_ACTION to: keep | edit | reset
# Returns 0 if state file found, 1 if not
state::check() {
  local gen_dir="$1"
  local state_file="${gen_dir}/.state"
  [[ -f "${state_file}" ]] || return 1

  local _preset _backend _model _fport _cport _ts
  _preset="$(grep '^PRESET='        "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  _backend="$(grep '^CHAT_BACKEND='  "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  _model="$(grep '^OLLAMA_MODEL='   "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  _fport="$(grep '^FRONTEND_PORT='  "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  _cport="$(grep '^CORE_PORT='      "${state_file}" 2>/dev/null | cut -d= -f2- || true)"
  _ts="$(grep '^TIMESTAMP='         "${state_file}" 2>/dev/null | cut -d= -f2- || true)"

  ui::info "Existing configuration found:"
  ui::box "Current Configuration" <<EOF
Preset:    ${_preset:-core+frontend+chat}
Inference: ${_backend:-mock}
Model:     ${_model:-(mock)}
Frontend:  http://localhost:${_fport:-9999}
API:       http://localhost:${_cport:-8000}
Saved:     ${_ts:-(unknown)}
EOF
  printf '\n'

  if [[ -n "${F13_CONFIG_NONINTERACTIVE:-}" ]]; then
    F13_STATE_ACTION="${F13_STATE_ACTION:-keep}"
    return 0
  fi

  local _raw
  while true; do
    printf '[k]eep  [e]dit  [r]eset > ' >&2
    if ! IFS= read -r _raw; then
      F13_STATE_ACTION="keep"
      break
    fi
    case "${_raw,,}" in
      k|keep)  F13_STATE_ACTION="keep";  break ;;
      e|edit)  F13_STATE_ACTION="edit";  break ;;
      r|reset) F13_STATE_ACTION="reset"; break ;;
      *)       ui::warn "Please enter k, e, or r" ;;
    esac
  done

  return 0
}
