#!/usr/bin/env bash
# Port availability probes

# ports::is_free PORT
# Returns 0 if PORT is available to bind, 1 if taken or privileged.
# Ports below 1024 are always reported as not free (require root to bind).
ports::is_free() {
  local port="${1:?port required}"

  if [[ "${port}" -lt 1024 ]]; then
    return 1
  fi

  if command -v lsof &>/dev/null; then
    if lsof -iTCP:"${port}" -sTCP:LISTEN -t &>/dev/null; then
      return 1
    else
      return 0
    fi
  fi

  if command -v ss &>/dev/null; then
    # Split each field on ':' and compare the last segment to the port number.
    # Works for both IPv4 (0.0.0.0:PORT) and IPv6 ([::]:PORT / :::PORT).
    if ss -tln 2>/dev/null | awk -v p="${port}" '
      NR > 1 {
        for (i = 1; i <= NF; i++) {
          n = split($i, parts, ":")
          if (n > 1 && parts[n] == p) { exit 0 }
        }
      }
      END { exit 1 }
    '; then
      return 1
    else
      return 0
    fi
  fi

  return 0
}

# ports::pick_free PREFERRED [FALLBACK...]
# Prints the first free port from the list. Returns 1 if none is free.
ports::pick_free() {
  local preferred="${1:?preferred port required}"
  shift

  if ports::is_free "${preferred}"; then
    printf '%s\n' "${preferred}"
    return 0
  fi

  local port
  for port in "$@"; do
    if ports::is_free "${port}"; then
      printf '%s\n' "${port}"
      return 0
    fi
  done

  return 1
}
