#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"

ICON_ICNS="$DESKTOP_DIR/src-tauri/icons/safebox-file.icns"
ICON_PNG="$DESKTOP_DIR/src-tauri/icons/safebox-file-source.png"

if [ -f "$ICON_ICNS" ]; then
  echo "OK: SBX icon source exists: $ICON_ICNS"
  exit 0
fi

for CANDIDATE in \
  "$WORKSPACE_DIR/target/release/bundle/macos/SafeBox.app/Contents/Resources/safebox-file.icns" \
  "/Applications/SafeBox.app/Contents/Resources/safebox-file.icns"
do
  if [ -f "$CANDIDATE" ]; then
    cp "$CANDIDATE" "$ICON_ICNS"
    echo "OK: copied existing SBX icon into source: $ICON_ICNS"
    exit 0
  fi
done

if [ -f "$ICON_PNG" ]; then
  TMP_ICONSET="$(mktemp -d)/safebox-file.iconset"
  mkdir -p "$TMP_ICONSET"

  sips -z 16 16 "$ICON_PNG" --out "$TMP_ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$TMP_ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$TMP_ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$TMP_ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$TMP_ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$TMP_ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$TMP_ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$TMP_ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$TMP_ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$TMP_ICONSET/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$TMP_ICONSET" -o "$ICON_ICNS"

  echo "OK: generated SBX icon source: $ICON_ICNS"
  exit 0
fi

echo "ERROR: missing SBX icon source."
echo "Expected one of:"
echo "  $ICON_ICNS"
echo "  $ICON_PNG"
echo "  /Applications/SafeBox.app/Contents/Resources/safebox-file.icns"
exit 1
