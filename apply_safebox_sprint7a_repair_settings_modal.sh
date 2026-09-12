#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 7A Repair — Settings Modal
# Force-repairs old Settings modal:
# - replaces "Use session code" with "Use global code by default"
# - adds Global sender label
# - adds Default access profile
# - keeps global code session-only
# - ensures Save stores sender/access/global code
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint7a_repair_settings_modal.sh

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint7a-repair-settings.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint7a-repair-settings.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

def replace_function(source: str, name: str, replacement: str) -> str:
    marker = f"function {name}"
    start = source.find(marker)
    if start == -1:
        raise SystemExit(f"Cannot find function {name}")
    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit(f"Cannot find opening brace for {name}")
    depth = 0
    for i in range(brace, len(source)):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[:start] + replacement + source[i+1:]
    raise SystemExit(f"Cannot find closing brace for {name}")

def replace_event_handler(source: str, marker: str, replacement: str) -> str:
    start = source.find(marker)
    if start == -1:
        raise SystemExit(f"Cannot find event handler marker: {marker}")
    end = source.find("\n});", start)
    if end == -1:
        raise SystemExit(f"Cannot find end of event handler: {marker}")
    end += len("\n});")
    return source[:start] + replacement + source[end:]

# Settings type
text = re.sub(
    r"type SafeBoxSettings\s*=\s*\{.*?\};",
    """type SafeBoxSettings = {
  defaultVisibleName: string;
  useGlobalCode: boolean;
  globalSenderLabel: string;
  defaultAccessProfile: string;
};""",
    text,
    count=1,
    flags=re.S
)

# Global code key and functions
text = re.sub(
    r'const\s+SESSION_CODE_KEY\s*=\s*"[^"]+";',
    'const GLOBAL_CODE_SESSION_KEY = "safebox.globalCode.session.v1";',
    text
)
if "const GLOBAL_CODE_SESSION_KEY" not in text:
    settings_key_marker = 'const SETTINGS_KEY'
    idx = text.find(settings_key_marker)
    if idx != -1:
        line_end = text.find("\n", idx)
        text = text[:line_end+1] + 'const GLOBAL_CODE_SESSION_KEY = "safebox.globalCode.session.v1";\n' + text[line_end+1:]

text = text.replace("SESSION_CODE_KEY", "GLOBAL_CODE_SESSION_KEY")

if "function getSessionCode" in text:
    text = replace_function(text, "getSessionCode", """function getGlobalCode(): string {
  return sessionStorage.getItem(GLOBAL_CODE_SESSION_KEY) || "";
}""")
if "function setSessionCode" in text:
    text = replace_function(text, "setSessionCode", """function setGlobalCode(code: string) {
  if (code.trim()) {
    sessionStorage.setItem(GLOBAL_CODE_SESSION_KEY, code.trim());
  } else {
    sessionStorage.removeItem(GLOBAL_CODE_SESSION_KEY);
  }
}""")

# If already global functions missing, add them near settings key.
if "function getGlobalCode" not in text:
    insert_after = text.find('const GLOBAL_CODE_SESSION_KEY')
    line_end = text.find("\n", insert_after)
    text = text[:line_end+1] + """
function getGlobalCode(): string {
  return sessionStorage.getItem(GLOBAL_CODE_SESSION_KEY) || "";
}

function setGlobalCode(code: string) {
  if (code.trim()) {
    sessionStorage.setItem(GLOBAL_CODE_SESSION_KEY, code.trim());
  } else {
    sessionStorage.removeItem(GLOBAL_CODE_SESSION_KEY);
  }
}

""" + text[line_end+1:]

text = text.replace("getSessionCode()", "getGlobalCode()")
text = text.replace("setSessionCode(", "setGlobalCode(")
text = text.replace("settingsUseSessionCode", "settingsUseGlobalCode")
text = text.replace("settingsSessionCode", "settingsGlobalCode")
text = text.replace("useSessionCode", "useGlobalCode")

# Public cleaners
if "function cleanPublicInput(" not in text:
    marker = "function sanitizeVisibleName(value: string): string"
    idx = text.find(marker)
    if idx == -1:
        raise SystemExit("Cannot find sanitizeVisibleName")
    brace = text.find("{", idx)
    depth = 0
    end = None
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit("Cannot find sanitizeVisibleName end")
    text = text[:end] + """

function cleanPublicInput(value: string): string {
  return (value || "")
    .trim()
    .replace(/[\\r\\n\\0]/g, " ")
    .replace(/\\s+/g, " ")
    .slice(0, 120);
}

function cleanPublicNote(value: string): string {
  return cleanPublicInput(value).slice(0, 180);
}
""" + text[end:]

# read/write settings
text = replace_function(text, "readSettings", """function readSettings(): SafeBoxSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) {
      return {
        defaultVisibleName: "document",
        useGlobalCode: false,
        globalSenderLabel: "",
        defaultAccessProfile: ""
      };
    }

    const parsed = JSON.parse(raw) as Partial<SafeBoxSettings> & { useSessionCode?: boolean };

    return {
      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || "document"),
      useGlobalCode: Boolean(parsed.useGlobalCode ?? parsed.useSessionCode),
      globalSenderLabel: cleanPublicInput((parsed as any).globalSenderLabel || ""),
      defaultAccessProfile: cleanPublicInput((parsed as any).defaultAccessProfile || "")
    };
  } catch {
    return {
      defaultVisibleName: "document",
      useGlobalCode: false,
      globalSenderLabel: "",
      defaultAccessProfile: ""
    };
  }
}""")

text = replace_function(text, "writeSettings", """function writeSettings(settings: SafeBoxSettings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify({
    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || "document"),
    useGlobalCode: Boolean(settings.useGlobalCode),
    globalSenderLabel: cleanPublicInput(settings.globalSenderLabel || ""),
    defaultAccessProfile: cleanPublicInput(settings.defaultAccessProfile || "")
  }));
}""")

# Force replace the Settings modal fields area from Default SBX name until settings note.
settings_fields = """        <label>
          Default SBX name
          <input id="settingsDefaultName" autocomplete="off" />
        </label>

        <label>
          Global sender label
          <input id="settingsGlobalSenderLabel" placeholder="Martina / Noureddine / Team" autocomplete="off" />
        </label>

        <label>
          Default access profile
          <input id="settingsDefaultAccessProfile" placeholder="Family / Work / Private" autocomplete="off" />
        </label>

        <label class="checkline settings-check">
          <input id="settingsUseGlobalCode" type="checkbox" />
          Use global code by default
        </label>

        <label id="settingsGlobalCodeBox">
          Global code
          <div class="password-action-row">
            <input id="settingsGlobalCode" type="password" placeholder="kept only for this app session" autocomplete="new-password" />
            <button id="toggleGlobalCodeBtn" class="mini-btn" type="button">Show</button>
          </div>
        </label>

        <button id="clearGlobalCodeBtn" class="secondary-link danger-link" type="button">Clear global code</button>

        <p class="settings-note">
          MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.
        </p>"""

pattern = re.compile(
    r"""        <label>\s*
          Default SBX name\s*
          <input id="settingsDefaultName"[^>]* />\s*
        </label>.*?<p class="settings-note">.*?</p>""",
    re.S
)
text, n = pattern.subn(settings_fields, text, count=1)
if n == 0:
    raise SystemExit("Could not replace Settings modal fields. Please send grep -n -A80 -B10 'settingsDefaultName' src/main.ts")

# open/close/apply functions
text = replace_function(text, "applySettingsToUi", """function applySettingsToUi() {
  settings = readSettings();
  const visibleName = sanitizeVisibleName(settings.defaultVisibleName || "document");
  setInput("#visibleName", visibleName);
  setInput("#senderLabel", settings.globalSenderLabel || "");
  setInput("#accessProfile", settings.defaultAccessProfile || "");

  if (settings.useGlobalCode) {
    const code = getGlobalCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}""")

text = replace_function(text, "openSettings", """function openSettings() {
  settings = readSettings();
  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  setInput("#settingsGlobalSenderLabel", settings.globalSenderLabel || "");
  setInput("#settingsDefaultAccessProfile", settings.defaultAccessProfile || "");
  $<HTMLInputElement>("#settingsUseGlobalCode").checked = settings.useGlobalCode;
  setInput("#settingsGlobalCode", getGlobalCode());
  $<HTMLInputElement>("#settingsGlobalCode").type = "password";
  $("#toggleGlobalCodeBtn").textContent = "Show";
  settingsModal.classList.remove("hidden");
  settingsModal.style.display = "grid";
  setTimeout(() => $<HTMLInputElement>("#settingsDefaultName").focus(), 80);
}""")

text = replace_function(text, "closeSettings", """function closeSettings() {
  settingsModal.classList.add("hidden");
  settingsModal.style.display = "none";
}""")

# Save settings handler
text = replace_event_handler(text, '$("#saveSettingsBtn").addEventListener("click", () => {', """$("#saveSettingsBtn").addEventListener("click", () => {
  const nextSettings: SafeBoxSettings = {
    defaultVisibleName: sanitizeVisibleName(inputValue("#settingsDefaultName")),
    useGlobalCode: checked("#settingsUseGlobalCode"),
    globalSenderLabel: cleanPublicInput(inputValue("#settingsGlobalSenderLabel")),
    defaultAccessProfile: cleanPublicInput(inputValue("#settingsDefaultAccessProfile"))
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
      <span>Sender</span><code>${esc(nextSettings.globalSenderLabel || "not set")}</code>
      <span>Access</span><code>${esc(nextSettings.defaultAccessProfile || "not set")}</code>
      <span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>
    </div>
  `);
});""")

# Add toggle/clear handlers if missing
if "toggleGlobalCodeBtn" in text and '$("#toggleGlobalCodeBtn").addEventListener' not in text:
    marker = '$("#cancelSettingsBtn").addEventListener("click", closeSettings);'
    if marker in text:
        text = text.replace(marker, marker + """

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
});""")

# Final guard: remove old labels if any remain in visible modal
text = text.replace("Use session code for Create SBX", "Use global code by default")
text = text.replace("Session code", "Global code")
text = text.replace("Codes are not stored permanently in this MVP. Keychain storage comes later.", "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.")

p.write_text(text)
print("Settings modal repaired.")
PY

cat >> src/style.css <<'CSS'

/* Sprint 7A Repair — Settings modal */
.hidden { display: none !important; }
.modal-backdrop.hidden { display: none !important; }

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
CSS

echo "==> Verify repaired Settings modal"
grep -n "Global sender label" src/main.ts
grep -n "Default access profile" src/main.ts
grep -n "Use global code by default" src/main.ts
grep -n "settingsGlobalSenderLabel" src/main.ts
grep -n "settingsDefaultAccessProfile" src/main.ts

echo ""
echo "Done."
echo "Now run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  killall SafeBox 2>/dev/null || true"
echo "  killall safebox-desktop 2>/dev/null || true"
echo "  rm -rf dist"
echo "  npm run tauri dev"
