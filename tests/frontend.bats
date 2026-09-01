#!/usr/bin/env bats
# Tests for lib/frontend.sh

LIB_DIR="${BATS_TEST_DIRNAME}/../lib"

# Helper: source ui.sh (required by frontend.sh) and frontend.sh
_source_frontend() {
  source "${LIB_DIR}/ui.sh"
  source "${LIB_DIR}/frontend.sh"
}

# ---------------------------------------------------------------------------
# Sourcing / function presence
# ---------------------------------------------------------------------------

@test "lib/frontend.sh sources without error" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/frontend.sh'"
  [ "$status" -eq 0 ]
}

@test "lib/frontend.sh defines frontend::get_source" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/frontend.sh'
    declare -f frontend::get_source > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/frontend.sh defines frontend::image_exists" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/frontend.sh'
    declare -f frontend::image_exists > /dev/null"
  [ "$status" -eq 0 ]
}

@test "lib/frontend.sh defines frontend::patch_and_build" {
  run bash -c "source '${LIB_DIR}/ui.sh'; source '${LIB_DIR}/frontend.sh'
    declare -f frontend::patch_and_build > /dev/null"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# frontend::get_source — git clone (always cloned, no local fast-path)
# ---------------------------------------------------------------------------

@test "frontend::get_source calls git clone with the upstream URL" {
  local dest
  dest="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_git_clone() { echo \"git_clone_called \$*\"; mkdir -p '${dest}/src'; }
    frontend::get_source '${dest}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"git_clone_called"* ]]
  [[ "${output}" == *"gitlab.opencode.de"* ]]
  rm -rf "${dest}"
}

@test "frontend::get_source passes --depth 1 to git clone" {
  local dest
  dest="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_git_clone() { echo \"ARGS: \$*\"; }
    frontend::get_source '${dest}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"--depth 1"* ]]
  rm -rf "${dest}"
}

@test "frontend::get_source pins git clone to v3.0.1 via --branch" {
  local dest
  dest="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_git_clone() { echo \"ARGS: \$*\"; }
    frontend::get_source '${dest}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"--branch v3.0.1"* ]]
  rm -rf "${dest}"
}

@test "frontend::get_source fails if git is not on PATH" {
  local dest
  dest="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    command() { [[ \"\$*\" == *git* ]] && return 1; builtin command \"\$@\"; }
    frontend::get_source '${dest}'
  "
  [ "$status" -ne 0 ]
  rm -rf "${dest}"
}

# ---------------------------------------------------------------------------
# frontend::image_exists
# ---------------------------------------------------------------------------

@test "frontend::image_exists returns 0 when docker inspect succeeds" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_docker_image_inspect() { return 0; }
    frontend::image_exists 'f13-frontend:test'
  "
  [ "$status" -eq 0 ]
}

@test "frontend::image_exists returns 1 when docker inspect fails" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_docker_image_inspect() { return 1; }
    frontend::image_exists 'f13-frontend:test'
  "
  [ "$status" -eq 1 ]
}

@test "frontend::image_exists uses FRONTEND_IMAGE_TAG default" {
  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_docker_image_inspect() { echo \"TAG: \$1\"; return 0; }
    frontend::image_exists
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"f13-frontend:v3.0.1_based"* ]]
}

# ---------------------------------------------------------------------------
# frontend::_patch_uistore
# ---------------------------------------------------------------------------

@test "frontend::_patch_uistore replaces old block with ENABLED_FEATURES block" {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/src/utils"

  cat > "${work_dir}/src/utils/UIStore.js" << 'EOF'
const store = condition
  ? writable({ all: true })
  : // If Keycloak is disabled, most features are enabled by default
    writable({
      chat: true,
      recherche: true,
      askTheText: false,
      summary: true,
      transcription: true,
      feedback: true,
      tools: {
        onlineSearch: true,
        skills: false,
      },
    });
EOF

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_uistore '${work_dir}'
  "
  [ "$status" -eq 0 ]
  grep -q 'ENABLED_FEATURES' "${work_dir}/src/utils/UIStore.js"
  grep -q 'features are driven by ENABLED_FEATURES' "${work_dir}/src/utils/UIStore.js"
  ! grep -q 'most features are enabled by default' "${work_dir}/src/utils/UIStore.js"
  rm -rf "${work_dir}"
}

@test "frontend::_patch_uistore preserves the v3 nested tools object" {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/src/utils"

  cat > "${work_dir}/src/utils/UIStore.js" << 'EOF'
const store = condition
  ? writable({ all: true })
  : // If Keycloak is disabled, most features are enabled by default
    writable({
      chat: true,
      recherche: true,
      askTheText: false,
      summary: true,
      transcription: true,
      feedback: true,
      tools: {
        onlineSearch: true,
        skills: false,
      },
    });

userInfo.subscribe((user) => {
  featureStore.update((features) => ({
    tools: {
      onlineSearch: keycloakIsDisabled
        ? features.tools.onlineSearch
        : roles.indexOf('chat-tools-websearch-access') !== -1,
      skills: keycloakIsDisabled ? features.tools.skills : roles.indexOf('chat-tools-skills-access') !== -1,
    },
  }));
});
EOF

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_uistore '${work_dir}'
  "
  [ "$status" -eq 0 ]
  # The v3 featureStore reads features.tools.onlineSearch on every
  # userInfo update, so a returned object missing the `tools` key
  # throws "Cannot read properties of undefined" at runtime.
  grep -q "tools: {" "${work_dir}/src/utils/UIStore.js"
  grep -q "onlineSearch: enabled.includes('onlineSearch')" "${work_dir}/src/utils/UIStore.js"
  grep -q "skills:       enabled.includes('skills')" "${work_dir}/src/utils/UIStore.js"
  rm -rf "${work_dir}"
}

@test "frontend::_patch_uistore is idempotent when already patched" {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/src/utils"

  cat > "${work_dir}/src/utils/UIStore.js" << 'EOF'
: // If Keycloak is disabled, features are driven by ENABLED_FEATURES
    writable((() => {
      const enabled = (window.APP_CONFIG.ENABLED_FEATURES || 'chat').split(',');
      return { chat: enabled.includes('chat') };
    })())
EOF

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_uistore '${work_dir}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"already patched"* ]] || [[ "${output}" == *"pattern"* ]]
  rm -rf "${work_dir}"
}

@test "frontend::_patch_uistore fails when UIStore.js not found" {
  local work_dir
  work_dir="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_uistore '${work_dir}'
  "
  [ "$status" -ne 0 ]
  rm -rf "${work_dir}"
}

# ---------------------------------------------------------------------------
# frontend::_patch_entrypoint
# ---------------------------------------------------------------------------

@test "frontend::_patch_entrypoint adds ENABLED_FEATURES to entrypoint" {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/scripts"

  cat > "${work_dir}/scripts/docker-entrypoint.sh" << 'EOF'
#!/bin/sh
generate_config_script() {
  local keycloak_disabled
  keycloak_disabled=$(escape_js_string "${KEYCLOAK_DISABLED:-false}")
  cat > /app/config.js << CONFIG
window.APP_CONFIG = {
  KEYCLOAK_DISABLED: "${keycloak_disabled}",
};
CONFIG
}
EOF

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_entrypoint '${work_dir}'
  "
  [ "$status" -eq 0 ]
  grep -q 'ENABLED_FEATURES' "${work_dir}/scripts/docker-entrypoint.sh"
  rm -rf "${work_dir}"
}

@test "frontend::_patch_entrypoint is idempotent when already patched" {
  local work_dir
  work_dir="$(mktemp -d)"
  mkdir -p "${work_dir}/scripts"

  cat > "${work_dir}/scripts/docker-entrypoint.sh" << 'EOF'
#!/bin/sh
  enabled_features=$(escape_js_string "${ENABLED_FEATURES:-chat}")
  ENABLED_FEATURES:"${enabled_features}",
EOF

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_entrypoint '${work_dir}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"already patched"* ]]
  rm -rf "${work_dir}"
}

@test "frontend::_patch_entrypoint warns but succeeds when entrypoint absent" {
  local work_dir
  work_dir="$(mktemp -d)"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    frontend::_patch_entrypoint '${work_dir}'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"not found"* ]]
  rm -rf "${work_dir}"
}

# ---------------------------------------------------------------------------
# frontend::patch_and_build
# ---------------------------------------------------------------------------

@test "frontend::patch_and_build calls docker build with correct tag" {
  local fake_fe work_dir
  fake_fe="$(mktemp -d)"
  mkdir -p "${fake_fe}/src/utils" "${fake_fe}/scripts"

  cat > "${fake_fe}/src/utils/UIStore.js" << 'EOF'
: // If Keycloak is disabled, most features are enabled by default
    writable({
      chat: true,
      recherche: true,
      askTheText: false,
      summary: true,
      transcription: true,
      feedback: true,
    })
EOF
  echo '#!/bin/sh' > "${fake_fe}/scripts/docker-entrypoint.sh"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    _FRONTEND_LOCAL_PATH='${fake_fe}'
    frontend::_docker_build() { echo \"docker_build_called \$*\"; }
    frontend::patch_and_build 'f13-frontend:test-tag'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"docker_build_called"* ]]
  [[ "${output}" == *"f13-frontend:test-tag"* ]]
  rm -rf "${fake_fe}"
}

@test "frontend::patch_and_build skips docker build when F13_SKIP_BUILD set" {
  local fake_fe
  fake_fe="$(mktemp -d)"
  mkdir -p "${fake_fe}/src/utils" "${fake_fe}/scripts"

  cat > "${fake_fe}/src/utils/UIStore.js" << 'EOF'
: // If Keycloak is disabled, most features are enabled by default
    writable({
      chat: true,
      recherche: true,
      askTheText: false,
      summary: true,
      transcription: true,
      feedback: true,
    })
EOF
  echo '#!/bin/sh' > "${fake_fe}/scripts/docker-entrypoint.sh"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    _FRONTEND_LOCAL_PATH='${fake_fe}'
    F13_SKIP_BUILD=1
    frontend::_docker_build() { echo 'SHOULD_NOT_RUN'; exit 1; }
    frontend::patch_and_build 'f13-frontend:test'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" != *"SHOULD_NOT_RUN"* ]]
  rm -rf "${fake_fe}"
}

@test "frontend::patch_and_build patches UIStore.js before building" {
  local fake_fe
  fake_fe="$(mktemp -d)"
  mkdir -p "${fake_fe}/src/utils" "${fake_fe}/scripts"

  cat > "${fake_fe}/src/utils/UIStore.js" << 'EOF'
: // If Keycloak is disabled, most features are enabled by default
    writable({
      chat: true,
      recherche: true,
      askTheText: false,
      summary: true,
      transcription: true,
      feedback: true,
    })
EOF
  echo '#!/bin/sh' > "${fake_fe}/scripts/docker-entrypoint.sh"

  run bash -c "
    source '${LIB_DIR}/ui.sh'
    source '${LIB_DIR}/frontend.sh'
    _FRONTEND_LOCAL_PATH='${fake_fe}'
    frontend::_docker_build() {
      # Args: -t <image_tag> <build_context>  — context is last arg
      local ctx=\"\${*: -1}\"
      if grep -q 'ENABLED_FEATURES' \"\${ctx}/src/utils/UIStore.js\"; then
        echo 'UISTORE_PATCHED'
      else
        echo 'UISTORE_NOT_PATCHED'
        exit 1
      fi
    }
    frontend::patch_and_build 'f13-frontend:test'
  "
  [ "$status" -eq 0 ]
  [[ "${output}" == *"UISTORE_PATCHED"* ]]
  rm -rf "${fake_fe}"
}
