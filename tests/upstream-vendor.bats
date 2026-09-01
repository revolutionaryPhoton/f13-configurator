#!/usr/bin/env bats
# Tests for docs/upstream/v3 (S121 — vendored core/chat v3.0.0 reference configs)

UPSTREAM_DIR="${BATS_TEST_DIRNAME}/../docs/upstream"

@test "docs/upstream/README.md exists and names both v3.0.0 tags" {
  [ -f "${UPSTREAM_DIR}/README.md" ]
  run grep -c 'v3.0.0' "${UPSTREAM_DIR}/README.md"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "vendored core v3 reference files are present and non-empty" {
  for f in general.yml llm_models.yml prompt_maps.yml agentic_chat.yml \
           apisix/apisix.yaml apisix/apisix-guest.yaml \
           apisix/config.yaml apisix/config-guest.yaml; do
    path="${UPSTREAM_DIR}/v3/core/${f}"
    [ -s "$path" ]
  done
}

@test "vendored chat v3 reference files are present and non-empty" {
  for f in general.yml llm_models.yml prompt_maps.yml agentic_chat.yml \
           opa/policies/permissions.rego opa/policies/test_permissions.rego \
           migration.md; do
    path="${UPSTREAM_DIR}/v3/chat/${f}"
    [ -s "$path" ]
  done
}

@test "vendored chat general.yml declares the mandatory opa service endpoint" {
  run grep -c 'opa:' "${UPSTREAM_DIR}/v3/chat/general.yml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "vendored chat agentic_chat.yml has no tools.<tool>.role entries" {
  run grep -c '^\s*role:' "${UPSTREAM_DIR}/v3/chat/agentic_chat.yml"
  [ "$status" -eq 1 ]
}

@test "vendored chat llm_models.yml uses context_length not max_context_tokens" {
  run grep -c 'context_length' "${UPSTREAM_DIR}/v3/chat/llm_models.yml"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -c 'max_context_tokens' "${UPSTREAM_DIR}/v3/chat/llm_models.yml"
  [ "$status" -eq 1 ]
}
