#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src/main.ts "src/main.ts.backup-parse-error-receiver.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-parse-error-receiver.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

def replace_function(source: str, signature_start: str, replacement: str) -> str:
    start = source.find(signature_start)
    if start == -1:
        raise SystemExit(f"Cannot find function starting with: {signature_start}")

    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit("Cannot find opening brace")

    depth = 0
    in_str = None
    escape = False
    in_line_comment = False
    in_block_comment = False

    i = brace
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == in_str:
                in_str = None
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue

        if ch in ("'", '"', "`"):
            in_str = ch
            i += 1
            continue

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[:start] + replacement + source[i + 1:]

        i += 1

    raise SystemExit("Cannot find function end")

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

    // Receiver first screen must remain minimal.
    // Sender/access/note are visible only inside File info.
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

text = replace_function(text, "async function loadReceiverPublicInfo", replacement)

# Remove main-screen metadata placeholders from the receiver overlay template.
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

# Make File info rows addressable and hide Note by default.
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

# If File info rows are missing, insert them after Type.
if 'id="hardInfoSender"' not in text:
    text = text.replace(
        '<div><span>Type</span><code>SafeBox File</code></div>',
        '<div><span>Type</span><code>SafeBox File</code></div>\\n        <div id="hardInfoSenderRow"><span>From</span><code id="hardInfoSender">not set</code></div>\\n        <div id="hardInfoAccessRow"><span>Access</span><code id="hardInfoAccess">not set</code></div>\\n        <div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>',
        1
    )

text = text.replace('\\n        <div id="hardInfoSenderRow"', '\n        <div id="hardInfoSenderRow"')
text = text.replace('\\n        <div id="hardInfoAccessRow"', '\n        <div id="hardInfoAccessRow"')
text = text.replace('\\n        <div id="hardInfoNoteRow"', '\n        <div id="hardInfoNoteRow"')

p.write_text(text)
print("loadReceiverPublicInfo repaired.")
PY

cat >> src/style.css <<'CSS'

/* Receiver first screen must stay minimal */
#hardReceiverIdentity,
#hardReceiverNote {
  display: none !important;
}

/* Hide empty optional File info rows */
#hardInfoNoteRow.hidden {
  display: none !important;
}
CSS

echo "==> Verify syntax build"
npm run build

echo ""
echo "==> Verify source markers"
grep -n 'async function loadReceiverPublicInfo' src/main.ts
grep -n 'hardInfoNoteRow' src/main.ts
grep -n 'hardReceiverIdentity' src/main.ts || true
grep -n 'hardReceiverNote' src/main.ts || true
grep -n 'empty' src/main.ts || true

echo ""
echo "Hotfix applied."
echo "Now run:"
echo "  npm run tauri dev"
