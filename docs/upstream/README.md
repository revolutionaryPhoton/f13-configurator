# Vendored upstream reference configs

Phase 17 (`feat/phase17-rebaseline`) re-baselines the configurator onto
core v3.0.0 + chat v3.0.0. Every later Phase 17 story diffs its generated
output against the files under `v3/` instead of guessing at the upstream
schema, so they must stay byte-for-byte as fetched (no hand-edits).

## Sources

| Repo | Tag | Commit | Fetched |
|---|---|---|---|
| `f13/microservices/core` | `v3.0.0` | `c20cc1bb28cc91d9da56d02577da7fbeae324538` | 2026-09-01 |
| `f13/microservices/chat` | `v3.0.0` | `b1f1dd04c9c3d771357c0da1f959bd806d9ff519` | 2026-09-01 |

Fetched anonymously (read-only) from:

```
git clone --depth 1 --branch v3.0.0 https://gitlab.opencode.de/f13/microservices/core.git
git clone --depth 1 --branch v3.0.0 https://gitlab.opencode.de/f13/microservices/chat.git
```

## Layout

```
v3/core/
  general.yml          upstream configs/general.yml
  llm_models.yml        upstream configs/llm_models.yml
  prompt_maps.yml        upstream configs/prompt_maps.yml
  agentic_chat.yml        upstream configs/agentic_chat.yml
  apisix/apisix.yaml           upstream configs/apisix/apisix.yaml
  apisix/apisix-guest.yaml       upstream configs/apisix/apisix-guest.yaml
  apisix/config.yaml           upstream configs/apisix/config.yaml
  apisix/config-guest.yaml       upstream configs/apisix/config-guest.yaml

v3/chat/
  general.yml          upstream configs/general.yml
  llm_models.yml        upstream configs/llm_models.yml
  prompt_maps.yml        upstream configs/prompt_maps.yml
  agentic_chat.yml        upstream configs/agentic_chat.yml
  opa/policies/permissions.rego     upstream opa/policies/permissions.rego
  opa/policies/test_permissions.rego  upstream opa/policies/test_permissions.rego
  migration.md          upstream docs/migration.md
```

## Confirmed startup-fatal facts (cross-checked against these files)

- `v3/chat/general.yml` has `service_endpoints.opa: http://opa:8181/` —
  chat v3 refuses to boot without it.
- `v3/chat/agentic_chat.yml` has zero `tools.<tool>.role` entries — any
  leftover `role` key prevents startup.
- `v3/chat/llm_models.yml` uses `context_length` (not `max_context_tokens`)
  on every model entry.
- `v3/core/general.yml` has no `active_llms.embedding` key, adds
  `llm_api_timeout: 180`, and its `service_endpoints` list has no
  `transcription_inference` key (replaced by `inference-adapter` /
  `inference`, both out of scope for the minimal stack).
- `grep -c 'microservices/core' v3/core/*` (not vendored — see upstream
  `docker-compose.yml` in the cloned repo) returns 0: the `core` service
  in the v3 deployment is `apache/apisix:3.15.0-ubuntu`, not an F13 image.

## Not vendored (out of scope for Phase 17)

RAG, summary, parser, transcription, inference-adapter, tusd, rustfs,
elasticsearch, and reranker configs exist upstream but are not copied
here — the minimal stack this phase targets omits them entirely.
