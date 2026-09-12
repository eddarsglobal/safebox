#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 3B patch
# Adds .sbx file association + opening document.sbx by double-click/open-with.

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Patching src-tauri/Cargo.toml"
python3 - <<'PY2'
from pathlib import Path
p = Path('src-tauri/Cargo.toml')
text = p.read_text()
def add_dep(text: str, dep_line: str) -> str:
    dep_name = dep_line.split('=')[0].strip()
    if dep_name in text:
        return text
    marker = 'tauri = { version = "2", features = [] }\n'
    if marker in text:
        return text.replace(marker, marker + dep_line + '\n')
    return text.rstrip() + '\n' + dep_line + '\n'
text = add_dep(text, 'tauri-plugin-dialog = "2"')
text = add_dep(text, 'tauri-plugin-single-instance = "2"')
p.write_text(text)
PY2

echo "==> Patching tauri.conf.json for .sbx association"
python3 - <<'PY2'
import json
from pathlib import Path
p = Path('src-tauri/tauri.conf.json')
data = json.loads(p.read_text())
bundle = data.setdefault('bundle', {})
bundle['active'] = True
bundle['targets'] = bundle.get('targets', 'all')
bundle['category'] = bundle.get('category', 'Utility')
bundle['icon'] = [
    'icons/32x32.png',
    'icons/128x128.png',
    'icons/128x128@2x.png',
    'icons/icon.png'
]
bundle['fileAssociations'] = [
    {
        'ext': ['sbx'],
        'name': 'SafeBox File',
        'description': 'SafeBox secure capsule',
        'mimeType': 'application/vnd.safebox.sbx',
        'role': 'Viewer',
        'rank': 'Owner',
        'exportedType': {
            'identifier': 'com.safebox.sbx',
            'conformsTo': ['public.data']
        }
    }
]
app = data.setdefault('app', {})
windows = app.setdefault('windows', [])
if windows:
    windows[0]['label'] = 'main'
p.write_text(json.dumps(data, indent=2) + '\n')
PY2

echo "==> Rewriting src-tauri/src/lib.rs with .sbx open handler"
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
    value
        .trim()
        .trim_matches('"')
        .trim_start_matches("file://")
        .to_string()
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

fn store_initial_sbx(app: &tauri::App, sbx_path: String) {
    let state = app.state::<OpenFileState>();
    if let Ok(mut slot) = state.initial_sbx_path.lock() {
        *slot = Some(sbx_path);
    }
}

fn emit_sbx_open(app: &tauri::AppHandle, sbx_path: String) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.set_focus();
        let _ = window.emit("sbx-open-file", sbx_path);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default().manage(OpenFileState::default());

    #[cfg(desktop)]
    {
        // Must be the first registered plugin.
        builder = builder.plugin(tauri_plugin_single_instance::init(|app, args, cwd| {
            let cwd_path = PathBuf::from(cwd);
            if let Some(sbx_path) = find_sbx_arg(args, Some(&cwd_path)) {
                emit_sbx_open(app, sbx_path);
            } else if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }));
    }

    builder
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let cwd = std::env::current_dir().ok();
            if let Some(sbx_path) = find_sbx_arg(std::env::args(), cwd.as_deref()) {
                store_initial_sbx(app, sbx_path);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path
        ])
        .run(tauri::generate_context!())
        .expect("error while running SafeBox desktop app");
}
RS

echo "==> Patching frontend to react to .sbx opened by OS"
python3 - <<'PY2'
from pathlib import Path
p = Path('src/main.ts')
text = p.read_text()
if 'SbxOpenPayload' not in text:
    marker = 'type TauriDropPayload = {\n  paths?: string[];\n  position?: { x: number; y: number };\n};\n'
    if marker in text:
        text = text.replace(marker, marker + '\ntype SbxOpenPayload = string;\n')
    else:
        text = text.replace('const app = document.querySelector<HTMLDivElement>("#app");', 'type SbxOpenPayload = string;\n\nconst app = document.querySelector<HTMLDivElement>("#app");')
if 'openSbxFromSystem' not in text:
    block = r'''
function openSbxFromSystem(path: string) {
  const cleaned = (path || "").trim();

  if (!cleaned.toLowerCase().endsWith(".sbx")) {
    return;
  }

  setTab("unlock");
  setInput("#unlockInput", cleaned);
  showResult("ok", `
    <strong>SafeBox file received.</strong><br/>
    Enter the code to unlock:<br/>
    <code>${esc(cleaned)}</code>
  `);

  setTimeout(() => {
    $<HTMLInputElement>("#unlockCode").focus();
  }, 80);
}

async function setupSystemOpenHandler() {
  await listen<SbxOpenPayload>("sbx-open-file", event => {
    openSbxFromSystem(event.payload);
  });

  const initial = await invoke<string | null>("get_initial_sbx_path");
  if (initial) {
    openSbxFromSystem(initial);
  }
}

setupSystemOpenHandler().catch(error => {
  showResult("error", `<strong>System open handler failed.</strong><br/><code>${esc(String(error))}</code>`);
});
'''
    marker = 'setupNativeFileDrop().catch(error => {\n  showResult("error", `<strong>Drag/drop init failed.</strong><br/><code>${esc(String(error))}</code>`);\n});\n'
    if marker in text:
        text = text.replace(marker, marker + block + '\n')
    else:
        text += '\n' + block + '\n'
p.write_text(text)
PY2

echo "==> Sprint 3B patch applied."
echo ""
echo "Now run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm install"
echo "  npm run tauri dev"
echo ""
echo "Real macOS association test needs a built app:"
echo "  npm run tauri build"
echo "  open -a \"$ROOT/safebox-desktop/src-tauri/target/release/bundle/macos/SafeBox.app\" \"/full/path/to/document.sbx\""
