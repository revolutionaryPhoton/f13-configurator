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

## Pending Stories

| Story | Description |
|-------|-------------|
| S12 | Idempotency + re-run (`lib/state.sh`) |
| S13 | Shellcheck clean-up |
| S14 | README.md |
| S15 | Demo transcript |

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
- S11 completed: lib/compose.sh — compose::up runs docker compose up -d, waits
  healthy, and prints a success box with Frontend/API URLs and stop command.
  compose::wait_healthy polls http://localhost:${CORE_PORT}/health for up to
  120s (timeout overridable via _COMPOSE_WAIT_MAX) with a ⏳ spinner; returns
  1 on timeout. compose::down tears down cleanly. Internal helpers
  compose::_docker_compose and compose::_curl_health are overridable for
  hermetic tests. 13 new bats tests (1 docker integration test marked skip);
  189/189 green, shellcheck clean.
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
