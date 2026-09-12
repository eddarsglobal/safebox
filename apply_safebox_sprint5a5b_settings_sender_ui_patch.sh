#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 5A + 5B
# Adds:
# - Settings modal
# - Default visible SBX name, default "document"
# - Optional session code, not permanently stored
# - Cleaner Sender/Create UI
# - Advanced options hidden by default
# - Keeps mini receiver overlay for .sbx open/drag/drop

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint5.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint5.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

echo "==> Writing Sprint 5 frontend main.ts"
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

type SafeBoxSettings = {
  defaultVisibleName: string;
  useSessionCode: boolean;
};

const SETTINGS_KEY = "safebox.settings.v1";
const SESSION_CODE_KEY = "safebox.sessionCode.v1";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("#app not found");

function readSettings(): SafeBoxSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) {
      return { defaultVisibleName: "document", useSessionCode: false };
    }

    const parsed = JSON.parse(raw) as Partial<SafeBoxSettings>;

    return {
      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || "document"),
      useSessionCode: Boolean(parsed.useSessionCode)
    };
  } catch {
    return { defaultVisibleName: "document", useSessionCode: false };
  }
}

function writeSettings(settings: SafeBoxSettings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify({
    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || "document"),
    useSessionCode: Boolean(settings.useSessionCode)
  }));
}

function getSessionCode(): string {
  return sessionStorage.getItem(SESSION_CODE_KEY) || "";
}

function setSessionCode(code: string) {
  if (code.trim()) {
    sessionStorage.setItem(SESSION_CODE_KEY, code.trim());
  } else {
    sessionStorage.removeItem(SESSION_CODE_KEY);
  }
}

let settings = readSettings();

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

        <div class="top-actions">
          <button id="settingsBtn" class="ghost-btn" type="button">Settings</button>
          <button id="themeToggle" class="ghost-btn" type="button">Dark</button>
        </div>
      </div>

      <div id="normalMode">
        <section id="createPanel" class="panel active-panel sender-panel">
          <div class="sender-head">
            <h2>Create SBX</h2>
            <p>Any file becomes a SafeBox file.</p>
          </div>

          <div id="createDrop" class="dropzone primary-drop">
            Drop any file here
          </div>

          <label>
            Original file
            <div class="field-action">
              <input id="createInput" placeholder="/Users/noury/Desktop/test.png" autocomplete="off" />
              <button id="chooseOriginalBtn" class="mini-btn" type="button">Choose</button>
            </div>
          </label>

          <div class="grid-2">
            <label>
              Visible SBX name
              <input id="visibleName" value="document" autocomplete="off" />
            </label>
            <label>
              Code
              <input id="createCode" type="password" placeholder="Enter sender code" autocomplete="new-password" />
            </label>
          </div>

          <button id="createBtn" class="primary-btn" type="button">Create SBX</button>

          <button id="advancedCreateToggle" class="soft-toggle" type="button">Advanced</button>

          <div id="advancedCreateBox" class="advanced-box hidden">
            <label>
              Output directory
              <div class="field-action">
                <input id="createOutDir" placeholder="leave empty = same folder as original" autocomplete="off" />
                <button id="chooseCreateDirBtn" class="mini-btn" type="button">Folder</button>
              </div>
            </label>

            <label class="checkline">
              <input id="keepAfterUnlock" type="checkbox" />
              Keep SBX after unlock, for tests only
            </label>
          </div>

          <button id="switchUnlockBtn" class="secondary-link" type="button">Open existing SBX</button>
        </section>

        <section id="unlockPanel" class="panel sender-panel">
          <div class="sender-head">
            <h2>Unlock SBX</h2>
            <p>For manual testing or opening an SBX file.</p>
          </div>

          <div id="unlockDrop" class="dropzone primary-drop">
            Drop document.sbx here
          </div>

          <label>
            SBX file
            <div class="field-action">
              <input id="unlockInput" placeholder="/Users/noury/Desktop/document.sbx" autocomplete="off" />
              <button id="chooseSbxBtn" class="mini-btn" type="button">Choose</button>
            </div>
          </label>

          <label>
            Code
            <input id="unlockCode" type="password" placeholder="Enter receiver code" autocomplete="current-password" />
          </label>

          <button id="unlockBtn" class="primary-btn" type="button">Unlock</button>

          <button id="advancedUnlockToggle" class="soft-toggle" type="button">Advanced</button>

          <div id="advancedUnlockBox" class="advanced-box hidden">
            <label>
              Output directory
              <div class="field-action">
                <input id="unlockOutDir" placeholder="leave empty = same folder as SBX" autocomplete="off" />
                <button id="chooseUnlockDirBtn" class="mini-btn" type="button">Folder</button>
              </div>
            </label>

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
          </div>

          <button id="switchCreateBtn" class="secondary-link" type="button">Create new SBX</button>
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

    <div id="settingsModal" class="modal-backdrop hidden" role="dialog" aria-modal="true">
      <section class="settings-modal">
        <div class="modal-head">
          <div>
            <h2>Settings</h2>
            <p>Sender defaults</p>
          </div>
          <button id="closeSettingsBtn" class="icon-btn" type="button">×</button>
        </div>

        <label>
          Default SBX name
          <input id="settingsDefaultName" autocomplete="off" />
        </label>

        <label class="checkline settings-check">
          <input id="settingsUseSessionCode" type="checkbox" />
          Use session code for Create SBX
        </label>

        <label id="settingsSessionCodeBox">
          Session code
          <input id="settingsSessionCode" type="password" placeholder="not stored permanently" autocomplete="new-password" />
        </label>

        <p class="settings-note">
          Codes are not stored permanently in this MVP. Keychain storage comes later.
        </p>

        <div class="modal-actions">
          <button id="saveSettingsBtn" class="primary-btn" type="button">Save</button>
          <button id="cancelSettingsBtn" class="mini-btn" type="button">Cancel</button>
        </div>
      </section>
    </div>
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
const createPanel = $("#createPanel");
const unlockPanel = $("#unlockPanel");
const result = $("#result");
const themeToggle = $("#themeToggle");
const createDrop = $("#createDrop");
const unlockDrop = $("#unlockDrop");
const brandSubtitle = $("#brandSubtitle");
const settingsModal = $("#settingsModal");

let activeMode: "create" | "unlock" = "create";
let receiverMode = false;
let receiverSbxPath = "";

function sanitizeVisibleName(value: string): string {
  const cleaned = (value || "document")
    .trim()
    .replace(/\.sbx$/i, "")
    .replace(/[^a-zA-Z0-9 _-]/g, "")
    .trim();

  return cleaned || "document";
}

function setTab(mode: "create" | "unlock") {
  activeMode = mode;
  const create = mode === "create";
  createPanel.classList.toggle("active-panel", create);
  unlockPanel.classList.toggle("active-panel", !create);
  clearResult();
}

function enterNormalMode(mode: "create" | "unlock" = "create") {
  hideHardReceiverOverlay();

  receiverMode = false;
  heroCard.classList.remove("receiver-only");

  normalMode.classList.remove("hidden");
  normalMode.style.display = "block";

  receiverModePanel.classList.remove("active-receiver-panel");
  receiverModePanel.style.display = "none";

  brandSubtitle.textContent = "Universal secure file format";
  setTab(mode);
}

function enterReceiverMode(sbxPath: string) {
  showHardReceiverOverlay(sbxPath);

  receiverMode = true;
  receiverSbxPath = sbxPath;

  heroCard.classList.add("receiver-only");

  normalMode.classList.add("hidden");
  normalMode.style.display = "none";

  receiverModePanel.classList.add("active-receiver-panel");
  receiverModePanel.style.display = "block";

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

function applySettingsToUi() {
  settings = readSettings();
  const visibleName = sanitizeVisibleName(settings.defaultVisibleName || "document");
  setInput("#visibleName", visibleName);

  if (settings.useSessionCode) {
    const code = getSessionCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}

$("#switchUnlockBtn").addEventListener("click", () => enterNormalMode("unlock"));
$("#switchCreateBtn").addEventListener("click", () => enterNormalMode("create"));

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
  const clean = path.replace(/\\/g, "/");
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

$("#advancedCreateToggle").addEventListener("click", () => {
  $("#advancedCreateBox").classList.toggle("hidden");
});

$("#advancedUnlockToggle").addEventListener("click", () => {
  $("#advancedUnlockBox").classList.toggle("hidden");
});

function openSettings() {
  settings = readSettings();
  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  $<HTMLInputElement>("#settingsUseSessionCode").checked = settings.useSessionCode;
  setInput("#settingsSessionCode", getSessionCode());
  settingsModal.classList.remove("hidden");
  setTimeout(() => $<HTMLInputElement>("#settingsDefaultName").focus(), 80);
}

function closeSettings() {
  settingsModal.classList.add("hidden");
}

$("#settingsBtn").addEventListener("click", openSettings);
$("#closeSettingsBtn").addEventListener("click", closeSettings);
$("#cancelSettingsBtn").addEventListener("click", closeSettings);

$("#saveSettingsBtn").addEventListener("click", () => {
  const nextSettings: SafeBoxSettings = {
    defaultVisibleName: sanitizeVisibleName(inputValue("#settingsDefaultName")),
    useSessionCode: checked("#settingsUseSessionCode")
  };

  writeSettings(nextSettings);

  if (nextSettings.useSessionCode) {
    setSessionCode(inputValue("#settingsSessionCode"));
  } else {
    setSessionCode("");
  }

  closeSettings();
  applySettingsToUi();

  showResult("ok", `
    <strong>Settings saved.</strong>
    <div class="result-grid compact">
      <span>Default name</span><code>${esc(nextSettings.defaultVisibleName)}.sbx</code>
      <span>Session code</span><code>${nextSettings.useSessionCode && getSessionCode() ? "enabled" : "disabled"}</code>
    </div>
  `);
});

settingsModal.addEventListener("click", event => {
  if (event.target === settingsModal) closeSettings();
});

function setDropVisual(on: boolean) {
  createDrop.classList.toggle("dragging", on && activeMode === "create" && !receiverMode);
  unlockDrop.classList.toggle("dragging", on && activeMode === "unlock" && !receiverMode);
  document.body.classList.toggle("dragging-file", on);
}

function applyDroppedPath(path: string) {
  const isSbx = path.toLowerCase().endsWith(".sbx");

  if (isSbx) {
    enterReceiverMode(path);
    return;
  }

  enterNormalMode("create");
  setInput("#createInput", path);
  showResult("ok", `<strong>File selected.</strong><br/><code>${esc(path)}</code>`);
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

function showHardReceiverOverlay(sbxPath: string) {
  receiverMode = true;
  receiverSbxPath = sbxPath;

  document.body.dataset.safeboxMode = "receiver";

  let overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "hardReceiverOverlay";
    overlay.className = "hard-receiver-overlay";
    document.body.appendChild(overlay);
  }

  const name = fileNameFromPath(sbxPath) || "document.sbx";

  overlay.innerHTML = `
    <div class="hard-receiver-card">
      <div class="hard-receiver-brand">
        <img src="/safebox-logo.png" alt="SafeBox" />
        <h1>SafeBox</h1>
      </div>

      <div class="hard-receiver-file">${esc(name)}</div>

      <label class="hard-receiver-label">
        Enter code
        <input id="hardReceiverCode" type="password" autocomplete="current-password" />
      </label>

      <button id="hardReceiverUnlock" type="button">Unlock</button>

      <button id="hardReceiverInfoBtn" type="button" class="hard-receiver-info-btn">File info</button>

      <div id="hardReceiverInfo" class="hard-receiver-info hidden">
        <div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>
      </div>

      <div id="hardReceiverResult" class="hard-receiver-result hidden"></div>
    </div>
  `;

  overlay.style.display = "grid";

  const codeInput = overlay.querySelector<HTMLInputElement>("#hardReceiverCode");
  const unlockBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverUnlock");
  const infoBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverInfoBtn");
  const infoBox = overlay.querySelector<HTMLDivElement>("#hardReceiverInfo");
  const overlayResult = overlay.querySelector<HTMLDivElement>("#hardReceiverResult");

  const showOverlayResult = (kind: "ok" | "error", html: string) => {
    if (!overlayResult) return;
    overlayResult.className = `hard-receiver-result ${kind}`;
    overlayResult.innerHTML = html;
  };

  const doUnlock = async () => {
    const code = (codeInput?.value || "").trim();

    if (!code) {
      showOverlayResult("error", "<strong>Wrong code</strong>");
      codeInput?.focus();
      return;
    }

    try {
      const report = await invoke<UnlockReport>("unlock_sbx_file", {
        sbxPath,
        code,
        outputDir: null,
        keepSbx: false,
        overwrite: false
      });

      showOverlayResult("ok", `
        <div class="boom-title">BOOOOM</div>
        <strong>Original restored.</strong><br/>
        <span>SBX completed.</span>
        <div class="result-grid compact">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Saved</span><code>${esc(report.restored_path)}</code>
        </div>
      `);
    } catch {
      showOverlayResult("error", "<strong>Wrong code</strong>");
      codeInput?.select();
      codeInput?.focus();
    }
  };

  unlockBtn?.addEventListener("click", doUnlock);
  codeInput?.addEventListener("keydown", event => {
    if (event.key === "Enter") doUnlock();
  });

  infoBtn?.addEventListener("click", () => {
    infoBox?.classList.toggle("hidden");
  });

  setTimeout(() => {
    codeInput?.focus();
  }, 80);
}

function hideHardReceiverOverlay() {
  delete document.body.dataset.safeboxMode;
  const overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (overlay) {
    overlay.style.display = "none";
  }
}

$("#createBtn").addEventListener("click", async () => {
  clearResult();
  const inputPath = inputValue("#createInput");
  const code = inputValue("#createCode");
  const visibleName = sanitizeVisibleName(inputValue("#visibleName") || settings.defaultVisibleName || "document");
  const outputDir = inputValue("#createOutDir");

  if (!inputPath || !code) {
    showResult("error", "<strong>Missing information.</strong><br/>File and code are required.");
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

    showResult("ok", `
      <strong>BOOOOM. Original restored.</strong>
      <div class="result-grid">
        <span>Original</span><code>${esc(report.original_file_name)}</code>
        <span>Saved</span><code>${esc(report.restored_path)}</code>
        <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
      </div>
    `);
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

applySettingsToUi();
enterNormalMode("create");
TS

echo "==> Appending Sprint 5 CSS"
cat >> src/style.css <<'CSS'

/* Sprint 5 — Settings + clean sender UI */
.top-actions {
  display: flex;
  gap: 10px;
  align-items: center;
}

.sender-panel {
  display: none;
}

.sender-panel.active-panel {
  display: grid;
  gap: 18px;
}

.sender-head {
  display: grid;
  gap: 6px;
}

.sender-head h2 {
  margin: 0;
  font-size: clamp(1.6rem, 5vw, 2.35rem);
  letter-spacing: -0.04em;
}

.sender-head p {
  margin: 0;
  color: var(--muted);
  font-weight: 700;
}

.primary-drop {
  min-height: 112px;
  font-size: 1rem;
  font-weight: 900;
}

.soft-toggle,
.secondary-link {
  border: 0;
  background: transparent;
  color: var(--muted);
  cursor: pointer;
  font-weight: 900;
  padding: 8px;
  justify-self: center;
}

.soft-toggle:hover,
.secondary-link:hover {
  color: var(--primary);
}

.advanced-box {
  display: grid;
  gap: 16px;
  padding: 16px;
  border: 1px solid var(--border);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.045);
}

.modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1000000;
  display: grid;
  place-items: center;
  padding: 22px;
  background: rgba(5, 11, 20, 0.70);
  backdrop-filter: blur(14px);
}

.settings-modal {
  width: min(460px, 100%);
  display: grid;
  gap: 18px;
  padding: 24px;
  border-radius: 26px;
  border: 1px solid var(--border);
  background: var(--card);
  color: var(--text);
  box-shadow: 0 30px 100px rgba(0, 0, 0, 0.42);
}

.modal-head {
  display: flex;
  justify-content: space-between;
  gap: 14px;
  align-items: flex-start;
}

.modal-head h2 {
  margin: 0;
  font-size: 1.7rem;
}

.modal-head p {
  margin: 3px 0 0;
  color: var(--muted);
  font-weight: 700;
}

.icon-btn {
  width: 38px;
  height: 38px;
  border: 1px solid var(--border);
  border-radius: 14px;
  background: rgba(255,255,255,0.06);
  color: var(--text);
  font-size: 1.6rem;
  line-height: 1;
  cursor: pointer;
}

.settings-check {
  margin-top: 2px;
}

.settings-note {
  margin: 0;
  color: var(--muted);
  font-size: 0.9rem;
  font-weight: 650;
  line-height: 1.45;
}

.modal-actions {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 12px;
}

@media (max-width: 680px) {
  .top-actions {
    width: 100%;
    justify-content: center;
    flex-wrap: wrap;
  }

  .modal-actions {
    grid-template-columns: 1fr;
  }
}
CSS

echo "==> Sprint 5A/5B patch applied."
echo ""
echo "Run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri dev"
