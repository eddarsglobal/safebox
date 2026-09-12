#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 4A
# Receiver Mode minimal:
# - double-click / Open With .sbx opens a minimal unlock screen
# - no Create tab
# - no "locked" message
# - only logo, code, Unlock, and optional File info
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint4a_receiver_mode_patch.sh

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup current frontend files"
cp src/main.ts "src/main.ts.backup-sprint4a.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint4a.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

echo "==> Writing Sprint 4A frontend main.ts"
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

type SbxOpenPayload = string;

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("#app not found");

app.innerHTML = `
  <main class="shell">
    <section id="heroCard" class="hero-card">
      <div class="topbar">
        <div class="brand">
          <img src="/safebox-logo.png" alt="SafeBox" class="logo" />
          <div>
            <h1>SafeBox</h1>
            <p id="brandSubtitle">Universal secure file format</p>
          </div>
        </div>
        <button id="themeToggle" class="ghost-btn" type="button">Dark</button>
      </div>

      <div id="normalMode">
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
            Drop document.sbx here.
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
      </div>

      <section id="receiverMode" class="receiver-panel">
        <div class="receiver-center">
          <div id="receiverFileName" class="receiver-file-name">document.sbx</div>

          <label class="receiver-code-label">
            Enter code
            <input id="receiverCode" class="receiver-code-input" type="password" autocomplete="current-password" autofocus />
          </label>

          <button id="receiverUnlockBtn" class="primary-btn receiver-unlock-btn" type="button">Unlock</button>

          <button id="fileInfoBtn" class="file-info-link" type="button">File info</button>

          <div id="fileInfoBox" class="file-info-box hidden">
            <div><span>Name</span><code id="fileInfoName">document.sbx</code></div>
            <div><span>Type</span><code>SafeBox File</code></div>
          </div>
        </div>
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

const heroCard = $("#heroCard");
const normalMode = $("#normalMode");
const receiverModePanel = $("#receiverMode");
const createTab = $("#createTab");
const unlockTab = $("#unlockTab");
const createPanel = $("#createPanel");
const unlockPanel = $("#unlockPanel");
const result = $("#result");
const themeToggle = $("#themeToggle");
const createDrop = $("#createDrop");
const unlockDrop = $("#unlockDrop");
const brandSubtitle = $("#brandSubtitle");

let activeMode: "create" | "unlock" = "create";
let receiverMode = false;
let receiverSbxPath = "";

function setTab(mode: "create" | "unlock") {
  activeMode = mode;
  const create = mode === "create";
  createTab.classList.toggle("active", create);
  unlockTab.classList.toggle("active", !create);
  createPanel.classList.toggle("active-panel", create);
  unlockPanel.classList.toggle("active-panel", !create);
  clearResult();
}

function enterNormalMode(mode: "create" | "unlock" = "create") {
  receiverMode = false;
  heroCard.classList.remove("receiver-only");
  normalMode.classList.remove("hidden");
  receiverModePanel.classList.remove("active-receiver-panel");
  brandSubtitle.textContent = "Universal secure file format";
  setTab(mode);
}

function enterReceiverMode(sbxPath: string) {
  receiverMode = true;
  receiverSbxPath = sbxPath;

  heroCard.classList.add("receiver-only");
  normalMode.classList.add("hidden");
  receiverModePanel.classList.add("active-receiver-panel");
  brandSubtitle.textContent = "";

  const name = fileNameFromPath(sbxPath) || "document.sbx";
  $("#receiverFileName").textContent = name;
  $("#fileInfoName").textContent = name;
  setInput("#unlockInput", sbxPath);
  setInput("#receiverCode", "");
  $("#fileInfoBox").classList.add("hidden");

  clearResult();

  setTimeout(() => {
    $<HTMLInputElement>("#receiverCode").focus();
  }, 100);
}

createTab.addEventListener("click", () => enterNormalMode("create"));
unlockTab.addEventListener("click", () => enterNormalMode("unlock"));

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

function fileNameFromPath(path: string): string {
  const clean = path.replaceAll("\\", "/");
  return clean.split("/").pop() || path;
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
  createDrop.classList.toggle("dragging", on && activeMode === "create" && !receiverMode);
  unlockDrop.classList.toggle("dragging", on && activeMode === "unlock" && !receiverMode);
  document.body.classList.toggle("dragging-file", on);
}

function applyDroppedPath(path: string) {
  const isSbx = path.toLowerCase().endsWith(".sbx");

  if (isSbx) {
    enterReceiverMode(path);
  } else {
    enterNormalMode("create");
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
      showResult("error", "<strong>Drop failed.</strong><br/>Use the Choose button.");
      return;
    }

    applyDroppedPath(path);
  });
}

setupNativeFileDrop().catch(error => {
  showResult("error", `<strong>Drag/drop init failed.</strong><br/><code>${esc(String(error))}</code>`);
});

function openSbxFromSystem(path: string) {
  const cleaned = (path || "").trim();

  if (!cleaned.toLowerCase().endsWith(".sbx")) {
    return;
  }

  enterReceiverMode(cleaned);
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

$("#fileInfoBtn").addEventListener("click", () => {
  $("#fileInfoBox").classList.toggle("hidden");
});

$("#receiverCode").addEventListener("keydown", event => {
  if (event.key === "Enter") {
    $("#receiverUnlockBtn").click();
  }
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

async function unlockNow(sbxPath: string, code: string, receiver: boolean) {
  clearResult();

  if (!sbxPath || !code) {
    showResult("error", receiver ? "<strong>Wrong code</strong>" : "<strong>Missing information.</strong><br/>SBX file and code are required.");
    return;
  }

  try {
    const report = await invoke<UnlockReport>("unlock_sbx_file", {
      sbxPath,
      code,
      outputDir: receiver ? null : (inputValue("#unlockOutDir") || null),
      keepSbx: receiver ? false : checked("#keepSbx"),
      overwrite: receiver ? false : checked("#overwrite")
    });

    if (receiver) {
      showResult("ok", `
        <div class="boom-title">BOOOOM</div>
        <strong>Original restored.</strong><br/>
        <span>SBX completed.</span>
        <div class="result-grid compact">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Saved</span><code>${esc(report.restored_path)}</code>
        </div>
      `);
    } else {
      showResult("ok", `
        <strong>BOOOOM. Original file restored.</strong>
        <div class="result-grid">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Restored path</span><code>${esc(report.restored_path)}</code>
          <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
          <span>Mission</span><code>${esc(report.mission)}</code>
        </div>
      `);
    }
  } catch (_error) {
    if (receiver) {
      showResult("error", "<strong>Wrong code</strong>");
      $<HTMLInputElement>("#receiverCode").select();
    } else {
      showResult("error", `<strong>Unlock failed.</strong><br/><code>${esc(String(_error))}</code>`);
    }
  }
}

$("#unlockBtn").addEventListener("click", async () => {
  await unlockNow(inputValue("#unlockInput"), inputValue("#unlockCode"), false);
});

$("#receiverUnlockBtn").addEventListener("click", async () => {
  await unlockNow(receiverSbxPath, inputValue("#receiverCode"), true);
});
TS

echo "==> Appending Sprint 4A CSS"
cat >> src/style.css <<'CSS'

/* Sprint 4A — Receiver Mode minimal */
.receiver-panel {
  display: none;
}

.receiver-panel.active-receiver-panel {
  display: block;
}

.hero-card.receiver-only {
  max-width: 560px;
  min-height: auto;
}

.hero-card.receiver-only .topbar {
  justify-content: center;
}

.hero-card.receiver-only .brand {
  flex-direction: column;
  text-align: center;
  gap: 12px;
}

.hero-card.receiver-only .brand h1 {
  font-size: clamp(2rem, 8vw, 3.2rem);
  line-height: 1;
}

.hero-card.receiver-only .logo {
  width: 82px;
  height: 82px;
}

.hero-card.receiver-only .ghost-btn {
  position: absolute;
  top: 18px;
  right: 18px;
}

.receiver-center {
  display: grid;
  gap: 18px;
  max-width: 360px;
  margin: 24px auto 0;
  text-align: center;
}

.receiver-file-name {
  font-size: 0.95rem;
  color: var(--muted);
  font-weight: 700;
  word-break: break-word;
}

.receiver-code-label {
  text-align: left;
  font-size: 0.95rem;
  font-weight: 800;
  color: var(--text);
}

.receiver-code-input {
  margin-top: 8px;
  min-height: 58px;
  font-size: 1.2rem;
  text-align: center;
  letter-spacing: 0.08em;
}

.receiver-unlock-btn {
  min-height: 58px;
  font-size: 1.02rem;
}

.file-info-link {
  border: 0;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
  font-weight: 800;
  padding: 8px;
  justify-self: center;
}

.file-info-link:hover {
  color: var(--primary);
}

.file-info-box {
  display: grid;
  gap: 10px;
  padding: 14px;
  border: 1px solid var(--border);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.055);
  text-align: left;
}

.file-info-box > div {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 8px;
  align-items: center;
}

.file-info-box span {
  color: var(--muted);
  font-weight: 800;
}

.file-info-box code {
  overflow-wrap: anywhere;
}

.boom-title {
  font-size: clamp(2rem, 10vw, 3.5rem);
  font-weight: 950;
  letter-spacing: 0.04em;
  margin-bottom: 8px;
}

.result-grid.compact {
  margin-top: 14px;
}

@media (max-width: 680px) {
  .hero-card.receiver-only {
    min-height: calc(100vh - 28px);
    display: grid;
    align-content: center;
  }

  .hero-card.receiver-only .ghost-btn {
    top: 12px;
    right: 12px;
  }

  .receiver-center {
    max-width: 100%;
  }
}
CSS

echo "==> Sprint 4A patch applied."
echo ""
echo "Now run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri dev"
echo ""
echo "Then build/install for Finder double-click:"
echo "  npm run tauri build"
echo "  cp -R \"$ROOT/target/release/bundle/macos/SafeBox.app\" /Applications/"
