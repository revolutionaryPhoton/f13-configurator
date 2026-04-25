#!/usr/bin/env bash
# Pre-flight dependency checks
# Requires lib/ui.sh to be sourced before use.
set -euo pipefail

# Ensure events::emit is available even when events.sh has not been sourced.
declare -f events::emit &>/dev/null || events::emit() { :; }

# ---------------------------------------------------------------------------
# Internal helpers — may be overridden in tests
# ---------------------------------------------------------------------------

preflight::_has_cmd()            { command -v "$1" &>/dev/null; }
preflight::_docker_info()        { docker info     &>/dev/null 2>&1; }
preflight::_docker_compose_ver() { docker compose version &>/dev/null 2>&1; }

# preflight::_disk_free_kb: print available KB on $PWD filesystem.
# Overridable via _PREFLIGHT_DISK_FREE_KB env var (testing).
preflight::_disk_free_kb() {
  if [[ -n "${_PREFLIGHT_DISK_FREE_KB:-}" ]]; then
    printf '%s' "${_PREFLIGHT_DISK_FREE_KB}"
  else
    df -k "${PWD}" | awk 'NR==2 { print $4 }'
  fi
}

preflight::_git_ls_remote() { git ls-remote --exit-code "$@" HEAD &>/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# preflight::run
# Checks all runtime dependencies in order; prints ✅/❌ per check.
# Set _PREFLIGHT_BASH_MAJOR to override bash version detection (testing).
# Returns 1 if any check fails.
# ---------------------------------------------------------------------------
preflight::run() {
  local failed=0
  local docker_ok=1

  # 1. docker on PATH and docker info succeeds
  if ! preflight::_has_cmd docker; then
    ui::err "docker not found — install from https://docs.docker.com/get-docker/"
    events::emit preflight "name=docker" "status=fail" "detail=not found"
    failed=$(( failed + 1 ))
    docker_ok=0
  elif ! preflight::_docker_info; then
    ui::err "docker is installed but not running — start Docker Desktop or dockerd"
    events::emit preflight "name=docker" "status=fail" "detail=not running"
    failed=$(( failed + 1 ))
    docker_ok=0
  else
    ui::ok "docker"
    events::emit preflight "name=docker" "status=ok"
  fi

  # 2. docker compose v2 plugin (skip if docker itself is missing)
  if [[ "${docker_ok}" -eq 1 ]]; then
    if ! preflight::_docker_compose_ver; then
      ui::err "docker compose not found — update Docker Desktop or install Compose v2"
      events::emit preflight "name=docker-compose" "status=fail" "detail=not found"
      failed=$(( failed + 1 ))
    else
      ui::ok "docker compose"
      events::emit preflight "name=docker-compose" "status=ok"
    fi
  fi

  # 3. bash >= 4.0
  local bash_major="${_PREFLIGHT_BASH_MAJOR:-${BASH_VERSINFO[0]}}"
  if [[ "${bash_major}" -lt 4 ]]; then
    ui::err "bash < 4.0 detected — on macOS: brew install bash"
    events::emit preflight "name=bash" "status=fail" "detail=version ${bash_major} < 4.0"
    failed=$(( failed + 1 ))
  else
    ui::ok "bash (>= 4.0)"
    events::emit preflight "name=bash" "status=ok"
  fi

  # 4. required tools on PATH
  local cmd
  for cmd in curl awk sed envsubst; do
    if preflight::_has_cmd "${cmd}"; then
      ui::ok "${cmd}"
      events::emit preflight "name=${cmd}" "status=ok"
    else
      ui::err "${cmd} not found — install via your package manager"
      events::emit preflight "name=${cmd}" "status=fail" "detail=not found"
      failed=$(( failed + 1 ))
    fi
  done

  # 5. ~2 GB free disk space on $PWD
  local required_kb=2097152  # 2 GB in KB
  local free_kb
  free_kb=$(preflight::_disk_free_kb)
  if [[ "${free_kb}" -lt "${required_kb}" ]]; then
    ui::err "Only $(( free_kb / 1024 )) MB free on ${PWD} — need >= 2 GB"
    events::emit preflight "name=disk" "status=fail" "detail=$(( free_kb / 1024 )) MB free"
    failed=$(( failed + 1 ))
  else
    ui::ok "disk space ($(( free_kb / 1024 / 1024 )) GB free)"
    events::emit preflight "name=disk" "status=ok" "detail=$(( free_kb / 1024 / 1024 )) GB free"
  fi

  # 6. Ollama probe — INFORMATIONAL only (never fails preflight).
  #    Mock-inference users don't need Ollama at all, so this is a hint,
  #    not a gate. The hard "Ollama required" check lives in the wizard's
  #    Ollama path (bin/f13-config :: _wizard_pick_ollama_model).
  if declare -f ollama::is_running &>/dev/null && ollama::is_running; then
    local -a _models=()
    if declare -f ollama::list_models &>/dev/null; then
      mapfile -t _models < <(ollama::list_models 2>/dev/null || true)
    fi
    if [[ ${#_models[@]} -gt 0 ]]; then
      ui::info "Ollama: detected (${#_models[@]} model(s)) — only needed for the Ollama inference option"
      events::emit preflight "name=ollama" "status=info" "detail=detected, ${#_models[@]} model(s)"
      local _m
      for _m in "${_models[@]}"; do
        printf '   • %s\n' "${_m}"
      done
    else
      ui::info "Ollama: detected — no models pulled yet (run 'ollama pull <name>' if you plan to use Ollama)"
      events::emit preflight "name=ollama" "status=info" "detail=detected, no models"
    fi
  else
    ui::info "Ollama: not detected (only needed if you pick the Ollama inference option)"
    events::emit preflight "name=ollama" "status=info" "detail=not detected"
  fi

  # 7. git reachability check — only when a clone will be needed for S16
  #    frontend::clone_required is defined in lib/frontend.sh (sourced by f13-config).
  #    If the function is not loaded yet, skip this check gracefully.
  if declare -f frontend::clone_required &>/dev/null && frontend::clone_required; then
    local _fe_url="https://gitlab.opencode.de/f13/microservices/frontend.git"
    if ! preflight::_has_cmd git; then
      ui::err "git not found — needed to clone frontend source (brew install git / apt install git)"
      events::emit preflight "name=git" "status=fail" "detail=not found"
      failed=$(( failed + 1 ))
    elif preflight::_git_ls_remote "${_fe_url}"; then
      ui::ok "git (clone required — remote reachable)"
      events::emit preflight "name=git" "status=ok"
    else
      ui::err "git remote unreachable: ${_fe_url}"
      events::emit preflight "name=git" "status=fail" "detail=remote unreachable"
      failed=$(( failed + 1 ))
    fi
  fi

  if [[ "${failed}" -gt 0 ]]; then
    ui::err "${failed} preflight check(s) failed"
    return 1
  fi
}
