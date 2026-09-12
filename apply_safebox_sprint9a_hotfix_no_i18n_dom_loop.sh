#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A Hotfix — Remove i18n DOM loop
#
# Problem:
# Sprint 9A added a MutationObserver that can trigger sbxApplyI18n repeatedly.
# This can freeze/block Settings and Help.
#
# Fix:
# - Remove the global MutationObserver.
# - Keep i18n applied on startup.
# - Keep i18n applied when Settings opens.
# - Help button still opens Help and renders content.
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint9a_hotfix_no_i18n_dom_loop.sh

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts"
cp src/main.ts "src/main.ts.backup-sprint9a-hotfix-no-dom-loop.$(date +%Y%m%d%H%M%S)"

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

start = text.find('new MutationObserver(() => {')
if start != -1:
    end = text.find('}).observe(document.body, {', start)
    if end == -1:
        raise SystemExit("Found MutationObserver start but not observe block")
    end2 = text.find('});', end)
    if end2 == -1:
        raise SystemExit("Found observe block but not closing });")
    end2 += len('});')
    text = text[:start] + '''
// Sprint 9A hotfix:
// Removed global MutationObserver to avoid recursive DOM/i18n loops.
// i18n is applied on startup, Settings open, Help open, and language change.
''' + text[end2:]
    print("Removed Sprint 9A global MutationObserver")
else:
    print("No global MutationObserver block found, continuing")

if "SAFEBOX_I18N_NO_DOM_LOOP_HOTFIX_MARKER" not in text:
    text += r'''

function SAFEBOX_I18N_NO_DOM_LOOP_HOTFIX_MARKER() {
  return "i18n-no-global-dom-observer";
}

console.debug(SAFEBOX_I18N_NO_DOM_LOOP_HOTFIX_MARKER());
'''

p.write_text(text)
PY

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify hotfix marker"
grep -R "i18n-no-global-dom-observer" dist || echo "ERROR: hotfix marker absent from dist"

echo ""
echo "Sprint 9A hotfix applied."
echo "Run:"
echo "  npm run tauri dev"
