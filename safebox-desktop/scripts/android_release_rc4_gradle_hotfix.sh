#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
cd "$D"
APP="src-tauri/gen/android/app/build.gradle.kts"
[ -f "$APP" ] || { echo "SAFEBOX_ANDROID_R86_RC4_HOTFIX_FAIL: $APP missing; run android_release_prepare.sh first" >&2; exit 1; }
python3 - "$APP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
imports=(
    'import java.util.Properties as SafeBoxProperties\n'
    'import java.io.FileInputStream as SafeBoxFileInputStream\n'
)
if 'import java.util.Properties as SafeBoxProperties' not in s:
    s=imports+s
s=s.replace('val props = java.util.Properties()', 'val props = SafeBoxProperties()')
s=s.replace('props.load(java.io.FileInputStream(f))', 'props.load(SafeBoxFileInputStream(f))')
s=s.replace('val props = Properties()', 'val props = SafeBoxProperties()')
s=s.replace('props.load(FileInputStream(f))', 'props.load(SafeBoxFileInputStream(f))')
p.write_text(s)
PY
grep -Fq 'import java.util.Properties as SafeBoxProperties' "$APP"
grep -Fq 'import java.io.FileInputStream as SafeBoxFileInputStream' "$APP"
grep -Fq 'val props = SafeBoxProperties()' "$APP"
grep -Fq 'props.load(SafeBoxFileInputStream(f))' "$APP"
echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_DSL_SHADOWING_FIX_PASS'
