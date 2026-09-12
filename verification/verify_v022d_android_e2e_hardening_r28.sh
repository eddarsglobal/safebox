#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] R28 Android E2E tooling invariants"
python3 - <<'PY'
import json
from pathlib import Path
p=json.loads(Path('safebox-desktop/package.json').read_text())
s=p['scripts']
expected={
 'android:import':'bash scripts/android_import.sh',
 'android:e2e-prepare':'bash scripts/android_e2e_prepare.sh',
 'android:e2e-idle':'bash scripts/android_e2e_idle_check.sh',
 'android:e2e-log':'bash scripts/android_e2e_log_check.sh',
 'android:compare':'bash scripts/android_compare.sh',
}
for k,v in expected.items():
    assert s.get(k)==v, (k,s.get(k))
imp=Path('safebox-desktop/scripts/android_import.sh').read_text()
prep=Path('safebox-desktop/scripts/android_e2e_prepare.sh').read_text()
idle=Path('safebox-desktop/scripts/android_e2e_idle_check.sh').read_text()
cmp=Path('safebox-desktop/scripts/android_compare.sh').read_text()
for token in ['sha256sum','SAFEBOX_ANDROID_IMPORT_READY','/sdcard/Download/SafeBox-E2E']:
    assert token in imp
for token in ['SafeBox E2E – unicode čćžšđ.txt','safebox-e2e-document.pdf','SAFEBOX_E2E_LARGE_MIB','SAFEBOX_ANDROID_E2E_FIXTURES_READY']:
    assert token in prep
for token in ['logcat -c','ANR in $PACKAGE','SAFEBOX_ANDROID_E2E_IDLE_PASS']:
    assert token in idle
assert 'SAFEBOX_ANDROID_COMPARE_PASS' in cmp
print('SAFEBOX_ANDROID_E2E_TOOLING_R28_PASS')
PY

echo "[2/6] No secret/crypto behavior introduced by E2E tooling"
python3 - <<'PY'
from pathlib import Path
scripts=[
 'safebox-desktop/scripts/android_import.sh',
 'safebox-desktop/scripts/android_e2e_prepare.sh',
 'safebox-desktop/scripts/android_e2e_idle_check.sh',
 'safebox-desktop/scripts/android_e2e_log_check.sh',
 'safebox-desktop/scripts/android_compare.sh',
]
for rel in scripts:
    t=Path(rel).read_text().lower()
    for forbidden in ['create_sbx_file','unlock_sbx_file','--code','sender code']:
        assert forbidden not in t, f'{forbidden} leaked into {rel}'
print('SAFEBOX_ANDROID_E2E_SECURITY_BOUNDARY_R28_PASS')
PY

echo "[3/6] Shell syntax + JSON/TOML + Rust format"
for f in verification/*.sh safebox-desktop/scripts/*.sh; do bash -n "$f"; done
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

echo "[4/6] R28 checkpoint hygiene before dependency installation"
python3 - <<'PY'
from pathlib import Path
bad=[]
for name in ['node_modules','target']:
    bad.extend(Path('.').rglob(name))
# Generated Android project is runtime output and must not ship in checkpoint.
android=Path('safebox-desktop/src-tauri/gen/android')
if android.exists(): bad.append(android)
assert not bad, bad
print('SAFEBOX_ANDROID_E2E_CHECKPOINT_HYGIENE_R28_PASS')
PY

echo "[5/6] R27 complete baseline gate"
bash verification/verify_v022d_android_verifier_closure_r27.sh

echo "[6/6] R28 marker"
echo "SAFEBOX_V022D_ANDROID_E2E_HARDENING_R28_VERIFY_PASS"
