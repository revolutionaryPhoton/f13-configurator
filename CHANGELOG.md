# Changelog

All notable changes to the F13 Configurator are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

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
