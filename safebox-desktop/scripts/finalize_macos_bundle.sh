#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"

APP="$WORKSPACE_DIR/target/release/bundle/macos/SafeBox.app"
ICON="$DESKTOP_DIR/src-tauri/icons/safebox-file.icns"

if [ ! -d "$APP" ]; then
  echo "No macOS app bundle found, skipping finalize."
  exit 0
fi

bash "$DESKTOP_DIR/scripts/ensure_sbx_icon_source.sh"

mkdir -p "$APP/Contents/Resources"
cp "$ICON" "$APP/Contents/Resources/safebox-file.icns"

python3 - <<PY
from pathlib import Path
import plistlib

plist_path = Path("$APP/Contents/Info.plist")

with plist_path.open("rb") as f:
    plist = plistlib.load(f)

plist["CFBundleDocumentTypes"] = [
    {
        "CFBundleTypeName": "SafeBox File",
        "CFBundleTypeExtensions": ["sbx"],
        "CFBundleTypeIconFile": "safebox-file",
        "CFBundleTypeRole": "Viewer",
        "LSHandlerRank": "Owner",
        "LSItemContentTypes": ["com.safebox.sbx"],
    }
]

plist["UTExportedTypeDeclarations"] = [
    {
        "UTTypeIdentifier": "com.safebox.sbx",
        "UTTypeDescription": "SafeBox encrypted file",
        "UTTypeConformsTo": ["public.data"],
        "UTTypeIconFile": "safebox-file",
        "UTTypeTagSpecification": {
            "public.filename-extension": ["sbx"],
            "public.mime-type": "application/x-safebox-sbx",
        },
    }
]

with plist_path.open("wb") as f:
    plistlib.dump(plist, f)
PY

plutil -lint "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "OK: SafeBox.app finalized with embedded .sbx icon."
