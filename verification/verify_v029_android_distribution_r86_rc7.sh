#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"

bash "$ROOT/verification/verify_v029_android_distribution_r86_rc6.sh"

python3 - "$D/src-tauri/tauri.android.conf.json" "$D/src/main.ts" "$D/src/landing.ts" "$D/src/landing.css" "$D/src/style.css" "$D/public/legal/legal.css" "$D/public/legal/legal.js" <<'PY'
from pathlib import Path
import json,sys
conf=json.loads(Path(sys.argv[1]).read_text())
main=Path(sys.argv[2]).read_text()
landing=Path(sys.argv[3]).read_text()
landing_css=Path(sys.argv[4]).read_text()
app_css=Path(sys.argv[5]).read_text()
legal_css=Path(sys.argv[6]).read_text()
legal_js=Path(sys.argv[7]).read_text()

assoc=conf['bundle']['fileAssociations'][0]
assert assoc['ext']==['sbx']
assert assoc['mimeType']=='application/x-safebox'
assert 'view' in assoc['androidIntentActionFilters']
print('SAFEBOX_R86_RC7_SBX_DEDICATED_MIME_ASSOCIATION_PASS')

for marker in ['sbx: "application/x-safebox"','png: "image/png"','jpg: "image/jpeg"','pdf: "application/pdf"']:
    assert marker in main
assert 'const destinationName = androidCollisionSafeSuggestedName(cleanSuggestedName);' in main
assert 'filters: saveDialogFiltersForName(destinationName)' in main
assert 'return `${base}-restored${suffix}`;' in main
assert 'extensions: [mime]' in main
print('SAFEBOX_R86_RC7_ANDROID_RESTORE_MIME_PASS')
print('SAFEBOX_R86_RC7_ANDROID_EXTENSION_SEMANTICS_PASS')

assert 'SAFEBOX_SHARED_THEME_KEY = "safebox-theme-mode.v1"' in landing
assert 'localStorage.setItem(SAFEBOX_SHARED_THEME_KEY,theme)' in landing
assert 'SafeBox R86 RC7 — dedicated high-contrast light palette' in landing_css
assert ':root[data-theme="light"] .stage-rail span' in landing_css
assert ':root[data-theme="light"] .download-card' in landing_css
assert 'SafeBox R86 RC7 — final light-mode contrast closure' in app_css
assert ':root[data-theme="light"] input' in app_css
print('SAFEBOX_R86_RC7_LIGHT_MODE_CONTRAST_PASS')

assert '--legal-bg:' in legal_css
assert ':root[data-theme="light"]' in legal_css
assert ':root[data-theme="dark"]' in legal_css
assert ':root[data-theme="system"]' in legal_css
assert 'SAFEBOX_THEME_MODE_KEY="safebox-theme-mode.v1"' in legal_js
assert 'themeSel.id="legalTheme"' in legal_js
assert 'applyLegalTheme()' in legal_js
print('SAFEBOX_R86_RC7_LEGAL_THEME_SYNC_PASS')
PY

node --check "$D/public/legal/legal.js"
bash -n "$D/scripts/android_release_prepare.sh"
bash -n "$D/scripts/android_release_build.sh"

echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC7_PASS'
