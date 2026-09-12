#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src/main.ts "src/main.ts.backup-sprint7a-fileinfo-only.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint7a-fileinfo-only.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

# Keep public metadata only for File info. Hide/remove first-screen metadata placeholders.
text = re.sub(
    r'    const identityTarget = document\.querySelector<HTMLElement>\("#hardReceiverIdentity"\);\n'
    r'    if \(identityTarget\) \{\n'
    r'      identityTarget\.textContent = identity;\n'
    r'      identityTarget\.classList\.toggle\("hidden", !identity\);\n'
    r'    \}',
    '    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");\n'
    '    if (identityTarget) {\n'
    '      identityTarget.textContent = "";\n'
    '      identityTarget.classList.add("hidden");\n'
    '    }',
    text
)

text = re.sub(
    r'    const noteTarget = document\.querySelector<HTMLElement>\("#hardReceiverNote"\);\n'
    r'    if \(noteTarget\) \{\n'
    r'      noteTarget\.textContent = note;\n'
    r'      noteTarget\.classList\.toggle\("hidden", !note\);\n'
    r'    \}',
    '    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");\n'
    '    if (noteTarget) {\n'
    '      noteTarget.textContent = "";\n'
    '      noteTarget.classList.add("hidden");\n'
    '    }',
    text
)

# Remove main-screen identity/note divs from overlay template.
text = re.sub(
    r'\n\s*<div id="hardReceiverIdentity" class="hard-receiver-identity hidden"></div>\s*\n\s*<div id="hardReceiverNote" class="hard-receiver-note hidden"></div>',
    '',
    text
)

# Ensure File info rows remain available.
if 'id="hardInfoSender"' not in text:
    text = text.replace(
        '<div><span>Name</span><code>${esc(name)}</code></div>\n        <div><span>Type</span><code>SafeBox File</code></div>',
        '<div><span>Name</span><code>${esc(name)}</code></div>\n        <div><span>Type</span><code>SafeBox File</code></div>\n        <div><span>From</span><code id="hardInfoSender">not set</code></div>\n        <div><span>Access</span><code id="hardInfoAccess">not set</code></div>\n        <div><span>Note</span><code id="hardInfoNote">empty</code></div>'
    )

p.write_text(text)
print("Receiver metadata moved to File info only.")
PY

cat >> src/style.css <<'CSS'

/* Sprint 7A Hotfix — keep receiver first screen minimal */
#hardReceiverIdentity,
#hardReceiverNote {
  display: none !important;
}
CSS

echo "==> Verify"
grep -n "hardInfoSender" src/main.ts || echo "WARNING: hardInfoSender missing"
grep -n "hardInfoAccess" src/main.ts || echo "WARNING: hardInfoAccess missing"
grep -n "hardInfoNote" src/main.ts || echo "WARNING: hardInfoNote missing"
grep -n "hardReceiverIdentity" src/main.ts || true
grep -n "hardReceiverNote" src/main.ts || true

echo ""
echo "Done."
echo "Run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  rm -rf dist"
echo "  npm run tauri dev"
echo ""
echo "For installed app / Finder double click:"
echo "  npm run tauri build"
echo "  rm -rf /Applications/SafeBox.app"
echo "  cp -R \"$ROOT/target/release/bundle/macos/SafeBox.app\" /Applications/SafeBox.app"
