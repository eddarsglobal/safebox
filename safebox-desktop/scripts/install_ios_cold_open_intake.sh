#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAURI_DIR="$APP_DIR/src-tauri"
APPLE_DIR="$TAURI_DIR/gen/apple"
BRIDGE="$TAURI_DIR/ios/SafeBoxColdOpenBridge.mm"

[[ "$(uname -s)" == 'Darwin' ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: macOS required' >&2; exit 171; }
[[ -d "$APPLE_DIR" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: generated Apple project missing' >&2; exit 172; }
[[ -f "$BRIDGE" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: canonical cold-open bridge missing' >&2; exit 173; }

# R56: iOS document registration is installed explicitly into the generated
# application Info.plist. Tauri fileAssociations remains useful to desktop
# platforms, but is not trusted as the iOS LaunchServices source of truth.
CANONICAL_REGISTRATION="$TAURI_DIR/ios/SafeBoxDocumentRegistration.plist"
PATCHER="$SCRIPT_DIR/ios_sbx_document_registration_patch.py"
CONTRACT_CHECKER="$SCRIPT_DIR/ios_sbx_document_contract_check.py"
[[ -f "$CANONICAL_REGISTRATION" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: canonical SBX document registration missing' >&2; exit 177; }
[[ -x "$PATCHER" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: SBX registration patcher missing' >&2; exit 178; }
[[ -x "$CONTRACT_CHECKER" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: SBX document contract checker missing' >&2; exit 179; }

GENERATED_INFO="$(python3 - "$APPLE_DIR" <<'PYINFO'
from pathlib import Path
import sys
root=Path(sys.argv[1])
candidates=sorted(p / 'Info.plist' for p in root.iterdir() if p.is_dir() and p.name.endswith('_iOS') and (p / 'Info.plist').is_file())
if len(candidates) != 1:
    raise SystemExit(1)
print(candidates[0])
PYINFO
)" || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: expected exactly one generated iOS app Info.plist' >&2; exit 180; }
[[ -f "$GENERATED_INFO" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: generated iOS app Info.plist missing' >&2; exit 181; }
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_PATCH_BEGIN'
python3 "$PATCHER" "$CANONICAL_REGISTRATION" "$GENERATED_INFO"
python3 "$CONTRACT_CHECKER" "$GENERATED_INFO" || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: generated SBX document contract invalid after R56 patch' >&2; exit 182; }
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_DOCUMENT_CONTRACT_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_INSTALL_PASS'

MAIN_MM="$(find "$APPLE_DIR/Sources" -name main.mm -type f -print -quit 2>/dev/null || true)"
[[ -n "$MAIN_MM" && -f "$MAIN_MM" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: generated main.mm missing' >&2; exit 174; }

INCLUDE_LINE='#include "../../../../ios/SafeBoxColdOpenBridge.mm"'
if ! grep -Fq "$INCLUDE_LINE" "$MAIN_MM"; then
  tmp="$MAIN_MM.safebox-cold-open.$$"
  { printf '%s\n' "$INCLUDE_LINE"; cat "$MAIN_MM"; } > "$tmp"
  mv -f "$tmp" "$MAIN_MM"
fi

if ! grep -Fq 'SBXColdOpenInstall();' "$MAIN_MM"; then
  python3 - "$MAIN_MM" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
pat=re.compile(r'^(?P<i>[ \t]*)(?P<c>(?:ffi::)?start_app\(\);)[ \t]*$',re.M)
m=pat.search(s)
if not m: raise SystemExit('SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: generated start_app call not found')
r=f"{m.group('i')}SBXColdOpenInstall();\n{m.group('i')}{m.group('c')}"
p.write_text(s[:m.start()]+r+s[m.end():])
PY
fi

grep -Fq "$INCLUDE_LINE" "$MAIN_MM" || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: bridge include missing' >&2; exit 175; }
grep -Fq 'SBXColdOpenInstall();' "$MAIN_MM" || { echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_FAIL: install call missing' >&2; exit 176; }

# Both hooks must be installed before start_app(). Do not alter R52 ordering.
python3 - "$MAIN_MM" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
start=s.find('start_app();')
if start < 0: start=s.find('ffi::start_app();')
if start < 0: raise SystemExit(1)
for marker in ('SBXShareInboxRegisterNativeBridge();','SBXColdOpenInstall();'):
    pos=s.find(marker)
    if pos < 0 or pos > start: raise SystemExit(1)
PY

echo 'SAFEBOX_IOS_COLD_OPEN_MAIN_WIRING_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_INSTALL_PASS'
