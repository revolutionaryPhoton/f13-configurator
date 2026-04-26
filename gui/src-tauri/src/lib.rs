use std::path::PathBuf;
use tauri::Manager;

// Are we running from a `cargo`/`tauri dev` build? Detected by looking
// for `target/debug` or `target/release` in the running executable's
// path. Bundled .app / .AppImage / .deb installs don't have either.
//
// We need this distinction because Tauri 2's `resource_dir()` returns
// `<project>/src-tauri/target/debug/` in dev mode — and ALSO copies/
// symlinks declared resources (bin/, lib/, templates/) into that dir
// for runtime resolution. So sentinel-file checks like
// `resource_dir/bin exists?` look indistinguishable between dev and
// bundled. The only reliable signal is the exe path itself.
fn is_dev_build() -> bool {
    let Ok(exe) = std::env::current_exe() else {
        return false;
    };
    exe.components().any(|c| {
        let s = c.as_os_str();
        s == "debug" || s == "release"
    }) && exe.components().any(|c| c.as_os_str() == "target")
}

// Walks up from the running executable to the configurator_v1/ workspace
// root. Only meaningful when is_dev_build() is true.
//
// The exe path looks like:
//   /…/configurator_v1/gui/src-tauri/target/debug/f13-configurator-gui
// So we need to walk up FIVE parents (exe -> debug -> target -> src-tauri
// -> gui -> configurator_v1). A previous version of this function used
// four — that was an off-by-one and landed at gui/, which made
// dev_workspace_root().join("bin") return gui/bin (not configurator_v1/bin).
//
// NOTE: this helper assumes the dev checkout layout and won't work for
// bundled installs. Phase 9 (signed distributables) replaces the bundled
// branch with appLocalDataDir() — see PRD Phase 9.
fn dev_workspace_root() -> Result<PathBuf, String> {
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let mut p = exe.clone();
    for _ in 0..5 {
        p = p
            .parent()
            .ok_or_else(|| format!("could not derive workspace from {}", exe.display()))?
            .to_path_buf();
    }
    Ok(p)
}

// Returns the absolute path to the configurator's `bin/` directory.
// Dev mode: <configurator_v1>/bin
// Bundled mode: <resource_dir>/bin
#[tauri::command]
fn get_bin_dir(app: tauri::AppHandle) -> Result<String, String> {
    if is_dev_build() {
        let candidate = dev_workspace_root()?.join("bin");
        if candidate.exists() {
            return Ok(candidate.to_string_lossy().into_owned());
        }
        return Err(format!(
            "dev mode: bin/ not found at {}",
            candidate.display()
        ));
    }

    if let Ok(resource_dir) = app.path().resource_dir() {
        let bundled = resource_dir.join("bin");
        if bundled.exists() {
            return Ok(bundled.to_string_lossy().into_owned());
        }
    }
    Err("bundled mode: could not locate bin/ in resource_dir".to_string())
}

// Returns the absolute path to the configurator's `generated/` directory —
// where the wizard writes docker-compose.yml, .env, secrets/, configs/.
//
// Mirrors the shell wizard's default GEN_DIR ($SCRIPT_DIR/../generated)
// so a stack started from the GUI can be torn down with `./bin/f13-stop`
// from a terminal without env-var overrides.
//
// Bundled mode: <resource_dir>/../generated  (sibling of bundled bin/)
// Dev mode:    <configurator_v1>/generated
//
// The directory is NOT created here — the wizard creates it on first
// render. Only the path is computed.
#[tauri::command]
fn get_generated_dir(app: tauri::AppHandle) -> Result<String, String> {
    // Dev: <configurator_v1>/generated (mirrors the shell wizard's
    // default GEN_DIR so `./bin/f13-stop` from a terminal Just Works).
    if is_dev_build() {
        return Ok(dev_workspace_root()?
            .join("generated")
            .to_string_lossy()
            .into_owned());
    }

    // Bundled: GEN_DIR is sibling to the shipped bin/, lib/, templates/.
    if let Ok(resource_dir) = app.path().resource_dir() {
        if let Some(parent) = resource_dir.parent() {
            return Ok(parent.join("generated").to_string_lossy().into_owned());
        }
    }
    Err("bundled mode: could not derive generated/ from resource_dir".to_string())
}

// Quiet GPU-related warnings on Linux setups without an accessible
// GPU device node. On WSL2 + Ubuntu, /dev/dri/* are owned root:root
// 0600 (the real GPU bridge goes through /dev/dxg), so libEGL spams
// `failed to open /dev/dri/* — Permission denied` on stderr while
// Mesa silently falls back to software rendering anyway. We force
// the software path explicitly:
//
//   * LIBGL_ALWAYS_SOFTWARE=1     — Mesa picks llvmpipe; no /dev/dri
//                                    probe, no libEGL warning.
//   * WEBKIT_DISABLE_DMABUF_RENDERER=1
//                                  — Skip WebKit's DMA-BUF compositor
//                                    path (which also pokes at GBM).
//   * WEBKIT_DISABLE_COMPOSITING_MODE=1
//                                  — Final hammer: disable WebKit's
//                                    accelerated compositor entirely.
//
// Each is only set when the user hasn't set it themselves, so
// someone on a Linux box with real DRI access can opt out by
// exporting "0" before launching.
//
// Safe no-op on macOS — none of the variables are read there.
#[cfg(target_os = "linux")]
fn apply_linux_runtime_defaults() {
    let defaults = [
        ("LIBGL_ALWAYS_SOFTWARE", "1"),
        ("WEBKIT_DISABLE_DMABUF_RENDERER", "1"),
        ("WEBKIT_DISABLE_COMPOSITING_MODE", "1"),
    ];
    for (key, value) in defaults {
        if std::env::var_os(key).is_none() {
            // SAFETY: called once at startup before any threads spawn.
            unsafe {
                std::env::set_var(key, value);
            }
        }
    }
}

#[cfg(not(target_os = "linux"))]
fn apply_linux_runtime_defaults() {}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    apply_linux_runtime_defaults();

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![get_bin_dir, get_generated_dir])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
