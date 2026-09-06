#!/usr/bin/env bash
# discover.sh — resolve the F13 generated/ directory across env, dev, and
# bundled install paths.

# discover::generated_dir SCRIPT_DIR
#
# Returns the path to the generated/ directory that contains a live stack
# (docker-compose.yml). Probes candidate locations in order:
#
#   1. $F13_GENERATED_DIR      — explicit env override; returned as-is.
#   2. SCRIPT_DIR/../generated — dev / direct-checkout install.
#   3. macOS appLocalDataDir:  ~/Library/Application Support/de.f13-os.configurator/generated
#   4. Linux appLocalDataDir:  ~/.local/share/de.f13-os.configurator/generated
#
# Tests may override each probed root via env vars:
#   _F13_DEV_ROOT        (default: SCRIPT_DIR/..)
#   _F13_MACOS_DATA_DIR  (default: ~/Library/Application Support/de.f13-os.configurator)
#   _F13_LINUX_DATA_DIR  (default: ~/.local/share/de.f13-os.configurator)
#
# _F13_DEV_ROOT exists so tests of the later branches are hermetic. Without it a
# test asserting "falls through to the macOS path" silently depends on the real
# checkout having no generated/ dir -- which is false the moment anyone runs the
# wizard, so the test passes or fails according to unrelated local state.
#
# On success: prints the resolved path and returns 0.
# On failure: returns 1 (caller is responsible for the error message).
discover::generated_dir() {
  local script_dir="${1:-}"

  # 1. Explicit env override — trust the caller; the calling script
  #    validates existence so legacy error messages remain accurate.
  if [[ -n "${F13_GENERATED_DIR:-}" ]]; then
    echo "${F13_GENERATED_DIR}"
    return 0
  fi

  # 2. Dev / direct-checkout: bin/../generated
  if [[ -n "${script_dir}" ]] || [[ -n "${_F13_DEV_ROOT:-}" ]]; then
    local dev_gen dev_root
    dev_root="${_F13_DEV_ROOT:-$(cd "${script_dir}/.." 2>/dev/null && pwd)}"
    dev_gen="${dev_root}/generated"
    if [[ -f "${dev_gen}/docker-compose.yml" ]]; then
      echo "${dev_gen}"
      return 0
    fi
  fi

  # 3. macOS bundled appLocalDataDir
  local macos_gen
  macos_gen="${_F13_MACOS_DATA_DIR:-${HOME}/Library/Application Support/de.f13-os.configurator}/generated"
  if [[ -f "${macos_gen}/docker-compose.yml" ]]; then
    echo "${macos_gen}"
    return 0
  fi

  # 4. Linux bundled appLocalDataDir
  local linux_gen
  linux_gen="${_F13_LINUX_DATA_DIR:-${HOME}/.local/share/de.f13-os.configurator}/generated"
  if [[ -f "${linux_gen}/docker-compose.yml" ]]; then
    echo "${linux_gen}"
    return 0
  fi

  return 1
}
