# F13 Shell Configurator -- Progress

## Completed Stories

| Story | Description | Commit | Tests |
|-------|-------------|--------|-------|
| S00 | Project bootstrap | TBD | 22/22 ✅ |

## Pending Stories

| Story | Description |
|-------|-------------|
| S01 | Colors, emoji, box-drawing helpers (`lib/ui.sh`) |
| S02 | F13 ASCII banner (`lib/banner.sh`) |
| S03 | Interactive prompts (`lib/prompt.sh`) |
| S04 | Random secrets (`lib/secrets.sh`) |
| S05 | Port probes (`lib/ports.sh`) |
| S06 | Preflight checks (`lib/preflight.sh`) |
| S07 | Host Ollama integration (`lib/ollama.sh`) |
| S08 | Template renderer (`lib/render.sh`) |
| S09 | Compose + config templates |
| S10 | Main wizard (`bin/f13-config`) |
| S11 | Launch + health wait (`lib/compose.sh`) |
| S12 | Idempotency + re-run (`lib/state.sh`) |
| S13 | Shellcheck clean-up |
| S14 | README.md |
| S15 | Demo transcript |

## Notes

- S00 completed: full directory layout scaffolded with stub lib files,
  template placeholders, and smoke bats tests (22 tests, all passing).
- Backpressure: shellcheck -S warning passes; bats 22/22 green.
