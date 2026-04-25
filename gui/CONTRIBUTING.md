# GUI Contributing Guide

## Stack

Tauri 2.x · Svelte 5 · SvelteKit · Vite · Tailwind CSS 4 · TypeScript strict · Vitest · Biome

## macOS Setup (validated target for Phase 7)

```bash
# 1. Install Xcode Command Line Tools
xcode-select --install

# 2. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 3. Install Node deps
npm install

# 4. Run headless checks
npm run check && npm run test:unit && cargo check

# 5. Run the app (maintainer only — do NOT run inside the Ralph loop)
npm run tauri dev
```

No extra Homebrew packages are required. Tauri uses the system WebKit framework on macOS.

## Linux Setup (compile-check path only, Phase 7)

Linux GUI *runtime* is deferred to Phase 8. The Ralph loop only exercises
`cargo check` on Linux (aarch64/x86_64), not `tauri dev` or `tauri build`.

### Apt dependencies (require root):

```bash
sudo apt-get install -y \
  libwebkit2gtk-4.1-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  libssl-dev \
  build-essential \
  librsvg2-dev \
  patchelf \
  libsoup-3.0-dev \
  libjavascriptcoregtk-4.1-dev
```

### Rust:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain stable -y
```

> **Note for the Ralph loop Docker image:** these packages are installed automatically
> via the `ralph.sh` bootstrap before running `cargo check`. See `ralph.sh` for details.

## Headless backpressure (CI and Ralph loop)

```bash
cd gui && npm run check && npm run test:unit && cargo check
```

All three must pass before committing. Never run `npm run tauri dev` or
`tauri build` inside the loop — those commands require a display.

## Coverage target

≥ 75% on new/modified TS and Svelte files.

## Commit convention

Same as the shell scripts — F13 standard:
```
<TYPE> [gui]: <description>   (max 72 chars)

Co-Authored-By: Claude Code
```
