#!/usr/bin/env bash
set -euo pipefail

# SafeBox Hardfix — Receiver metadata block parse error
#
# Replaces the entire broken block:
#   async function loadReceiverPublicInfo(...)
# up to:
#   function showHardReceiverOverlay(...)
#
# This removes orphan catch blocks left by previous patches.
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_hardfix_receiver_block_parse_error.sh

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and style.css"
cp src/main.ts "src/main.ts.backup-hardfix-receiver-block.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-hardfix-receiver-block.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

# Ensure cleaner helpers exist.
if "function cleanPublicInput(" not in text:
    marker = "function fileNameFromPath(path: string): string"
    idx = text.find(marker)
    if idx == -1:
        marker = "function sanitizeVisibleName(value: string): string"
        idx = text.find(marker)
    if idx == -1:
        raise SystemExit("Cannot find a safe location to insert cleanPublicInput")

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
    text = text[:end] + helper + text[end:]

start = text.find("async function loadReceiverPublicInfo")
if start == -1:
    # If missing completely, insert before showHardReceiverOverlay.
    start = text.find("function showHardReceiverOverlay")
    if start == -1:
        raise SystemExit("Cannot find loadReceiverPublicInfo or showHardReceiverOverlay")
    end = start
else:
    end = text.find("function showHardReceiverOverlay", start)
    if end == -1:
        raise SystemExit("Cannot find function showHardReceiverOverlay after loadReceiverPublicInfo")

replacement = """async function loadReceiverPublicInfo(sbxPath: string) {
  try {
    const info = await invoke<PublicInfo>("read_sbx_public_info", { sbxPath });

    const name = info.visible_file_name || fileNameFromPath(sbxPath) || "document.sbx";
    const sender = cleanPublicInput(info.sender_label || "");
    const access = cleanPublicInput(info.access_profile || "");
    const note = cleanPublicNote(info.public_note || "");

    [
      document.querySelector<HTMLElement>("#hardReceiverFile"),
      document.querySelector<HTMLElement>("#receiverFileName"),
      document.querySelector<HTMLElement>("#fileInfoName")
    ].forEach((target) => {
      if (target) target.textContent = name;
    });

    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");
    if (identityTarget) {
      identityTarget.textContent = "";
      identityTarget.classList.add("hidden");
      identityTarget.style.display = "none";
    }

    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");
    if (noteTarget) {
      noteTarget.textContent = "";
      noteTarget.classList.add("hidden");
      noteTarget.style.display = "none";
    }

    const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
    const infoAccess = document.querySelector<HTMLElement>("#hardInfoAccess");
    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");
    const noteRow = document.querySelector<HTMLElement>("#hardInfoNoteRow");

    if (infoSender) infoSender.textContent = sender || "not set";
    if (infoAccess) infoAccess.textContent = access || "not set";
    if (infoNote) infoNote.textContent = note;

    if (noteRow) {
      noteRow.classList.toggle("hidden", !note);
      noteRow.style.display = note ? "" : "none";
    }
  } catch (error) {
    console.warn("SafeBox public metadata not available:", error);
  }
}

"""

text = text[:start] + replacement + text[end:]

# Remove public metadata from main receiver screen template.
text = re.sub(
    r'\n\s*<div id="hardReceiverIdentity" class="hard-receiver-identity hidden"></div>\s*',
    '\n',
    text
)
text = re.sub(
    r'\n\s*<div id="hardReceiverNote" class="hard-receiver-note hidden"></div>\s*',
    '\n',
    text
)

# Normalize File info rows.
text = text.replace(
    '<div><span>From</span><code id="hardInfoSender">not set</code></div>',
    '<div id="hardInfoSenderRow"><span>From</span><code id="hardInfoSender">not set</code></div>'
)
text = text.replace(
    '<div><span>Access</span><code id="hardInfoAccess">not set</code></div>',
    '<div id="hardInfoAccessRow"><span>Access</span><code id="hardInfoAccess">not set</code></div>'
)
text = text.replace(
    '<div><span>Note</span><code id="hardInfoNote">empty</code></div>',
    '<div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>'
)
text = text.replace(
    '<div id="hardInfoNoteRow"><span>Note</span><code id="hardInfoNote">empty</code></div>',
    '<div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>'
)

# Add missing File info rows if absent.
if 'id="hardInfoSender"' not in text:
    text = text.replace(
        '<div><span>Type</span><code>SafeBox File</code></div>',
        '<div><span>Type</span><code>SafeBox File</code></div>\n        <div id="hardInfoSenderRow"><span>From</span><code id="hardInfoSender">not set</code></div>\n        <div id="hardInfoAccessRow"><span>Access</span><code id="hardInfoAccess">not set</code></div>\n        <div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>',
        1
    )

p.write_text(text)
print("Receiver block hardfixed.")
PY

cat >> src/style.css <<'CSS'

/* Hardfix — Receiver first screen must stay minimal */
#hardReceiverIdentity,
#hardReceiverNote {
  display: none !important;
}

/* Hardfix — hide optional Note row when no public note exists */
#hardInfoNoteRow.hidden {
  display: none !important;
}
CSS

echo "==> Check around receiver block"
nl -ba src/main.ts | sed -n '720,805p'

echo ""
echo "==> TypeScript/Vite build check"
npm run build

echo ""
echo "Hardfix applied."
echo "Run:"
echo "  npm run tauri dev"
