#!/usr/bin/env bash
# Frontend source acquisition, patching, and image build.
# Requires lib/ui.sh to be sourced before use.
set -euo pipefail

# Upstream repo used when the local monorepo is absent.
readonly _FRONTEND_REPO_URL="https://gitlab.opencode.de/f13/microservices/frontend.git"

# Git ref (tag or branch) checked out when cloning. Pinned so an
# unattended clone produces a known build, instead of tracking
# whatever main happens to be on the day of install.
readonly _FRONTEND_GIT_REF="v2.0.0"

# IMAGE_TAG for the locally built patched frontend image.  Derived
# from the upstream git ref so a tag bump automatically renames the
# built image — single source of truth.  Format: "<ref>_based" (e.g.
# v2.0.0_based) makes it obvious in `docker images` that this is a
# locally patched copy of upstream v2.0.0.
readonly FRONTEND_IMAGE_TAG="f13-frontend:${_FRONTEND_GIT_REF}_based"

# ---------------------------------------------------------------------------
# Internal helpers — may be overridden in tests
# ---------------------------------------------------------------------------

frontend::_docker_build()         { docker build "$@"; }
frontend::_docker_image_inspect() { docker image inspect "$@" &>/dev/null 2>&1; }
frontend::_git_clone()            { git clone "$@"; }
frontend::_git_ls_remote()        { git ls-remote "$@"; }

# ---------------------------------------------------------------------------
# frontend::get_source DEST_DIR
# Populates DEST_DIR with the frontend source tree by cloning the
# pinned upstream tag.  Always clones; the previous local-monorepo
# fast-path was removed because an arbitrary local checkout could
# diverge from the pinned ref the patched image is supposed to be
# based on, breaking the FRONTEND_IMAGE_TAG (v2.0.0_based) contract.
# ---------------------------------------------------------------------------
frontend::get_source() {
  local dest_dir="${1:?frontend::get_source: DEST_DIR required}"

  if ! command -v git &>/dev/null; then
    ui::err "git not found — needed to clone frontend source. Install git and retry."
    return 1
  fi

  ui::info "Cloning frontend ${_FRONTEND_GIT_REF} from remote..."
  frontend::_git_clone --depth 1 --branch "${_FRONTEND_GIT_REF}" "${_FRONTEND_REPO_URL}" "${dest_dir}"
}

# ---------------------------------------------------------------------------
# frontend::image_exists IMAGE_TAG
# Returns 0 when the local docker image already exists (usable as cache).
# ---------------------------------------------------------------------------
frontend::image_exists() {
  local image_tag="${1:-${FRONTEND_IMAGE_TAG}}"
  frontend::_docker_image_inspect "${image_tag}"
}

# ---------------------------------------------------------------------------
# frontend::patch_and_build IMAGE_TAG
# Orchestrates: get source → apply patches → docker build.
# Set F13_SKIP_BUILD=1 to skip the actual docker build (CI / dry-run).
# ---------------------------------------------------------------------------
frontend::patch_and_build() {
  local image_tag="${1:-${FRONTEND_IMAGE_TAG}}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp_dir}'" ERR EXIT

  frontend::get_source "${tmp_dir}"
  frontend::_patch_uistore "${tmp_dir}"
  frontend::_patch_entrypoint "${tmp_dir}"

  if [[ -n "${F13_SKIP_BUILD:-}" ]]; then
    ui::info "F13_SKIP_BUILD set — skipping docker build."
    trap - ERR EXIT
    rm -rf "${tmp_dir}"
    return 0
  fi

  ui::step "Building patched frontend image (${image_tag})..."
  frontend::_docker_build -t "${image_tag}" "${tmp_dir}"

  trap - ERR EXIT
  rm -rf "${tmp_dir}"
  ui::ok "Frontend image built: ${image_tag}"
}

# ---------------------------------------------------------------------------
# Internal: UIStore.js patch
# Replaces the hardcoded guest-mode feature object with an ENABLED_FEATURES-
# driven version. Matched by content, not line numbers.
# ---------------------------------------------------------------------------
frontend::_patch_uistore() {
  local work_dir="${1:?}"
  local target="${work_dir}/src/utils/UIStore.js"

  if [[ ! -f "${target}" ]]; then
    ui::err "UIStore.js not found at expected path: ${target}"
    return 1
  fi

  if ! grep -q 'most features are enabled by default' "${target}"; then
    ui::info "UIStore.js: old pattern absent — already patched or upstream changed."
    return 0
  fi

  local awk_script tmp_out
  awk_script="$(mktemp)"
  tmp_out="$(mktemp)"

  # Write the awk replacement script to a temp file (avoids quoting hell).
  cat > "${awk_script}" << 'AWKEOF'
/most features are enabled by default/ {
  skip=1
  print ": // If Keycloak is disabled, features are driven by ENABLED_FEATURES"
  print "    writable((() => {"
  print "      const enabled = ("
  print "        (typeof window !== 'undefined' &&"
  print "          window.APP_CONFIG &&"
  print "          window.APP_CONFIG.ENABLED_FEATURES) || 'chat,recherche,askTheText,summary,transcription,feedback'"
  print "      ).split(',').map(f => f.trim());"
  print "      return {"
  print "        chat:          enabled.includes('chat'),"
  print "        recherche:     enabled.includes('recherche'),"
  print "        askTheText:    enabled.includes('askTheText'),"
  print "        summary:       enabled.includes('summary'),"
  print "        transcription: enabled.includes('transcription'),"
  print "        feedback:      enabled.includes('feedback'),"
  print "      };"
  print "    })());"
  next
}
skip && /^[[:space:]]*\}\);?[[:space:]]*$/ { skip=0; next }
skip { next }
{ print }
AWKEOF

  awk -f "${awk_script}" "${target}" > "${tmp_out}"
  mv "${tmp_out}" "${target}"
  rm -f "${awk_script}"
  ui::ok "UIStore.js patched."
}

# ---------------------------------------------------------------------------
# Internal: docker-entrypoint.sh patch
# Injects ENABLED_FEATURES into the generate_config_script function so it
# is written into window.APP_CONFIG at container start.
# ---------------------------------------------------------------------------
frontend::_patch_entrypoint() {
  local work_dir="${1:?}"
  local target=""
  local candidate

  for candidate in \
    "${work_dir}/scripts/docker-entrypoint.sh" \
    "${work_dir}/docker-entrypoint.sh"; do
    if [[ -f "${candidate}" ]]; then
      target="${candidate}"
      break
    fi
  done

  if [[ -z "${target}" ]]; then
    ui::warn "docker-entrypoint.sh not found — skipping entrypoint patch."
    return 0
  fi

  if grep -q 'ENABLED_FEATURES' "${target}"; then
    ui::info "docker-entrypoint.sh already patched — skipping."
    return 0
  fi

  local awk_script tmp_out
  awk_script="$(mktemp)"
  tmp_out="$(mktemp)"

  cat > "${awk_script}" << 'AWKEOF'
# Match the first variable-assignment that calls escape_js_string,
# NOT the 'escape_js_string() {' function-definition line. Inserting
# after the def would put the new line inside the function body and
# cause infinite recursion when generate_config_script calls escape_js_string.
/=\$\(escape_js_string/ && !added_var {
  print
  print "    enabled_features=$(escape_js_string \"${ENABLED_FEATURES:-chat,recherche,askTheText,summary,transcription,feedback}\")"
  added_var=1
  next
}
# The APP_CONFIG object is a one-liner inside a heredoc:
#   <script>window.APP_CONFIG={KEY:"val",...};</script>
# So we match that single line and inject the new field in place,
# right before the closing '};</script>'. Multi-line state matching
# does NOT work here (the original code tried that and never fired).
/window[.]APP_CONFIG[[:space:]]*=/ && !added_field {
  sub(/\};<\/script>/, ",ENABLED_FEATURES:\"${enabled_features}\"};</script>")
  added_field=1
}
{ print }
AWKEOF

  awk -f "${awk_script}" "${target}" > "${tmp_out}"
  mv "${tmp_out}" "${target}"
  # 0755 (not chmod +x) so non-root users (USER 999 in the image) can both
  # read AND execute the script. mktemp gave us 0600; +x would yield 0711.
  chmod 755 "${target}"
  rm -f "${awk_script}"
  ui::ok "docker-entrypoint.sh patched."
}
