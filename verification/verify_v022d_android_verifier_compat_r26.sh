#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/5] R26 R17 semantic icon-verifier compatibility"
python3 - <<'PY'
from pathlib import Path
v=Path('verification/verify_v022c_android_icon_r17.sh').read_text()
installer=Path('safebox-desktop/scripts/install_android_launcher_icon.sh').read_text()
assert "semantic Tauri icon invocation missing" in v
assert "node_modules/.bin/tauri" in v
assert '"$DESKTOP_DIR/node_modules/.bin/tauri" icon "$ICON_SOURCE"' in installer
assert 'npx tauri' not in installer
print('SAFEBOX_ANDROID_ICON_VERIFIER_COMPAT_R26_PASS')
PY

echo "[2/5] Shell syntax"
bash -n verification/verify_v022c_android_icon_r17.sh
bash -n verification/verify_v022d_android_dev_runtime_r25.sh
bash -n verification/verify_v022d_android_verifier_compat_r26.sh
bash -n safebox-desktop/scripts/install_android_launcher_icon.sh
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/safebox_tauri.sh

echo "[3/5] JSON/TOML + Rust format"
python3 - <<'PY'
import json,tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'),Path('safebox-desktop/package-lock.json'),Path('safebox-desktop/src-tauri/tauri.conf.json'),Path('safebox-desktop/src-tauri/tauri.android.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'),Path('safebox-core/Cargo.toml'),Path('safebox-cli/Cargo.toml'),Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY
cargo fmt --all -- --check

echo "[4/5] R25 complete baseline gate"
bash verification/verify_v022d_android_dev_runtime_r25.sh

echo "[5/5] R26 no-regression policy"
python3 - <<'PY'
from pathlib import Path
cold=Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
wrap=Path('safebox-desktop/scripts/safebox_tauri.sh').read_text()
icon=Path('safebox-desktop/scripts/install_android_launcher_icon.sh').read_text()
for text,name in [(cold,'cold'),(wrap,'wrapper'),(icon,'icon')]:
    assert 'npx tauri' not in text, f'npx tauri regressed into {name}'
assert 'SAFEBOX_FRONTEND_TOOLCHAIN_READY' in Path('safebox-desktop/scripts/ensure_frontend_toolchain.sh').read_text()
print('SAFEBOX_ANDROID_RUNTIME_NO_NPX_R26_PASS')
PY

echo "SAFEBOX_V022D_ANDROID_VERIFIER_COMPAT_R26_VERIFY_PASS"
