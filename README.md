# F13 Configurator

A setup wizard that brings up a minimal F13 deployment — `core + frontend + chat` — with a single command. The shell wizard (`bin/f13-config`) is the fully stable surface; the desktop GUI (`gui/`, Tauri 2 + Svelte 5) is **mostly stable on macOS and Linux for daily local use** — every documented flow works, but we haven't exercised every combination of state transitions, error paths, and inputs, so a few loose ends and edge cases remain. Both surfaces share one engine. No YAML hand-editing, no manual secret generation, no ops experience required.

> ⚠️  **AI-generated code.** Almost all of this codebase was written by Claude Code running inside an automated [ralph loop](https://github.com/revolutionaryPhoton/f13-configurator-ralph) driven by a PRD. Human review has been spot-check level, not line-by-line. Read the diffs before using it for anything beyond local development, and treat the test suite as a smoke check rather than a guarantee. Issues and PRs are very welcome — see [SECURITY.md](SECURITY.md) for the implications.

## What is F13?

F13 is an open-source AI assistant platform for German public administration, built as a set of microservices (chat, RAG, summary, transcription, …) behind a Svelte frontend.

- **Project site & documentation:** [www.f13-os.de](https://www.f13-os.de)
- **Microservice source:** [gitlab.opencode.de/f13/microservices](https://gitlab.opencode.de/f13/microservices)

This configurator is an independent, third-party tool that wraps F13's shipped Docker images and configs into a friendly setup wizard. It does not modify the upstream services.

---

## Quickstart

```bash
cd configurator_v1
./bin/f13-config
```

The wizard walks you through every choice (chat inference, ports), generates all secrets, renders the compose stack, and optionally starts it. Total time from zero to running: under two minutes.

---

## GUI vs CLI

Two surfaces, one engine. The shell wizard is fully stable. The desktop GUI is mostly stable on macOS and Linux for daily local use.

> ℹ️  The desktop GUI on macOS and Linux handles every documented flow — first-time setup, Stop/Start cycles, full reset, mock or host-Ollama (including cloud-tagged models), and live reconfigure of a running stack. Linux runtime parity was validated on WSL2 Ubuntu 22.04 in v0.3.0; the reconfigure flow (HF4) landed in v0.3.1. We have **not** exercised every combination of state transitions, error paths, and inputs yet, so edge-case bugs may still surface. For production-adjacent work, the shell wizard remains the recommended surface.

| | Shell wizard (`bin/f13-config`) | Desktop GUI (`gui/`) |
|---|---|---|
| **Status** | ✅ stable (v0.1.0) | 🟢 mostly stable on macOS + Linux (v0.3.0) |
| **Launch** | `./bin/f13-config` in any terminal | `npm run tauri dev` (dev) or open the `.app` (packaged) |
| **Platform** | macOS, Linux, WSL2 | macOS, Linux, WSL2 (mostly stable) |
| **Requirements** | Bash 4+, Docker | Node 20+, Rust stable, Docker |
| **Non-interactive / CI** | `F13_CONFIG_NONINTERACTIVE=1 …` env vars | Not applicable |
| **Scripting / automation** | Full — pipes, env overrides, `--emit-events` | Not applicable |
| **Visual feedback** | ANSI colour in terminal | Native window, animated pipeline, health polling |
| **Re-run / idempotency** | `./bin/f13-config` prompts keep / edit / reset | Welcome screen detects existing state automatically |
| **Best for** | Ops, CI, headless servers, users comfortable with the terminal | Desktop users who prefer a click-through wizard |

Both surfaces produce identical `generated/` output and share the same shell-script engine.

---

## Requirements

| Requirement | Notes |
|---|---|
| Docker Engine 20.10+ | Must include `docker compose` (v2 plugin) |
| Bash 4+ | macOS ships 3.2 — run `brew install bash` and use `/usr/local/bin/bash` |
| `curl` | Used for Ollama probing and health checks |
| `awk`, `sed`, `envsubst` | Usually pre-installed; `envsubst` is in `gettext` |
| `git` | Required — the wizard clones the pinned frontend tag from GitLab on every install |
| ~3 GB free disk | F13 images plus the local frontend build |
| Ports 8000 and 9999 | Defaults; the wizard lets you pick alternatives if busy |

---

## Chat inference

The wizard asks how chat inference should run:

```
Where should chat inference run?
  1) 🧪 Mock inference (no GPU, deterministic responses)
  2) 🦙 Host Ollama (connects to ollama serve on this machine)
```

### Option 1 — Mock inference

Spins up the shipped `ollama-mock` container alongside the stack. No GPU needed. Responses are deterministic and useful for testing the UI or integration.

```
  1) 🧪 Mock inference (no GPU, deterministic responses)
> 1

✅  Chat inference: mock
```

### Option 2 — Host Ollama

Connects the chat container to your local `ollama serve` instance. The wizard calls `ollama::is_running` to check whether Ollama is listening on `localhost:11434`; if it is not, it prints instructions and waits.

Once Ollama is reachable it fetches the live model list and asks you to pick one:

```
  2) 🦙 Host Ollama (connects to ollama serve on this machine)
> 2

ℹ️   Fetching models from Ollama…
  1) gemma4:31b-cloud
  2) llama3.2:latest
Pick a model [1]: 1

✅  Chat inference: ollama  model: gemma4:31b-cloud
```

> ⚠️ **Pick a model that fits your hardware.** Local Ollama models load
> into VRAM/RAM at the size of their weights — running a 31B model on
> a laptop without a capable GPU is technically possible but you'll wait
> many seconds per generated token.
>
> ⚠️ **Cloud-hosted Ollama models** (tags ending in `:cloud`, e.g.
> `gemma4:31b-cloud`) run on Ollama's infrastructure and require a
> signed-in Ollama account on the host machine. If you haven't already,
> run `ollama signin` before starting the configurator.

#### How Docker reaches the host (Linux)

On macOS, `host.docker.internal` resolves automatically. On Linux it does not exist by default. The generated `docker-compose.yml` injects:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

This is always present in the chat service definition (harmless when using mock inference, required for host-Ollama on Linux). Requires Docker Engine 20.10+.

---

## Ports

The wizard probes whether the preferred ports are free and falls back or asks:

```
Frontend port [9999]:
Core API port  [8000]:
```

Both values end up in `generated/.env` and are substituted into `docker-compose.yml` at render time. You can change them on any re-run.

---

## Preset

The only preset in v1 is **`core + frontend + chat`**:

| Service | Image | Notes |
|---|---|---|
| `frontend` | `f13-frontend:v2.0.0_based` (built locally) | Patched to honour `ENABLED_FEATURES`; only the Chat tab is visible |
| `core` | `registry.opencode.de/f13/microservices/core:v2.0.0` | Guest mode enabled (`authentication.guest_mode: true`) |
| `chat` | `registry.opencode.de/f13/microservices/chat:v1.2.0` | Configured for mock or host-Ollama |
| `feedback-db` | `postgres:17-alpine` | Password from generated secret; user `member` |
| `ollama-mock` | `base-images/ollama-mock-f13:1.2.0` | Only when mock inference is selected (compose profile) |

The F13 service images (`core`, `chat`, `ollama-mock`) are `linux/amd64`. On Apple Silicon the generated compose sets `platform: linux/amd64` so Docker Desktop runs them via Rosetta 2 emulation — no rebuild needed, first boot is slightly slower. The `frontend` image is built locally and is therefore native (`arm64` on Apple Silicon).

### Feature gating (frontend)

The shipped F13 frontend hardcodes all features visible when Keycloak is disabled — chat, RAG, summary, transcription tabs would all show even though the configurator only runs `chat`. To fix that, the wizard:

1. Obtains the frontend source by `git clone --depth 1 --branch v2.0.0` from `https://gitlab.opencode.de/f13/microservices/frontend.git` (the tag is pinned so every install produces the same build, regardless of what may sit alongside in `../frontend/`).
2. Patches `src/utils/UIStore.js` so the guest-mode default reads `window.APP_CONFIG.ENABLED_FEATURES` (a comma-separated list).
3. Patches `scripts/docker-entrypoint.sh` to inject that field into `window.APP_CONFIG` at container start.
4. Builds `f13-frontend:v2.0.0_based` locally.
5. Sets `ENABLED_FEATURES=chat` in the generated `.env` so only the Chat tab renders.

All patching happens on a temp copy of the cloned tag. Force a rebuild after bumping `_FRONTEND_GIT_REF` in `lib/frontend.sh` with `./bin/f13-rebuild-frontend`.

---

## Stop / reset / re-run

```bash
# Stop the stack (preserves postgres data — safe for normal restarts)
./bin/f13-stop

# Stop the stack AND wipe all data volumes + generated/ (clean slate)
./bin/f13-reset

# Force a rebuild of the patched frontend image (after upstream changes)
./bin/f13-rebuild-frontend

# Re-run the wizard (keep / edit / reset existing config)
./bin/f13-config

# Force-reset generated/ and start the wizard from scratch
./bin/f13-config --reset

# Render templates without launching (dry run)
./bin/f13-config --dry-run

# Fully non-interactive (CI / scripting)
F13_CONFIG_NONINTERACTIVE=1 \
  F13_CHAT_BACKEND=mock \
  F13_FRONTEND_PORT=9999 \
  F13_CORE_PORT=8000 \
  ./bin/f13-config
```

> **Tip:** After `f13-reset`, always start a fresh run with `./bin/f13-config`. Do not manually delete `generated/` without running `f13-stop` first, or Docker volumes will be left behind and postgres will fail to start on the next run.

When you re-run without `--reset` and `generated/.state` exists, the wizard detects the previous configuration and prompts:

```
Existing configuration found:
  Preset:    core+frontend+chat
  Inference: mock
  Frontend:  http://localhost:9999
  API:       http://localhost:8000

[k]eep existing / [e]dit (re-run with current values) / [r]eset:
```

- **keep** — skip the wizard and offer to start the stack directly.
- **edit** — re-run the wizard with saved values pre-filled as defaults.
- **reset** — delete `generated/` and start fresh.

---

## What's generated

After a successful run `generated/` looks like this:

```
generated/
├── docker-compose.yml       # rendered compose stack (no version: key)
├── .env                     # port overrides and inference vars for compose
├── .state                   # wizard state for idempotent re-runs (chmod 600)
├── configs/
│   ├── core/
│   │   ├── general.yml      # guest_mode, single chat endpoint, allow_origins
│   │   └── llm_models.yml   # one model entry matching active_llms
│   └── chat/
│       ├── general.yml      # active_llms selection + log_level
│       ├── llm_models.yml   # one model entry (mock or ollama)
│       └── prompt_maps.yml  # copied from chat/configs/ — system prompts
└── secrets/
    ├── feedback_db.secret        # postgres password for user 'member' (chmod 600)
    ├── llm_api.secret            # placeholder for future cloud LLM
    ├── transcription_db.secret   # placeholder
    ├── rabbitmq.secret           # placeholder
    ├── rustfs.secret             # placeholder
    └── huggingface_token.secret  # placeholder
```

Secrets are never committed — `generated/` is in `.gitignore`.

---

## Roadmap

> No fixed dates — pull requests welcome 🙌

**Platform**

- 🐧 **Linux & WSL distro coverage** — Ubuntu 22.04 + WSL2 is the validated target as of v0.3.0. Other Linux distros (Fedora, Arch, native Ubuntu without WSLg, etc.) should largely work but haven't been smoke-tested; expect small fixes around the apt prerequisites (`fonts-noto-color-emoji`, `wslu`) and any distro-specific DRI permission quirks.

**Configuration depth**

- 🧩 **Full / per-service F13 configuration** — presets beyond `core+chat`: RAG, summary, parser, transcription, inference, with toggles to mix and match.
- 📝 **Custom system prompts** — supply or edit the chat system prompt during the wizard rather than copying the upstream `prompt_maps.yml` verbatim. Probably an `--editor` flag that opens `$EDITOR` on a generated draft.

**Inference options**

- ☁️ **Cloud LLM inference** — wire in OpenAI / Anthropic / Cohere etc. via the existing `is_remote: true` model schema, with API-key prompts and `llm_api.secret` integration.
- ⚡ **Local vLLM inference** — a third chat inference option alongside mock and Ollama for users with a vLLM server.

**Security**

- 🔐 **Keycloak authentication** — optional preset that spins up a real Keycloak container with a sample realm, replacing the current guest-mode default for production-like setups.

**User experience**

- 🖥️ **Desktop GUI — _mostly stable on macOS + Linux (v0.3.0+)_** — a Tauri 2 + Svelte 5 desktop app alongside the shell wizard, for users who'd rather click than type. Same engine: shells out to `bin/f13-config` via a JSON-event protocol, no logic duplication. Every documented flow works on both surfaces — first-time setup, Stop/Start, Reset, mock or host-Ollama with cloud-tagged models, and live reconfigure of a running stack (the last shipped in v0.3.1). Edge-case combinations of state and error paths haven't been exhaustively exercised. See [`gui/README.md`](gui/README.md) for the GUI's own docs.

---

## Known limitations

- **Single preset**: `core + frontend + chat` only. No RAG, summary, parser, transcription, or inference services. The corresponding tabs are hidden in the patched frontend.
- **First-run is slower**: The frontend is built locally (~1–3 min depending on hardware and network). Subsequent runs reuse the cached `f13-frontend:v2.0.0_based` image.
- **No real auth**: Keycloak runs in guest mode; there is no login UI.
- **No cloud LLM**: API-key inference providers (OpenAI, Anthropic, etc.) are out of scope for v1.
- **No GPU variants**: The compose file does not wire NVIDIA/ROCm device grants.
- **Linux only for host-Ollama port forwarding**: `host.docker.internal:host-gateway` requires Docker 20.10+. Older installations must upgrade.
- **Windows / WSL**: Not supported. Use Linux or macOS.
