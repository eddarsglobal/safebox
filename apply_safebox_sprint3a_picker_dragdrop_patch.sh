#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 3A patch
# Adds:
# - native file picker buttons
# - native Tauri drag/drop handling
# - dialog plugin setup
# - dialog permissions
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint3a_picker_dragdrop_patch.sh

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Patching package.json"
python3 - <<'PY'
import json
from pathlib import Path

p = Path("package.json")
data = json.loads(p.read_text())

deps = data.setdefault("dependencies", {})
deps["@tauri-apps/api"] = deps.get("@tauri-apps/api", "2")
deps["@tauri-apps/plugin-dialog"] = deps.get("@tauri-apps/plugin-dialog", "2")

dev = data.setdefault("devDependencies", {})
dev["@tauri-apps/cli"] = dev.get("@tauri-apps/cli", "2")
dev["typescript"] = dev.get("typescript", "latest")
dev["vite"] = dev.get("vite", "latest")

p.write_text(json.dumps(data, indent=2) + "\n")
PY

echo "==> Patching Rust Cargo.toml"
python3 - <<'PY'
from pathlib import Path

p = Path("src-tauri/Cargo.toml")
text = p.read_text()

if "tauri-plugin-dialog" not in text:
    marker = 'tauri = { version = "2", features = [] }\n'
    if marker in text:
        text = text.replace(marker, marker + 'tauri-plugin-dialog = "2"\n')
    else:
        text += '\ntauri-plugin-dialog = "2"\n'

p.write_text(text)
PY

echo "==> Patching src-tauri/src/lib.rs"
python3 - <<'PY'
from pathlib import Path

p = Path("src-tauri/src/lib.rs")
text = p.read_text()

if ".plugin(tauri_plugin_dialog::init())" not in text:
    text = text.replace(
        "tauri::Builder::default()\n        .invoke_handler",
        "tauri::Builder::default()\n        .plugin(tauri_plugin_dialog::init())\n        .invoke_handler"
    )

p.write_text(text)
PY

echo "==> Adding dialog permissions"
mkdir -p src-tauri/capabilities
cat > src-tauri/capabilities/default.json <<'JSON'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "SafeBox default desktop permissions",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "dialog:default"
  ]
}
JSON

echo "==> Writing improved frontend main.ts"
cat > src/main.ts <<'TS'
import { invoke } from "@tauri-apps/api/core";
import { listen, TauriEvent } from "@tauri-apps/api/event";
import { open } from "@tauri-apps/plugin-dialog";
import "./style.css";

type CreateReport = {
  input_path: string;
  output_path: string;
  visible_sbx_name: string;
  encrypted_chunks: number;
  mission: string;
};

type UnlockReport = {
  sbx_path: string;
  restored_path: string;
  original_file_name: string;
  original_size: number;
  decrypted_chunks: number;
  sbx_deleted: boolean;
  mission: string;
};

type TauriDropPayload = {
  paths?: string[];
  position?: { x: number; y: number };
};

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("#app not found");

app.innerHTML = `
  <main class="shell">
    <section class="hero-card">
      <div class="topbar">
        <div class="brand">
          <img src="/safebox-logo.png" alt="SafeBox" class="logo" />
          <div>
            <h1>SafeBox</h1>
            <p>Universal secure file format</p>
          </div>
        </div>
        <button id="themeToggle" class="ghost-btn" type="button">Dark</button>
      </div>

      <div class="mission-line">
        <span>Any file</span>
        <strong>→</strong>
        <span>document.sbx</span>
        <strong>→</strong>
        <span>code</span>
        <strong>→</strong>
        <span>original file</span>
      </div>

      <div class="tabs" role="tablist">
        <button id="createTab" class="tab active" type="button">Create SBX</button>
        <button id="unlockTab" class="tab" type="button">Unlock SBX</button>
      </div>

      <section id="createPanel" class="panel active-panel">
        <label>
          Original file
          <div class="field-action">
            <input id="createInput" placeholder="/Users/noury/Desktop/test.png" autocomplete="off" />
            <button id="chooseOriginalBtn" class="mini-btn" type="button">Choose</button>
          </div>
        </label>

        <div id="createDrop" class="dropzone">
          Drop any original file here. SafeBox will create document.sbx.
        </div>

        <div class="grid-2">
          <label>
            Visible SBX name
            <input id="visibleName" value="document" autocomplete="off" />
          </label>
          <label>
            Code
            <input id="createCode" type="password" placeholder="MIRA-2026-SAFE" autocomplete="new-password" />
          </label>
        </div>

        <label>
          Output directory optional
          <div class="field-action">
            <input id="createOutDir" placeholder="leave empty = same folder as original" autocomplete="off" />
            <button id="chooseCreateDirBtn" class="mini-btn" type="button">Folder</button>
          </div>
        </label>

        <label class="checkline">
          <input id="keepAfterUnlock" type="checkbox" />
          Keep SBX after unlock, for tests only
        </label>

        <button id="createBtn" class="primary-btn" type="button">Create document.sbx</button>
      </section>

      <section id="unlockPanel" class="panel">
        <label>
          SBX file
          <div class="field-action">
            <input id="unlockInput" placeholder="/Users/noury/Desktop/document.sbx" autocomplete="off" />
            <button id="chooseSbxBtn" class="mini-btn" type="button">Choose</button>
          </div>
        </label>

        <div id="unlockDrop" class="dropzone">
          Drop document.sbx here. SafeBox will ask for the code.
        </div>

        <div class="grid-2">
          <label>
            Code
            <input id="unlockCode" type="password" placeholder="Enter receiver code" autocomplete="current-password" />
          </label>
          <label>
            Output directory optional
            <div class="field-action">
              <input id="unlockOutDir" placeholder="leave empty = same folder as SBX" autocomplete="off" />
              <button id="chooseUnlockDirBtn" class="mini-btn" type="button">Folder</button>
            </div>
          </label>
        </div>

        <div class="grid-2 checks">
          <label class="checkline">
            <input id="keepSbx" type="checkbox" />
            Keep SBX, for tests only
          </label>
          <label class="checkline">
            <input id="overwrite" type="checkbox" />
            Overwrite original if exists
          </label>
        </div>

        <button id="unlockBtn" class="primary-btn" type="button">Unlock & restore original</button>
      </section>

      <section id="result" class="result hidden" aria-live="polite"></section>
    </section>
  </main>
`;

const $ = <T extends HTMLElement>(selector: string): T => {
  const el = document.querySelector<T>(selector);
  if (!el) throw new Error(`${selector} not found`);
  return el;
};

const createTab = $("#createTab");
const unlockTab = $("#unlockTab");
const createPanel = $("#createPanel");
const unlockPanel = $("#unlockPanel");
const result = $("#result");
const themeToggle = $("#themeToggle");
const createDrop = $("#createDrop");
const unlockDrop = $("#unlockDrop");

let activeMode: "create" | "unlock" = "create";

function setTab(mode: "create" | "unlock") {
  activeMode = mode;
  const create = mode === "create";
  createTab.classList.toggle("active", create);
  unlockTab.classList.toggle("active", !create);
  createPanel.classList.toggle("active-panel", create);
  unlockPanel.classList.toggle("active-panel", !create);
  clearResult();
}

createTab.addEventListener("click", () => setTab("create"));
unlockTab.addEventListener("click", () => setTab("unlock"));

function setTheme(theme: "dark" | "light") {
  document.documentElement.dataset.theme = theme;
  localStorage.setItem("safebox-theme", theme);
  themeToggle.textContent = theme === "dark" ? "Light" : "Dark";
}

const savedTheme = localStorage.getItem("safebox-theme");
setTheme(savedTheme === "light" ? "light" : "dark");
themeToggle.addEventListener("click", () => {
  setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
});

function showResult(kind: "ok" | "error", html: string) {
  result.classList.remove("hidden", "ok", "error");
  result.classList.add(kind);
  result.innerHTML = html;
}

function clearResult() {
  result.classList.add("hidden");
  result.innerHTML = "";
}

function esc(value: string): string {
  return value.replace(/[&<>'"]/g, ch => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#039;",
    '"': "&quot;"
  }[ch] ?? ch));
}

function inputValue(id: string): string {
  return ($<HTMLInputElement>(id).value || "").trim();
}

function checked(id: string): boolean {
  return $<HTMLInputElement>(id).checked;
}

function setInput(id: string, value: string) {
  $<HTMLInputElement>(id).value = value;
}

function selectedPath(selected: string | string[] | null): string | null {
  if (Array.isArray(selected)) return selected[0] ?? null;
  return selected;
}

async function chooseFile(targetInput: string, sbxOnly = false) {
  const selected = await open({
    multiple: false,
    directory: false,
    filters: sbxOnly ? [{ name: "SafeBox File", extensions: ["sbx"] }] : undefined
  });
  const path = selectedPath(selected);
  if (path) setInput(targetInput, path);
}

async function chooseDirectory(targetInput: string) {
  const selected = await open({
    multiple: false,
    directory: true
  });
  const path = selectedPath(selected);
  if (path) setInput(targetInput, path);
}

$("#chooseOriginalBtn").addEventListener("click", () => chooseFile("#createInput", false));
$("#chooseSbxBtn").addEventListener("click", () => chooseFile("#unlockInput", true));
$("#chooseCreateDirBtn").addEventListener("click", () => chooseDirectory("#createOutDir"));
$("#chooseUnlockDirBtn").addEventListener("click", () => chooseDirectory("#unlockOutDir"));

function setDropVisual(on: boolean) {
  createDrop.classList.toggle("dragging", on && activeMode === "create");
  unlockDrop.classList.toggle("dragging", on && activeMode === "unlock");
  document.body.classList.toggle("dragging-file", on);
}

function applyDroppedPath(path: string) {
  const isSbx = path.toLowerCase().endsWith(".sbx");

  if (isSbx) {
    setTab("unlock");
    setInput("#unlockInput", path);
    showResult("ok", `<strong>SBX selected.</strong><br/><code>${esc(path)}</code>`);
  } else {
    setTab("create");
    setInput("#createInput", path);
    showResult("ok", `<strong>Original file selected.</strong><br/><code>${esc(path)}</code>`);
  }
}

async function setupNativeFileDrop() {
  await listen<TauriDropPayload>(TauriEvent.DRAG_ENTER, () => {
    setDropVisual(true);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_OVER, () => {
    setDropVisual(true);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_LEAVE, () => {
    setDropVisual(false);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_DROP, event => {
    setDropVisual(false);
    const path = event.payload.paths?.[0];

    if (!path) {
      showResult("error", "<strong>Drop failed.</strong><br/>SafeBox did not receive a file path. Use the Choose button.");
      return;
    }

    applyDroppedPath(path);
  });
}

setupNativeFileDrop().catch(error => {
  showResult("error", `<strong>Drag/drop init failed.</strong><br/><code>${esc(String(error))}</code>`);
});

$("#createBtn").addEventListener("click", async () => {
  clearResult();
  const inputPath = inputValue("#createInput");
  const code = inputValue("#createCode");
  const visibleName = inputValue("#visibleName") || "document";
  const outputDir = inputValue("#createOutDir");

  if (!inputPath || !code) {
    showResult("error", "<strong>Missing information.</strong><br/>Original file and code are required.");
    return;
  }

  try {
    const report = await invoke<CreateReport>("create_sbx_file", {
      inputPath,
      code,
      visibleName,
      outputDir: outputDir || null,
      keepAfterUnlock: checked("#keepAfterUnlock")
    });

    showResult("ok", `
      <strong>SafeBox created.</strong>
      <div class="result-grid">
        <span>Output</span><code>${esc(report.output_path)}</code>
        <span>Visible name</span><code>${esc(report.visible_sbx_name)}</code>
        <span>Original hidden</span><code>yes</code>
        <span>Mission</span><code>${esc(report.mission)}</code>
      </div>
    `);
  } catch (error) {
    showResult("error", `<strong>Create failed.</strong><br/><code>${esc(String(error))}</code>`);
  }
});

$("#unlockBtn").addEventListener("click", async () => {
  clearResult();
  const sbxPath = inputValue("#unlockInput");
  const code = inputValue("#unlockCode");
  const outputDir = inputValue("#unlockOutDir");

  if (!sbxPath || !code) {
    showResult("error", "<strong>Missing information.</strong><br/>SBX file and code are required.");
    return;
  }

  try {
    const report = await invoke<UnlockReport>("unlock_sbx_file", {
      sbxPath,
      code,
      outputDir: outputDir || null,
      keepSbx: checked("#keepSbx"),
      overwrite: checked("#overwrite")
    });

    showResult("ok", `
      <strong>BOOOOM. Original file restored.</strong>
      <div class="result-grid">
        <span>Original</span><code>${esc(report.original_file_name)}</code>
        <span>Restored path</span><code>${esc(report.restored_path)}</code>
        <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
        <span>Mission</span><code>${esc(report.mission)}</code>
      </div>
    `);
  } catch (error) {
    showResult("error", `<strong>Unlock failed.</strong><br/><code>${esc(String(error))}</code>`);
  }
});
TS

echo "==> Appending CSS for picker/drop UI"
cat >> src/style.css <<'CSS'

/* Sprint 3A: native picker + native Tauri drag/drop */
.field-action {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
}

.mini-btn {
  min-height: 48px;
  padding: 0 16px;
  border: 1px solid var(--border);
  border-radius: 15px;
  color: var(--text);
  font-weight: 800;
  cursor: pointer;
  background: rgba(255, 255, 255, 0.07);
}

.mini-btn:hover {
  border-color: rgba(56, 189, 248, 0.55);
  background: rgba(56, 189, 248, 0.12);
}

body.dragging-file .hero-card {
  border-color: rgba(56, 189, 248, 0.75);
  box-shadow: 0 0 0 4px rgba(56, 189, 248, 0.10), 0 26px 90px rgba(0, 0, 0, 0.30);
}

@media (max-width: 680px) {
  .field-action {
    grid-template-columns: 1fr;
  }

  .mini-btn {
    width: 100%;
  }
}
CSS

echo "==> Patch applied."
echo ""
echo "Now run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm install"
echo "  npm run tauri dev"
