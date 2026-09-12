#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 3C patch
# Fixes macOS Finder "Open With SafeBox" and double-click:
# Finder does NOT pass the .sbx as --args.
# It sends a native file-open event, which Tauri exposes as RunEvent::Opened.

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup current lib.rs"
cp src-tauri/src/lib.rs "src-tauri/src/lib.rs.backup-sprint3c.$(date +%Y%m%d%H%M%S)"

echo "==> Rewriting src-tauri/src/lib.rs with RunEvent::Opened support"
cat > src-tauri/src/lib.rs <<'RS'
use safebox_core::{create_sbx, unlock_sbx, CreateOptions, UnlockOptions};
use serde::Serialize;
use std::{
    path::{Path, PathBuf},
    sync::Mutex,
};
use tauri::{Emitter, Manager, State};

#[derive(Default)]
struct OpenFileState {
    initial_sbx_path: Mutex<Option<String>>,
}

#[derive(Debug, Serialize)]
struct CreateUiReport {
    input_path: String,
    output_path: String,
    visible_sbx_name: String,
    encrypted_chunks: u64,
    mission: String,
}

#[derive(Debug, Serialize)]
struct UnlockUiReport {
    sbx_path: String,
    restored_path: String,
    original_file_name: String,
    original_size: u64,
    decrypted_chunks: u64,
    sbx_deleted: bool,
    mission: String,
}

#[tauri::command]
fn get_initial_sbx_path(state: State<'_, OpenFileState>) -> Option<String> {
    state.initial_sbx_path.lock().ok().and_then(|value| value.clone())
}

#[tauri::command]
fn create_sbx_file(
    input_path: String,
    code: String,
    visible_name: String,
    output_dir: Option<String>,
    keep_after_unlock: bool,
) -> Result<CreateUiReport, String> {
    let input = PathBuf::from(clean_path(&input_path));
    let visible_sbx_name = normalize_sbx_name(&visible_name);
    let output_path = resolve_create_output_path(&input, output_dir.as_deref(), &visible_sbx_name)?;

    let mut options = CreateOptions::new(input.clone(), output_path.clone(), code);
    options.burn_after_unlock = !keep_after_unlock;

    let report = create_sbx(options).map_err(|err| err.to_string())?;

    Ok(CreateUiReport {
        input_path: report.input_path.display().to_string(),
        output_path: report.output_path.display().to_string(),
        visible_sbx_name: report.visible_sbx_name,
        encrypted_chunks: report.encrypted_chunks,
        mission: "SBX capsule ready for sending".to_string(),
    })
}

#[tauri::command]
fn unlock_sbx_file(
    sbx_path: String,
    code: String,
    output_dir: Option<String>,
    keep_sbx: bool,
    overwrite: bool,
) -> Result<UnlockUiReport, String> {
    let sbx = PathBuf::from(clean_path(&sbx_path));
    let mut options = UnlockOptions::new(sbx.clone(), code);
    options.output_dir = output_dir
        .as_deref()
        .map(clean_path)
        .filter(|v| !v.trim().is_empty())
        .map(PathBuf::from);
    options.burn_after_unlock = !keep_sbx;
    options.overwrite = overwrite;

    let report = unlock_sbx(options).map_err(|err| err.to_string())?;

    Ok(UnlockUiReport {
        sbx_path: report.sbx_path.display().to_string(),
        restored_path: report.restored_path.display().to_string(),
        original_file_name: report.original_file_name,
        original_size: report.original_size,
        decrypted_chunks: report.decrypted_chunks,
        sbx_deleted: report.sbx_deleted,
        mission: if report.sbx_deleted {
            "SBX mission completed and local capsule removed".to_string()
        } else {
            "Original restored; SBX kept for testing".to_string()
        },
    })
}

fn clean_path(value: &str) -> String {
    let trimmed = value.trim().trim_matches('"');

    if let Some(rest) = trimmed.strip_prefix("file://") {
        return rest.replace("%20", " ");
    }

    trimmed.to_string()
}

fn resolve_create_output_path(
    input: &Path,
    output_dir: Option<&str>,
    visible_sbx_name: &str,
) -> Result<PathBuf, String> {
    let base_dir = output_dir
        .map(clean_path)
        .filter(|v| !v.trim().is_empty())
        .map(PathBuf::from)
        .or_else(|| input.parent().map(Path::to_path_buf))
        .unwrap_or_else(|| PathBuf::from("."));

    Ok(base_dir.join(visible_sbx_name))
}

fn normalize_sbx_name(input: &str) -> String {
    let trimmed = input.trim().trim_end_matches(".sbx");
    let cleaned: String = trimmed
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || *ch == '-' || *ch == '_' || *ch == ' ')
        .collect();

    let base = if cleaned.trim().is_empty() {
        "document".to_string()
    } else {
        cleaned.trim().to_string()
    };

    format!("{base}.sbx")
}

fn find_sbx_arg<I>(args: I, cwd: Option<&Path>) -> Option<String>
where
    I: IntoIterator<Item = String>,
{
    for raw in args {
        let cleaned = clean_path(&raw);
        if !cleaned.to_ascii_lowercase().ends_with(".sbx") {
            continue;
        }

        let path = PathBuf::from(&cleaned);
        let absolute = if path.is_absolute() {
            path
        } else if let Some(cwd) = cwd {
            cwd.join(path)
        } else {
            path
        };

        return Some(absolute.display().to_string());
    }

    None
}

fn find_sbx_url(urls: &[tauri::Url]) -> Option<String> {
    for url in urls {
        if url.scheme() != "file" {
            continue;
        }

        if let Ok(path) = url.to_file_path() {
            let path_string = path.display().to_string();

            if path_string.to_ascii_lowercase().ends_with(".sbx") {
                return Some(path_string);
            }
        }
    }

    None
}

fn set_initial_sbx_state(app: &tauri::AppHandle, sbx_path: String) {
    let state = app.state::<OpenFileState>();
    let mut slot = state
        .initial_sbx_path
        .lock()
        .expect("SafeBox initial SBX state lock failed");

    *slot = Some(sbx_path);
}

fn set_initial_sbx_state_from_app(app: &tauri::App, sbx_path: String) {
    let state = app.state::<OpenFileState>();
    let mut slot = state
        .initial_sbx_path
        .lock()
        .expect("SafeBox initial SBX state lock failed");

    *slot = Some(sbx_path);
}

fn focus_main_window(app: &tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

fn emit_sbx_open(app: &tauri::AppHandle, sbx_path: String) {
    set_initial_sbx_state(app, sbx_path.clone());
    focus_main_window(app);

    if let Some(window) = app.get_webview_window("main") {
        let _ = window.emit("sbx-open-file", sbx_path);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default().manage(OpenFileState::default());

    #[cfg(desktop)]
    {
        builder = builder.plugin(tauri_plugin_single_instance::init(|app, args, cwd| {
            let cwd_path = PathBuf::from(cwd);

            if let Some(sbx_path) = find_sbx_arg(args, Some(&cwd_path)) {
                emit_sbx_open(app, sbx_path);
            } else {
                focus_main_window(app);
            }
        }));
    }

    let app = builder
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let cwd = std::env::current_dir().ok();
            if let Some(sbx_path) = find_sbx_arg(std::env::args(), cwd.as_deref()) {
                set_initial_sbx_state_from_app(app, sbx_path);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path
        ])
        .build(tauri::generate_context!())
        .expect("error while building SafeBox desktop app");

    app.run(|app_handle, event| {
        #[cfg(any(target_os = "macos", target_os = "ios", target_os = "android"))]
        if let tauri::RunEvent::Opened { urls } = event {
            if let Some(sbx_path) = find_sbx_url(&urls) {
                emit_sbx_open(app_handle, sbx_path);
            }
        }
    });
}
RS

echo "==> Verifying frontend handler exists"
if ! grep -R "sbx-open-file" -n src/main.ts >/dev/null 2>&1; then
  echo "ERROR: src/main.ts does not listen to sbx-open-file."
  echo "Apply Sprint 3B first, then re-run this patch."
  exit 1
fi

echo "==> Sprint 3C patch applied."
echo ""
echo "Now run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri build"
echo ""
echo "Then install:"
echo "  cp -R \"$ROOT/target/release/bundle/macos/SafeBox.app\" /Applications/"
