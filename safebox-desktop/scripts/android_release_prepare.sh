#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
cd "$D"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
if [ -z "${NDK_HOME:-}" ]; then
  NDK_VER="$(ls -1 "$ANDROID_HOME/ndk" 2>/dev/null | sort -V | tail -n1)"
  export NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"
fi
bash scripts/android_release_doctor.sh
GEN=src-tauri/gen/android
if [ ! -f "$GEN/gradlew" ]; then
  rm -rf "$GEN"
  npm run tauri -- android init
fi
bash scripts/install_android_launcher_icon.sh
bash scripts/android_release_fix_tauri_buildtask.sh
APP="$GEN/app/build.gradle.kts"
[ -f "$APP" ] || { echo "SAFEBOX_ANDROID_R86_PREPARE_FAIL: $APP missing" >&2; exit 1; }
python3 - "$APP" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
orig=s
# Current and older Android Gradle Plugin syntaxes.
s=re.sub(r'compileSdk\s*=\s*\d+', 'compileSdk = 36', s)
s=re.sub(r'compileSdkVersion\s*\(?\s*\d+\s*\)?', 'compileSdk = 36', s)
s=re.sub(r'targetSdk\s*=\s*\d+', 'targetSdk = 36', s)
s=re.sub(r'targetSdkVersion\s*\(?\s*\d+\s*\)?', 'targetSdk = 36', s)
# Tauri templates can source values from project properties. If literals were absent,
# inject target/compile SDK directly in android/defaultConfig blocks.
if not re.search(r'compileSdk\s*=\s*36', s):
    s=re.sub(r'(android\s*\{)', r'\1\n    compileSdk = 36', s, count=1)
if not re.search(r'targetSdk\s*=\s*36', s):
    s=re.sub(r'(defaultConfig\s*\{)', r'\1\n        targetSdk = 36', s, count=1)
p.write_text(s)
if s==orig:
    print('SAFEBOX_ANDROID_R86_GRADLE_ALREADY_ALIGNED')
PY
grep -Eq 'compileSdk\s*=\s*36' "$APP" || { echo 'SAFEBOX_ANDROID_R86_PREPARE_FAIL: compileSdk 36 missing' >&2; exit 1; }
grep -Eq 'targetSdk\s*=\s*36' "$APP" || { echo 'SAFEBOX_ANDROID_R86_PREPARE_FAIL: targetSdk 36 missing' >&2; exit 1; }
echo 'SAFEBOX_ANDROID_R86_API36_GRADLE_PASS'
echo 'SAFEBOX_ANDROID_R86_PROJECT_PREPARE_PASS'
