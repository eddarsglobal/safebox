#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/target/release/bundle/macos/SafeBox.app"
if [ ! -d "$APP" ]; then echo "ERROR: SafeBox.app not found: $APP"; exit 1; fi
ICON_PNG="$ROOT/safebox-desktop/src-tauri/icons/icon.png"
ICONSET="/tmp/safebox-file.iconset"
ICNS="$APP/Contents/Resources/safebox-file.icns"
INFO="$APP/Contents/Info.plist"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null; done
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICNS"
if /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0" "$INFO" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDocumentTypes:0:CFBundleTypeIconFile safebox-file" "$INFO" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeIconFile string safebox-file" "$INFO"
fi
touch "$APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then "$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true; fi
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
echo "SBX document icon applied to: $APP"
