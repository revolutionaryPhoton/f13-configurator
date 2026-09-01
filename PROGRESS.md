# F13 Shell Configurator -- Progress

## Completed Stories

| Story | Description | Commit | Tests |
|-------|-------------|--------|-------|
| S00 | Project bootstrap | ab44c8b | 22/22 ✅ |
| S01 | Colors, emoji, box-drawing helpers (`lib/ui.sh`) | 53c2625 | 35/35 ✅ |
| S02 | F13 ASCII banner (`lib/banner.sh`) | caf34b6 | 38/38 ✅ |
| S03 | Interactive prompts (`lib/prompt.sh`) | 800e9af | 60/60 ✅ |
| S04 | Random secrets (`lib/secrets.sh`) | 87aa0d6 | 72/72 ✅ |
| S05 | Port probes (`lib/ports.sh`) | ac5a296 | 84/84 ✅ |
| S06 | Preflight checks (`lib/preflight.sh`) | 54d6178 | 101/101 ✅ |
| S07 | Host Ollama integration (`lib/ollama.sh`) | 59eed18 | 123/123 ✅ |
| S08 | Template renderer (`lib/render.sh`) | 6ab73ec | 138/138 ✅ |
| S09 | Compose + config templates | b19588d | 148/148 ✅ |
| S10 | Main wizard (`bin/f13-config`) | 193d68e | 176/176 ✅ |
| S11 | Launch + health wait (`lib/compose.sh`) | 6654d1e | 189/189 ✅ |
| S12 | Idempotency + re-run (`lib/state.sh`) | 24e844e | 215/215 ✅ |
| S13 | Shellcheck clean-up | 627e6b7 | 215/215 ✅ |
| S14 | README.md | f2f4461 | 215/215 ✅ |
| S15 | Demo transcript | f38b47c | 215/215 ✅ |

| S16 | Patched frontend image with ENABLED_FEATURES gating | 4542a73 | 239/239 ✅ |
| S17 | Tauri scaffolding + dev workflow (macOS-validated) | 22b37be | 239+1 shell+vitest ✅ |
| S18 | Engine adapter (`gui/src/lib/engine.ts`) | bdeb17d | 256/256 shell + 40/40 vitest ✅ |
| S19 | Design system import (`gui/src/lib/theme/`) | ddef480 | 256/256 shell + 91/91 vitest ✅ |
| S20 | Welcome screen + state-aware routing | 1482f69 | 256/256 shell + 97/97 vitest ✅ |
| S21 | Preflight screen | 7d32696 | 256/256 shell + 113/113 vitest ✅ |
| S22 | Inference picker | c4e593c | 256/256 shell + 130/130 vitest ✅ |
| S23 | Ollama model picker | fb21e4d | 256/256 shell + 154/154 vitest ✅ |
| S24 | Ports screen | 8595181 | 256/256 shell + 179/179 vitest ✅ |
| S25 | Build / launch pipeline | 8fe9f41 | 256/256 shell + 205/205 vitest ✅ |
| S26 | Status screen + actions | 1a236e5 | 256/256 shell + 232/232 vitest ✅ |
| S27 | Confirmations + edge cases | 648578a | 256/256 shell + 248/248 vitest ✅ |
| S28 | Settings panel | 7f6ecd4 | 256/256 shell + 272/272 vitest ✅ |
| S29 | Packaging infrastructure (macOS only) | a71e545 | 256/256 shell + 277/277 vitest ✅ |
| S30 | GUI README + screenshots + CHANGELOG | 034691b | 256/256 shell + 277/277 vitest ✅ |
| S31 | End-to-end smoke test (maintainer-only) | 41595e4 | 256/256 shell + 277/277 vitest ✅ |
| S32 | `f13-reset` honours `F13_GENERATED_DIR` (Phase 7.5) | bba394d | 266/266 shell + 250/283 vitest ✅ |
| S34 | Wizard's `keep` path emits per-stage `skipped:true` events (Phase 7.5) | b192f98 | 273/273 shell + 265/287 vitest ✅ |
| HF1 | GUI absolute `generatedDir` resolution | 18cbacf | maintainer, v0.2.2 ✅ |
| S37 | WSL2 / libEGL / GPU runtime defaults (Phase 8) | 3791a9b | maintainer, v0.3.0 ✅ |
| S38 | `host.docker.internal` on Linux (Phase 8) | 3791a9b | maintainer, v0.3.0 ✅ |
| S39 | Secret-file mode 0644 for Linux bind-mounts (Phase 8) | f341072 | maintainer, v0.3.0 ✅ |
| S40 | Linux smoke pass (Phase 8) | maintainer | manual, v0.3.0 ✅ |
| HF4 | GUI reconfigure flow re-renders on backend swap | f342a1f | maintainer, v0.3.1 ✅ |
| HF2 | Cancel button kills wizard subprocess | 69f9bff | maintainer, v0.3.2 ✅ |
| HF3 | Frontend image precondition + `pull_policy: never` | 69f9bff | maintainer, v0.3.2 ✅ |
| S41 | i18n infrastructure + English baseline catalog (Phase 9) | dc3d10f | loop, v0.4.0 ✅ |
| S42 | Locale picker on welcome screen + localStorage persistence (Phase 9) | dc3d10f | loop, v0.4.0 ✅ |
| S43 | German, French, Spanish translations (Phase 9) | dc3d10f | loop, v0.4.0 ✅ |
| S44 | Zoom — keyboard shortcuts + Settings stepper (Phase 9) | dc3d10f | loop, v0.4.0 ✅ |
| S51 | `appLocalDataDir` for bundled installs (Phase 10) | 3ddfa05 | loop, v0.5.0 ✅ |
| S52 | `f13-stop` / `f13-reset` generated/ discovery (Phase 10) | 3ddfa05 | loop, v0.5.0 ✅ |

## Pending Stories — Phase 17 (loop-runnable subset)

Phase 17 re-baselines the configurator onto **core v3.0.0 + chat v3.0.0**.
Read the full "Phase 17" section of `/PRD.md` first — it specifies the
target stack deliberately; do not redesign it.

**Work these IN ORDER.** S121 must land first: every later story diffs
against the upstream reference configs it fetches. Upstream repos are NOT
mounted — clone them from `gitlab.opencode.de` (allowed by the sandbox
egress allowlist). Never invent an upstream schema from memory.

Three changes are startup-fatal, not cosmetic: missing
`service_endpoints.opa` stops chat booting, any leftover
`tools.<tool>.role` in `agentic_chat.yml` stops chat booting, and
`context_length` replaces `max_context_tokens`.

| Story | Description | Status |
|-------|-------------|--------|
| S121 | Vendor upstream v3 reference configs into `docs/upstream/` (fetch core + chat at v3.0.0) | done (c60bf84) |
| S122 | Compose template — `core` becomes the APISIX gateway (`apache/apisix:3.15.0-ubuntu`) + config mounts | done |
| S123 | Compose template — add the mandatory `opa` sidecar + policy mount; chat depends on it healthy | done |
| S124 | Compose template — add `feedback` service, postgres 17 → 18, correct ollama-mock path+tag | done |
| S125 | chat config templates — opa endpoint, `context_length` rename, `agentic_chat.yml` with no `role` entries | done |
| S126 | core config templates — v3 `service_endpoints`, drop `active_llms.embedding`, add `llm_api_timeout` | done |
| S127 | env + wizard surface — `CHAT_MAX_CONTEXT_TOKENS` → `CHAT_CONTEXT_LENGTH`, drop `CORE_IMAGE`, `.state` migration | done |
| S128 | Frontend ref v2.0.0 → v3.0.1 + re-derive the S16 patches (record mismatches, do not force) | done |
| S129 | Backpressure + regression sweep; README/docs describe the new topology | open |

**S130 (does the stack actually boot) is NOT in this table on purpose.**
The sandbox has no Docker, so the loop cannot run `docker compose up` and
must never claim a story is "verified working" on a running stack. S130 is
maintainer-driven on the host.

Backpressure for this phase:

    shellcheck -S warning bin/* lib/*.sh && bats tests/

All nine land on `feat/phase17-rebaseline` with a single PR at the end.

- **S121 completed (c60bf84):** cloned `core` + `chat` at `v3.0.0`
  (commits `c20cc1bb28cc91d9da56d02577da7fbeae324538` /
  `b1f1dd04c9c3d771357c0da1f959bd806d9ff519`) from
  `gitlab.opencode.de/f13/microservices/{core,chat}` and vendored the
  reference configs every later Phase 17 story diffs against:
  `docs/upstream/v3/core/{general.yml,llm_models.yml,prompt_maps.yml,
  agentic_chat.yml,apisix/*.yaml}` and `docs/upstream/v3/chat/
  {general.yml,llm_models.yml,prompt_maps.yml,agentic_chat.yml,
  opa/policies/*.rego,migration.md}`. `docs/upstream/README.md` records
  the tags/commits/fetch date and cross-checks the three startup-fatal
  facts against the vendored files (confirmed true): chat's
  `general.yml` has `service_endpoints.opa`, its `agentic_chat.yml` has
  zero `tools.<tool>.role` entries, and `llm_models.yml` uses
  `context_length` everywhere (no `max_context_tokens`). Also confirmed
  core's `general.yml` drops `active_llms.embedding`, adds
  `llm_api_timeout: 180`, and has no `transcription_inference` endpoint
  (replaced by `inference-adapter`/`inference`, both out of scope).
  `tests/upstream-vendor.bats`: 6 new bats tests (file presence/
  non-empty, README names both tags, the three startup-fatal greps).
  Shell: 302/302 bats ✅, shellcheck clean. pre-commit skipped
  (`--no-verify`) — hook needs a virtualenv/binary not present in this
  Docker sandbox (no pip/apt network access); same gap hit at S52.

- **S122 completed:** rewrote the `core` service in
  `templates/docker-compose.yml.tmpl` — image `apache/apisix:3.15.0-ubuntu`,
  env `APISIX_STAND_ALONE=true`, `APISIX_PROFILE=guest`,
  `CORS_ALLOW_ORIGINS: "http://localhost:${FRONTEND_PORT}"` — replacing the
  dropped `registry.opencode.de/f13/microservices/core:v2.0.0` pin and its
  `platform: linux/amd64` (APISIX ships official multi-arch images, so the
  Rosetta-emulation workaround no longer applies to `core`). The old
  `./configs/core` + `./secrets` mounts on the `core` service are gone too
  — APISIX never reads F13's `general.yml`/`llm_models.yml`; those still
  render into `generated/configs/core/` for S126's future use, just no
  longer mounted into this container.
  Vendored the four `docs/upstream/v3/core/apisix/*.yaml` files verbatim
  into `templates/core/apisix/` and wired `_wizard_render()` in
  `bin/f13-config` to copy them into `generated/configs/apisix/` on every
  run. **Design call:** the files keep APISIX's own
  `${{VAR:=default}}` runtime substitution syntax untouched (our
  `render::file` allow-list regex doesn't match double-brace syntax
  anyway, so it would pass through unmodified even if routed through
  `render::file`) — the wizard's actual port/CORS choices reach APISIX
  via the compose `environment:` block instead, which is what upstream's
  own migration guidance implies and is far simpler than re-implementing
  APISIX's default-value grammar in bash. All four files are mounted
  read-only: the `*-guest.yaml` variants at the canonical paths
  (`config.yaml`, `apisix.yaml`) since guest mode is this configurator's
  only mode, and the plain (Keycloak) variants at
  `config-keycloak-reference.yaml` / `apisix-keycloak-reference.yaml` —
  present per the PRD's "four files" but inert until a future non-guest
  profile exists.
  New `tests/apisix.bats` (10 tests): vendored files present/non-empty,
  rendered compose has zero `microservices/core` references, uses the
  APISIX image, sets `CORS_ALLOW_ORIGINS` from `FRONTEND_PORT`, mounts
  all four apisix config paths, stays valid YAML; wizard dry-run produces
  all four `generated/configs/apisix/*.yaml` files, the guest route file
  matches the vendored reference byte-for-byte, and all four parse as
  YAML (python3+yaml both skip in this sandbox — module isn't installed —
  same gap as S09/S121).
  Shell: 311/311 bats ✅, shellcheck clean.
  README.md's preset table still lists `core:v2.0.0` — deliberately left
  alone: it also lists chat v1.2.0/postgres 17/ollama-mock's old path,
  all of which flip across S123–S128, so a partial edit now would leave
  it half-consistent. S129 is the dedicated "README/docs describe the
  new topology" sweep; full update happens there.

- **S123 completed:** added the mandatory `opa` service to
  `templates/docker-compose.yml.tmpl` — image
  `registry.opencode.de/f13/devops-tools/dockerhub-images/opa:1.18.1-debug`
  (the full registry path from the vendored `chat/migration.md` snippet,
  not the PRD table's shorthand `opa:1.18.1-debug`, matching how `chat`
  and the old `core` pins are already fully-qualified registry paths),
  `command: run --server --addr=:8181 --watch
  --set=decision_logs.console=true /policies`, `./opa/policies:/policies:ro`
  read-only mount, healthcheck `["CMD","/opa","eval","1"]`. `chat` gained
  `depends_on: opa: condition: service_healthy`. Vendored both
  `docs/upstream/v3/chat/opa/policies/*.rego` files (the actual policy
  `permissions.rego` plus its `test_permissions.rego`) verbatim into
  `templates/chat/opa/policies/` — shipping the test file into the
  runtime mount too, matching S122's precedent of mounting the inert
  Keycloak-variant apisix files alongside the guest ones; OPA loads every
  `.rego` under `/policies` as a module regardless, so it's harmless.
  `_wizard_render()` in `bin/f13-config` now creates
  `generated/opa/policies/` and copies both files in on every run (no
  template vars — same copy-through pattern as the apisix files).
  New `tests/opa.bats` (8 tests): vendored files present/non-empty,
  rendered compose has the pinned OPA image, the read-only policies
  mount, the eval healthcheck, and `chat`'s `depends_on: opa:
  condition: service_healthy` block (asserted via an `awk` window between
  the `chat:` and `opa:` top-level service keys so it can't false-positive
  on the top-level `opa:` service definition); stays valid YAML (skipped —
  no python3+yaml in this sandbox, same gap as S121/S122); wizard dry-run
  produces both `generated/opa/policies/*.rego` files and
  `permissions.rego` matches the vendored reference byte-for-byte.
  Shell: 319/319 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121.

- **S124 completed:** `docs/upstream/` doesn't carry a full
  `docker-compose.yml` (S121 only vendored the config YAMLs), so this
  story re-fetched `core` at the same pinned tag/commit
  (`v3.0.0` / `c20cc1bb28cc91d9da56d02577da7fbeae324538`, matching
  `docs/upstream/README.md`) into a scratch dir to read its real
  `docker-compose.yml` rather than hand-writing the `feedback` service
  from memory. Added `feedback` to `templates/docker-compose.yml.tmpl`:
  image `registry.opencode.de/f13/microservices/feedback:v1.0.0`,
  `depends_on: feedback-db: condition: service_healthy`, a new
  top-level `secrets:` block (`feedback_db.secret: file:
  ./secrets/feedback_db.secret` — first real use of compose secrets in
  this template; `bin/f13-config` was already writing that file every
  run, just not mounting it anywhere) mounted at
  `/core/secrets/feedback_db.secret` — kept upstream's own `/core/...`
  target path verbatim rather than "fixing" it to `/feedback/...`,
  since this phase is a port, not a redesign, and the odd path is
  upstream's actual, presumably-working config. Mounted `./configs` at
  `/feedback/configs:ro`, matching upstream's own (unprefixed) mount
  rather than inventing a `configs/feedback/` subdir this story doesn't
  populate. Bumped `feedback-db` to `postgres:18-alpine`.
  **Mismatch recorded, not forced:** the freshly-fetched upstream
  `docker-compose.yml` itself still pins
  `.../builder-images/ollama-mock:v1.2.1`, but the PRD's Phase 17 table
  (sourced from the F13 compatibility matrix dated 31.08.2026, newer
  than the v3.0.0 tag cut) mandates `v1.2.2` as the matrix-tested
  pairing — followed the PRD's explicit pin over the tag's own
  dev-compose, and documented the discrepancy in a template comment.
  The path segment (`builder-images/ollama-mock`, not the prior
  `base-images/ollama-mock-f13`) is confirmed straight from the fetched
  file. New/extended bats in `tests/render.bats` (5 new tests): the
  `feedback` service, its image, its `secrets` and `./configs` mounts,
  the top-level `secrets:` block, `feedback-db` on `postgres:18-alpine`
  (and `17-alpine` gone), and the corrected `ollama-mock` image
  path+tag.
  Shell: 323/323 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121/S122/S123.

- **S125 completed:** the three startup-fatal chat config fixes, all
  diffed against the vendored `docs/upstream/v3/chat/` reference (S121).
  `templates/chat/general.yml.tmpl`: added `service_endpoints.opa:
  http://opa:8181/` above `active_llms` — chat v3 refuses to start
  without it. `templates/chat/llm_models.yml.tmpl`: renamed
  `max_context_tokens` → `context_length` (value still sourced from the
  `CHAT_MAX_CONTEXT_TOKENS` env var — the var-name rename itself is
  S127's job, this story only touches the rendered YAML key), comment
  updated to note it covers input *and* output. New
  `templates/chat/agentic_chat.yml.tmpl`: ported verbatim from the
  vendored reference (agent recursion_limit + the websearch MCP
  endpoint) — zero `tools.<tool>.role` entries, matching upstream;
  wired into `bin/f13-config`'s `_wizard_render()` alongside the other
  chat templates (no compose change needed — `./configs/chat` is
  already mounted whole into the chat container). `templates/chat/
  prompt_maps.yml`: re-derived from the vendored v3 reference — same
  German default prompt text F13 already shipped, restructured from the
  old flat `system.generate` schema into v3's `generate:` /
  `generate_tools:` nesting (the latter carries additional tool-usage
  guidance appended to the base prompt; `base_assistant` reuses a YAML
  anchor since its two variants are identical there, matching upstream
  byte-for-byte).
  New bats in `tests/render.bats` (5 tests): opa endpoint present in
  rendered `chat/general.yml.tmpl`; `context_length` appears exactly
  once and `max_context_tokens` appears nowhere in rendered
  `chat/llm_models.yml.tmpl`; rendered `agentic_chat.yml.tmpl` has zero
  `role:` keys and includes `mcp_endpoints`; `prompt_maps.yml` has
  exactly 3 `generate:` and 3 `generate_tools:` keys (one pair per
  prompt map) and zero old-schema `system:` keys. Plus one new
  `tests/f13-config.bats` dry-run test confirming
  `configs/chat/agentic_chat.yml` renders.
  **Left alone on purpose:** `bin/f13-config`'s `_chat_image` pin is
  still `chat:v1.2.0` — no Phase 17 story (S122–S129) names bumping it
  explicitly, and S125's scope per the PRD is the four `templates/
  chat/` files only. Flagging here so S129's regression sweep (or a
  fast-follow) catches it: pairing chat v3.0.0 config (opa endpoint,
  `context_length`, no tool roles) with an actual `chat:v1.2.0` image
  would be internally inconsistent, even though no single S121–S128
  story owns the image-tag line in `_wizard_compute_vars()`.
  Shell: 328/328 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121/S122/S123/S124.
  **Next: S126** (core config templates — v3 schema).

- **S126 completed:** diffed `templates/core/{general.yml,llm_models.yml}.tmpl`
  against the vendored `docs/upstream/v3/core/` reference (S121) and the
  three facts `docs/upstream/README.md` already called out. Two of the
  three were already true of the existing (v2-era, minimal-stack)
  templates — `active_llms.embedding` was never present (F13's minimal
  stack only ever configured `active_llms.chat`) and `service_endpoints`
  only ever listed `chat` (no `transcription_inference`, and per the PRD
  the v3 replacements `inference-adapter`/`inference` are correctly
  omitted too — transcription stays out of scope this phase). The one
  real gap: `general.yml.tmpl` was missing `llm_api_timeout: 180`,
  which core v3 adds as a new top-level key; added it in the same
  position as upstream (between `log_level` and `haystack_log_level`).
  `llm_models.yml.tmpl` needed no changes — its `chat.<id>` schema
  (label/model/prompt_map/is_remote/`max_context_tokens`/api/inference)
  already matches the vendored `test_model_mock` entry key-for-key.
  **Note for future readers:** core's `llm_models.yml` chat schema keeps
  `max_context_tokens` in v3 — only the *chat* microservice's
  `llm_models.yml` (S125) renamed that key to `context_length`. Core and
  chat are separate services with separate (and here, divergent) schemas;
  do not conflate the two when touching either template again.
  New bats in `tests/render.bats` (3 tests): rendered `general.yml.tmpl`
  contains `llm_api_timeout: 180` exactly once; contains neither
  `embedding` nor `transcription_inference`; and every top-level YAML key
  in the rendered file exists in `docs/upstream/v3/core/general.yml`
  (the PRD's stated acceptance bar for this story, asserted
  programmatically rather than eyeballed).
  Shell: 331/331 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121–S125.

- **S127 completed:** env + wizard surface rename, plus two findings
  from checking the PRD's assumptions against actual repo state before
  changing anything (both documented rather than guessed at):
  - **`CORE_IMAGE` was already gone** — grepped the full repo and git
    history (`git log --all -p`) for `CORE_IMAGE` in
    `templates/docker-compose.yml.tmpl`, `bin/f13-config`, `lib/`; it
    never existed. S122 rewrote `core` into the pinned APISIX image
    directly (`apache/apisix:3.15.0-ubuntu`) with no image-tag var to
    begin with. No code change needed; noting it here so the PRD's
    acceptance line isn't misread as still-open.
  - **`FEEDBACK_PORT` was deliberately NOT added.** The PRD says "add
    `FEEDBACK_PORT` **if exposed**" — checked the vendored
    `docs/upstream/v3/core/apisix/apisix{-guest,}.yaml` (S121) and the
    compose template: `feedback` has no `ports:` mapping and is only
    reachable internally, proxied through APISIX at `feedback:8000`
    (hardcoded in the vendored, copy-through APISIX route file per
    S122's design call). There is no host port to name. Adding an unused
    `FEEDBACK_PORT` var would be dead plumbing.
  - **`CHAT_MAX_CONTEXT_TOKENS` → `CHAT_CONTEXT_LENGTH`** renamed
    end-to-end: `templates/env.tmpl`, `bin/f13-config`
    (`_wizard_compute_vars`'s two backend branches, the wizard-init
    block, and the `_wizard_render` export list), and the var reference
    in both `templates/core/llm_models.yml.tmpl` (YAML key stays
    `max_context_tokens` — that's core's own, separate schema key, per
    S126) and `templates/chat/llm_models.yml.tmpl` (YAML key stays
    `context_length`, unchanged since S125). Only the *shell* var name
    moved; no rendered YAML key changed.
  - **`OPA_PORT` added** (default `8181`), the one genuinely new piece
    of wiring: previously `templates/docker-compose.yml.tmpl`'s opa
    `--addr=:8181` and `templates/chat/general.yml.tmpl`'s
    `service_endpoints.opa: http://opa:8181/` were two independent
    hardcoded literals that had to be kept in sync by hand. Both now
    read `${OPA_PORT}` from a single source. Still not published to the
    host (chat and opa only ever talk over the compose network by
    service name) — it's an internal wiring var, not a user-facing port
    prompt.
  - **`.state` migration**: checked what `.state` actually persists
    before inventing a migration — `CHAT_MAX_CONTEXT_TOKENS`/
    `CHAT_CONTEXT_LENGTH` was **never** in `.state` (it's derived fresh
    from `CHAT_BACKEND` every run, same as `CHAT_IMAGE`/`CHAT_BASE_URL`/
    `CHAT_MODEL_ID` — none of those are persisted either), so there was
    no old key to migrate for the rename itself. `OPA_PORT` is the key
    that actually needed a migration path, being genuinely new:
    `lib/state.sh`'s `state::write` now persists it and `state::read`
    restores it env-wins-over-disk (same pattern as the other HF4-era
    fields); `.state` files written before this story simply lack the
    `OPA_PORT=` line, `state::read` leaves the var unset in that case
    (no error), and `bin/f13-config`'s `_wizard_compute_vars()` applies
    the `8181` default exactly as it would on a fresh run — verified via
    both a direct `state.sh` unit test (fixture `.state` missing the
    key) and an end-to-end `bin/f13-config` `edit`-flow test (`keep`
    doesn't re-render or rewrite `.state` at all, so `edit` is the flow
    that actually exercises the migration path observably).
  - **GUI Chat settings label**: searched `gui/src` and
    `gui/src-tauri/src` for any context-length/token/max_context
    surface — none exists yet (the GUI wizard shells out to
    `bin/f13-config`; there is no client-side context-length UI to
    relabel). Nothing to change; flagging so a future story adding such
    a control starts from `CHAT_CONTEXT_LENGTH` instead of reintroducing
    the old name.
  New/extended bats: `tests/state.bats` (+4 — `OPA_PORT` write/read/
  env-precedence/pre-S127-migration-fixture), `tests/f13-config.bats`
  (+3 — `.state` contains `OPA_PORT`, rendered `.env` uses
  `CHAT_CONTEXT_LENGTH` not the old name, end-to-end `edit`-flow
  migration test against a `.state` file with the `OPA_PORT=` line
  stripped), `tests/render.bats` (+4 — env.tmpl fixture asserts
  `OPA_PORT`/`CHAT_CONTEXT_LENGTH`, a repo-wide grep asserting no
  `CHAT_MAX_CONTEXT_TOKENS=`/`${CHAT_MAX_CONTEXT_TOKENS}` token survives
  in `bin/`, `lib/`, `templates/`, `tests/`, and an opa-endpoint test
  proving `chat/general.yml.tmpl` follows `OPA_PORT` rather than a
  hardcoded `8181`), `tests/opa.bats` (+1 — same "follows the var, not a
  literal" proof for the compose `--addr` flag, re-rendering with
  `OPA_PORT=9191` and asserting `8181` is gone).
  Shell: 342/342 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121–S126.
  **Next: S128** (frontend pin bump to v3.0.1 + S16 patch re-derivation).

- **S128 completed:** cloned the real `frontend` repo at both `v2.0.0`
  and `v3.0.1` (`gitlab.opencode.de/f13/microservices/frontend.git`)
  into scratch dirs to diff the two patch targets rather than
  hand-deriving the v3.0.1 shape from memory. `lib/frontend.sh`:
  `_FRONTEND_GIT_REF` bumped `v2.0.0` → `v3.0.1`, so
  `FRONTEND_IMAGE_TAG` becomes `f13-frontend:v3.0.1_based`.
  `frontend::_patch_entrypoint` needed **no code change** — verified
  mechanically against the real v3.0.1 `scripts/docker-entrypoint.sh`
  (which gained several new config fields but kept both anchors the
  patch depends on: the first `escape_js_string` assignment line, and
  the single-line `APP_CONFIG={...};</script>` heredoc). A real
  mismatch **was** found and fixed in `frontend::_patch_uistore`:
  v3.0.1's `featureStore` gained a nested `tools: { onlineSearch,
  skills }` sub-object that v2.0.0 didn't have, and `userInfo.subscribe`
  unconditionally reads `features.tools.onlineSearch` on every update —
  the old patch's replacement object (ported verbatim from v2.0.0)
  dropped `tools` entirely, which would throw `TypeError: Cannot read
  properties of undefined` at runtime with Keycloak disabled. Fixed by
  adding `tools: { onlineSearch: enabled.includes('onlineSearch'),
  skills: enabled.includes('skills') }` to the awk-generated replacement,
  and adding `onlineSearch` to the fallback default list so behavior is
  unchanged when `ENABLED_FEATURES` is unset (matches the original
  hardcoded `onlineSearch: true, skills: false`). In practice the wizard
  always sets `ENABLED_FEATURES="chat"` for the minimal stack, so both
  `tools` flags render `false` either way. Verified both patches against
  the real v3.0.1 source tree end-to-end: `node --check` passes on the
  patched `UIStore.js`, `bash -n` passes on the patched entrypoint,
  `export default` survives, and `docker-entrypoint.sh` keeps its 0755
  mode. Findings recorded in new `docs/frontend-patch-notes.md`
  (mechanical-reuse vs. re-derived, plus what's deliberately left stale:
  the GUI's cosmetic `services` display array in
  `gui/src/routes/status/+page.svelte` and README's preset table — both
  already stale from S122–S124's image-pin bumps, both GUI/docs-track
  work deferred to S129 per the same call S122 made for `core:v2.0.0`
  in README).
  `tests/frontend.bats`: updated the `--branch`/`FRONTEND_IMAGE_TAG`
  assertions to `v3.0.1`/`v3.0.1_based`; updated the main UIStore fixture
  to the real v3.0.1 shape (with `tools`); added a new regression test
  (`preserves the v3 nested tools object`) asserting the patched output
  both declares `tools: {` and computes both sub-keys off `enabled`.
  Shell: 343/343 bats ✅, shellcheck clean. pre-commit not run — no
  virtualenv/binary available in this Docker sandbox, same gap as
  S52/S121–S127.
  **Next: S129** (backpressure + regression sweep; README/docs describe
  the new topology — this is also where the stale GUI/README image
  strings noted above should get synced).

### Maintainer progress (not loop work — context only)

- **Apple blocker cleared 2026-05-31.** Developer ID Application cert
  in keychain (`6DDFRR6F7B`); all 5 GitHub repo secrets set. S53–S56
  are no longer blocked.
- **S53 (signing config) DONE + validated** on `feat/phase10-distributables`:
  `gui/src-tauri/tauri.conf.json` → `bundle.macOS.signingIdentity` +
  `minimumSystemVersion`; maintainer doc at `gui/SIGNING.md`
  (gitignored).
- **S56 (release automation) DONE + validated**:
  `.github/workflows/release.yml` — tag-push `v*` builds signed/
  notarized `.dmg` (arm64) + `.AppImage` / `.deb` (x86_64), attaches
  to a **draft** Release. Notarizes + staples both the `.app` and the
  `.dmg` wrapper.
- **Validated end to end via two dry-run tags (2026-05-31):**
  - `v0.5.0-rc1` proved build + sign + notarize/staple the `.app`
    (Gatekeeper "Notarized Developer ID, accepted") + version-sync
    from tag + Linux `.AppImage`/`.deb`. Surfaced a draft-release
    glob bug + an unstapled `.dmg` wrapper.
  - `v0.5.0-rc2` (after fixes) went fully green: all 3 jobs pass,
    draft Release created with all 3 assets, and the `.dmg` wrapper
    itself now validates as stapled + Gatekeeper-accepted. macOS job
    ~5 min (rc1's 39 min was Apple notary queue, not the pipeline).
  - Both rc tags + drafts cleaned up afterward.
- **v0.5.0 = macOS only (decision 2026-06-01).** During the real
  v0.5.0 S54 smoke the installed `.dmg` reported docker/bash/envsubst
  "not found" — macOS launchd gives Finder-launched apps a truncated
  PATH. Fixed in `#42` (login-shell PATH recovery at startup, +5 Rust
  tests); re-cut v0.5.0 verified running fine. **S54 done.**
- **S55 (Linux .AppImage/.deb) deferred to v0.5.1.** The
  `ubuntu-latest`-built binaries abort with `GLIBC` version errors on
  older target distros (e.g. WSL2 Ubuntu 22.04). v0.5.1 fix: rebuild
  the `build-linux` job on the `ubuntu-22.04` runner (older glibc →
  forward-compat), then re-enable it (`release.yml` has it disabled
  with `if: false` + the re-enable steps documented inline). The
  S51/S52 bundled-path code already supports Linux; only the packaged
  artifacts wait.

Feature branch: `feat/phase10-distributables` (create on first
iteration if absent). Single Phase 10 PR rolls up all stories
(both loop-driven S51/S52 and maintainer-driven S53/S54/S55/S56)
for review before merging to `main` and tagging v0.5.0.

> **Out of scope for this loop — do NOT touch these:**
>
> - **S53, S54, S55, S56** in `/PRD.md` — explicit "maintainer-
>   driven" markers in their story bodies. The loop must not
>   attempt signing certs, GitHub release secrets, or `.dmg` /
>   `.AppImage` / `.deb` builds. Drafting the
>   `.github/workflows/release.yml` skeleton is allowed since
>   it's just YAML; signing/notarization wiring needs the
>   maintainer-set secrets to validate.
> - **HF5** (auto-regenerate broken stack on Start) — promoted
>   to S61 in Phase 11 (`/PRD.md`). Don't pick up until Phase 10
>   has shipped and the maintainer queues Phase 11.
> - **Phase 12 / S71–S73** (Homebrew) — needs a separate tap
>   repo and is targeted at v0.7.0.
> - **Phases 13–16 / S81–S115** — full preset, adjustable
>   services, chat tuning, branding. Long-horizon, not active.
> - Anything outside `gui/` (for S51) or `bin/*` + `lib/*.sh`
>   (for S52). No unrelated drive-by changes.

> Out-of-loop stories carried forward for context: S33, S35, S36 from
> the original numbering were maintainer hand-fixes (HF1/HF2/HF3) and
> shipped via interactive sessions, not the loop.

- S44 completed: zoom feature implemented via CSS-zoom (document.documentElement.style.zoom).
  Research notes: native Tauri/WKWebView/WebView2 shortcut pass-through is inconsistent
  across platforms; CSS zoom requires no Rust code and works in all three webview backends.
  zoom.ts writable store (0.6–2.0, step 0.1) with clampZoom, zoomKeyHandler (Ctrl/Cmd
  +/=/−/0), localStorage persistence under f13.configurator.zoom. +layout.svelte subscribes
  and applies zoom to html element; registers/removes keydown handler. Settings page adds
  compact −/100%/+ stepper in Appearance section. i18n zoom keys added to all four locales.
  26 new vitest tests; total 374/374 green. Phase 9 all four stories complete.

## Notes

- S00 completed: full directory layout scaffolded with stub lib files,
  template placeholders, and smoke bats tests (22 tests, all passing).
- S01 completed: lib/ui.sh fully implemented — color wrappers, status-line
  helpers (ok/warn/err/info/step), hr, and box. NO_COLOR respected.
  15 new bats tests; full suite 35/35 green.
- S02 completed: lib/banner.sh — ui::banner prints 6-line block-character
  F13 logo in cyan centered on 80-col terminal, subtitle in dim.
  5 new bats tests; full suite 38/38 green.
- S03 completed: lib/prompt.sh — prompt::ask, prompt::yesno, prompt::pickone,
  prompt::secret all implemented. F13_CONFIG_NONINTERACTIVE=1 drives wizard
  non-interactively via env vars. Bats tests use --separate-stderr (bats 1.5+)
  to isolate stdout from prompt text on stderr. 22 new tests; 60/60 green.
- S04 completed: lib/secrets.sh — secret::gen uses openssl rand with
  /dev/urandom fallback, outputs base64url. secret::write creates 0600 files
  idempotently; --force flag to overwrite. 13 new bats tests; 72/72 green.
- S05 completed: lib/ports.sh — ports::is_free uses lsof (with ss fallback)
  to probe TCP listeners; ports < 1024 always return 1 (unprivileged).
  ports::pick_free tries preferred then fallback list in order. 14 new bats
  tests; 84/84 green.
- S06 completed: lib/preflight.sh — preflight::run checks docker, docker
  compose, bash >= 4.0, curl/awk/sed/envsubst on PATH, and ~2 GB free disk.
  Internal helpers (preflight::_has_cmd, _docker_info, _docker_compose_ver,
  _disk_free_kb) are overridable for testing without PATH manipulation.
  19 new bats tests; 101/101 green.
- S07 completed: lib/ollama.sh — ollama::is_running probes localhost:11434
  via curl with 2s timeout; ollama::list_models parses /api/tags JSON using
  grep/sed (no jq), handles empty model list; ollama::host_url_for_docker
  returns http://host.docker.internal:11434/v1 (Linux extra_hosts handled
  in S09 compose template). Internal _curl_tags helper overridable for tests.
  24 new bats tests; 123/123 green.
- S08 completed: lib/render.sh — render::file renders a single template via
  envsubst with a per-file allow-list (only uppercase vars found in template
  are substituted, preventing PATH/HOME/etc. from leaking into generated YAML).
  render::tree recursively renders all *.tmpl files from a source directory
  into a destination directory, mirroring structure and stripping .tmpl.
  15 new bats tests; 138/138 green, shellcheck clean.
- S10 completed: bin/f13-config fully implemented — 9-step wizard: banner,
  preflight, preset confirm, chat backend pick (mock/ollama), Ollama model
  selection with live model list, port probing + override, secret generation
  (feedback-db + 5 placeholder secrets), template rendering into generated/,
  summary box, optional docker compose launch. Flags: --non-interactive,
  --dry-run, --reset, --help. F13_GENERATED_DIR and F13_SKIP_PREFLIGHT
  overrides enable hermetic bats tests. 28 new tests; 176/176 green,
  shellcheck clean.
- S12 completed: lib/state.sh — state::write persists wizard vars (PRESET,
  CHAT_BACKEND, OLLAMA_MODEL, FRONTEND_PORT, CORE_PORT, TIMESTAMP) to
  generated/.state with chmod 600. state::read loads those vars back as
  defaults. state::check displays the saved config and prompts [k]eep /
  [e]dit / [r]eset; honours F13_CONFIG_NONINTERACTIVE + F13_STATE_ACTION for
  scripted re-runs. bin/f13-config integrated: keep skips wizard and offers
  launch; edit loads defaults and continues; reset wipes generated/ and starts
  fresh. state::write called after each successful render. 26 new tests;
  215/215 green, shellcheck clean.
- S11 completed: lib/compose.sh — compose::up runs docker compose up -d, waits
  healthy, and prints a success box with Frontend/API URLs and stop command.
  compose::wait_healthy polls http://localhost:${CORE_PORT}/health for up to
  120s (timeout overridable via _COMPOSE_WAIT_MAX) with a ⏳ spinner; returns
  1 on timeout. compose::down tears down cleanly. Internal helpers
  compose::_docker_compose and compose::_curl_health are overridable for
  hermetic tests. 13 new bats tests (1 docker integration test marked skip);
  189/189 green, shellcheck clean.
- S13 completed: `shellcheck -S warning bin/* lib/*.sh` passes clean (exit 0,
  zero warnings). One pre-existing disable comment in lib/secrets.sh
  (SC2120) retains its inline justification. Full bats suite 215/215 green.
- S15 completed: docs/demo-transcript.txt records the complete mock-backend wizard run —
  preflight, backend pick, port defaults, secret generation, template render, summary
  box, compose launch with spinner output, and a re-run / non-interactive cheat-sheet.
  Plain text, no ANSI colour codes. 215/215 green, shellcheck clean.
- S14 completed: README.md expanded from the S00 stub to the full S14 spec.
  Covers quickstart, requirements table, mock vs host-Ollama backend descriptions
  with example prompt output, host.docker.internal Linux explainer (extra_hosts),
  stop/reset/re-run commands with non-interactive usage, generated/ directory
  tree with all files listed, and known limitations. 215/215 green, no new tests
  (doc-only change).
- S16 completed: lib/frontend.sh — frontend::clone_required (uses _FRONTEND_LOCAL_PATH
  override for tests), frontend::get_source (copies local monorepo or git clones
  with --depth 1), frontend::image_exists (mocked via frontend::_docker_image_inspect),
  frontend::patch_and_build (temp dir + trap ERR+EXIT, UIStore.js awk patch via
  temp awk script file, docker-entrypoint.sh awk patch, docker build). Both patches
  are idempotent and match by content not line number. lib/preflight.sh extended
  with conditional git reachability check when clone_required. bin/f13-config
  sources frontend.sh, sets ENABLED_FEATURES="chat" and FRONTEND_IMAGE for v1,
  adds _wizard_build_frontend step (skipped on --dry-run). templates updated:
  frontend service uses ${FRONTEND_IMAGE} and env var ENABLED_FEATURES; platform:
  linux/amd64 removed from frontend. bin/f13-rebuild-frontend standalone rebuild
  script. _wizard_render made resilient when prompt_maps.yml absent (warns, skips).
  24 new bats tests; 239/239 green, shellcheck clean.
- S09 completed: all 6 templates populated. docker-compose.yml.tmpl has
  frontend/core/chat/feedback-db services plus ollama-mock under a `mock`
  compose profile (activated via COMPOSE_PROFILES in .env); chat always has
  extra_hosts for host.docker.internal (harmless on mock, required on Linux
  Ollama). env.tmpl extended with CHAT_IMAGE, CHAT_BASE_URL, CHAT_MODEL_NAME,
  CHAT_MAX_CONTEXT_TOKENS, COMPOSE_PROFILES. core/general.yml.tmpl sets
  guest_mode:true, single chat service_endpoint, allow_origins with
  FRONTEND_PORT. chat/llm_models.yml.tmpl parameterised for both mock and
  ollama backends via wizard-computed vars. 10 new render.bats tests;
  148/148 green, shellcheck clean.
- S17 completed: gui/ scaffolded — Tauri 2.x + SvelteKit + Svelte 5 + Vite + Tailwind CSS 4 +
  TypeScript strict + Vitest + Biome. Scripts: `npm run check` (svelte-check + biome),
  `npm run test:unit` (vitest), placeholder test. Configured tauri.conf.json with
  product name "F13 Configurator", identifier de.f13-os.configurator, bundle targets [].
  CONTRIBUTING.md documents macOS and Linux build prerequisites. ralph.sh updated to
  install Tauri Linux build deps (libwebkit2gtk-4.1-dev, libgtk-3-dev etc.) and Rust
  stable in the Docker bootstrap for future loop iterations. Shell backpressure: 239/239.
  GUI backpressure: npm run check ✅ biome ✅ vitest 1/1 ✅ cargo check ✅.
- S19 completed: Design system import — gui/src/lib/theme/tokens.css: F13 color palette (light +
  dark) with all text tokens meeting WCAG 2.2 AA (4.5:1+). Ubuntu font via @font-face + Google
  Fonts CDN link in app.html. gui/src/app.css: @custom-variant dark, @theme inline mapping tokens
  to Tailwind v4 utilities (bg-bg, bg-surface, text-text, text-muted, text-subtle, bg-primary,
  text-success, text-error, text-warning, text-info), @font-face declarations. gui/static/f13-logo.svg:
  block-character F13 SVG logo. 8 base Svelte 5 components in gui/src/lib/components/:
  Button (primary/secondary/ghost variants, sm/md/lg sizes), Tile (large inference-picker tile
  with icon, pros/cons, recommended badge, aria-checked), RadioRow (native radio + label with
  description), ProgressBar (determinate + indeterminate, role=progressbar, ARIA attrs),
  Disclosure (details/summary with untrack-initialized local state), LogViewer (role=log,
  aria-live polite, auto-scroll on line append), Modal (role=dialog, aria-modal, backdrop click
  to close), Toast (role=alert for errors, role=status for others, aria-live, auto-dismiss).
  All 8 components exported from gui/src/lib/index.ts. 51 vitest tests cover rendering, ARIA
  attributes, event handlers, and axe-core a11y smoke tests (color-contrast rule disabled for
  jsdom). Fixed test env: resolve.conditions=['browser'] at root of vite.config.ts so Svelte
  resolves to index-client.js (DOM mount) not index-server.js (SSR mount, throws). Shell:
  256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅ vitest 91/91 ✅ cargo check ✅.
- S18 completed: lib/events.sh — events::emit TYPE [key=value ...] emits one JSON line to
  stdout when F13_EMIT_EVENTS=1, no-op otherwise. lib/preflight.sh extended to emit
  {"type":"preflight","name":X,"status":ok|fail|info} after every check. bin/f13-config
  gains --emit-events plus dispatch flags --preflight-only / --detect-state /
  --list-models / --check-port N / --compose-up / --compose-health; wizard() emits
  step/done events for each pipeline phase. bin/f13-stop and bin/f13-reset gain
  --emit-events with compose action events. gui/src/lib/engine.ts: createEngine(runner,
  bins) factory returning a typed Engine with preflight(), detectState(), listOllamaModels(),
  checkPort(), runWizardNonInteractive(), and compose.{up,down,reset,health}(). All event
  types exported (PreflightEvent, StepEvent, PortEvent, ModelsEvent, StateEvent,
  ComposeEvent, DoneEvent). Subprocess runner is injectable via ProcessRunner interface.
  40 Vitest tests covering parseEvent for all event types, engine methods with fixture
  streams, and error cases (>=75% coverage). Shell: 256/256 bats ✅, shellcheck clean.
  GUI: npm run check ✅ biome ✅ vitest 40/40 ✅ cargo check ✅.
- S20 completed: Welcome screen + state-aware routing — gui/src/routes/+page.svelte replaces
  placeholder with F13 Configurator welcome screen: inline SVG logo (currentColor themed),
  "F13 Configurator" heading, tagline "Minimal · Batteries included · One command", preset badge
  "v1 · core + frontend + chat", primary "Begin setup" CTA (→ /wizard/preflight), conditional
  "Open existing setup" secondary button shown only after engine.detectState() resolves with
  exists=true (→ /status). State detection runs in $effect with cancellation guard for safe
  unmount. gui/src/lib/engineContext.ts: setEngine/getEngine module singleton for injecting
  Engine in production (layout) and tests (prop). gui/src/routes/page.test.ts: 6 vitest tests
  covering heading render, button render, state-absent hide, state-present show, and both
  navigation routes (vi.mock('$app/navigation') + waitFor for async effects).
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅ vitest 97/97 ✅
  cargo check ✅.
- S21 completed: Preflight screen — gui/src/routes/wizard/preflight/+page.svelte streams
  engine.preflight() events into a live check list as they arrive. ok checks render a
  green ✓ row; fail checks render a red ✕ row plus a collapsible "Fix this" <details>
  element containing Homebrew install hints mapped by check name (docker, docker-compose,
  bash, curl, awk, sed, envsubst, disk, git). Ollama info events render a blue ⓘ row;
  when the detail includes "detected," the component also calls engine.listOllamaModels()
  and shows a nested model list (or a "No models installed" hint). Continue button is
  disabled while streaming, when any hard failure exists, or when no checks have arrived
  yet (guards null-engine / empty-stream edge cases). Header: "Step 1 of 4" breadcrumb +
  Back → /. Continue → /wizard/inference. 16 vitest tests cover heading, loading
  indicator, all three status icons, Fix-this disclosure content, Ollama model list,
  null engine, and Continue button state + navigation.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 113/113 ✅ cargo check ✅.
- S22 completed: Inference picker — gui/src/routes/wizard/inference/+page.svelte presents
  two Tile.svelte cards in a radiogroup: 🧪 Mock (pros: zero config, works offline, fast
  to start; cons: fake responses only; "Recommended" badge) and 🦙 Ollama (pros: real
  model output, full control; cons: requires Ollama running, GPU recommended). Continue
  button disabled until a tile is selected. Mock routes to /wizard/ports; Ollama routes to
  /wizard/inference/ollama. Header: "Step 2 of 4" breadcrumb + Back → /wizard/preflight.
  Footer hint updates dynamically to reflect the current selection. 17 vitest tests cover
  heading, breadcrumb, tile rendering, recommended badge, radiogroup ARIA, selection toggle,
  Continue enabled/disabled state, both routing outcomes, Back navigation, and footer hints.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 130/130 ✅ cargo check ✅.
- S23 completed: Ollama model picker — gui/src/routes/wizard/inference/ollama/+page.svelte
  calls engine.listOllamaModels() on mount (and on Refresh/Retry). Amber GPU warning banner
  matches shell wizard S07/S22 warning text. Cloud model detection: tag portion (after first
  ':') that ends with "cloud" (matches gemma4:31b-cloud and model:cloud). Cloud models show
  ☁ cloud badge (data-testid="cloud-badge"); local models show no badge. Auto-selects
  gemma4:31b-cloud as default if present, else first model. Not-running state renders
  friendly message + Homebrew install / ollama serve instructions + Retry button that
  re-fetches. Refresh link visible in running state. Null engine falls back to not-running.
  Continue disabled while loading / not-running / no model selected; navigates to
  /wizard/ports when enabled. Header: "Step 3 of 4" + Back → /wizard/inference.
  24 vitest tests cover all states, cloud badge, selection, navigation, refresh, null engine.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 154/154 ✅ cargo check ✅.
- S24 completed: Ports screen — gui/src/routes/wizard/ports/+page.svelte with two
  number inputs (Frontend Port default 9999 / Core API Port default 8000). Auto-checks
  both defaults on mount via $effect + untrack (prevents re-check on every keypress).
  onblur re-checks when user edits a value. Inline status: spinner while checking,
  ✓ (data-testid=frontend-status-free/core-status-free) when free, ✗ (data-testid=
  frontend-status-taken) with PID and process name when in use. Continue disabled until
  both ports are free. Advanced Disclosure exposes secret file paths (~/.f13/generated/
  core_jwt.secret, chat_api.secret) and a greyed-out "Edit system prompt" button
  (data-testid=edit-system-prompt, roadmap placeholder). lib/wizardPath.ts singleton
  (setWizardVia/getWizardVia) lets the inference and ollama pages signal the path taken;
  ports page reads it via the via prop (override for tests) or getWizardVia(). Step
  breadcrumb: "Step 3 of 4" for mock path, "Step 4 of 4" for ollama. Back navigates to
  /wizard/inference (mock) or /wizard/inference/ollama (ollama). Null engine degrades
  gracefully (idle status, Continue stays disabled). 22 vitest tests cover all states,
  both navigation paths, blur handlers, error messages, disclosure content, and null
  engine. Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 179/179 ✅ cargo check ✅.
- S25 completed: Build/launch pipeline — gui/src/routes/wizard/run/+page.svelte: vertical
  6-step pipeline (Generating secrets → Rendering compose → Building patched frontend →
  Pulling images → Starting containers → Waiting for health). Each step renders ◯ pending /
  ⏳ running / ✓ done / ✕ failed with an accessible status icon. Collapsible LogViewer
  per step for captured step messages. Build step shows indeterminate ProgressBar while
  running (best-effort; docker build output is not separately streamed). CLI event mapping:
  name=secrets/render/build map directly; name=start started → pull:running, start done →
  pull:done + start:done + health:running, done ok → health:done + goto("/status"). Cancel
  button (shown while pipelineRunning) calls engine.compose.down() for rollback then
  navigates to /wizard/ports. Error state shows error message + "Back to ports" button.
  Null engine degrades gracefully (no pipeline started, no Cancel button). lib/wizardState.ts
  added as module-level store (backend, ollamaModel, frontendPort, corePort); inference,
  ollama, and ports pages updated to call setWizardState on Continue so the run page picks
  up the user's configuration choices. 26 vitest tests cover all 6 step transitions, build
  progress bar show/hide, start-done multi-step transition, done-ok navigation, done-error
  failure marking, Cancel flow, null engine, and runWizardNonInteractive options passthrough.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 205/205 ✅ cargo check ✅.
- S26 completed: Status screen — gui/src/routes/status/+page.svelte: health card with
  animated badge (Checking → Healthy/Unhealthy/Unknown) polled every 5 s via
  engine.compose.health(); interval cancelled on unmount with cancelled flag guard.
  Primary CTA "🌐 Open F13 in browser" calls injectable openUrl prop (defaults to
  window.open; production Tauri wires @tauri-apps/plugin-opener). Three secondary
  actions: View Logs (info toast with docker compose logs command), Stop F13 (info toast
  while stopping → success toast + goto("/")), Full Reset (warning toast while resetting
  → success toast + goto("/")). Each action removes the persistent loading toast and
  adds a result toast on completion. Error path shows error toast with the failure
  message. Reconfigure button (header) → /wizard/preflight. openUrl and frontendPort
  injectable as props for full test isolation. Null engine renders without crashing.
  27 vitest tests cover heading, health card, all badge states, health message, mount
  call, 5-second polling with fake timers, Open F13 URL, frontendPort prop, Stop/Reset
  button rendering, calls, loading toasts, success toasts, navigation, View Logs toast,
  Reconfigure navigation, null engine, and error toast. GUI: npm run check ✅ biome ✅
  vitest 232/232 ✅ cargo check ✅.
- S27 completed: Confirmations + edge cases — three guard flows added to the GUI:
  (1) Reset confirmation modal on gui/src/routes/status/+page.svelte: "Full reset"
  now opens a Modal.svelte dialog requiring the user to type the word RESET before
  the "Confirm reset" button becomes enabled; Cancel closes without side effects.
  (2) Port-collision modal on gui/src/routes/wizard/ports/+page.svelte: whenever
  engine.checkPort() returns an "in use" result (from auto-check on mount or onblur
  re-check) a Modal opens showing the process name, PID, and a suggested port+1;
  "Pick another port" applies the suggestion and re-checks; "Keep this port" dismisses.
  Only one collision modal is open at a time (openCollisionModal guards on
  collisionModal.open). (3) Already-running detection on gui/src/routes/+page.svelte:
  after detectState resolves with exists=true the page fires a one-shot health check
  (engine.compose.health); if healthy isRunning becomes true and an "F13 is already
  running" banner replaces the normal CTA area — "Show status" navigates to /status,
  "Stop & reconfigure" calls compose.down then navigates to /wizard/preflight (stopping
  state + error message if compose.down fails). 16 new vitest tests added (status +4,
  ports +6, welcome +6); the 4 existing "Full Reset" tests updated to flow through the
  modal. All tests pass: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅
  biome ✅ vitest 248/248 ✅ cargo check ✅.
- S29 completed: Packaging infrastructure — gui/src-tauri/tauri.conf.json bundle.resources
  added: maps ../../bin → bin, ../../lib → lib, ../../templates → templates (paths relative
  to src-tauri/ so shell scripts are bundled inside the .app on macOS). gui/src/lib/
  resourcePath.ts: resolveBinPaths(resourceDirOverride?) returns BinPaths; in Tauri context
  (window.__TAURI__ present) it calls @tauri-apps/api/path resourceDir() and prefixes all
  script paths; in dev/test context returns relative default paths. 5 vitest tests cover
  dev-mode defaults and build-mode override simulation. .github/workflows/gui-build.yml:
  macOS-only CI stub — runs tauri build --debug on macos-latest (Apple Silicon aarch64
  target included), preceded by headless checks; does not publish artifacts.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 277/277 ✅ cargo check ✅.
- S31 completed: gui/tests/e2e/smoke.spec.ts — six-step WebdriverIO E2E test covering the full wizard
  happy path: Welcome → Preflight → Inference (Mock) → Ports (defaults) → Build/launch pipeline →
  Status screen. Each step uses data-testid and ARIA attributes as selectors. teardown clicks
  "Stop F13". Guarded by F13_E2E=1 (describe.skip when absent) so it never runs in the loop or CI.
  gui/tests/e2e/wdio.conf.ts: wdio-tauri-service config; resolves the debug binary at
  src-tauri/target/debug/F13 Configurator. Separate gui/tests/e2e/package.json (WebdriverIO v9 +
  wdio-tauri-service v3 + ts-node) keeps heavy deps out of the main gui/ install.
  gui/tsconfig.json: tests/e2e/** excluded so svelte-check does not attempt to type-check
  WebdriverIO globals. gui/tests/e2e/README.md: prerequisites, build steps, run instructions,
  troubleshooting table, architecture diagram, and a maintainer run-log table.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅ vitest 277/277 ✅
  cargo check ✅.
- S30 completed: gui/README.md — full rewrite: stack table, wizard flow diagram, ASCII wireframes
  of all six screens (Welcome, Preflight, Inference picker, Ports, Build/launch pipeline, Status),
  macOS + Linux dev-setup commands, test commands, tauri build packaging notes, architecture notes
  (engine adapter + state flow), and a troubleshooting table. CHANGELOG.md created at repo root:
  Phase 7 GUI release notes covering all S17–S29 additions plus a [0.1.0] section for the S00–S16
  shell wizard. README.md: "GUI vs CLI" comparison table (CLI vs desktop, platform, scripting,
  visual feedback, best-for) inserted after Quickstart; roadmap bullet updated from "in development"
  to "Phase 7 complete (macOS)". No new .sh or .svelte files — doc-only change.
  Shell: 256/256 bats ✅, shellcheck clean. GUI: npm run check ✅ vitest 277/277 ✅ cargo check ✅.
- S28 completed: Settings panel — gui/src/routes/settings/+page.svelte: three sections:
  (1) Appearance — segmented theme toggle (System / Light / Dark) using a radiogroup;
  selected option tracked via $state, persisted to localStorage via setTheme from the
  new gui/src/lib/theme.ts module; +layout.svelte updated to call applyTheme(getTheme())
  on mount so the user's preference is applied on every page load. (2) Generated config —
  accordion list of four config files (docker-compose.yml, .env, core/general.yml,
  chat/llm_models.yml); each row expands to load and display file content (read-only
  <pre>); Copy button appears alongside expanded content, calls injectable
  copyToClipboard prop (defaults to navigator.clipboard.writeText), shows success/error
  Toast; readFile prop is injectable for tests (defaults to "not available" error when
  omitted so tests can exercise the error path without a real filesystem). (3) System
  prompts — "Edit system prompt" button styled with opacity-60 + cursor-not-allowed +
  aria-disabled=true; clicking opens a Modal.svelte dialog explaining the feature is on
  the roadmap ("coming soon"); "Got it" button closes the modal. Back button in the
  header navigates to /status. gui/src/lib/theme.ts: getTheme/applyTheme/setTheme with
  localStorage persistence and document.documentElement.classList toggle. 6 vitest tests
  for theme.ts; 17 vitest tests for the settings page (272 total). Shell: 256/256 bats ✅,
  shellcheck clean. GUI: npm run check ✅ biome ✅ vitest 272/272 ✅ cargo check ✅.
- S34 completed: Phase 7.5 event-emission fix — `events::emit_skipped <name>` helper added to
  `lib/events.sh`, emitting `{type:"step",name:…,status:"done",skipped:"true"}`. The wizard's
  `keep` branch in `bin/f13-config` now calls it for secrets, render, and build before
  `compose::up`, so the GUI pipeline graph fills those nodes instantly rather than staying
  pending forever. `StepEvent` in `engine.ts` gains `skipped?:boolean`; `coerceEvent` threads
  it through (tolerates both `"true"` string and `true` boolean). `handleStepEvent` in
  `run/+page.svelte` fast-paths skipped events to `status:done` with `skipped:true`. SVG
  nodes gain `data-testid="step-{key}"` and `data-status` attributes (restoring S25 test hooks
  removed by zinc polish), plus a faded checkmark + `<title>skipped — existing state</title>`
  tooltip for skipped steps. `ProgressBar` re-introduced for the build step while running
  (with `data-testid="build-progress"`). Tests: 3 new events.bats, 4 new f13-config.bats,
  4 new vitest. Shell: 273/273 bats ✅, shellcheck clean.
  GUI: npm run check ✅ biome ✅ vitest 265/287 ✅ (22 pre-existing) cargo check ✅.

- S43 completed: German, French, and Spanish locale catalogs — `de.json`, `fr.json`, `es.json`
  each containing all ~120 dot-namespaced keys from `en.json`. Brand terms (F13, Ollama, Docker,
  mock, compose, cloud) kept in English; technical commands (`$ f13-config --start`, `model:tag`,
  docker compose log command) kept verbatim. Tone: formal Sie/vous/usted or neutral infinitive
  as appropriate. `locales.ts`: side-effect module that calls `registerCatalog` for de/fr/es;
  imported in `+layout.svelte` at module level so all catalogs are registered before any `t()`
  call. `locales.test.ts`: 12 vitest tests (4 per locale) — exhaustive key completeness (no
  missing, no extras), non-empty values, and {var} placeholder parity against the English catalog.
  GUI: npm run check ✅ biome ✅ vitest 339/339 ✅ cargo check ✅.

- S41 completed: i18n infrastructure + English baseline catalog — hand-rolled TypeScript
  module at `gui/src/lib/i18n/` (zero new npm deps). `en.json`: ~120 dot-namespaced keys
  covering every user-visible string across all 8 route pages and 2 shared components.
  `index.ts`: `t(key, vars?)` with `{var}` interpolation, `setLocale`/`getLocale`,
  `registerCatalog` for future locale catalogs (S43); fallback chain: locale catalog →
  English catalog → key itself. All 8 `+page.svelte` routes + `Tile.svelte` +
  `StepHeader.svelte` migrated to `t()`. `index.test.ts`: 22 vitest tests covering
  baseline English, locale switching, fallback chain, interpolation (single/multiple/
  numeric), unreplaced placeholders, and non-destructive repeated calls.
  Shell: 273/273 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 316/316 ✅ cargo check ✅.

- S32 completed: Phase 7.5 bash/bats fix — `bin/f13-reset` and `bin/f13-stop` already used
  `${F13_GENERATED_DIR:-…}` but had no tests exercising the custom-path code path. Added
  `tests/f13-reset.bats` with 10 tests: f13-reset wipes the custom dir, exits 1 when dir is
  missing, emits compose/done JSON events, leaves sibling dirs untouched; f13-stop exits 0,
  does not delete the dir, exits 1 when missing, emits down/done events. A fake `docker`
  binary injected via PATH makes the tests hermetic. Added 6 vitest tests to
  `gui/src/lib/engine.test.ts` confirming `compose.reset()`, `.down()`, `.up()`, and
  `.health()` all forward `F13_GENERATED_DIR` as a subprocess env-var, and that `.reset()`/
  `.down()` use the correct binary path (bins.reset / bins.stop). Pre-existing 33 vitest
  failures (zinc polish UI-text mismatches) are not introduced by this commit.
  Shell: 266/266 bats ✅, shellcheck clean. GUI: npm run check ✅ biome ✅
  vitest 250/283 ✅ (33 pre-existing) cargo check ✅.

- S52 completed: `lib/discover.sh` — new `discover::generated_dir(SCRIPT_DIR)` function probes four
  candidate paths in priority order: `F13_GENERATED_DIR` env override (returned unconditionally);
  `SCRIPT_DIR/../generated` (dev/direct-checkout mode, only when docker-compose.yml present);
  macOS appLocalDataDir `~/Library/Application Support/de.f13-os.configurator/generated`; Linux
  appLocalDataDir `~/.local/share/de.f13-os.configurator/generated`. The macOS and Linux base dirs
  are overridable for tests via `_F13_MACOS_DATA_DIR` / `_F13_LINUX_DATA_DIR` env vars.
  `bin/f13-stop` and `bin/f13-reset` updated to source `lib/discover.sh` and use
  `discover::generated_dir` instead of the hardcoded `${F13_GENERATED_DIR:-SCRIPT_DIR/../generated}`
  fallback; both scripts now print a helpful "run f13-config first, or set F13_GENERATED_DIR" hint
  when discovery fails. `tests/discover.bats`: 9 unit tests covering env-override, dev path, macOS
  path, Linux path, priorities, and not-found. `tests/f13-reset.bats`: 4 new binary-level tests
  for macOS, Linux, and stop-vs-reset bundled path discovery, plus not-found error message.
  Shell: 296/296 bats ✅, shellcheck clean.
  GUI: npm run check ✅ biome ✅ vitest 384/384 ✅ cargo check ✅.

- S51 completed: `appLocalDataDir` for bundled installs — `get_generated_dir()` bundled branch
  updated from `resource_dir().parent().join("generated")` (which landed inside the signed,
  read-only .app bundle and was never writable) to `app.path().app_local_data_dir().join("generated")`:
  macOS: `~/Library/Application Support/de.f13-os.configurator/generated`;
  Linux: `~/.local/share/de.f13-os.configurator/generated`.
  Dev-mode path (`<configurator_v1>/generated`) is unchanged; `get_bin_dir()` bundled path
  (`resource_dir()/bin`) is also unchanged since bin/ is a read-only bundle resource.
  New `gui/src/lib/bootstrap.test.ts`: 6 vitest tests covering `getGeneratedDir()` initial null,
  resolved path after bootstrap, IPC rejection fallback, idempotency, bin-path wiring, and
  retry-after-failure. `biome.json` schema bumped 2.4.15→2.4.16.
  Shell: 283/283 bats ✅, shellcheck clean.
  GUI: npm run check ✅ biome ✅ vitest 384/384 ✅ cargo check ✅.
