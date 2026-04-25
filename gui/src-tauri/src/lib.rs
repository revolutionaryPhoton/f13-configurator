use tauri::Manager;

// Returns the absolute path to the configurator's `bin/` directory.
// In bundled mode: <resource-dir>/bin
// In dev mode: walks up from the running binary in target/debug to
//              configurator_v1/bin (the workspace root sibling of gui/).
#[tauri::command]
fn get_bin_dir(app: tauri::AppHandle) -> Result<String, String> {
    // Bundled / packaged path first.
    if let Ok(resource_dir) = app.path().resource_dir() {
        let bundled = resource_dir.join("bin");
        if bundled.exists() {
            return Ok(bundled.to_string_lossy().into_owned());
        }
    }

    // Dev fallback: derive from the running executable.
    // tauri dev runs target/debug/<binary>, so up four levels lands at the
    // configurator_v1/ workspace root (target/debug -> target -> src-tauri ->
    // gui -> configurator_v1).
    let exe = std::env::current_exe().map_err(|e| e.to_string())?;
    let mut p = exe.clone();
    for _ in 0..4 {
        p = p
            .parent()
            .ok_or_else(|| format!("could not derive workspace from {}", exe.display()))?
            .to_path_buf();
    }
    let candidate = p.join("bin");
    if candidate.exists() {
        return Ok(candidate.to_string_lossy().into_owned());
    }
    Err(format!(
        "could not locate configurator bin/ (tried bundled resource_dir/bin and dev fallback {})",
        candidate.display()
    ))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![get_bin_dir])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
