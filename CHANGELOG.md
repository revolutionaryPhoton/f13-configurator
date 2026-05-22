# Changelog

All notable changes to the F13 Configurator are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

## [0.4.1] — 2026-05-22

> **Highlights:** Maintenance release. CI-blocking Tauri JS/Rust version
> mismatch fixed; svelte and SvelteKit bumped (svelte includes a
> transitive XSS fix); explicit Dependabot grouping config added so the
> mismatch can't reopen. No user-facing changes — same wizard, same GUI,
> same flows.

### Fixed

- **`@tauri-apps/api` pin (PR #7, squash `5de58bd`).** Dependabot bumped
  the cargo-side `tauri` crate 2.10.3 → 2.11.1 on 2026-05-08 (PR #2),
  but the JS-side `@tauri-apps/api` stayed at 2.10.1 in the lockfile.
  Tauri's startup version-mismatch guard tripped on every macOS CI run
  for two weeks before anyone noticed. `gui/package.json` is now
  `"@tauri-apps/api": "^2.11.0"` and the lockfile installs 2.11.0+.

### Security

- **`svelte` 5.55.5 → 5.55.9 (Dependabot PR #8, squash `04dacc9`).**
  Patch line. Notable: 5.55.7 fixes an XSS on `hydratable` from user
  content. F13's GUI doesn't render arbitrary user content, so the
  practical exposure is low, but the upstream fix lands here regardless.
  Also includes SSR empty-attribute ban, regex hardening, runtime-property
  symbol move (5.55.7); `svelte:body` print + keyframe percentage
  double-printing fixes (5.55.8); `{#await}` batch + hydration fixes
  and batch-invariant false-positive fix (5.55.9); stale-promise /
  `$state.eager` / `bind:this` proxification fixes (5.55.6). Transitively
  bumps `devalue` 5.7.1 → 5.8.1.

### Changed

- **`@sveltejs/kit` 2.58.0 → 2.60.1 (Dependabot PR #9, squash `bb3e04c`).**
  Minor bump. Adds form `submit`/`hidden` numbers + booleans, warns on
  unread form remote-function validation, fixes `query.batch` cross-talk
  and aborts navigation after async rendering if obsolete. F13 doesn't
  use SvelteKit form actions (Tauri shell via `@sveltejs/adapter-static`),
  so the new features are inert here; the navigation/cross-talk fixes
  touch the static build path.
- **`.github/dependabot.yml` (PR #10, squash `0714ebb`).** Groups
  `@tauri-apps/*` (npm `/gui`) and `tauri` + `tauri-build` +
  `tauri-plugin-*` + `wry` + `tao` (cargo `/gui/src-tauri`) into one
  PR per ecosystem, same weekly cadence, so the JS/Rust pair surfaces
  together. Previously there was no `dependabot.yml`; version updates
  were running off the UI toggle, ungrouped — that's how the v0.4.0
  cycle's mismatch slipped past review.

### Tests

- No new tests. vitest stays 378/378 green; `cargo check` passes;
  macOS CI green from PR #7 onwards. Maintainer smoke-tested the GUI
  on macOS after the SvelteKit minor bump (the riskier of the three
  dep changes) — no regressions on the static-adapter build path.

## [0.4.0] — 2026-05-14

> **Highlights:** GUI localization to German, French, and Spanish (English
> remains the canonical source) and webview-level zoom. Phase 9 of the PRD
> ships here. Shell wizard terminal output stays English by design.

### Added — Localization (S41 + S42 + S43)

- `gui/src/lib/i18n/` module providing a typed `t()` translation function
  with three-tier fallback (current locale → English → raw key) and
  `{var}` interpolation. JSON catalogs at `gui/src/lib/i18n/<locale>.json`,
  167 keys each, dotted namespaces (`welcome.*`, `inference.*`,
  `status.*`, etc.).
- Full catalogs for English (canonical), German, French, and Spanish.
  Brand terms (`F13`, `Ollama`, `Docker`, `docker compose`,
  `ollama serve`, `ollama pull`, `mock`) intentionally left untranslated.
  Key parity across all four catalogs is enforced by a vitest fixture.
- `LocalePicker.svelte` rendered on the welcome screen footer only — a
  four-button row (EN / DE / FR / ES). Selection persists to
  `localStorage` under `f13.configurator.locale` (with a one-shot
  migration from the pre-v0.4.0 `f13_locale` key). The picker is
  deliberately **not** present in Settings or anywhere mid-flow; users
  pick once on first run.
- All hardcoded strings in route pages (`welcome`, `preflight`,
  `inference`, `inference/ollama`, `ports`, `run`, `status`, `settings`)
  replaced with `t()` calls.

### Added — Zoom (S44)

- `gui/src/lib/zoom.ts` writable store with clamp (0.6×–2.0×, 0.1 step)
  and localStorage persistence under `f13.configurator.zoom`.
- Keyboard shortcuts registered at the layout level: `Ctrl/Cmd + +/=`
  zooms in, `Ctrl/Cmd + −` zooms out, `Ctrl/Cmd + 0` resets to 100%.
- Compact `−` / `100%` / `+` stepper in Settings → Appearance.
- Implementation uses the CSS `zoom` property on `document.documentElement`
  (not per-platform Tauri webview APIs). Works identically across
  WKWebView / WebView2 / WebKitGTK with no Rust code; trade-off
  documented in the S44 commit body.

### Tests

- 21 new vitest tests for the i18n module covering `t()` fallbacks,
  `{var}` interpolation, `setLocale`/`getLocale` persistence, and the
  pre-v0.4.0 → v0.4.0 localStorage key migration.
- 4 new vitest tests for catalog key parity (every English key exists
  in de/fr/es; no extras).
- 7 new vitest tests for `LocalePicker` (rendering, ARIA, click → persist
  + reload, click-active → no reload, group-role label).
- 27 new vitest tests for the zoom store and keyboard handler.
- 1 absence test on the Settings page confirming the locale picker is
  **not** rendered there (welcome-only rule).
- vitest total: **378/378 green** (up from 299 in v0.3.2).

## [0.3.2] — 2026-05-14

> **Highlights:** Two backlog hand-fixes — Cancel actually stops the
> wizard, and a missing locally-built frontend image surfaces a clear
> precondition error instead of a confusing `pull access denied`.
> Tauri bumped 2.10.3 → 2.11.1 via Dependabot.

### Fixed — HF2: Cancel button kills the wizard subprocess

- `ProcessRunner.run` gains an optional `signal: AbortSignal` parameter.
  `tauriRunner` stores the spawned Tauri `Child` and listens for the
  abort event; on abort it calls `child.kill()`.
- `engine.runWizardNonInteractive` forwards the signal to `runner.run`.
- `/wizard/run/+page.svelte` creates an `AbortController` per pipeline
  run; `handleCancel()` calls `controller.abort()` before tearing down
  state, so the kill fires before the cancel-button-navigates-away
  path begins.
- Killing the bash leader does NOT kill its `docker compose up`
  grandchild (reparented to PID 1). `handleCancel` therefore tears
  down twice with a 1.5 s gap so the second pass catches containers
  the orphaned `compose up` might have brought up during the first.
  The proper kernel-level fix (kill the process group, not just the
  leader) needs a Rust-side change to tauri-plugin-shell and is
  deferred.

### Fixed — HF3: clear "frontend image missing" error instead of pull-access-denied

- `templates/docker-compose.yml.tmpl`: pinned `pull_policy: never` on
  the frontend service. The image is built locally by this configurator
  and never pushed to any registry, so a registry pull is always wrong
  for it.
- `lib/compose.sh`: precondition check in `compose::up` runs
  `docker image inspect ${FRONTEND_IMAGE}` (via a testable
  `compose::_docker_image_inspect` helper) before invoking
  `docker compose up`. On miss, returns 1 with a clear "frontend image
  is missing locally — re-run the wizard so it can rebuild" message.
  `FRONTEND_IMAGE` is read straight from the rendered `.env` so the
  check works for any wizard-driven invocation.
- `bin/f13-config` `--compose-up` handler propagates the specific
  failure reason into the `done` event message via
  `COMPOSE_ERROR_MESSAGE`, so the GUI's error toast surfaces the
  friendly text instead of a generic "compose up failed".

### Changed — Dependencies

- `tauri` 2.10.3 → 2.11.1 (Dependabot #2). Cargo.lock only; no API
  changes required in our Rust glue. Backpressure (`cargo check`,
  full GUI test suite) green against the new version.

### Tests

- 4 new bats assertions covering the HF3 precondition (errors when
  image missing, proceeds when present, skips precondition when
  `FRONTEND_IMAGE` not in `.env`, sets `COMPOSE_ERROR_MESSAGE`).
- 1 new bats assertion: rendered `docker-compose.yml` pins
  `pull_policy: never`.
- 3 new vitest assertions covering HF2 (AbortSignal plumbed through
  to the runner, Cancel aborts the signal handed to the engine,
  Cancel tears down twice for the orphan-up race).
- Existing `calls runWizardNonInteractive with the provided backend`
  updated for the new two-arg signature.

## [0.3.1] — 2026-05-14

> **Highlights:** HF4 fix — the GUI's Reconfigure flow now actually
> swaps the chat backend (mock ↔ Ollama) on a running stack instead of
> silently no-op'ing. Three compounding bugs found and fixed: env vars
> clobbered by `state::read`, `F13_STATE_ACTION` shadowed before
> `state::check` could read it, and containers left bound to the ports
> the wizard was about to re-render onto.

### Fixed — HF4: GUI reconfigure flow re-renders on backend swap

- `lib/state.sh`: `state::read` lets env-set values win over on-disk
  state for all five wizard vars (PRESET, CHAT_BACKEND, OLLAMA_MODEL,
  FRONTEND_PORT, CORE_PORT). Previously the GUI's exported
  `CHAT_BACKEND=ollama` was silently reverted to whatever the previous
  run had saved. Also normalized `OLLAMA_MODEL` — was missing the
  empty-state guard the other four had.
- `bin/f13-config`: stopped unconditionally clearing `F13_STATE_ACTION`
  before `state::check` reads it, so the GUI's exported
  `F13_STATE_ACTION=edit` survives. Without this the idempotency check
  defaulted to `keep` in non-interactive mode regardless of what the
  GUI passed.
- `bin/f13-config`: new `_wizard_stop_running_stack` helper called
  from both `edit` and `reset` branches before preflight / `rm -rf`,
  so the previous run's containers don't block the new compose from
  claiming the chosen ports. Emits `step name=stop` events; skipped on
  `--dry-run`.
- `gui/src/routes/wizard/run/+page.svelte`: calls
  `engine.detectState(generatedDir)` before `runWizardNonInteractive`
  and passes `stateAction: "edit"` when state exists, so the wizard
  takes the edit branch instead of the default keep branch.
- `gui/src/routes/status/+page.svelte`: Reconfigure button now calls
  `engine.compose.down(generatedDir)` before navigating to
  `/wizard/preflight` (skipped if the stack is already
  unhealthy/stopped). Without this early stop, the wizard's port check
  at `/wizard/ports` reported both ports as in-use by the previous
  run's containers and the user got stuck. Shows a "Stopping current
  stack…" toast + "Stopping…" button label during the call.

### Tests

- 4 new bats regressions in `tests/state.bats` covering env-wins for
  `CHAT_BACKEND`, `OLLAMA_MODEL`, `FRONTEND_PORT`, plus an empty-env
  case to lock in the interactive-edit defaults.
- 4 new bats assertions in `tests/f13-config.bats` covering stop event
  emission on edit / reset and its absence on keep / fresh init.
- Pre-existing `re-run with edit action re-renders config` tightened —
  old form only checked `docker-compose.yml` existed (true after the
  first run too); now asserts the unique `Editing configuration.`
  banner so the edit branch was provably entered.
- 4 new vitest assertions covering `stateAction:"edit"` plumbing in
  the run page and `compose.down` invocation on the Reconfigure
  button.

### Drive-by

- Fixed two trailing-comma format errors in
  `gui/src/routes/wizard/run/page.test.ts` that were left by `d452fc3`
  and were blocking `npm run check`.

## [0.3.0] — 2026-04-26

> **Highlights:** Linux runtime parity for the GUI (WSL2 Ubuntu 22.04
> validated end-to-end), all upstream images pinned to documented F13
> versions, locally built frontend image renamed to reflect its
> upstream basis, and a handful of UX bug fixes that surfaced during
> Linux testing. Phase 8 of the PRD ships here. Ralph loop was not
> used for any of this — interactive maintainer + Claude Code
> sessions on the actual Linux box.
>
> Note: the "Added — Desktop GUI" block below (Phase 7) actually
> shipped in v0.2.0; it was never given its own CHANGELOG entry at
> the time. It's grouped into this entry for completeness rather
> than backfilling three retroactive sections.

### Changed — Pinned upstream component versions

- `core` image: `core/main:latest` → `core:v2.0.0`.
- `chat` image (both mock and Ollama backends): `chat:v1.1.0` /
  `chat/main:latest` → `chat:v1.2.0`.
- `feedback-db` image: `postgres:16-alpine` → `postgres:17-alpine`.
- Frontend git clone (when the local monorepo is absent): pinned to
  `--branch v2.0.0` instead of the upstream default branch
  (`_FRONTEND_GIT_REF` constant in `lib/frontend.sh`).
- Locally built patched frontend image renamed:
  `f13-frontend:configurator-v1` → `f13-frontend:v2.0.0_based`. The
  tag is derived from `_FRONTEND_GIT_REF`, so future ref bumps
  cascade through `frontend::patch_and_build`, the GUI status
  screen, and the README image table without further edits. Old
  image lingers as a dangling tag after upgrade — clear with
  `docker image rm f13-frontend:configurator-v1` once you don't
  need it anymore.
- `frontend::get_source` always clones the pinned upstream tag
  now. The previous fast-path that copied a local
  `../frontend/` checkout was removed: an arbitrary local tree
  could diverge from the pinned ref, breaking the
  `vX.Y.Z_based` image-tag contract. `git` is therefore an
  unconditional preflight requirement. `frontend::clone_required`
  and `frontend::_local_path` were removed since the predicate
  is now always true.

> ⚠️ **Postgres major bump (16 → 17) is a breaking change for existing
> stacks.** The `feedback-db-data` named volume initialized by the old
> postgres:16 image will not auto-upgrade. Existing installs need to
> `./bin/f13-reset` (which drops the volume) before pulling this
> version, or perform a manual `pg_upgrade` outside the configurator.

### Added — Desktop GUI (Phase 7, `gui/`)

A cross-platform desktop application built with Tauri 2 + Svelte 5 + Vite +
Tailwind CSS 4 + TypeScript strict. Ships alongside the existing shell wizard;
both surfaces share the same engine (`bin/f13-config --emit-events`).

**Wizard screens**

- Welcome screen with state-aware routing: detects an existing `.state`,
  shows "Open existing setup" when found, and presents a running-stack banner
  with "Show status / Stop & reconfigure" actions when the stack is healthy.
- Preflight screen (Step 1): live streaming check list — Docker, docker compose,
  Bash ≥ 4, curl/awk/sed/envsubst, disk space, Ollama info row with nested
  model list; collapsible fix hints per failing check.
- Inference picker (Step 2): Mock (recommended, offline) vs. Ollama cards with
  pros/cons and aria-checked tile interaction.
- Ollama model picker (Step 3, Ollama path): live model list from `ollama serve`;
  cloud-hosted models (`:cloud` tag suffix) shown with ☁ badge; auto-selects
  `gemma4:31b-cloud` as default when present; Retry / Refresh controls.
- Ports screen (Step 3/4): auto-checks both ports on mount; re-checks on blur;
  collision modal with PID, process name, and port+1 suggestion; advanced
  disclosure showing secret file paths.
- Build / launch pipeline: six-step vertical pipeline with per-step log viewers
  and a Cancel button that calls `compose down` for rollback.
- Status screen: health card polling every 5 s; "Open F13 in browser" CTA;
  Stop, Full Reset (requires typing RESET in a confirmation modal), and
  View Logs actions; Reconfigure shortcut.
- Settings panel: System/Light/Dark theme toggle persisted to localStorage;
  read-only config file viewer with Copy; coming-soon system-prompt modal.

**Infrastructure**

- Engine adapter (`src/lib/engine.ts`): `createEngine(runner, bins)` with
  injectable `ProcessRunner` for full test isolation; typed event types for
  all `--emit-events` output.
- Design system (`src/lib/theme/tokens.css`, `src/app.css`): F13 colour palette
  (light + dark) with WCAG 2.2 AA contrast; Ubuntu font; Tailwind v4 custom
  utilities.
- Eight base components: `Button`, `Tile`, `RadioRow`, `ProgressBar`,
  `Disclosure`, `LogViewer`, `Modal`, `Toast` — all with ARIA attributes and
  axe-core smoke tests.
- `wizardState.ts` / `wizardPath.ts` / `resourcePath.ts` / `engineContext.ts` /
  `theme.ts` module singletons for state propagation, routing signals, bundle
  path resolution, engine injection, and theme persistence.
- Packaging infrastructure: `bundle.resources` in `tauri.conf.json` bundles
  `bin/`, `lib/`, `templates/` inside the macOS `.app`; `resourcePath.ts`
  resolves paths at runtime via `@tauri-apps/api/path`.
- CI stub: `.github/workflows/gui-build.yml` runs `tauri build --debug` on
  `macos-latest` (aarch64 target) preceded by headless checks.
- 277 Vitest tests (≥ 75% coverage on all new/modified files).

---

## [0.1.0] — Shell wizard (Phase 0–6)

### Added

- **S00** Project bootstrap: directory layout, stub lib files, bats harness.
- **S01** `lib/ui.sh`: colour wrappers, status-line helpers, `hr`, `box`;
  `NO_COLOR` respected.
- **S02** `lib/banner.sh`: F13 ASCII logo in cyan.
- **S03** `lib/prompt.sh`: `prompt::ask`, `yesno`, `pickone`, `secret`;
  `F13_CONFIG_NONINTERACTIVE` for scripted runs.
- **S04** `lib/secrets.sh`: `secret::gen` (openssl / /dev/urandom), `secret::write`
  (0600, idempotent, `--force`).
- **S05** `lib/ports.sh`: `ports::is_free` (lsof / ss), `ports::pick_free`.
- **S06** `lib/preflight.sh`: checks Docker, docker compose, Bash ≥ 4,
  curl/awk/sed/envsubst, ~2 GB free disk.
- **S07** `lib/ollama.sh`: `ollama::is_running`, `ollama::list_models`,
  `ollama::host_url_for_docker`.
- **S08** `lib/render.sh`: `render::file` with per-file allow-list,
  `render::tree` recursive render.
- **S09** Compose + config templates: `docker-compose.yml.tmpl`,
  `env.tmpl`, `core/general.yml.tmpl`, `chat/llm_models.yml.tmpl`,
  `ollama-mock` compose profile.
- **S10** `bin/f13-config`: 9-step wizard, `--non-interactive`, `--dry-run`,
  `--reset`, `--help`.
- **S11** `lib/compose.sh`: `compose::up`, `compose::wait_healthy` (120 s
  spinner), `compose::down`.
- **S12** `lib/state.sh`: wizard state persistence; keep/edit/reset flow.
- **S13** `shellcheck -S warning` clean across all shell scripts.
- **S14** `README.md`: full quickstart, requirements, inferences, ports,
  generated tree, roadmap.
- **S15** `docs/demo-transcript.txt`: complete mock-backend wizard run.
- **S16** `lib/frontend.sh`: frontend clone, UIStore patch, entrypoint patch,
  `docker build`; `bin/f13-rebuild-frontend`; `ENABLED_FEATURES=chat` gating.
  256 bats tests, shellcheck clean.
