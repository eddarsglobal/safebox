#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] Android v0.2.4 closure evidence manifest"
python3 - <<'PY'
from pathlib import Path
p=Path('checkpoints/SAFEBOX_V024_ANDROID_FINAL_R29_REPORT.md')
t=p.read_text()
for token in [
    'ANDROID CORE FLOW: DONE',
    'SAFEBOX_ANDROID_E2E_IDLE_PASS',
    'SAFEBOX_ANDROID_E2E_LOG_PASS',
    'SAFEBOX_ANDROID_COMPARE_PASS',
    '78f6e771760e5eb03a547ebc1dc48a4ce5461ccc5c8573f56f74fb3517ba59dc',
    'Password visibility',
    'Footer Settings',
    'iOS Files / security-scoped document I/O foundation',
]:
    assert token in t, token
print('SAFEBOX_ANDROID_V024_EVIDENCE_R29_PASS')
PY

echo "[2/6] R29 password-eye + footer Settings UI invariants"
python3 - <<'PY'
from pathlib import Path
main=Path('safebox-desktop/src/main.ts').read_text()
css=Path('safebox-desktop/src/style.css').read_text()
assert '<footer class="app-footer"' in main
assert 'id="settingsBtn" class="footer-settings-btn"' in main
assert '<div class="top-actions" aria-hidden="true"></div>' in main
assert 'sbxFullSetText("#settingsBtn", "settings")' not in main
assert 'function sbxSyncPasswordEye' in main
assert 'function sbxSyncAllPasswordEyes' in main
for target in [
    'createCode',
    'unlockCode',
    'receiverCode',
    'settingsGlobalCode',
    'profileEditorCode',
    'hardReceiverCode',
]:
    needle=f'data-password-target="{target}"'
    assert needle in main, needle
assert '--safebox-r29-footer-settings-password-eye: 1' in css
assert '#settingsBtn.footer-settings-btn' in css
assert '.password-eye-btn' in css
assert '.password-field > input' in css
print('SAFEBOX_ANDROID_R29_PASSWORD_EYE_FOOTER_SETTINGS_PASS')
PY

echo "[3/6] R28 E2E tooling remains present"
python3 - <<'PY'
import json
from pathlib import Path
p=json.loads(Path('safebox-desktop/package.json').read_text())
for key in ['android:import','android:e2e-prepare','android:e2e-idle','android:e2e-log','android:compare']:
    assert key in p['scripts'], key
for rel in [
 'safebox-desktop/scripts/android_import.sh',
 'safebox-desktop/scripts/android_e2e_prepare.sh',
 'safebox-desktop/scripts/android_e2e_idle_check.sh',
 'safebox-desktop/scripts/android_e2e_log_check.sh',
 'safebox-desktop/scripts/android_compare.sh',
 'verification/verify_v022d_android_e2e_hardening_r28.sh',
]:
    assert Path(rel).is_file(), rel
print('SAFEBOX_ANDROID_R28_TOOLING_FROZEN_R29_PASS')
PY

echo "[4/6] Android provider-selected destination boundary"
python3 - <<'PY'
from pathlib import Path
rust=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
ts=Path('safebox-desktop/src/main.ts').read_text()
assert 'save_generated_file' in rust
assert 'verify_export_bytes(&app, &source, destination_path)?;' in rust
assert 'const destination = await save({ defaultPath: suggestedName || fileNameFromPath(sourcePath) });' in ts
assert 'destination' in ts
print('SAFEBOX_ANDROID_PROVIDER_DESTINATION_BOUNDARY_R29_PASS')
PY

echo "[5/6] Syntax + format + clean checkpoint"
for f in verification/*.sh safebox-desktop/scripts/*.sh; do bash -n "$f"; done
if command -v cargo >/dev/null 2>&1; then
  cargo fmt --all -- --check
else
  echo "cargo not available in this packaging environment; user verifier on development Mac will enforce rustfmt"
fi
python3 - <<'PY'
from pathlib import Path
bad=[]
for name in ['node_modules','target']:
    bad.extend(Path('.').rglob(name))
android=Path('safebox-desktop/src-tauri/gen/android')
if android.exists(): bad.append(android)
ios=Path('safebox-desktop/src-tauri/gen/apple')
if ios.exists(): bad.append(ios)
assert not bad, bad
print('SAFEBOX_ANDROID_V024_CHECKPOINT_HYGIENE_R29_PASS')
PY

echo "[6/6] Final Android v0.2.4 marker"
echo "ANDROID_V024_STATUS: DONE"
echo "SAFEBOX_V024_ANDROID_FINAL_R29_VERIFY_PASS"
