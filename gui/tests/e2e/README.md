# F13 Configurator — E2E Smoke Test

End-to-end wizard smoke test using [Tauri WebDriver](https://tauri.app/develop/tests/webdriver/) and [WebdriverIO](https://webdriver.io/).

**This test is maintainer-only.** It is not run by the loop, not run in CI, and requires a macOS machine with a display, Docker, and the full build toolchain. The `F13_E2E=1` environment guard prevents accidental execution.

---

## What the test covers

| Step | Screen | Assertion |
|------|--------|-----------|
| 1 | Welcome | Heading visible, "Begin setup" click navigates to `/wizard/preflight` |
| 2 | Preflight | All checks pass (no fail rows), Continue enabled and clicked |
| 3 | Inference picker | Mock tile selected (`aria-checked=true`), navigates to `/wizard/ports` |
| 4 | Ports screen | Frontend (9999) and Core (8000) ports show as free, Continue clicked |
| 5 | Build / launch pipeline | All 6 steps reach `data-status="done"` (no "failed") |
| 6 | Status screen | `health-badge` contains "Healthy"; `GET http://localhost:8000/health` → HTTP 200 |
| Teardown | Status screen | "Stop F13" clicked; navigates back to `/` |

---

## Prerequisites

### One-time install (macOS)

```sh
# 1. Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 2. Tauri CLI and tauri-driver
cargo install tauri-cli --version '^2'
cargo install tauri-driver

# 3. WebdriverIO E2E deps (separate from the main gui/ devDeps)
cd gui/tests/e2e
npm install
```

> **Why a separate `package.json`?**  
> WebdriverIO packages are heavy (~200 MB) and only needed for manual E2E runs.
> Keeping them out of the main `gui/package.json` means the loop and CI stay fast.

### Required at runtime

| Dependency | Version | Notes |
|------------|---------|-------|
| macOS | 13+ (Ventura) | Tauri WebDriver uses the system WebKit; Linux not supported until Phase 8 |
| Docker Desktop | 4+ | The F13 stack (core, chat, frontend, feedback-db) launches inside Docker |
| Ports 9999 & 8000 | Free | Default wizard ports; change via `F13_FRONTEND_PORT` / `F13_CORE_PORT` env vars |

---

## Build the app (debug)

```sh
cd gui
npm run build          # Vite production build (required before Tauri bundle)
cargo tauri build --debug
```

The debug binary lands at:

```
gui/src-tauri/target/debug/F13 Configurator     # macOS ARM/Intel binary
```

`wdio.conf.ts` resolves this path automatically relative to `tests/e2e/`.

---

## Run the test

```sh
# From gui/tests/e2e/ (after npm install and cargo tauri build --debug above)
F13_E2E=1 npm test

# Optional overrides
F13_E2E=1 F13_CORE_PORT=8000 npm test
```

Expected output (abbreviated):

```
[chrome #0-0] Running: F13 Configurator — wizard smoke test
[chrome #0-0]   ✓ welcome screen: shows heading and navigates to preflight (1.2s)
[chrome #0-0]   ✓ preflight: all checks pass, continues to inference picker (8.4s)
[chrome #0-0]   ✓ inference picker: selects Mock backend and navigates to ports (0.9s)
[chrome #0-0]   ✓ ports screen: defaults are free, continues to run pipeline (3.1s)
[chrome #0-0]   ✓ pipeline: all 6 steps complete successfully (142.3s)
[chrome #0-0]   ✓ status screen: health badge is Healthy and core /health returns 200 (6.7s)

[chrome #0-0] 6 passing (163.6s)
```

> **Note:** The pipeline step takes the longest (docker pull + frontend build inside Docker).
> Allow 3–10 minutes depending on network speed and image cache state.

---

## Maintainer run log

<!-- Filled in once the maintainer runs the test on their macOS machine. -->

| Date | Machine | Result | Duration | Notes |
|------|---------|--------|----------|-------|
| (pending) | | | | First run — record output here |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `tauri-driver: command not found` | Run `cargo install tauri-driver` |
| `Cannot find module 'wdio-tauri-service'` | Run `npm install` from `gui/tests/e2e/` |
| Binary not found error in wdio.conf.ts | Ensure `cargo tauri build --debug` completed; check the path in `wdio.conf.ts` |
| Port 9999 / 8000 already in use | Stop any running F13 stack: `docker compose -f generated/docker-compose.yml down` |
| Health badge stuck on "Checking" | Docker pull taking long — wait; or check `docker compose logs` for errors |
| `F13_E2E` not set warning | Export the variable: `export F13_E2E=1` before running |

---

## Architecture note

The test uses Tauri's native WebDriver support:

```
npm test
  └─ wdio run wdio.conf.ts
       ├─ wdio-tauri-service starts tauri-driver (WebDriver proxy)
       ├─ tauri-driver launches the F13 Configurator.app process
       └─ WebdriverIO connects via WebDriver protocol
            └─ smoke.spec.ts drives the wizard UI
                 └─ Engine adapter shells out to bin/f13-config
                      └─ Docker stack is started inside Docker Desktop
```

The `F13_E2E` guard inside `smoke.spec.ts` causes the entire suite to be
skipped via `describe.skip` when the variable is absent, so the file is safe
to `import` or include in any test runner that might accidentally discover it.
