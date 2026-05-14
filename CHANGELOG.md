# Changelog

All notable changes to the F13 Configurator are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

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
