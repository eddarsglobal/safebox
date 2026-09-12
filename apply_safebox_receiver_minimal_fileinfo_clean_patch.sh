#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src/main.ts "src/main.ts.backup-receiver-minimal-clean.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-receiver-minimal-clean.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

# Remove main-screen identity/note divs from receiver overlay template.
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

# Force any leftover first-screen metadata targets to stay hidden.
text = re.sub(
    r'''    const identityTarget = document\.querySelector<HTMLElement>\("#hardReceiverIdentity"\);\n\s*if \(identityTarget\) \{\n.*?\n\s*}\n''',
    '''    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");
    if (identityTarget) {
      identityTarget.textContent = "";
      identityTarget.classList.add("hidden");
      identityTarget.style.display = "none";
    }
''',
    text,
    flags=re.S
)

text = re.sub(
    r'''    const noteTarget = document\.querySelector<HTMLElement>\("#hardReceiverNote"\);\n\s*if \(noteTarget\) \{\n.*?\n\s*}\n''',
    '''    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");
    if (noteTarget) {
      noteTarget.textContent = "";
      noteTarget.classList.add("hidden");
      noteTarget.style.display = "none";
    }
''',
    text,
    flags=re.S
)

# Make File info rows addressable.
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
text = text.replace(
    '<div id="hardInfoNoteRow"><span>Note</span><code id="hardInfoNote"></code></div>',
    '<div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>'
)

# Add rows if they are missing.
if 'id="hardInfoSender"' not in text:
    text = text.replace(
        '<div><span>Type</span><code>SafeBox File</code></div>',
        '<div><span>Type</span><code>SafeBox File</code></div>\n        <div id="hardInfoSenderRow"><span>From</span><code id="hardInfoSender">not set</code></div>\n        <div id="hardInfoAccessRow"><span>Access</span><code id="hardInfoAccess">not set</code></div>\n        <div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>',
        1
    )

# Replace the File info update block so empty notes are hidden, not displayed as "empty".
text = re.sub(
    r'''    const infoSender = document\.querySelector<HTMLElement>\("#hardInfoSender"\);\n\s*const infoAccess = document\.querySelector<HTMLElement>\("#hardInfoAccess"\);\n\s*const infoNote = document\.querySelector<HTMLElement>\("#hardInfoNote"\);\n\s*\n\s*if \(infoSender\).*?\n\s*if \(infoAccess\).*?\n\s*if \(infoNote\).*?\n''',
    '''    const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
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
''',
    text,
    flags=re.S
)

# Fallback in case the block was not matched.
if 'const noteRow = document.querySelector<HTMLElement>("#hardInfoNoteRow");' not in text:
    text = text.replace(
        '    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");\n\n    if (infoSender) infoSender.textContent = sender || "not set";\n    if (infoAccess) infoAccess.textContent = access || "not set";\n    if (infoNote) infoNote.textContent = note || "empty";',
        '    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");\n    const noteRow = document.querySelector<HTMLElement>("#hardInfoNoteRow");\n\n    if (infoSender) infoSender.textContent = sender || "not set";\n    if (infoAccess) infoAccess.textContent = access || "not set";\n    if (infoNote) infoNote.textContent = note;\n\n    if (noteRow) {\n      noteRow.classList.toggle("hidden", !note);\n      noteRow.style.display = note ? "" : "none";\n    }'
    )

p.write_text(text)
print("Receiver minimal + clean file info patch applied.")
PY

cat >> src/style.css <<'CSS'

/* Receiver first screen must stay minimal: no public sender/access/note outside File info */
#hardReceiverIdentity,
#hardReceiverNote {
  display: none !important;
}

/* Hide empty optional File info rows */
#hardInfoNoteRow.hidden {
  display: none !important;
}
CSS

echo "==> Verify source"
grep -n 'id="hardReceiverIdentity"' src/main.ts && echo "WARNING: hardReceiverIdentity still in template" || echo "OK: no hardReceiverIdentity template"
grep -n 'id="hardReceiverNote"' src/main.ts && echo "WARNING: hardReceiverNote still in template" || echo "OK: no hardReceiverNote template"
grep -n 'hardInfoNoteRow' src/main.ts
grep -n 'infoNote.textContent = note' src/main.ts || true
grep -n 'empty' src/main.ts || true

echo ""
echo "Done."
echo ""
echo "Now run DEV test:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  killall SafeBox 2>/dev/null || true"
echo "  killall safebox-desktop 2>/dev/null || true"
echo "  rm -rf dist node_modules/.vite"
echo "  npm run build"
echo "  npm run tauri dev"
