#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] Android official-icon invariants"
python3 - <<'PY'
from pathlib import Path
import json, struct
installer=Path('safebox-desktop/scripts/install_android_launcher_icon.sh').read_text()
cold=Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
pkg=json.loads(Path('safebox-desktop/package.json').read_text())
source=Path('assets/safebox-app-icon-source.png')
assert source.is_file(), 'official icon source missing'
raw=source.read_bytes()
assert raw[:8] == b'\x89PNG\r\n\x1a\n', 'icon source is not PNG'
length=struct.unpack('>I', raw[8:12])[0]
assert raw[12:16] == b'IHDR' and length == 13, 'invalid PNG IHDR'
w,h,bit_depth,color_type,_,_,_=struct.unpack('>IIBBBBB', raw[16:29])
assert w == h and w >= 256, (w,h)
assert bit_depth == 8 and color_type in (4,6), (bit_depth,color_type)
assert pkg['scripts']['android:icon'] == 'bash scripts/install_android_launcher_icon.sh'
icon_invocations = [
    'npx tauri icon "$ICON_SOURCE"',
    '"$DESKTOP_DIR/node_modules/.bin/tauri" icon "$ICON_SOURCE"',
]
assert any(token in installer for token in icon_invocations), 'semantic Tauri icon invocation missing'
for token in [
    'SAFEBOX_ANDROID_ICON_READY',
    'SAFEBOX_ANDROID_ICON_REUSED',
    'mipmap-xxxhdpi/ic_launcher_foreground.png',
    '.safebox-app-icon.sha256',
]:
    assert token in installer, token
assert 'bash "$DESKTOP_DIR/scripts/install_android_launcher_icon.sh"' in cold
assert cold.index('ensure_android_project') < cold.rindex('install_android_launcher_icon.sh')
print('ANDROID_OFFICIAL_ICON_R17_INVARIANTS_PASS')
PY

echo "[2/6] Shell syntax"
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/install_android_launcher_icon.sh
bash -n verification/verify_v022c_android_icon_r17.sh

echo "[3/6] JSON/TOML"
python3 - <<'PY'
import json, tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'), Path('safebox-desktop/src-tauri/tauri.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'), Path('safebox-core/Cargo.toml'), Path('safebox-cli/Cargo.toml'), Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY

echo "[4/6] Checkpoint hygiene before dependency installation"
python3 - <<'PY'
from pathlib import Path
bad=[p for p in Path('.').rglob('*') if 'node_modules' in p.parts]
assert not bad, bad[:5]
print('CHECKPOINT_HYGIENE_R17_PASS')
PY

echo "[5/6] R16 complete baseline gate"
bash verification/verify_v022c_android_anr_r16.sh

echo "[6/6] Generated-project icon policy"
python3 - <<'PY'
from pathlib import Path
s=Path('safebox-desktop/scripts/install_android_launcher_icon.sh').read_text()
for density in ['mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi']:
    for name in ['ic_launcher.png','ic_launcher_round.png','ic_launcher_foreground.png']:
        token=f'mipmap-{density}/{name}'
        assert token in s, token
assert 'android_icons_complete' in s
assert 'required mipmap resources are incomplete' in s
print('ANDROID_GENERATED_ICON_POLICY_R17_PASS')
PY

echo "SAFEBOX_V022C_ANDROID_OFFICIAL_ICON_R17_VERIFY_PASS"
