# GUI Contributing Guide

## Stack

Tauri 2.x · Svelte 5 · SvelteKit · Vite · Tailwind CSS 4 · TypeScript strict · Vitest · Biome

## macOS Setup

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

## Linux Setup

Linux GUI runtime parity shipped in v0.3.0 (WSL2 Ubuntu 22.04 validated
end-to-end). The Ralph loop only exercises `cargo check` on Linux
(aarch64/x86_64), not `tauri dev` or `tauri build` — those need a real
display.

### WSL2 / headless-Linux runtime quirks

Three things macOS gives you for free that have to be installed
explicitly on WSL2 + Ubuntu:

#### 1. Color-emoji font

The inference picker (and a couple of other screens) renders
emoji glyphs (🧪 🦙 ✓ ⚠️ ⓘ). macOS ships Apple Color Emoji
system-wide; Ubuntu / WSL2 ships none by default — emoji codepoints
fall back to a missing-glyph box. Install:

```bash
sudo apt install -y fonts-noto-color-emoji
fc-cache -fv
```

After installing, restart the app — fontconfig caches the new font.

#### 2. `xdg-open` shim for the Windows browser

The Status screen's "Open F13 in browser" button calls
`tauri-plugin-opener::openUrl()`, which on Linux calls `xdg-open`.
WSL2 has no graphical browser registered by default, so `xdg-open`
silently fails. The fix is `wslu`, which provides `wslview` and
wires `xdg-open` through to the Windows-side default browser:

```bash
sudo apt install -y wslu
```

No restart required — the next click on "Open F13 in browser" will
open your Windows browser at `http://localhost:9999`.

#### 3. libEGL noise + GPU probe failures

WebKit2GTK and Mesa probe `/dev/dri/card0` / `/dev/dri/renderD128`
on startup. On WSL2 + Ubuntu these nodes are owned `root:root` mode
`0600` and the real GPU bridge goes through `/dev/dxg`, so the
probes log noisy `libEGL warning: failed to open … Permission denied`
lines on stderr while Mesa silently falls back to software
rendering anyway. The runtime forces the software path explicitly
on Linux via `apply_linux_runtime_defaults()` in
`src-tauri/src/lib.rs` — it sets `LIBGL_ALWAYS_SOFTWARE=1`,
`WEBKIT_DISABLE_DMABUF_RENDERER=1`, and
`WEBKIT_DISABLE_COMPOSITING_MODE=1` when the user hasn't already
set them. To opt back in on a Linux box with real DRI access,
export each var as `0` before launching.

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
