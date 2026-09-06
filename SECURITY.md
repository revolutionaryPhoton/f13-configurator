# Security Notes — F13 Configurator

This configurator (both the shell wizard and the desktop GUI) is designed
for **local development use only**. As of v0.4.0 the desktop GUI is
mostly stable on macOS and Linux (WSL2 Ubuntu 22.04 validated in v0.3.0;
live reconfigure on a running stack in v0.3.1; localization to DE / FR /
ES and webview zoom in v0.4.0) for daily local use — every documented
flow works, but not every combination of state transitions and error
paths has been exercised, so edge-case bugs may still surface. Prefer
the shell wizard for any production-adjacent work. The stack it
generates is not hardened for production or internet-facing deployment.

---

## ⚠️  AI-generated code

Almost the entire codebase was written by Claude Code via an automated
[ralph loop](https://github.com/revolutionaryPhoton/f13-configurator-ralph)
driven by a PRD. The ralph harness *itself* is also largely AI-generated
(Claude Code in interactive sessions on macOS and Linux), so both halves
of the project — the configurator you're looking at and the loop that
produced it — were written by an AI with human review at the diff level,
not line-by-line.

Each loop iteration runs `shellcheck` + `bats` (and for the GUI,
`npm run check` + `cargo check`) as backpressure. The maintainer
spot-checks diffs before pushing, but **there has been no formal security
audit**.

Implications for anyone reading or running this code:

- Treat dependency choices, parsing logic, and shell-out commands as
  needing extra scrutiny — these are exactly the bug classes an automated
  test suite catches least reliably (off-by-one parsing, race conditions,
  shell injection in dynamically-built commands, escaping mistakes in
  YAML templates).
- The five regressions found during S16 frontend bringup (paren
  imbalance, semicolon-eating regex, mktemp perms, exec-but-not-read on
  USER 999, recursive function injection) are representative — these are
  the kinds of bugs you should expect to find more of.
- If you spot something concerning, please open an issue on GitHub
  rather than relying on this in production.

---

## 🔐 Secrets

- All generated secrets live in `generated/secrets/` with `chmod 644`.
  Mode 0644 (not 0600) is required so the non-root container user
  inside the service image that reads them (as of v0.6.0,
  `feedback_db.secret` is mounted into the `feedback` container, not
  `core` — `core` is now the APISIX gateway and never touches secrets)
  can read the secrets through a Linux Docker bind-mount; macOS Docker
  Desktop's userspace bind-mount shim papers over UID mismatches but
  native Linux / WSL2 doesn't, so 0600 caused a `PermissionError` on
  startup. Host-side gating is provided by the parent `generated/`
  directory living inside `$HOME`.
- `generated/` is listed in `.gitignore` — never commit it.
- The `feedback_db.secret` file contains the postgres password in plain text.
  On a shared machine, ensure `generated/` is only readable by your user
  (`chmod -R go-rwx generated/` is fine — it tightens the parent dir, not
  the secret files).
- Placeholder secret files (llm_api, transcription_db, rabbitmq, rustfs,
  huggingface_token) contain random values. If you later put real credentials
  in them, treat the entire `generated/secrets/` folder as sensitive.

## 🐳 Docker socket

- Running `docker` requires access to the Docker socket (`/var/run/docker.sock`),
  which is equivalent to root access on the host. Only run this configurator
  as a trusted user on a machine you control.

## 🌐 No TLS, no authentication

- The generated stack runs entirely over plain HTTP on localhost.
- `authentication.guest_mode: true` disables all auth checks in the core API.
- **Never expose ports 8000 or 9999 to a network** — bind them to localhost
  only (the default). Do not add firewall rules or reverse proxies that make
  these ports publicly reachable.

## 🗄️ Database

- Postgres runs with a generated random password stored in `feedback_db.secret`.
- The database port (5432) is not published to the host — it is only reachable
  within the Docker network. Do not add a `ports:` mapping for `feedback-db`.

## 📦 Image provenance

- Most F13 service images (`chat`, `feedback`, `ollama-mock`, `opa`) are
  pulled from `registry.opencode.de`. Ensure you trust this registry and
  have not substituted image names or tags with unverified alternatives.
- `core` is the third-party `apache/apisix` image from Docker Hub, not an
  F13-published image — as of v0.6.0 (core v3.0.0) the `core` service is
  the APISIX gateway, not an F13 app container. `frontend` is built
  locally by this configurator (see the frontend feature-gating section
  in `README.md`) and is never pulled from a registry.
- Images are pinned by tag, not digest. For stronger supply-chain guarantees,
  consider pinning by SHA-256 digest in the compose template.

## 🔄 Volume hygiene

- `docker compose down` (without `-v`) leaves the `feedback-db-data` volume
  on disk. Use `./bin/f13-reset` (which runs `down -v`) to remove it when
  done, especially on shared machines.

## ✅ What this configurator does NOT do

- It does not open any network listeners of its own.
- It does not send telemetry or usage data anywhere.
- It does not require or request elevated privileges (no `sudo`).
- It does not modify files outside `configurator_v1/generated/`.
