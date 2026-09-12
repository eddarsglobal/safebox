#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DESKTOP_DIR"

ANDROID_PROJECT_DIR="$DESKTOP_DIR/src-tauri/gen/android"
ANDROID_RES_DIR="$ANDROID_PROJECT_DIR/app/src/main/res"
ICON_SOURCE="${SAFEBOX_APP_ICON_SOURCE:-$DESKTOP_DIR/../assets/safebox-app-icon-source.png}"
STAMP_FILE="$ANDROID_PROJECT_DIR/.safebox-app-icon.sha256"

if [ ! -f "$ANDROID_PROJECT_DIR/gradlew" ] || [ ! -d "$ANDROID_PROJECT_DIR/app" ]; then
  echo "SAFEBOX_ANDROID_ICON_PROJECT_MISSING: run tauri android init first" >&2
  exit 21
fi
if [ ! -f "$ICON_SOURCE" ]; then
  echo "SAFEBOX_ANDROID_ICON_SOURCE_MISSING: $ICON_SOURCE" >&2
  exit 22
fi
bash "$DESKTOP_DIR/scripts/ensure_frontend_toolchain.sh" >/dev/null

icon_hash="$(shasum -a 256 "$ICON_SOURCE" | awk '{print $1}')"

required_icon_files() {
  cat <<'EOF'
mipmap-mdpi/ic_launcher.png
mipmap-mdpi/ic_launcher_round.png
mipmap-mdpi/ic_launcher_foreground.png
mipmap-hdpi/ic_launcher.png
mipmap-hdpi/ic_launcher_round.png
mipmap-hdpi/ic_launcher_foreground.png
mipmap-xhdpi/ic_launcher.png
mipmap-xhdpi/ic_launcher_round.png
mipmap-xhdpi/ic_launcher_foreground.png
mipmap-xxhdpi/ic_launcher.png
mipmap-xxhdpi/ic_launcher_round.png
mipmap-xxhdpi/ic_launcher_foreground.png
mipmap-xxxhdpi/ic_launcher.png
mipmap-xxxhdpi/ic_launcher_round.png
mipmap-xxxhdpi/ic_launcher_foreground.png
EOF
}

android_icons_complete() {
  local rel
  while IFS= read -r rel; do
    [ -s "$ANDROID_RES_DIR/$rel" ] || return 1
  done < <(required_icon_files)
  return 0
}

if [ -f "$STAMP_FILE" ] \
  && [ "$(tr -d '[:space:]' < "$STAMP_FILE")" = "$icon_hash" ] \
  && android_icons_complete; then
  echo "SAFEBOX_ANDROID_ICON_REUSED: $icon_hash"
  exit 0
fi

echo "SafeBox Android icon: generating official launcher/adaptive resources"
"$DESKTOP_DIR/node_modules/.bin/tauri" icon "$ICON_SOURCE"

if ! android_icons_complete; then
  echo "SAFEBOX_ANDROID_ICON_GENERATION_FAILED: required mipmap resources are incomplete" >&2
  exit 23
fi

printf '%s\n' "$icon_hash" > "$STAMP_FILE"
echo "SAFEBOX_ANDROID_ICON_READY: $icon_hash"
