#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] Android ANR/UI-thread invariants"
python3 - <<'PY'
from pathlib import Path
rust=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
ts=Path('safebox-desktop/src/main.ts').read_text()
required_rust=[
    'async fn read_sbx_public_info(',
    'async fn create_sbx_file(',
    'async fn unlock_sbx_file(',
    'async fn save_generated_file(',
    'tauri::async_runtime::spawn_blocking',
    '#[cfg(mobile)]\nfn focus_main_window(_app: &tauri::AppHandle)',
]
for token in required_rust:
    assert token in rust, token
assert rust.count('tauri::async_runtime::spawn_blocking') >= 4
required_ts=[
    'const likelyMobileRuntime = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);',
    'function scheduleDesktopMaintenance(',
    'scheduleDesktopMaintenance(sbxHideMainAccessProfileWhenEmpty, 1000);',
    'scheduleDesktopMaintenance(sbxMainPageScrollbarGuard, 1000);',
    'scheduleDesktopMaintenance(sbxFullApplyAppLanguage, 1200);',
]
for token in required_ts:
    assert token in ts, token
assert 'placeholder="/Users/noury/Desktop/test.png"' not in ts
assert 'placeholder="Select a file"' in ts
print('ANDROID_ANR_R15_INVARIANTS_PASS')
PY

echo "[2/6] Shell syntax"
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n verification/verify_v022c_android_anr_r15.sh

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

echo "[4/6] Rust format"
cargo fmt --all -- --check

echo "[5/6] R14 complete baseline gate"
bash verification/verify_v022c_android_window_api_r14.sh

echo "[6/6] Mobile UI-loop policy"
python3 - <<'PY'
from pathlib import Path
s=Path('safebox-desktop/src/main.ts').read_text()
for forbidden in [
    'setInterval(sbxHideMainAccessProfileWhenEmpty',
    'setInterval(sbxMainPageScrollbarGuard',
    'setInterval(sbxFullApplyAppLanguage',
]:
    assert forbidden not in s, forbidden
print('ANDROID_MOBILE_UI_LOOP_POLICY_PASS')
PY

echo "SAFEBOX_V022C_ANDROID_ANR_R15_VERIFY_PASS"
