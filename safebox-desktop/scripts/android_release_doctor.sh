#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
cd "$D"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
fail(){ echo "SAFEBOX_ANDROID_R86_DOCTOR_FAIL: $*" >&2; exit 1; }
[ -x "$JAVA_HOME/bin/java" ] || fail "JAVA_HOME invalid: $JAVA_HOME"
[ -d "$ANDROID_HOME" ] || fail "ANDROID_HOME missing: $ANDROID_HOME"
[ -f "$ANDROID_HOME/platforms/android-36/android.jar" ] || fail "Android 16 / API 36 SDK Platform missing. Install Android SDK Platform 36 in Android Studio > SDK Manager."
[ -d "$ANDROID_HOME/platform-tools" ] || fail "platform-tools missing"
[ -d "$ANDROID_HOME/build-tools" ] || fail "build-tools missing"
[ -d "$ANDROID_HOME/ndk" ] || fail "NDK missing"
command -v rustup >/dev/null || fail "rustup missing"
for t in aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android; do
  rustup target list --installed | grep -Fxq "$t" || fail "Rust Android target missing: $t"
done
[ -x node_modules/.bin/tauri ] || fail "node_modules missing; run npm ci"
python3 - <<'PY'
from pathlib import Path
import json
p=Path('src-tauri/tauri.android.conf.json')
d=json.loads(p.read_text())
assert d.get('identifier')=='com.safebox.desktop', d.get('identifier')
assert d.get('version')=='0.2.9', d.get('version')
a=d.get('bundle',{}).get('android',{})
assert a.get('versionCode')==2009, a
assert a.get('minSdkVersion')==24, a
print('SAFEBOX_ANDROID_R86_ID_VERSION_PASS')
PY
echo "SAFEBOX_ANDROID_R86_API36_SDK_PASS"
echo "SAFEBOX_ANDROID_R86_TOOLCHAIN_PASS"
echo "SAFEBOX_ANDROID_R86_DOCTOR_PASS"
