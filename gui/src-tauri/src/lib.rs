use std::path::PathBuf;
use tauri::Manager;

// Walks up from the running executable to the configurator_v1/ workspace
// root (target/debug -> target -> src-tauri -> gui -> configurator_v1).
// Used as the dev-mode fallback when bundled resource_dir is unavailable
// or doesn't contain the resource we're looking for.
fn dev_workspace_root() -> Result<PathBuf, String> {
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let mut p = exe.clone();
    for _ in 0..4 {
        p = p
            .parent()
            .ok_or_else(|| format!("could not derive workspace from {}", exe.display()))?
            .to_path_buf();
    }
    Ok(p)
}

// Returns the absolute path to the configurator's `bin/` directory.
// Bundled mode: <resource_dir>/bin
// Dev mode: <configurator_v1>/bin
#[tauri::command]
fn get_bin_dir(app: tauri::AppHandle) -> Result<String, String> {
    if let Ok(resource_dir) = app.path().resource_dir() {
        let bundled = resource_dir.join("bin");
        if bundled.exists() {
            return Ok(bundled.to_string_lossy().into_owned());
        }
    }

    let candidate = dev_workspace_root()?.join("bin");
    if candidate.exists() {
        return Ok(candidate.to_string_lossy().into_owned());
    }
    Err(format!(
        "could not locate configurator bin/ (tried bundled resource_dir/bin and dev fallback {})",
        candidate.display()
    ))
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
    if let Ok(resource_dir) = app.path().resource_dir() {
        // The wizard's GEN_DIR is sibling to bin/, lib/, templates/.
        if let Some(parent) = resource_dir.parent() {
            let bundled = parent.join("generated");
            // The dir may not exist yet (first run) — return the path
            // unconditionally as long as the parent path exists.
            if parent.exists() {
                return Ok(bundled.to_string_lossy().into_owned());
            }
        }
    }

    Ok(dev_workspace_root()?
        .join("generated")
        .to_string_lossy()
        .into_owned())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![get_bin_dir, get_generated_dir])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
