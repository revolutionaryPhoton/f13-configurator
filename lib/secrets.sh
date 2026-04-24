#!/usr/bin/env bash
# Random secret generation helpers

# secret::gen [bytes]
# Prints a base64url-encoded random secret (default 32 bytes).
# Uses openssl rand when available, falls back to /dev/urandom + base64.
# shellcheck disable=SC2120  # bytes arg is optional; callers omit it for default
secret::gen() {
  local bytes="${1:-32}"
  if command -v openssl &>/dev/null; then
    openssl rand -base64 "$bytes" | tr '+/' '-_' | tr -d '='
  else
    dd if=/dev/urandom bs=1 count="$bytes" 2>/dev/null \
      | base64 | tr '+/' '-_' | tr -d '=\n'
  fi
}

# secret::write PATH [--force]
# Generate a secret and write it to PATH with chmod 600.
# Idempotent: skips if file already exists, unless --force is passed.
secret::write() {
  local path="${1:?secret::write requires a PATH argument}"
  local force=0
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=1 ;;
    esac
    shift
  done

  if [[ -f "$path" && "$force" -eq 0 ]]; then
    return 0
  fi

  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  secret::gen > "$path"
  chmod 600 "$path"
}
