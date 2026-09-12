#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 6A
# Adds:
# - Global code in Settings
# - Use global code by default
# - Global code kept only in sessionStorage for MVP
# - Show / Hide global code
# - Clear global code
# - Auto-fill Create SBX code when global code is enabled
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint6a_global_code_patch.sh

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint6a.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint6a.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

echo "==> Patch main.ts for Global Code"
python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

# 1) Type SafeBoxSettings
text = text.replace(
'''type SafeBoxSettings = {
  defaultVisibleName: string;
  useSessionCode: boolean;
};''',
'''type SafeBoxSettings = {
  defaultVisibleName: string;
  useGlobalCode: boolean;
};'''
)

# 2) Session key name. Keep value key to avoid losing current session, but rename constant.
text = text.replace(
'''const SESSION_CODE_KEY = "safebox.sessionCode.v1";''',
'''const GLOBAL_CODE_SESSION_KEY = "safebox.globalCode.session.v1";'''
)

# Backward compatible get/set functions.
text = text.replace(
'''function getSessionCode(): string {
  return sessionStorage.getItem(SESSION_CODE_KEY) || "";
}

function setSessionCode(code: string) {
  if (code.trim()) {
    sessionStorage.setItem(SESSION_CODE_KEY, code.trim());
  } else {
    sessionStorage.removeItem(SESSION_CODE_KEY);
  }
}''',
'''function getGlobalCode(): string {
  return sessionStorage.getItem(GLOBAL_CODE_SESSION_KEY) || "";
}

function setGlobalCode(code: string) {
  if (code.trim()) {
    sessionStorage.setItem(GLOBAL_CODE_SESSION_KEY, code.trim());
  } else {
    sessionStorage.removeItem(GLOBAL_CODE_SESSION_KEY);
  }
}'''
)

# 3) readSettings / writeSettings
old = '''function readSettings(): SafeBoxSettings {
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
}'''

new = '''function readSettings(): SafeBoxSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) {
      return { defaultVisibleName: "document", useGlobalCode: false };
    }

    const parsed = JSON.parse(raw) as Partial<SafeBoxSettings> & { useSessionCode?: boolean };

    return {
      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || "document"),
      useGlobalCode: Boolean(parsed.useGlobalCode ?? parsed.useSessionCode)
    };
  } catch {
    return { defaultVisibleName: "document", useGlobalCode: false };
  }
}

function writeSettings(settings: SafeBoxSettings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify({
    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || "document"),
    useGlobalCode: Boolean(settings.useGlobalCode)
  }));
}'''

if old not in text:
    raise SystemExit("Could not find readSettings/writeSettings block. Send me that block from src/main.ts.")
text = text.replace(old, new)

# 4) Settings modal HTML IDs/text
old = '''        <label class="checkline settings-check">
          <input id="settingsUseSessionCode" type="checkbox" />
          Use session code for Create SBX
        </label>

        <label id="settingsSessionCodeBox">
          Session code
          <input id="settingsSessionCode" type="password" placeholder="not stored permanently" autocomplete="new-password" />
        </label>

        <p class="settings-note">
          Codes are not stored permanently in this MVP. Keychain storage comes later.
        </p>'''

new = '''        <label class="checkline settings-check">
          <input id="settingsUseGlobalCode" type="checkbox" />
          Use global code by default
        </label>

        <label id="settingsGlobalCodeBox">
          Global code
          <div class="password-action-row">
            <input id="settingsGlobalCode" type="password" placeholder="kept only for this session" autocomplete="new-password" />
            <button id="toggleGlobalCodeBtn" class="mini-btn" type="button">Show</button>
          </div>
        </label>

        <button id="clearGlobalCodeBtn" class="secondary-link danger-link" type="button">Clear global code</button>

        <p class="settings-note">
          MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.
        </p>'''

if old not in text:
    raise SystemExit("Could not find old settings session code HTML block.")
text = text.replace(old, new)

# 5) applySettingsToUi
old = '''function applySettingsToUi() {
  settings = readSettings();
  const visibleName = sanitizeVisibleName(settings.defaultVisibleName || "document");
  setInput("#visibleName", visibleName);

  if (settings.useSessionCode) {
    const code = getSessionCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}'''

new = '''function applySettingsToUi() {
  settings = readSettings();
  const visibleName = sanitizeVisibleName(settings.defaultVisibleName || "document");
  setInput("#visibleName", visibleName);

  if (settings.useGlobalCode) {
    const code = getGlobalCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}'''

if old not in text:
    raise SystemExit("Could not find applySettingsToUi block.")
text = text.replace(old, new)

# 6) openSettings
old = '''function openSettings() {
  settings = readSettings();
  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  $<HTMLInputElement>("#settingsUseSessionCode").checked = settings.useSessionCode;
  setInput("#settingsSessionCode", getSessionCode());
  settingsModal.classList.remove("hidden");
  setTimeout(() => $<HTMLInputElement>("#settingsDefaultName").focus(), 80);
}'''

new = '''function openSettings() {
  settings = readSettings();
  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  $<HTMLInputElement>("#settingsUseGlobalCode").checked = settings.useGlobalCode;
  setInput("#settingsGlobalCode", getGlobalCode());
  $<HTMLInputElement>("#settingsGlobalCode").type = "password";
  $("#toggleGlobalCodeBtn").textContent = "Show";
  settingsModal.classList.remove("hidden");
  settingsModal.style.display = "grid";
  setTimeout(() => $<HTMLInputElement>("#settingsDefaultName").focus(), 80);
}'''

if old not in text:
    # Some users already patched modal style.display. Try alternative.
    old_alt = '''function openSettings() {
  settings = readSettings();
  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  $<HTMLInputElement>("#settingsUseSessionCode").checked = settings.useSessionCode;
  setInput("#settingsSessionCode", getSessionCode());
  settingsModal.classList.remove("hidden");
  settingsModal.style.display = "grid";
  setTimeout(() => $<HTMLInputElement>("#settingsDefaultName").focus(), 80);
}'''
    if old_alt not in text:
        raise SystemExit("Could not find openSettings block.")
    text = text.replace(old_alt, new)
else:
    text = text.replace(old, new)

# 7) closeSettings if not forced
text = text.replace(
'''function closeSettings() {
  settingsModal.classList.add("hidden");
}''',
'''function closeSettings() {
  settingsModal.classList.add("hidden");
  settingsModal.style.display = "none";
}'''
)

# 8) Save handler
old = '''$("#saveSettingsBtn").addEventListener("click", () => {
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
});'''

new = '''$("#saveSettingsBtn").addEventListener("click", () => {
  const nextSettings: SafeBoxSettings = {
    defaultVisibleName: sanitizeVisibleName(inputValue("#settingsDefaultName")),
    useGlobalCode: checked("#settingsUseGlobalCode")
  };

  writeSettings(nextSettings);

  if (nextSettings.useGlobalCode) {
    setGlobalCode(inputValue("#settingsGlobalCode"));
  } else {
    setGlobalCode("");
  }

  closeSettings();
  applySettingsToUi();

  showResult("ok", `
    <strong>Settings saved.</strong>
    <div class="result-grid compact">
      <span>Default name</span><code>${esc(nextSettings.defaultVisibleName)}.sbx</code>
      <span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>
    </div>
  `);
});'''

if old not in text:
    raise SystemExit("Could not find saveSettingsBtn handler.")
text = text.replace(old, new)

# 9) Add toggle/clear handlers after cancel handlers.
marker = '''$("#cancelSettingsBtn").addEventListener("click", closeSettings);'''
insert = '''$("#cancelSettingsBtn").addEventListener("click", closeSettings);

$("#toggleGlobalCodeBtn").addEventListener("click", () => {
  const input = $<HTMLInputElement>("#settingsGlobalCode");
  const isHidden = input.type === "password";
  input.type = isHidden ? "text" : "password";
  $("#toggleGlobalCodeBtn").textContent = isHidden ? "Hide" : "Show";
});

$("#clearGlobalCodeBtn").addEventListener("click", () => {
  setInput("#settingsGlobalCode", "");
  setGlobalCode("");
  setInput("#createCode", "");
  showResult("ok", "<strong>Global code cleared.</strong>");
});'''
if marker not in text:
    raise SystemExit("Could not find cancelSettingsBtn listener.")
text = text.replace(marker, insert)

# 10) Replace references if any remain.
text = text.replace("useSessionCode", "useGlobalCode")
text = text.replace("settingsUseSessionCode", "settingsUseGlobalCode")
text = text.replace("settingsSessionCode", "settingsGlobalCode")
text = text.replace("getSessionCode()", "getGlobalCode()")
text = text.replace("setSessionCode(", "setGlobalCode(")

p.write_text(text)
print("Sprint 6A main.ts patch applied")
PY

echo "==> Append Sprint 6A CSS"
cat >> src/style.css <<'CSS'

/* Sprint 6A — Global code settings */
.password-action-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
}

.danger-link {
  color: #FCA5A5;
}

.danger-link:hover {
  color: #F87171;
}

@media (max-width: 680px) {
  .password-action-row {
    grid-template-columns: 1fr;
  }
}
CSS

echo "==> Sprint 6A patch applied."
echo ""
echo "Run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri dev"
