# F13 Shell Configurator v1

Shell configurator for a minimal F13 deployment.

Walks a first-time user from zero to a running F13 instance
(`core + frontend + chat`) with a single command — no YAML hand-editing
required.

## Quick start

```bash
cd configurator_v1
./bin/f13-config
```

## Requirements

- Docker Engine 20.10+ with `docker compose` (v2)
- Bash 4+ (`brew install bash` on macOS)
- `curl`, `awk`, `sed`, `envsubst`
- ~2 GB free disk space
- Ports 8000 and 9999 available (configurable)

## Chat backends

| Backend | Description |
|---------|-------------|
| Mock    | Uses the shipped `ollama-mock` image — no GPU, deterministic responses. Ideal for testing. |
| Host Ollama | Connects to `ollama serve` running on this machine at `localhost:11434`. |

On Linux, Docker reaches the host via `host.docker.internal:host-gateway`
(requires Docker 20.10+).

## Stop / reset / re-run

```bash
# Stop
cd generated && docker compose down

# Re-run wizard (keep / edit / reset existing config)
./bin/f13-config

# Force reset
./bin/f13-config --reset
```

## What's generated

```
generated/
  docker-compose.yml    # minimal stack
  .env                  # port + backend vars
  configs/core/         # core service YAML configs
  configs/chat/         # chat service YAML configs
  secrets/              # generated secrets (chmod 600)
```

## Known limitations

- Single preset only: `core + frontend + chat`
- Keycloak is in guest mode — no real auth UI
- No RAG, summary, parser, transcription, or inference services
- Windows / WSL not supported
