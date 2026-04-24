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

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# compose::up — start detached services, then wait healthy and show summary
# Reads globals: GEN_DIR, CORE_PORT, FRONTEND_PORT
compose::up() {
  local gen_dir="${GEN_DIR:?GEN_DIR is required}"

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
