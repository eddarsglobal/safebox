#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src/main.ts "src/main.ts.backup-sprint7a-hotfix.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint7a-hotfix.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "type PublicInfo" not in text:
    text = text.replace(
        "type SbxOpenPayload = string;",
        """type SbxOpenPayload = string;

type PublicInfo = {
  visible_file_name: string;
  sender_label?: string | null;
  access_profile?: string | null;
  public_note?: string | null;
};"""
    )

if "function cleanPublicInput(" not in text:
    marker = "function fileNameFromPath(path: string): string {"
    helper = """
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

"""
    if marker not in text:
        raise SystemExit("Cannot find fileNameFromPath")
    text = text.replace(marker, helper + marker)

if "async function loadReceiverPublicInfo" not in text:
    marker = "function showHardReceiverOverlay(sbxPath: string) {"
    helper = """
async function loadReceiverPublicInfo(sbxPath: string) {
  try {
    const info = await invoke<PublicInfo>("read_sbx_public_info", { sbxPath });

    const name = info.visible_file_name || fileNameFromPath(sbxPath) || "document.sbx";
    const sender = cleanPublicInput(info.sender_label || "");
    const access = cleanPublicInput(info.access_profile || "");
    const note = cleanPublicNote(info.public_note || "");
    const identity = [sender, access].filter(Boolean).join(" · ");

    [
      document.querySelector<HTMLElement>("#hardReceiverFile"),
      document.querySelector<HTMLElement>("#receiverFileName"),
      document.querySelector<HTMLElement>("#fileInfoName")
    ].forEach(target => {
      if (target) target.textContent = name;
    });

    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");
    if (identityTarget) {
      identityTarget.textContent = identity;
      identityTarget.classList.toggle("hidden", !identity);
    }

    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");
    if (noteTarget) {
      noteTarget.textContent = note;
      noteTarget.classList.toggle("hidden", !note);
    }

    const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
    const infoAccess = document.querySelector<HTMLElement>("#hardInfoAccess");
    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");

    if (infoSender) infoSender.textContent = sender || "not set";
    if (infoAccess) infoAccess.textContent = access || "not set";
    if (infoNote) infoNote.textContent = note || "empty";
  } catch (error) {
    console.warn("SafeBox public metadata not available:", error);
  }
}

"""
    if marker not in text:
        raise SystemExit("Cannot find showHardReceiverOverlay")
    text = text.replace(marker, helper + marker)

if 'id="hardReceiverIdentity"' not in text:
    text = text.replace(
        '<div class="hard-receiver-file">${esc(name)}</div>',
        '<div id="hardReceiverFile" class="hard-receiver-file">${esc(name)}</div>\\n\\n      <div id="hardReceiverIdentity" class="hard-receiver-identity hidden"></div>\\n      <div id="hardReceiverNote" class="hard-receiver-note hidden"></div>'
    )

text = text.replace('\\n\\n      <div id="hardReceiverIdentity"', '\n\n      <div id="hardReceiverIdentity"')
text = text.replace('</div>\\n      <div id="hardReceiverNote"', '</div>\n      <div id="hardReceiverNote"')

if 'id="hardInfoSender"' not in text:
    text = text.replace(
        """<div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>""",
        """<div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>
        <div><span>From</span><code id="hardInfoSender">not set</code></div>
        <div><span>Access</span><code id="hardInfoAccess">not set</code></div>
        <div><span>Note</span><code id="hardInfoNote">empty</code></div>"""
    )

if "loadReceiverPublicInfo(sbxPath);" not in text:
    focus_block = """  setTimeout(() => {
    codeInput?.focus();
  }, 80);"""
    if focus_block not in text:
        raise SystemExit("Cannot find receiver focus block")
    text = text.replace(
        focus_block,
        """  loadReceiverPublicInfo(sbxPath);

  setTimeout(() => {
    codeInput?.focus();
  }, 80);""",
        1
    )

p.write_text(text)
print("Frontend metadata display patched.")
PY

cat >> src/style.css <<'CSS'

/* Sprint 7A Hotfix — receiver public metadata display */
.hard-receiver-identity {
  margin-top: -6px;
  color: #F8FBFF;
  font-weight: 950;
  letter-spacing: -0.01em;
  word-break: break-word;
}

.hard-receiver-note {
  margin-top: -8px;
  color: #8EA7C2;
  font-weight: 750;
  line-height: 1.4;
  word-break: break-word;
}

.hard-receiver-info > div {
  grid-template-columns: 74px minmax(0, 1fr);
}
CSS

grep -n "read_sbx_public_info" src-tauri/src/lib.rs >/dev/null || {
  echo "ERROR: read_sbx_public_info not found. Reapply Sprint 7A full patch."
  exit 1
}

grep -n "hardReceiverIdentity" src/main.ts
grep -n "hardInfoSender" src/main.ts
grep -n "loadReceiverPublicInfo" src/main.ts

echo "Hotfix applied. Run: cd safebox-desktop && npm run tauri dev"
echo "Important: create a NEW .sbx after this fix."
