#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 5C
# Adds after unlock:
# - Open original
# - Show in Finder
#
# Works in:
# - normal Unlock mode
# - mini receiver overlay

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup files"
cp src/main.ts "src/main.ts.backup-sprint5c.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint5c.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
cp src-tauri/src/lib.rs "src-tauri/src/lib.rs.backup-sprint5c.$(date +%Y%m%d%H%M%S)"

echo "==> Patch Rust commands: open original + reveal in file manager"
python3 - <<'PY'
from pathlib import Path

p = Path("src-tauri/src/lib.rs")
text = p.read_text()

commands = r'''
#[tauri::command]
fn open_original_file(path: String) -> Result<(), String> {
    let file_path = PathBuf::from(clean_path(&path));

    if !file_path.exists() {
        return Err(format!("File not found: {}", file_path.display()));
    }

    #[cfg(target_os = "macos")]
    {
        run_system_command("open", &[file_path.display().to_string()])
    }

    #[cfg(target_os = "windows")]
    {
        run_system_command(
            "cmd",
            &[
                "/C".to_string(),
                "start".to_string(),
                "".to_string(),
                file_path.display().to_string(),
            ],
        )
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        run_system_command("xdg-open", &[file_path.display().to_string()])
    }
}

#[tauri::command]
fn reveal_in_file_manager(path: String) -> Result<(), String> {
    let file_path = PathBuf::from(clean_path(&path));

    if !file_path.exists() {
        return Err(format!("File not found: {}", file_path.display()));
    }

    #[cfg(target_os = "macos")]
    {
        run_system_command("open", &["-R".to_string(), file_path.display().to_string()])
    }

    #[cfg(target_os = "windows")]
    {
        run_system_command("explorer", &[format!("/select,{}", file_path.display())])
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let dir = file_path
            .parent()
            .map(Path::to_path_buf)
            .unwrap_or_else(|| PathBuf::from("."));

        run_system_command("xdg-open", &[dir.display().to_string()])
    }
}

fn run_system_command(program: &str, args: &[String]) -> Result<(), String> {
    let status = std::process::Command::new(program)
        .args(args)
        .status()
        .map_err(|err| format!("Failed to run {program}: {err}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("{program} exited with status: {status}"))
    }
}

'''

if "fn open_original_file(" not in text:
    marker = "#[tauri::command]\nfn get_initial_sbx_path"
    if marker not in text:
        raise SystemExit("Could not find command insertion marker")
    text = text.replace(marker, commands + "\n" + marker)

handler_old = '''        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path
        ])'''
handler_mid = '''        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path,
            open_original_file,
            reveal_in_file_manager
        ])'''
handler_existing_3c = '''        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path
        ])'''

if handler_old in text:
    text = text.replace(handler_old, handler_mid)
elif handler_existing_3c in text:
    text = text.replace(handler_existing_3c, handler_mid)
elif "open_original_file" not in text.split("tauri::generate_handler!", 1)[1]:
    text = text.replace("get_initial_sbx_path\n        ])", "get_initial_sbx_path,\n            open_original_file,\n            reveal_in_file_manager\n        ])")

p.write_text(text)
print("Rust open/reveal commands patched")
PY

echo "==> Patch frontend actions"
python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

helpers = r'''
function restoredActionsHtml(path: string): string {
  return `
    <div class="restore-actions" data-restored-path="${esc(path)}">
      <button type="button" data-restore-action="open">Open original</button>
      <button type="button" data-restore-action="show">Show in Finder</button>
    </div>
  `;
}

async function openOriginalPath(path: string) {
  if (!path) return;

  try {
    await invoke("open_original_file", { path });
  } catch (error) {
    showResult("error", `<strong>Open failed.</strong><br/><code>${esc(String(error))}</code>`);
  }
}

async function revealOriginalPath(path: string) {
  if (!path) return;

  try {
    await invoke("reveal_in_file_manager", { path });
  } catch (error) {
    showResult("error", `<strong>Show in Finder failed.</strong><br/><code>${esc(String(error))}</code>`);
  }
}

document.addEventListener("click", event => {
  const target = event.target as HTMLElement | null;
  const button = target?.closest<HTMLButtonElement>("[data-restore-action]");
  if (!button) return;

  const wrapper = button.closest<HTMLElement>(".restore-actions");
  const path = wrapper?.dataset.restoredPath || "";
  const action = button.dataset.restoreAction;

  if (action === "open") {
    openOriginalPath(path);
  } else if (action === "show") {
    revealOriginalPath(path);
  }
});

'''

if "function restoredActionsHtml" not in text:
    marker = 'function showHardReceiverOverlay(sbxPath: string) {'
    if marker not in text:
        raise SystemExit("Could not find showHardReceiverOverlay marker")
    text = text.replace(marker, helpers + "\n" + marker)

# Hard overlay result block
old_hard = '''        <div class="result-grid compact">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Saved</span><code>${esc(report.restored_path)}</code>
        </div>
      `);'''
new_hard = '''        <div class="result-grid compact">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Saved</span><code>${esc(report.restored_path)}</code>
        </div>
        ${restoredActionsHtml(report.restored_path)}
      `);'''

if old_hard in text and "${restoredActionsHtml(report.restored_path)}" not in text[text.find(old_hard)-200:text.find(old_hard)+len(old_hard)+200]:
    text = text.replace(old_hard, new_hard, 1)

# Normal result block
old_normal = '''      <div class="result-grid">
        <span>Original</span><code>${esc(report.original_file_name)}</code>
        <span>Saved</span><code>${esc(report.restored_path)}</code>
        <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
      </div>
    `);'''
new_normal = '''      <div class="result-grid">
        <span>Original</span><code>${esc(report.original_file_name)}</code>
        <span>Saved</span><code>${esc(report.restored_path)}</code>
        <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
      </div>
      ${restoredActionsHtml(report.restored_path)}
    `);'''

if old_normal in text:
    text = text.replace(old_normal, new_normal, 1)
elif "BOOOOM. Original restored." in text and "restoredActionsHtml(report.restored_path)" not in text:
    raise SystemExit("Normal unlock block changed; please send the unlockNow success block.")

p.write_text(text)
print("Frontend open/show actions patched")
PY

echo "==> Append CSS"
cat >> src/style.css <<'CSS'

/* Sprint 5C — Open original + Show in Finder */
.restore-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-top: 16px;
}

.restore-actions button {
  min-height: 46px;
  border: 1px solid var(--border);
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.07);
  color: var(--text);
  font-weight: 950;
  cursor: pointer;
}

.restore-actions button:hover {
  border-color: rgba(56, 189, 248, 0.55);
  background: rgba(56, 189, 248, 0.12);
}

.hard-receiver-card .restore-actions button {
  border-color: rgba(167, 232, 255, 0.18);
  color: #F8FBFF;
}

@media (max-width: 520px) {
  .restore-actions {
    grid-template-columns: 1fr;
  }
}
CSS

echo "==> Sprint 5C patch applied."
echo ""
echo "Run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri dev"
echo ""
echo "Then test:"
echo "  Unlock an SBX file"
echo "  Click Open original"
echo "  Click Show in Finder"
