#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/5] R30 emulator storage preflight semantics"
python3 - <<'PY'
import json
from pathlib import Path
cold=Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
recover=Path('safebox-desktop/scripts/android_storage_recover.sh').read_text()
pkg=json.loads(Path('safebox-desktop/package.json').read_text())
for token in [
    'ANDROID_MIN_FREE_KB="${SAFEBOX_ANDROID_MIN_FREE_KB:-524288}"',
    'ensure_emulator_install_space',
    'SAFEBOX_ANDROID_STORAGE_FREE_KB',
    'SAFEBOX_ANDROID_STORAGE_RECOVERED',
    'shell rm -rf /sdcard/Download/SafeBox-E2E',
]:
    assert token in cold, token
assert 'ensure_emulator_install_space "$existing_serial"' in cold
assert 'ensure_emulator_install_space "$serial"' in cold
assert 'SAFEBOX_ANDROID_STORAGE_RECOVERY_REFUSED_PHYSICAL_DEVICE' in recover
assert 'shell rm -rf /sdcard/Download/SafeBox-E2E' in recover
assert 'uninstall "$PACKAGE"' in recover
assert pkg['scripts']['android:storage-recover'] == 'bash scripts/android_storage_recover.sh'
print('SAFEBOX_ANDROID_STORAGE_PREFLIGHT_R30_PASS')
PY

echo "[2/5] R30 cleanup boundary: no broad user-data wipe"
python3 - <<'PY'
from pathlib import Path
texts=[
 Path('safebox-desktop/scripts/android_cold_dev.sh').read_text(),
 Path('safebox-desktop/scripts/android_storage_recover.sh').read_text(),
]
for t in texts:
    assert 'rm -rf /sdcard/Download/SafeBox-E2E' in t
    assert 'rm -rf /sdcard/Download/' not in t.replace('rm -rf /sdcard/Download/SafeBox-E2E','')
    assert 'wipe-data' not in t
print('SAFEBOX_ANDROID_STORAGE_CLEANUP_BOUNDARY_R30_PASS')
PY

echo "[3/5] Syntax + package JSON"
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/android_storage_recover.sh
python3 -m json.tool safebox-desktop/package.json >/dev/null

echo "[4/5] R29 product baseline"
bash verification/verify_v024_android_final_r29.sh

echo "[5/5] R30 marker"
echo "ANDROID_V024_STATUS: DONE"
echo "SAFEBOX_V024_ANDROID_STORAGE_RECOVERY_R30_VERIFY_PASS"
