#!/usr/bin/env bash
# Docker Compose launch, health-wait, and shutdown
set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers — overridable in tests
# ---------------------------------------------------------------------------

compose::_docker_compose() {
  docker compose "$@"
}

compose::_curl_health() {
  local url="$1"
  curl -fsS --max-time 2 "${url}" >/dev/null 2>&1
}

# Overridable in tests so we can simulate present/missing local images
# without needing a real docker daemon.
compose::_docker_image_inspect() {
  docker image inspect "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# compose::up — start detached services, then wait healthy and show summary
# Reads globals: GEN_DIR, CORE_PORT, FRONTEND_PORT
# compose::validate_generated GEN_DIR
# Check every bind-mount source in the generated compose file exists with the
# type its container target implies.
#
# Docker creates a missing bind-mount source as a DIRECTORY. When the target is
# a file path the container then dies inside runc with:
#   error mounting ".../config.yaml" to rootfs at "/usr/local/apisix/conf/config.yaml":
#   not a directory: Are you trying to mount a directory onto a file (or vice-versa)?
# That message names the container path, not the thing that is actually wrong,
# and `docker compose down -v` does not clear it -- these are host paths under
# generated/, not volumes. Failing here instead names the real file.
#
# Returns 0 when the tree looks launchable, 1 otherwise (printing what is wrong).
compose::validate_generated() {
  local gen_dir="${1:?}"
  local compose_file="${gen_dir}/docker-compose.yml"
  local bad=0 line src dst

  if [[ ! -f "${compose_file}" ]]; then
    ui::err "No docker-compose.yml in ${gen_dir}"
    return 1
  fi

  while IFS= read -r line; do
    src="${line%%:*}"
    dst="${line#*:}"; dst="${dst%%:*}"
    [[ -n "${src}" && -n "${dst}" ]] || continue
    local host_path="${gen_dir}/${src#./}"
    # A target with an extension is a file mount; anything else is a directory.
    if [[ "${dst##*/}" == *.* ]]; then
      if [[ ! -f "${host_path}" ]]; then
        if [[ -d "${host_path}" ]]; then
          ui::err "${src} is a directory but is mounted as a file (${dst})."
        else
          ui::err "${src} is missing but is mounted at ${dst}."
        fi
        bad=1
      fi
    elif [[ ! -d "${host_path}" ]]; then
      ui::err "${src} is missing but is mounted as a directory at ${dst}."
      bad=1
    fi
  done < <(grep -oE '^[[:space:]]+- \./[^[:space:]]+' "${compose_file}" | sed 's/^[[:space:]]*- //')

  return "${bad}"
}

compose::up() {
  local gen_dir="${GEN_DIR:?GEN_DIR is required}"

  # Precondition: the generated tree must be launchable. Without this a damaged
  # generated/ surfaces as an opaque runc mount error naming the container path.
  if ! compose::validate_generated "${gen_dir}"; then
    ui::err "Generated stack in ${gen_dir} is incomplete — re-run the wizard and choose reset."
    return 1
  fi

  # HF3: precondition — the frontend image is built locally and never
  # pushed to a registry, so if it's missing on disk compose will try
  # to pull it from registry.opencode.de and surface a confusing "pull
  # access denied" error. Surface a clear precondition failure instead.
  local frontend_image
  frontend_image="$(grep '^FRONTEND_IMAGE=' "${gen_dir}/.env" 2>/dev/null | cut -d= -f2- || true)"
  if [[ -n "${frontend_image}" ]] \
      && ! compose::_docker_image_inspect "${frontend_image}"; then
    # HF3: stash the specific reason so the --compose-up handler can
    # surface it in the done event message — otherwise the GUI toast
    # would just say "compose up failed".
    # shellcheck disable=SC2034  # consumed by bin/f13-config compose-up handler
    COMPOSE_ERROR_MESSAGE="Frontend image '${frontend_image}' is missing locally — re-run the wizard so it can rebuild."
    ui::err "Frontend image '${frontend_image}' is missing locally."
    ui::info "It's built by this configurator and never pushed to a registry."
    ui::info "Re-run the wizard so it can rebuild the image."
    return 1
  fi

  compose::_docker_compose \
    -f "${gen_dir}/docker-compose.yml" \
    --env-file "${gen_dir}/.env" \
    up -d

  compose::wait_healthy

  local configurator_dir
  configurator_dir="$(cd "${gen_dir}/../" && pwd)"

  ui::box "F13 is up!" <<EOF
Frontend:   http://localhost:${FRONTEND_PORT:-9999}
API:        http://localhost:${CORE_PORT:-8000}

Stop:       ${configurator_dir}/bin/f13-stop
Full reset: ${configurator_dir}/bin/f13-reset
EOF
}

# compose::wait_healthy — poll core /health for up to _COMPOSE_WAIT_MAX seconds
# Reads globals: CORE_PORT
# _COMPOSE_WAIT_MAX may be overridden in tests.
compose::wait_healthy() {
  local port="${CORE_PORT:-8000}"
  local url="http://localhost:${port}/health"
  local max="${_COMPOSE_WAIT_MAX:-120}"
  local elapsed=0

  printf '⏳ Waiting for core to be healthy'

  while (( elapsed < max )); do
    if compose::_curl_health "${url}"; then
      printf '\n'
      return 0
    fi
    sleep 2
    (( elapsed += 2 )) || true
    printf '\r⌛ Waiting for core to be healthy (%ds elapsed)' "${elapsed}"
  done

  printf '\n'
  ui::err "Core did not become healthy within ${max}s."
  ui::info "Check logs: cd ${GEN_DIR:-generated} && docker compose logs core"
  return 1
}

# compose::down — stop and remove containers
# Reads globals: GEN_DIR
compose::down() {
  local gen_dir="${GEN_DIR:?GEN_DIR is required}"
  compose::_docker_compose \
    -f "${gen_dir}/docker-compose.yml" \
    down
}
