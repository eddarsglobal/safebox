#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 7B — Official .sbx file icon on macOS
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint7b_sbx_file_icon_patch.sh

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src-tauri/tauri.conf.json "src-tauri/tauri.conf.json.backup-sprint7b-icon.$(date +%Y%m%d%H%M%S)"

python3 - <<'PY'
import json
from pathlib import Path

p = Path("src-tauri/tauri.conf.json")
data = json.loads(p.read_text())

build = data.setdefault("build", {})
build["beforeBuildCommand"] = "npm run build"
build["frontendDist"] = "../dist"

bundle = data.setdefault("bundle", {})
bundle["targets"] = ["app"]
bundle["fileAssociations"] = [
  {
    "ext": ["sbx"],
    "name": "SafeBox File",
    "description": "SafeBox encrypted file",
    "role": "Viewer"
  }
]

p.write_text(json.dumps(data, indent=2) + "\n")
print("Updated tauri.conf.json .sbx association")
PY

mkdir -p scripts
cat > scripts/install_macos_sbx_file_icon.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"
APP_PATH="$ROOT_DIR/target/release/bundle/macos/SafeBox.app"
PLIST="$APP_PATH/Contents/Info.plist"
RESOURCES="$APP_PATH/Contents/Resources"
ICONSET="$DESKTOP_DIR/src-tauri/icons/safebox-file.iconset"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: SafeBox.app not found:"
  echo "$APP_PATH"
  echo "Run first: npm run tauri build"
  exit 1
fi

SOURCE_ICON=""
for candidate in   "$DESKTOP_DIR/src-tauri/icons/icon.png"   "$DESKTOP_DIR/public/safebox-logo.png"   "$DESKTOP_DIR/src-tauri/icons/128x128@2x.png"   "$DESKTOP_DIR/src-tauri/icons/128x128.png"
do
  if [ -f "$candidate" ]; then
    SOURCE_ICON="$candidate"
    break
  fi
done

if [ -z "$SOURCE_ICON" ]; then
  echo "ERROR: no SafeBox PNG icon found."
  exit 1
fi

echo "Using source icon: $SOURCE_ICON"

mkdir -p "$RESOURCES"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# Build a valid macOS .icns from existing SafeBox PNG.
sips -z 16 16 "$SOURCE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SOURCE_ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$RESOURCES/safebox-file.icns"

# Force macOS document type registration.
echo "Patching Info.plist..."
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string SafeBox File" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeIconFile string safebox-file" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string sbx" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string com.safebox.sbx" "$PLIST"

/usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeIdentifier string com.safebox.sbx" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeDescription string SafeBox encrypted file" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo:0 string public.data" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 string sbx" "$PLIST"

echo "Registering SafeBox with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"

qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall Finder 2>/dev/null || true

echo "Done. safebox-file.icns installed in built SafeBox.app."
SH

chmod +x scripts/install_macos_sbx_file_icon.sh

echo "Sprint 7B patch applied."
echo ""
echo "Next:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run build"
echo "  npm run tauri build"
echo "  bash scripts/install_macos_sbx_file_icon.sh"
