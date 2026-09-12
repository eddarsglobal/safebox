#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$D/.." && pwd)"
cd "$D"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
if [ -z "${NDK_HOME:-}" ]; then NDK_VER="$(ls -1 "$ANDROID_HOME/ndk" | sort -V | tail -n1)"; export NDK_HOME="$ANDROID_HOME/ndk/$NDK_VER"; fi
bash scripts/android_release_prepare.sh
[ -f src-tauri/gen/android/keystore.properties ] || { echo 'SAFEBOX_ANDROID_R86_BUILD_FAIL: run scripts/android_release_signing_setup.sh first' >&2; exit 1; }
npm run tauri android build -- --apk
npm run tauri android build -- --aab
OUT="$ROOT/release/android"
mkdir -p "$OUT"
APK="$(find src-tauri/gen/android/app/build/outputs/apk -type f -name '*release*.apk' | sort | tail -n1)"
AAB="$(find src-tauri/gen/android/app/build/outputs/bundle -type f -name '*release*.aab' | sort | tail -n1)"
[ -n "$APK" ] && [ -f "$APK" ] || { echo 'SAFEBOX_ANDROID_R86_BUILD_FAIL: release APK missing' >&2; exit 1; }
[ -n "$AAB" ] && [ -f "$AAB" ] || { echo 'SAFEBOX_ANDROID_R86_BUILD_FAIL: release AAB missing' >&2; exit 1; }
cp "$APK" "$OUT/SafeBox-v0.2.9-universal.apk"
cp "$AAB" "$OUT/SafeBox-v0.2.9-play.aab"
(cd "$OUT" && shasum -a 256 SafeBox-v0.2.9-universal.apk SafeBox-v0.2.9-play.aab | tee SHA256SUMS.txt)
APKSIGNER="$(find "$ANDROID_HOME/build-tools" -type f -name apksigner | sort -V | tail -n1)"
if [ -x "$APKSIGNER" ]; then "$APKSIGNER" verify --verbose "$OUT/SafeBox-v0.2.9-universal.apk" >/dev/null && echo 'SAFEBOX_ANDROID_R86_APK_SIGNATURE_PASS'; fi
echo "SAFEBOX_ANDROID_R86_APK_READY: $OUT/SafeBox-v0.2.9-universal.apk"
echo "SAFEBOX_ANDROID_R86_AAB_READY: $OUT/SafeBox-v0.2.9-play.aab"
echo 'SAFEBOX_ANDROID_R86_RELEASE_BUILD_PASS'
