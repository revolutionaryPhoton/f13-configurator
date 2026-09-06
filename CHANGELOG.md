# Changelog

All notable changes to the F13 Configurator are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

## [0.6.0] — 2026-09-06

> **Highlights:** The upstream re-baseline (**Phase 17**). The configurator now
> generates a stack for **core v3.0.0 + chat v3.0.0**, where "core" is no longer
> an F13 image at all but an **APISIX gateway**. Also moves CI to **Node 24 LTS**
> and brings five GitHub Actions up from 3–4 majors behind. **macOS only** —
> Linux `.AppImage` / `.deb` remain deferred.

### Changed — upstream re-baseline (Phase 17)

The headline is architectural rather than a version bump. In core v3.0.0 the
`core` service is `apache/apisix:3.15.0-ubuntu`; the monolithic core
application is gone from the deployment and APISIX routes to the individual
services. `grep -c 'microservices/core'` in core v3's own compose returns 0.

- **core** → `apache/apisix:3.15.0-ubuntu` plus its four mounted config files.
- **chat** → `v3.0.0`, which **requires an OPA sidecar**: without
  `service_endpoints.opa` the service refuses to start.
- **opa** → `opa:1.18.1-debug`, new and mandatory, with the policy set shipped
  into `generated/opa/policies/`.
- **feedback** → `feedback:v1.0.1`, new in the minimal stack.
- **feedback-db** → `postgres:18-alpine` (was 17).
- **ollama-mock** → `builder-images/ollama-mock:v1.2.2` (both path and tag
  changed upstream).
- **frontend** → patched build re-derived against `v3.0.1` (was `v2.0.0`).
- `CHAT_MAX_CONTEXT_TOKENS` → **`CHAT_CONTEXT_LENGTH`**, matching chat v3, where
  the value now covers input *and* output.

Versions follow the F13 compatibility matrix. RAG, summary, parser and
transcription remain explicitly out of scope.

### Fixed — found by launching the stack, not by tests

Six defects that only exist once containers actually run. None were reachable
from the test suite, which stayed green throughout:

- **postgres 18 moved its volume mount** to `/var/lib/postgresql`; the pre-18
  `/var/lib/postgresql/data` form makes the container refuse to start.
- **APISIX opens `config-guest.yaml` by name**, so renaming the mounted config
  files crash-loops the gateway. Upstream mounts all four 1:1.
- **feedback reads core's `general.yml`** — upstream's `configs/` is flat, ours
  is per-service, so the service started with no config at all.
- **A missing bind-mount source is created by Docker as a DIRECTORY**, after
  which `cp` copies into it and every later render latches into the broken
  shape. `docker compose down -v` does not clear it: these are host paths under
  `generated/`, not volumes.
- **The frontend requires `tusd`** or nginx refuses to start. Patched out of the
  nginx template rather than pulling rustfs and transcription into the stack.
- **`mktemp` creates 0600 and `mv` carries that mode**, leaving the patched
  nginx template unreadable by the non-root nginx user.

### Added — guards against the above

- `compose::validate_generated` runs as a precondition in `compose::up`, so a
  damaged tree reports the actual host file instead of an opaque runc error
  naming the container path.
- The wizard's **"keep" path now re-renders when the tree is damaged** instead of
  launching it. Keep means keep your *answers*, not keep whatever files happen
  to be on disk.
- `_wizard_copy_file` replaces plain `cp` for all seven vendored-file copies, so
  a stray directory is overwritten rather than copied into.

### Changed — toolchain and CI

- **Node 20 → 24 LTS** across all four workflow pins, plus an explicit
  `engines` floor in `gui/package.json`. Node 20 had begun blocking work: jsdom
  30 requires `^22.22.2 || ^24.15.0 || >=26.0.0`.
- **Dependabot now watches GitHub Actions**, which nothing had been doing —
  the pins had drifted 3–4 majors. `actions/checkout` 4 → 7, `setup-node` 4 → 7,
  `upload-artifact` 4 → 7, `download-artifact` 4 → 8, `gitleaks-action` 2 → 3.
  Left ungrouped on purpose so each major lands with its own CI run.
- `jsdom` 30.0.1, `@testing-library/jest-dom` 7.0.1, `svelte` 5.57.0,
  `axe-core` 4.13.0, and the tauri JS/Rust plugin pair kept in step.

### Fixed — tests that asserted the developer's machine

Two tests were green in CI and red on any real dev box, which is the polarity
that teaches you to ignore local failures:

- The discovery tests required `configurator_v1/generated/` to be absent, which
  stops being true the moment anyone runs the wizard.
- `--list-models` required Ollama to be **unreachable**.

Both now force their condition through `_F13_DEV_ROOT` and `_F13_OLLAMA_URL`
hooks. The suite is green locally as well as in CI.

### Known limitations

- **No resumable file upload** in the minimal stack: the frontend's upload path
  needs `tusd`, which would pull in rustfs and transcription.
- **Routes to omitted services hang rather than failing fast.** APISIX ships
  routes for rag/summary/transcription; with those services absent the request
  stalls until the client times out (the gateway logs `499`). Not reachable in
  normal use, since `ENABLED_FEATURES` gates them out of the UI.
- `opa`, `feedback` and `chat` are published for `linux/amd64` only, so they run
  emulated on Apple Silicon. The compose file now declares the platform
  explicitly to silence the warning; making them native needs multi-arch images
  upstream.

## [0.5.4] — 2026-08-31

> **Highlights:** Security release. Clears **all 9 open advisories** (2 HIGH)
> that accumulated during a two-month maintenance gap, plus the dependency
> refresh and repo hygiene that came with them. No functional changes.
> **macOS only** — Linux `.AppImage` / `.deb` remain deferred (the
> `ubuntu-latest` glibc rebuild is still pending; see `release.yml` for the
> re-enable plan).

### Security

- **`undici`** 7.28.0 → 7.29.0 (#80) — resolves five advisories:
  - **HIGH** (GHSA-4cwx-7wf7-3272): cross-user information disclosure and a
    parse-time issue.
  - **MEDIUM** (GHSA-m8rv-5g2x-5cg5): CRLF injection via a blob-like body
    `type` property.
  - **MEDIUM** (GHSA-v3r7-h72x-cjcm): cookie attribute injection via an
    unsanitized domain.
  - **MEDIUM** (GHSA-jr45-8vmc-qm54): cross-user information disclosure via a
    whitespace bypass.
  - **MEDIUM** (GHSA-8xcm-r25x-g524): downstream response desynchronization
    via retry handling.
- **`postcss`** 8.5.16 → 8.5.26 (#79) —
  **HIGH** (GHSA-r28c-9q8g-f849): path traversal in previous-source-map
  auto-loading; **MEDIUM** (GHSA-fxqj-rqcc-2cmp): incomplete fix of
  GHSA-6g55-p6wh-862q.
- **`@sveltejs/kit`** 2.66.0 → 2.70.3 (#78) — **MEDIUM**
  (GHSA-866w-xmhq-wj7x): prototype pollution in the remote-form file-input
  deletion path.
- **`serde_with`** 3.18.0 → 3.22.0 (#74) — **MEDIUM** (GHSA-7gcf-g7xr-8hxj):
  `KeyValueMap` serialization panics on an empty sequence or map.

### Changed — dependency bumps

- **`@biomejs/biome`** 2.5.0 → 2.5.11 (#72); `biome.json` `$schema` synced to
  match the installed version.
- **`svelte-check`** 4.6.0 → 4.7.6 (#73).
- **vite-build group** (#75): `vite` 8.2.2, `@sveltejs/vite-plugin-svelte`
  7.3.0, `@tailwindcss/vite` 4.3.3, `vitest` 4.1.11.
- **`serde`** 1.0.229 (#76) and **`serde_json`** 1.0.151 (#77).

### Changed — repo

- **Commit trailers now name the model**, not just the harness:
  `Co-Authored-By: <Agent>, <Model>` (e.g. `Claude Code, Opus 5`). Canonical
  definition in `AGENTS.md`. The Ralph harness pins `claude --model`, injects
  the model into the iteration prompt, and verifies every commit against the
  model recorded in that iteration's stream `init` event.
- Landed documentation fixes that had been sitting uncommitted since
  2026-07-11 (`../PRD.md` path, the Linux-Docker → macOS lockfile note, the
  `LOOP_CONTEXT.md` / `AGENTS.md` backpressure union), and corrected a stale
  claim that the Ralph harness is reachable from inside the loop sandbox — it
  is deliberately excluded.
- **TypeScript majors held** via a `.github/dependabot.yml` ignore: no
  `@sveltejs/kit` 2.x accepts TypeScript 7 (peer `^5.3.3 || ^6.0.0`), so the
  bump cannot resolve at `npm ci`. Deferred, not abandoned — #70 closed with
  the recheck command recorded beside the rule.

All bumps patch/minor. CI green on every PR; the macOS `.dmg` builds, signs,
notarizes and Gatekeeper-accepts unchanged from v0.5.3.

## [0.5.3] — 2026-07-05

> **Highlights:** Dependency-maintenance release. Rolls up the Tauri
> toolchain (JS + Rust), the Vite/Tailwind build chain, and the Svelte /
> test-lib deps accumulated since v0.5.2. No functional changes.
> **macOS only** — Linux `.AppImage` / `.deb` remain deferred (the
> `ubuntu-latest` glibc rebuild is still pending; see `release.yml` for
> the re-enable plan).

### Changed — dependency bumps

- **Tauri (Rust)** — `tauri` → 2.11.5, `tauri-build` → 2.6.3
  (#61, #63, tauri-rust group).
- **Tauri (JS)** — `@tauri-apps/api` → 2.11.1, `@tauri-apps/cli` → 2.11.4
  (#59, #62, tauri-js group). JS + Rust sides stay aligned on the 2.11 line.
- **`@tailwindcss/vite`** + **`vite`** → 4.3.2 (#64, vite-build group);
  pulls `tailwindcss` core to 4.3.2 transitively, so the standalone
  bump #66 was auto-closed by Dependabot as redundant.
- **`svelte`** 5.56.3 → 5.56.4 (#65).
- **`@testing-library/svelte`** 5.3.1 → 5.4.2 (#67, dev dependency).
- **`axe-core`** 4.12.0 → 4.12.1 (#60, dev dependency).

All patch/minor; no security advisories this cycle. CI green on every PR;
the macOS `.dmg` builds, signs, notarizes, and Gatekeeper-accepts
unchanged from v0.5.2.

## [0.5.2] — 2026-06-20

> **Highlights:** Security + dependency-maintenance release. Resolves two
> `undici` advisories (one HIGH) and refreshes the GUI build/runtime deps.
> No functional changes. **macOS only** — Linux `.AppImage` / `.deb` remain
> deferred (the `ubuntu-latest` glibc rebuild is still pending; see
> `release.yml` for the re-enable plan).

### Security

- **`undici`** 7.25.0 → 7.28.0 (#56) — resolves two Dependabot advisories
  on the transitive `undici` dependency:
  - **HIGH** (GHSA-vmh5-mc38-953g): TLS certificate-validation bypass via
    dropped `requestTls` in the SOCKS5 `ProxyAgent`.
  - **MEDIUM** (GHSA-pr7r-676h-xcf6): cross-user information disclosure via
    a shared-cache whitespace bypass.

### Changed — dependency bumps

- **`@sveltejs/kit`** 2.63.0 → 2.66.0 (#53).
- **`svelte`** 5.56.2 → 5.56.3 (#55).
- **`@biomejs/biome`** 2.4.16 → 2.5.0 (#52); `biome.json` `$schema` URL
  synced to match.
- **`tailwindcss`** 4.3.0 → 4.3.1 (#54) and **`@tailwindcss/vite`** 4.3.0
  → 4.3.1 (#57, vite-build group).
- **`vitest`** 4.1.8 → 4.1.9 (#57, vite-build group).

All patch/minor (except the security-driven undici bump). CI green on
every PR; the macOS `.dmg` builds, signs, notarizes, and Gatekeeper-
accepts unchanged from v0.5.1.

## [0.5.1] — 2026-06-07

> **Highlights:** Dependency-maintenance release. GUI build/runtime deps
> refreshed; no functional changes. **macOS only** — Linux `.AppImage` /
> `.deb` remain deferred (the `ubuntu-latest` glibc rebuild is still
> pending; see `release.yml` for the re-enable plan).

### Changed — dependency bumps

- **`vite`** 8.0.14 → 8.0.16 and **`vitest`** 4.1.7 → 4.1.8 (vite-build
  group, #45).
- **`svelte`** 5.56.0 → 5.56.2 (#47).
- **`@sveltejs/kit`** 2.61.1 → 2.63.0 (#49).
- **`svelte-check`** 4.4.8 → 4.6.0 (#48; pulls new transitive
  `@sveltejs/load-config`).
- **`axe-core`** 4.11.4 → 4.12.0 (#46; a11y test dep).

All patch/minor, no majors. CI green on every PR (tauri build +
shellcheck/bats + gitleaks); macOS `.dmg` builds, signs, notarizes,
and Gatekeeper-accepts unchanged from v0.5.0.

## [0.5.0] — 2026-06-01

> **Highlights:** First **signed + notarized macOS distributable.** A
> tagged release now produces a Gatekeeper-clean `.dmg` (macOS arm64),
> attached to a draft GitHub Release for manual publish. Bundled installs
> now write their generated config to a proper per-user data directory
> instead of (impossibly) inside the signed app bundle. Phase 10 of the
> PRD ships here.
>
> **Linux is not in this release.** The `.AppImage` / `.deb` (S55) are
> deferred to **v0.5.1**: the `ubuntu-latest`-built binaries failed with
> `GLIBC` version errors on older target distros (e.g. WSL2 Ubuntu 22.04),
> so they need a rebuild on an older-glibc runner before shipping. The
> bundled-path fixes below already cover Linux at the code level; only the
> packaged artifacts wait for v0.5.1.

### Added — Signed macOS distributable (S53 + S54 + S56)

- **`.github/workflows/release.yml`** — on a `v*` tag push, builds a
  signed + **notarized + stapled** `.dmg` for macOS arm64 and attaches
  it to a **draft** Release. The maintainer reviews and publishes
  manually (no auto-publish). `workflow_dispatch` is available for
  build-only dry runs. Bundle version is synced from the tag at build
  time. (A `build-linux` job exists but is disabled pending the v0.5.1
  glibc fix.)
- **Code signing** via `tauri.conf.json` `bundle.macOS.signingIdentity`
  (`Developer ID Application`, `minimumSystemVersion` 11.0 — the arm64
  floor). Notarization runs through `notarytool`; both the `.app` and
  the `.dmg` wrapper are stapled so a downloaded dmg opens cleanly
  offline. Maintainer setup lives in `gui/SIGNING.md` (gitignored).
- Single-architecture by design: macOS **arm64 only**. Universal builds,
  Homebrew, and auto-update are deferred to later phases.

### Fixed — Bundled app finds the host toolchain (macOS)

- **Login-shell PATH recovery** — a Finder/Launchpad-launched `.app`
  inherits launchd's minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`),
  so the preflight (which shells out through the bundled wizard)
  reported `docker`, Homebrew `bash`, and `envsubst` as "not found"
  even when installed. The app now recovers the real PATH from a login
  shell at startup and adopts it process-wide, so subprocess spawns see
  the full toolchain. No-op when launched from a terminal (PATH already
  complete).

### Fixed — Bundled-mode data paths (S51 + S52)

- **`get_generated_dir()` (Rust)** — in a bundled install, the
  `generated/` directory (docker-compose.yml, `.env`, secrets) now
  resolves to the platform app-local-data dir instead of a path
  *inside* the signed, read-only `.app` bundle (which was never
  writable and would have broken the signature):
  - macOS: `~/Library/Application Support/de.f13-os.configurator/generated`
  - Linux: `~/.local/share/de.f13-os.configurator/generated`

  Dev-mode path (`configurator_v1/generated`) is unchanged. **This is
  what makes the signed distributable actually functional once
  installed.**
- **`lib/discover.sh` + `bin/f13-stop` / `bin/f13-reset`** — the
  teardown scripts now auto-discover `generated/` across the
  `F13_GENERATED_DIR` env override, the dev `SCRIPT_DIR/../generated`
  layout, and the bundled app-local-data locations above, so
  `./bin/f13-stop` works whether you're in a checkout or running a
  bundled install. A clear "run f13-config first, or set
  F13_GENERATED_DIR" hint is shown when no stack is found.

### Tests

- +6 vitest (`bootstrap.test.ts`, the bundled-path resolution),
  +13 bats (`discover.bats` + `f13-reset.bats` integration), and +5
  Rust unit tests (the macOS PATH-truncation heuristic). Totals:
  vitest **384/384**, bats **295** — green on macOS and Linux.
- Pipeline validated end to end via `v0.5.0-rc1` / `rc2` dry-run tags:
  build → sign → notarize + staple (`.app` **and** `.dmg`) →
  Gatekeeper accept (`spctl`: "Notarized Developer ID, accepted") →
  draft Release with all three assets. Both rc tags + drafts cleaned
  up.

## [0.4.1] — 2026-05-22

> **Highlights:** Maintenance release. CI-blocking Tauri JS/Rust version
> mismatch fixed; build chain refreshed (TypeScript 5 → 6, vite 6 → 8
> via `@sveltejs/vite-plugin-svelte` 5 → 7, svelte 5.55.5 → 5.55.9 with
> a transitive XSS fix); Dependabot grouping config added so neither the
> JS/Rust mismatch nor a vite/peer-dep deadlock can reopen silently.
> **No user-facing changes** — same wizard, same GUI, same flows.

### Fixed

- **`@tauri-apps/api` pin (PR #7, squash `5de58bd`).** Dependabot bumped
  the cargo-side `tauri` crate 2.10.3 → 2.11.1 on 2026-05-08 (PR #2),
  but the JS-side `@tauri-apps/api` stayed at 2.10.1 in the lockfile.
  Tauri's startup version-mismatch guard tripped on every macOS CI run
  for two weeks before anyone noticed. `gui/package.json` widened to
  `"@tauri-apps/api": "^2.11.0"`; subsequently bumped to 2.11.2 via
  the new `tauri-js` Dependabot group (PR #13).
- **`gui/biome.json` `$schema` URL (PR #24, squash `37179ba`).** The
  CLI was at 2.4.15 (post-#16) but the JSON schema URL still resolved
  to `/2.4.13/`, causing an info-level deserialize warning on every
  `biome check`. One-line fix.

### Security

- **`svelte` 5.55.5 → 5.55.9 (PR #8, squash `04dacc9`).** Patch line.
  5.55.7 fixes an XSS on `hydratable` from user content. F13's GUI
  doesn't render arbitrary user content, so practical exposure is low,
  but the upstream fix lands here regardless. Also: SSR empty-attribute
  ban, regex hardening, runtime-property symbol move (5.55.7);
  `svelte:body` print + keyframe percentage double-printing fixes
  (5.55.8); `{#await}` batch + hydration fixes and batch-invariant
  false-positive fix (5.55.9); stale-promise / `$state.eager` /
  `bind:this` proxification fixes (5.55.6). Transitively bumps
  `devalue` 5.7.1 → 5.8.1.

### Changed — build chain majors

- **`typescript` 5.6.3 → 6.0.3 (PR #14, squash `aeff244`).** TS 5 → 6.
  Pin tightened from `~5.6.2` to `~6.0.3` so future Dependabot bumps
  stay within 6.0.x patches. Full backpressure suite green under TS 6
  (svelte-check + tsc + vitest + cargo).
- **`vite-build` group: vite 6 → 8 + plugin-svelte 5 → 7 (PR #20,
  squash `1c783df`).** Bundled by the new `vite-build` Dependabot
  group (PR #19). `@sveltejs/vite-plugin-svelte` 7.1.2 widens its
  peer to `vite ^8.0.0-beta.7 || ^8.0.0`, unblocking the vite major.
  `@sveltejs/vite-plugin-svelte` 5.1.1 → 7.1.2; `vite` 6.0.3 →
  8.0.14; `vitest` patch. A prior standalone vite-8 bump (PR #17)
  was ERESOLVE'ing on the vite-plugin-svelte 5.x peer constraint —
  the group config is what fixed it. PR #17 was auto-closed as
  superseded.
- **`tailwindcss` 4.2.4 → 4.3.0 (transitive via PR #20).** Minor.
  New utilities (`@container-size`, `scrollbar-*`, `zoom-*`, `tab-*`,
  more `@variant` flexibility) — none of which we use yet —
  plus canonicalization fixes. Standalone PR #22 was auto-closed
  as redundant after #20's lockfile churn lifted it.

### Changed — SvelteKit + tooling

- **`@sveltejs/kit` 2.58.0 → 2.60.1 (PR #9, squash `bb3e04c`).**
  Minor. Form `submit`/`hidden` accept numbers + booleans; warns on
  unread form remote-function validation; fixes `query.batch`
  cross-talk and aborts navigation after async render. F13 is a
  Tauri shell via `@sveltejs/adapter-static`, so the new features
  are inert here; the navigation/cross-talk fixes touch the static
  build path.
- **`svelte-check` 4.4.6 → 4.4.8 (PR #15, squash `3193028`).** Patch.
- **`@biomejs/biome` 2.4.13 → 2.4.15 (PR #16, squash `4ae036c`).**
  Patch.

### Changed — Tauri pair (matched JS+Rust via dependabot groups)

- **`tauri-rust` group: 2.11.1 → 2.11.2 (PR #11, squash `29bd9ec`).**
  Patch line across `tauri`, `tauri-build`, `tauri-codegen`,
  `tauri-macros`, `tauri-plugin-opener`, `tauri-plugin-shell`,
  `tauri-runtime`, `tauri-runtime-wry`.
- **`tauri-js` group: api+cli 2.10.1 → 2.11.2 (PR #13, squash
  `7e82d0c`).** `@tauri-apps/api` and `@tauri-apps/cli` bumped
  together. JS/Rust now matched at 2.11.2 across both ecosystems —
  the grouping config's first successful validation.
- **`serde_json` 1.0.149 → 1.0.150 (PR #12, squash `4823d6d`).**
  Cargo patch.

### Changed — test-only dev dependencies

- **`jsdom` 29.0.2 → 29.1.1 (PR #23, squash `c47db4c`).** vitest env;
  `getComputedStyle()` fixes (border-radius serialization,
  background-origin/clip, cache freshness), basic `ratio` CSS-type
  support, perf optimization for initial calls.
- **`axe-core` 4.11.3 → 4.11.4 (PR #21, squash `5a2bf9a`).** vitest
  a11y tests; `aria-labelledby` + natively-hidden ancestor fix;
  escape node names in `getAncestry`. Upstream: "unlikely to change
  the number of issues found."

### Added — Dependabot config

- **`.github/dependabot.yml` (PR #10, squash `0714ebb`; extended in
  PR #19, squash `386dc39`).** Previously there was no config —
  version updates were running off the UI toggle, ungrouped, which
  is how the v0.4.0 cycle's JS/Rust mismatch slipped past review.
  Now two npm groups (`tauri-js`, `vite-build`) and one cargo group
  (`tauri-rust`) bundle deps that must move together. The
  `vite-build` group was validated end-to-end during this release
  cycle: PR #17's standalone vite 8 bump was correctly superseded
  by PR #20's grouped vite-plugin-svelte 7 + vite 8 bundle.

### Added — CI

- **`shellcheck + bats` job alongside the macOS Tauri build (PR #26,
  squash `0482072`).** The existing workflow only covered three of
  the five backpressure pieces (`npm run check`, `npm run test:unit`,
  `cargo check`). The shell side (`shellcheck -S warning bin/* lib/*.sh`
  and `bats tests/`) was previously enforced only locally + via the
  ralph loop, so a shell-only regression could have landed via PR.
  Closing that gap: new `shell-checks` job on `ubuntu-latest`, runs
  in parallel with `build-macos` in ~1m on a cold cache. Paths filter
  extended to include `tests/**` and `.github/workflows/**`. Workflow
  display name renamed from "GUI build (macOS)" to "CI"; file path
  kept as `gui-build.yml`.

### Tests

- No new tests. vitest stays 378/378 green; `cargo check` passes;
  full backpressure suite (svelte-check + tsc + vitest + cargo +
  shellcheck + bats 283/283) clean both at the initial release
  cut and again after the build-chain bumps (TS 6, vite 8,
  vite-plugin-svelte 7, tailwindcss 4.3, +eight smaller bumps).
  Maintainer smoke-tested the GUI on macOS at multiple points — no
  regressions on the static-adapter build path through SvelteKit
  2.60.1, vite 8.0.14, or vite-plugin-svelte 7.1.2.

## [0.4.0] — 2026-05-14

> **Highlights:** GUI localization to German, French, and Spanish (English
> remains the canonical source) and webview-level zoom. Phase 9 of the PRD
> ships here. Shell wizard terminal output stays English by design.

### Added — Localization (S41 + S42 + S43)

- `gui/src/lib/i18n/` module providing a typed `t()` translation function
  with three-tier fallback (current locale → English → raw key) and
  `{var}` interpolation. JSON catalogs at `gui/src/lib/i18n/<locale>.json`,
  167 keys each, dotted namespaces (`welcome.*`, `inference.*`,
  `status.*`, etc.).
- Full catalogs for English (canonical), German, French, and Spanish.
  Brand terms (`F13`, `Ollama`, `Docker`, `docker compose`,
  `ollama serve`, `ollama pull`, `mock`) intentionally left untranslated.
  Key parity across all four catalogs is enforced by a vitest fixture.
- `LocalePicker.svelte` rendered on the welcome screen footer only — a
  four-button row (EN / DE / FR / ES). Selection persists to
  `localStorage` under `f13.configurator.locale` (with a one-shot
  migration from the pre-v0.4.0 `f13_locale` key). The picker is
  deliberately **not** present in Settings or anywhere mid-flow; users
  pick once on first run.
- All hardcoded strings in route pages (`welcome`, `preflight`,
  `inference`, `inference/ollama`, `ports`, `run`, `status`, `settings`)
  replaced with `t()` calls.

### Added — Zoom (S44)

- `gui/src/lib/zoom.ts` writable store with clamp (0.6×–2.0×, 0.1 step)
  and localStorage persistence under `f13.configurator.zoom`.
- Keyboard shortcuts registered at the layout level: `Ctrl/Cmd + +/=`
  zooms in, `Ctrl/Cmd + −` zooms out, `Ctrl/Cmd + 0` resets to 100%.
- Compact `−` / `100%` / `+` stepper in Settings → Appearance.
- Implementation uses the CSS `zoom` property on `document.documentElement`
  (not per-platform Tauri webview APIs). Works identically across
  WKWebView / WebView2 / WebKitGTK with no Rust code; trade-off
  documented in the S44 commit body.

### Tests

- 21 new vitest tests for the i18n module covering `t()` fallbacks,
  `{var}` interpolation, `setLocale`/`getLocale` persistence, and the
  pre-v0.4.0 → v0.4.0 localStorage key migration.
- 4 new vitest tests for catalog key parity (every English key exists
  in de/fr/es; no extras).
- 7 new vitest tests for `LocalePicker` (rendering, ARIA, click → persist
  + reload, click-active → no reload, group-role label).
- 27 new vitest tests for the zoom store and keyboard handler.
- 1 absence test on the Settings page confirming the locale picker is
  **not** rendered there (welcome-only rule).
- vitest total: **378/378 green** (up from 299 in v0.3.2).

## [0.3.2] — 2026-05-14

> **Highlights:** Two backlog hand-fixes — Cancel actually stops the
> wizard, and a missing locally-built frontend image surfaces a clear
> precondition error instead of a confusing `pull access denied`.
> Tauri bumped 2.10.3 → 2.11.1 via Dependabot.

### Fixed — HF2: Cancel button kills the wizard subprocess

- `ProcessRunner.run` gains an optional `signal: AbortSignal` parameter.
  `tauriRunner` stores the spawned Tauri `Child` and listens for the
  abort event; on abort it calls `child.kill()`.
- `engine.runWizardNonInteractive` forwards the signal to `runner.run`.
- `/wizard/run/+page.svelte` creates an `AbortController` per pipeline
  run; `handleCancel()` calls `controller.abort()` before tearing down
  state, so the kill fires before the cancel-button-navigates-away
  path begins.
- Killing the bash leader does NOT kill its `docker compose up`
  grandchild (reparented to PID 1). `handleCancel` therefore tears
  down twice with a 1.5 s gap so the second pass catches containers
  the orphaned `compose up` might have brought up during the first.
  The proper kernel-level fix (kill the process group, not just the
  leader) needs a Rust-side change to tauri-plugin-shell and is
  deferred.

### Fixed — HF3: clear "frontend image missing" error instead of pull-access-denied

- `templates/docker-compose.yml.tmpl`: pinned `pull_policy: never` on
  the frontend service. The image is built locally by this configurator
  and never pushed to any registry, so a registry pull is always wrong
  for it.
- `lib/compose.sh`: precondition check in `compose::up` runs
  `docker image inspect ${FRONTEND_IMAGE}` (via a testable
  `compose::_docker_image_inspect` helper) before invoking
  `docker compose up`. On miss, returns 1 with a clear "frontend image
  is missing locally — re-run the wizard so it can rebuild" message.
  `FRONTEND_IMAGE` is read straight from the rendered `.env` so the
  check works for any wizard-driven invocation.
- `bin/f13-config` `--compose-up` handler propagates the specific
  failure reason into the `done` event message via
  `COMPOSE_ERROR_MESSAGE`, so the GUI's error toast surfaces the
  friendly text instead of a generic "compose up failed".

### Changed — Dependencies

- `tauri` 2.10.3 → 2.11.1 (Dependabot #2). Cargo.lock only; no API
  changes required in our Rust glue. Backpressure (`cargo check`,
  full GUI test suite) green against the new version.

### Tests

- 4 new bats assertions covering the HF3 precondition (errors when
  image missing, proceeds when present, skips precondition when
  `FRONTEND_IMAGE` not in `.env`, sets `COMPOSE_ERROR_MESSAGE`).
- 1 new bats assertion: rendered `docker-compose.yml` pins
  `pull_policy: never`.
- 3 new vitest assertions covering HF2 (AbortSignal plumbed through
  to the runner, Cancel aborts the signal handed to the engine,
  Cancel tears down twice for the orphan-up race).
- Existing `calls runWizardNonInteractive with the provided backend`
  updated for the new two-arg signature.

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
