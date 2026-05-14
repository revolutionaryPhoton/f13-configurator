# F13 Configurator — Desktop GUI

A cross-platform desktop application that wraps the F13 shell wizard in a
click-through interface. Built with **Tauri 2 + Svelte 5 + Vite + Tailwind CSS 4**;
shells out to `bin/f13-config` via a structured JSON-event protocol — no logic
duplication between the GUI and the CLI.

> **Status (v0.3.1):** mostly stable for daily local use on macOS and on
> Linux (WSL2 Ubuntu 22.04 validated end-to-end in v0.3.0). The reconfigure
> flow on a running stack (HF4) landed in v0.3.1. Phase 9 (signed
> distributables — `.dmg`, `.AppImage`, `.deb` — and bundled-mode data
> paths) is the next planned phase but unstarted.

---

## Stack

| Layer | Technology |
|---|---|
| App shell | Tauri 2.x (`src-tauri/`) |
| UI framework | Svelte 5 (runes, no stores) |
| Router | SvelteKit (static-adapter, client-side only) |
| Styling | Tailwind CSS 4 (utility-first + F13 design tokens) |
| Language | TypeScript strict |
| Linter / formatter | Biome |
| Tests | Vitest + Testing Library + axe-core |
| Build tool | Vite 6 |

---

## Wizard flow

```
Welcome
  └─ Preflight checks          (Step 1 of 4)
       └─ Inference picker     (Step 2 of 4)
            ├─ Mock  ──────────────────────────────┐
            └─ Ollama → Model picker (Step 3 of 4) │
                                └─ Ports           │
                    ┌──────────────────────────────┘
                    └─ Ports screen  (Step 3/4 of 4)
                         └─ Build / launch pipeline
                              └─ Status screen
                                   └─ Settings
```

### Screen-by-screen

**Welcome** — detects whether a previous configuration exists; shows
"Open existing setup" when it does; offers a running-stack banner with
"Show status / Stop & reconfigure" options when the stack is already healthy.

**Preflight (Step 1)** — streams `bin/f13-config --preflight-only --emit-events`
into a live check list: Docker, docker compose, Bash ≥ 4, curl/awk/sed/envsubst,
disk space, optional Ollama. Continue is disabled until all hard checks pass.

**Inference picker (Step 2)** — two cards: 🧪 Mock (recommended — zero config,
offline) and 🦙 Ollama (real model output, GPU recommended). Mock routes to
Ports; Ollama routes to the model picker.

**Ollama model picker (Step 3, Ollama path)** — fetches the live model list from
`ollama serve`. Cloud-hosted models (tag ends in `:cloud`) show a ☁ badge.
Auto-selects `gemma4:31b-cloud` as default when present.

**Ports (Step 3/4)** — two numeric inputs (Frontend default 9999, Core API
default 8000). Auto-checks on mount; re-checks on blur. A collision modal
appears when a port is in use, showing the blocking process and offering a
port+1 suggestion.

**Build / launch pipeline** — six-step vertical pipeline:
Generating secrets → Rendering compose → Building patched frontend →
Pulling images → Starting containers → Waiting for health.
Each step shows ◯ pending / ⏳ running / ✓ done / ✕ failed.
A Cancel button calls `compose down` for rollback.

**Status** — health card polling `compose health` every 5 s. Primary CTA opens
the F13 frontend in the default browser. Secondary actions: View Logs, Stop F13,
Full Reset (requires typing RESET to confirm).

**Settings** — theme toggle (System / Light / Dark), read-only config file
viewer with Copy, coming-soon system-prompt editor.

---

## ASCII wireframes

```
┌─────────────────────────────────────────┐
│  ██████╗ ██╗██████╗                     │
│  ██╔══██╗██║╚════██╗                    │
│  ██████╔╝██║ █████╔╝                    │
│  ██╔══██╗██║ ╚═══██╗                    │
│  ██║  ██║██║██████╔╝                    │
│  ╚═╝  ╚═╝╚═╝╚═════╝                    │
│                                         │
│  F13 Configurator                       │
│  Minimal · Batteries included · One cmd │
│  ┌─────────────────────┐                │
│  │ v1 · core+frontend  │                │
│  └─────────────────────┘                │
│                                         │
│  [ Begin setup ]   [ Open existing ] *  │
│                    * shown when .state  │
│                      already exists     │
└─────────────────────────────────────────┘
                Welcome

┌─────────────────────────────────────────┐
│  ← Back          Step 1 of 4            │
│  Preflight checks                       │
│  ─────────────────────────────          │
│  ✓  Docker 24.0.5                       │
│  ✓  docker compose 2.24.0               │
│  ✓  Bash 5.2.26                         │
│  ✓  curl, awk, sed, envsubst            │
│  ✓  Disk space 48.2 GB free             │
│  ⓘ  Ollama detected — gemma4:31b-cloud  │
│     └─ gemma4:31b-cloud  ☁              │
│        llama3.2:latest                  │
│                                         │
│                        [ Continue → ]   │
└─────────────────────────────────────────┘
             Preflight screen

┌─────────────────────────────────────────┐
│  ← Back          Step 2 of 4            │
│  Choose inference                       │
│  ─────────────────────────────          │
│  ┌──────────────────┐ ┌──────────────┐  │
│  │ 🧪 Mock          │ │ 🦙 Ollama    │  │
│  │ ★ Recommended    │ │              │  │
│  │ ✓ Zero config    │ │ ✓ Real model │  │
│  │ ✓ Works offline  │ │ ✓ Full ctrl  │  │
│  │ ✗ Fake responses │ │ ✗ Needs GPU  │  │
│  └──────────────────┘ └──────────────┘  │
│                                         │
│  Hint: Mock is great for testing the UI │
│                        [ Continue → ]   │
└─────────────────────────────────────────┘
           Inference picker

┌─────────────────────────────────────────┐
│  ← Back          Step 3/4 of 4          │
│  Ports                                  │
│  ─────────────────────────────          │
│  Frontend port   [ 9999 ]   ✓ free      │
│  Core API port   [ 8000 ]   ✓ free      │
│                                         │
│  ▼ Advanced                             │
│    Secret files stored in               │
│    ~/.f13/generated/                    │
│    · core_jwt.secret                    │
│    · chat_api.secret                    │
│    [ Edit system prompt ] (roadmap)     │
│                                         │
│                        [ Continue → ]   │
└─────────────────────────────────────────┘
              Ports screen

┌─────────────────────────────────────────┐
│  Build & launch                         │
│  ─────────────────────────────          │
│  ✓  Generating secrets                  │
│  ✓  Rendering compose                   │
│  ⏳ Building patched frontend           │
│     ████████████░░░░░░░░░░░░  building  │
│  ◯  Pulling images                      │
│  ◯  Starting containers                 │
│  ◯  Waiting for health                  │
│                                         │
│                        [ Cancel ]       │
└─────────────────────────────────────────┘
          Build / launch pipeline

┌─────────────────────────────────────────┐
│  F13 Configurator           ⚙ Settings  │
│  ─────────────────────────────          │
│  ● Healthy                              │
│  Stack is up and responding             │
│                                         │
│  [ 🌐 Open F13 in browser ]             │
│                                         │
│  [ View Logs ]  [ Stop F13 ]            │
│  [ Full Reset ]                         │
│                                         │
│  [ Reconfigure ]                        │
└─────────────────────────────────────────┘
              Status screen
```

> Real screenshots will be added once the macOS DMG is produced in Phase 9
> (signed distributables — currently planned but unstarted).

---

## Dev setup

### macOS (validated target)

```bash
# Prerequisites
xcode-select --install
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Node deps
cd gui
npm install

# Headless checks (fast — no display needed)
npm run check && npm run test:unit && cargo check

# Run the app (requires a display — NOT inside the Ralph loop)
npm run tauri dev
```

No extra Homebrew packages required. Tauri uses the system WebKit on macOS.

### Linux (WSL2 Ubuntu 22.04 validated, also fine for compile-check)

Linux GUI runtime parity shipped in v0.3.0 — first-time setup, Stop/Start,
Reset, and reconfigure all work end-to-end on WSL2 + Docker Desktop. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for the WSL2-specific apt packages
(`fonts-noto-color-emoji`, `wslu`) beyond the build-toolchain deps below.
Build prereqs:

```bash
# Apt packages (one-time)
sudo apt-get install -y \
  libwebkit2gtk-4.1-dev libglib2.0-dev libgtk-3-dev \
  libssl-dev build-essential librsvg2-dev patchelf \
  libsoup-3.0-dev libjavascriptcoregtk-4.1-dev

# Headless checks
cd gui && npm run check && npm run test:unit && cargo check
```

---

## Running tests

```bash
# All tests once (no display needed)
npm run test:unit

# Watch mode (interactive development)
npm run test:unit:watch

# Type-check + lint
npm run check
```

Coverage target: ≥ 75% on new/modified TS and Svelte files.

---

## Building a release package (macOS only)

```bash
# Debug build (faster, no codesigning)
npm run tauri build -- --debug

# Release build (requires Apple Developer certificate for distribution)
npm run tauri build
```

The `.app` bundle is written to `src-tauri/target/[debug|release]/bundle/macos/`.
The shell scripts (`bin/`, `lib/`, `templates/`) are bundled inside the `.app`
via `bundle.resources` in `tauri.conf.json`.

A stub GitHub Actions workflow (`.github/workflows/gui-build.yml`) runs the debug
build on `macos-latest` to catch regressions in CI. It does not publish artifacts.

---

## Architecture notes

### Engine adapter (`src/lib/engine.ts`)

`createEngine(runner, bins)` returns a typed `Engine` that drives all GUI actions
by spawning subprocesses. The `ProcessRunner` interface is injectable, making
every engine method testable without a real shell.

```
GUI routes → Engine methods → ProcessRunner → bin/f13-config --emit-events
                                              bin/f13-stop --emit-events
                                              bin/f13-reset --emit-events
```

Event protocol: one JSON line per event on stdout.

```json
{"type":"preflight","name":"docker","status":"ok","detail":"24.0.5"}
{"type":"step","name":"secrets","status":"done"}
{"type":"done","ok":true}
```

### State flow

```
wizardState.ts (module singleton)
  ├─ backend       "mock" | "ollama"
  ├─ ollamaModel   string | null
  ├─ frontendPort  number
  └─ corePort      number

wizardPath.ts — "mock" | "ollama" routing signal
resourcePath.ts — resolves bin paths inside .app bundle vs. dev mode
theme.ts — persists theme preference to localStorage
engineContext.ts — injects Engine for production; overridable in tests
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `npm run check` fails with "Cannot find module '$app/navigation'" | SvelteKit sync not run | Run `npm run check` (it calls `svelte-kit sync` first) or `npx svelte-kit sync` |
| `cargo check` fails with linker errors on Linux | Missing system libs | Install the apt packages listed in Linux Setup above |
| `npm run tauri dev` hangs immediately | No display (headless env) | Only run `tauri dev` on a machine with a display. Use `npm run check && npm run test:unit && cargo check` in CI |
| Preflight screen shows no checks | Engine not provided | Ensure `setEngine()` is called in `+layout.ts` before navigation |
| Health polling does not stop after unmount | Effect cleanup not firing | Verify `$effect` returns a cleanup function that sets the `cancelled` flag |
| Tailwind classes have no effect | Tailwind config not imported | Confirm `import 'tailwindcss'` (or your app.css) is in `+layout.svelte` |
| `window.__TAURI__` undefined in packaged app | CSP too strict | Check `tauri.conf.json` → `app.security.csp`; `ipc:` scheme must be allowed |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide including the F13
commit convention and backpressure commands.
