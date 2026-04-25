#!/usr/bin/env bash
# Structured JSON event emission for --emit-events / F13_EMIT_EVENTS mode.
# When F13_EMIT_EVENTS=1 each events::emit call prints one JSON line to stdout.
# Non-event output (ui::*, printf) also reaches stdout; the TypeScript adapter
# ignores any line that does not parse as valid JSON.
set -euo pipefail

# events::emit TYPE [key=value ...]
# Prints one JSON event line to stdout. No-op unless F13_EMIT_EVENTS=1.
# Values are plain strings; double-quotes and backslashes are escaped.
events::emit() {
  [[ -z "${F13_EMIT_EVENTS:-}" ]] && return 0
  local _type="${1:?events::emit requires a type}"
  shift
  local _json="{\"type\":\"${_type}\""
  local _pair _key _val
  for _pair in "$@"; do
    _key="${_pair%%=*}"
    _val="${_pair#*=}"
    _val="${_val//\\/\\\\}"
    _val="${_val//\"/\\\"}"
    _json="${_json},\"${_key}\":\"${_val}\""
  done
  _json="${_json}}"
  printf '%s\n' "${_json}"
}
