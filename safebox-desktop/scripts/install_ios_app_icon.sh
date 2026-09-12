#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$APP_DIR/.." && pwd)"
APPLE_DIR="$APP_DIR/src-tauri/gen/apple"
APPICON_DIR="$APPLE_DIR/Assets.xcassets/AppIcon.appiconset"
CONTENTS="$APPICON_DIR/Contents.json"
SOURCE="${SAFEBOX_IOS_ICON_SOURCE:-$ROOT_DIR/assets/safebox-app-icon-ios-1024.png}"
STAMP="$APPLE_DIR/.safebox-ios-app-icon.sha256"

[[ "$(uname -s)" == 'Darwin' ]] || {
  echo 'SAFEBOX_IOS_ICON_FAIL: macOS required' >&2
  exit 81
}
command -v sips >/dev/null 2>&1 || {
  echo 'SAFEBOX_IOS_ICON_FAIL: sips unavailable' >&2
  exit 82
}
[[ -f "$SOURCE" ]] || {
  echo "SAFEBOX_IOS_ICON_FAIL: official source missing: $SOURCE" >&2
  exit 83
}
[[ -f "$CONTENTS" ]] || {
  echo "SAFEBOX_IOS_ICON_FAIL: AppIcon Contents.json missing; run tauri ios init first: $CONTENTS" >&2
  exit 84
}

SOURCE_SHA="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"
TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT

# Keep Tauri/Xcode's own Contents.json as the source of truth. We only replace
# every referenced PNG with the official SafeBox artwork at the exact pixel
# dimensions declared by that asset set.
python3 - "$CONTENTS" >"$TMP_LIST" <<'PY'
import json, sys
from decimal import Decimal
p=sys.argv[1]
data=json.load(open(p, encoding='utf-8'))
seen=set()
for item in data.get('images', []):
    name=item.get('filename')
    size=item.get('size')
    scale=item.get('scale')
    if not name or not size or not scale:
        continue
    if name in seen:
        continue
    seen.add(name)
    base=Decimal(size.split('x',1)[0])
    mult=Decimal(scale.rstrip('x'))
    pixels=int(base*mult)
    if pixels <= 0:
        raise SystemExit(f'invalid AppIcon size for {name}')
    print(f'{name}\t{pixels}')
PY

COUNT=0
while IFS=$'\t' read -r NAME PIXELS; do
  [[ -n "$NAME" && "$PIXELS" =~ ^[0-9]+$ ]] || continue
  DEST="$APPICON_DIR/$NAME"
  TMP="$APPICON_DIR/.${NAME}.safebox.$$.png"
  sips -z "$PIXELS" "$PIXELS" "$SOURCE" --out "$TMP" >/dev/null
  WIDTH="$(sips -g pixelWidth "$TMP" 2>/dev/null | awk '/pixelWidth:/{print $2}')"
  HEIGHT="$(sips -g pixelHeight "$TMP" 2>/dev/null | awk '/pixelHeight:/{print $2}')"
  [[ "$WIDTH" == "$PIXELS" && "$HEIGHT" == "$PIXELS" ]] || {
    rm -f "$TMP"
    echo "SAFEBOX_IOS_ICON_FAIL: generated size mismatch for $NAME" >&2
    exit 85
  }
  mv -f "$TMP" "$DEST"
  COUNT=$((COUNT+1))
done <"$TMP_LIST"

[[ "$COUNT" -ge 10 ]] || {
  echo "SAFEBOX_IOS_ICON_FAIL: incomplete AppIcon set ($COUNT files)" >&2
  exit 86
}

# App Store / iOS icons must not carry alpha. The packaged 1024 source is RGB;
# sips preserves that property in generated PNGs. Verify the 1024 marketing
# icon as an explicit guard because it is the strictest asset.
MARKETING="$(python3 - "$CONTENTS" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding='utf-8')).get('images', []):
    if item.get('idiom') == 'ios-marketing' and item.get('filename'):
        print(item['filename'])
        break
PY
)"
if [[ -n "$MARKETING" && -f "$APPICON_DIR/$MARKETING" ]]; then
  HAS_ALPHA="$(sips -g hasAlpha "$APPICON_DIR/$MARKETING" 2>/dev/null | awk '/hasAlpha:/{print $2}')"
  [[ "$HAS_ALPHA" == 'no' ]] || {
    echo "SAFEBOX_IOS_ICON_FAIL: marketing icon has alpha: $MARKETING" >&2
    exit 87
  }
fi

printf '%s\n' "$SOURCE_SHA" > "$STAMP"
echo "SAFEBOX_IOS_ICON_SOURCE_SHA256: $SOURCE_SHA"
echo "SAFEBOX_IOS_APPICON_COUNT: $COUNT"
echo 'SAFEBOX_IOS_APPICON_INSTALL_PASS'
