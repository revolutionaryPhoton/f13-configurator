#!/usr/bin/env bash
# Host Ollama detection and model listing
set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers — overridable in tests
# ---------------------------------------------------------------------------

# ollama::_curl_tags: fetch the /api/tags response from local Ollama.
ollama::_curl_tags() {
  curl -fsS --max-time 2 "http://localhost:11434/api/tags"
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# ollama::is_running
# Returns 0 if the Ollama HTTP API responds within 2 s, 1 otherwise.
ollama::is_running() {
  ollama::_curl_tags >/dev/null 2>&1
}

# ollama::list_models
# Prints one model name per line parsed from /api/tags JSON. No jq required.
# Returns 1 (and prints nothing) if Ollama is unreachable.
ollama::list_models() {
  local json
  json=$(ollama::_curl_tags) || return 1
  # grep exits 1 when no matches; that's valid (empty list), not an error.
  printf '%s\n' "${json}" \
    | grep -o '"name":"[^"]*"' \
    | sed 's/^"name":"//; s/"$//' \
    || true
}

# ollama::host_url_for_docker
# Prints the base URL the chat container should use to reach host Ollama.
# The URL is identical on macOS and Linux; Linux compose templates must also
# add extra_hosts: host.docker.internal:host-gateway (handled in S09).
ollama::host_url_for_docker() {
  printf 'http://host.docker.internal:11434/v1\n'
}
