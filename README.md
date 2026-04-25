# F13 Shell Configurator v1

A shell-based wizard that brings up a minimal F13 deployment — `core + frontend + chat` — with a single command. No YAML hand-editing, no manual secret generation, no ops experience required.

---

## Quickstart

```bash
cd configurator_v1
./bin/f13-config
```

The wizard walks you through every choice (chat backend, ports), generates all secrets, renders the compose stack, and optionally starts it. Total time from zero to running: under two minutes.

---

## Requirements

| Requirement | Notes |
|---|---|
| Docker Engine 20.10+ | Must include `docker compose` (v2 plugin) |
| Bash 4+ | macOS ships 3.2 — run `brew install bash` and use `/usr/local/bin/bash` |
| `curl` | Used for Ollama probing and health checks |
| `awk`, `sed`, `envsubst` | Usually pre-installed; `envsubst` is in `gettext` |
| `git` | Only required if `../frontend/` is not present locally — the wizard clones it from GitLab |
| ~3 GB free disk | F13 images plus the local frontend build |
| Ports 8000 and 9999 | Defaults; the wizard lets you pick alternatives if busy |

---

## Chat backends

The wizard asks how chat inference should run:

```
Where should chat inference run?
  1) 🧪 Mock backend (no GPU, deterministic responses)
  2) 🦙 Host Ollama (connects to ollama serve on this machine)
```

### Option 1 — Mock backend

Spins up the shipped `ollama-mock` container alongside the stack. No GPU needed. Responses are deterministic and useful for testing the UI or integration.

```
  1) 🧪 Mock backend (no GPU, deterministic responses)
> 1

✅  Chat backend: mock
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

✅  Chat backend: ollama  model: gemma4:31b-cloud
```

#### How Docker reaches the host (Linux)

On macOS, `host.docker.internal` resolves automatically. On Linux it does not exist by default. The generated `docker-compose.yml` injects:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

This is always present in the chat service definition (harmless when using the mock backend, required for host-Ollama on Linux). Requires Docker Engine 20.10+.

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
| `frontend` | `f13-frontend:configurator-v1` (built locally) | Patched to honour `ENABLED_FEATURES`; only the Chat tab is visible |
| `core` | `registry.opencode.de/f13/microservices/core/main:latest` | Guest mode enabled (`authentication.guest_mode: true`) |
| `chat` | `registry.opencode.de/f13/microservices/chat:v1.1.0` | Configured for mock or host-Ollama |
| `feedback-db` | `postgres:16-alpine` | Password from generated secret; user `member` |
| `ollama-mock` | `base-images/ollama-mock-f13:1.2.0` | Only when mock backend is selected (compose profile) |

The F13 service images (`core`, `chat`, `ollama-mock`) are `linux/amd64`. On Apple Silicon the generated compose sets `platform: linux/amd64` so Docker Desktop runs them via Rosetta 2 emulation — no rebuild needed, first boot is slightly slower. The `frontend` image is built locally and is therefore native (`arm64` on Apple Silicon).

### Feature gating (frontend)

The shipped F13 frontend hardcodes all features visible when Keycloak is disabled — chat, RAG, summary, transcription tabs would all show even though the configurator only runs `chat`. To fix that, the wizard:

1. Obtains the frontend source — local monorepo (`../frontend/`) if available, otherwise `git clone` from `https://gitlab.opencode.de/f13/microservices/frontend.git`.
2. Patches `src/utils/UIStore.js` so the guest-mode default reads `window.APP_CONFIG.ENABLED_FEATURES` (a comma-separated list).
3. Patches `scripts/docker-entrypoint.sh` to inject that field into `window.APP_CONFIG` at container start.
4. Builds `f13-frontend:configurator-v1` locally.
5. Sets `ENABLED_FEATURES=chat` in the generated `.env` so only the Chat tab renders.

The original `../frontend/` is never modified; all patching happens on a temp copy. Force a rebuild after upstream frontend changes with `./bin/f13-rebuild-frontend`.

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
  Backend:   mock
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
├── .env                     # port overrides and backend vars for compose
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

## Known limitations

- **Single preset**: `core + frontend + chat` only. No RAG, summary, parser, transcription, or inference services. The corresponding tabs are hidden in the patched frontend.
- **First-run is slower**: The frontend is built locally (~1–3 min depending on hardware and network). Subsequent runs reuse the cached `f13-frontend:configurator-v1` image.
- **No real auth**: Keycloak runs in guest mode; there is no login UI.
- **No cloud LLM**: API-key backends (OpenAI, Anthropic, etc.) are out of scope for v1.
- **No GPU variants**: The compose file does not wire NVIDIA/ROCm device grants.
- **Linux only for host-Ollama port forwarding**: `host.docker.internal:host-gateway` requires Docker 20.10+. Older installations must upgrade.
- **Windows / WSL**: Not supported. Use Linux or macOS.
