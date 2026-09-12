#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LIB="safebox-desktop/src-tauri/src/lib.rs"

echo "[1/6] Android window API invariants"
python3 - <<'PY'
from pathlib import Path
s = Path('safebox-desktop/src-tauri/src/lib.rs').read_text()

# R14/R15 platform contract: desktop-only window APIs must never compile into
# Android/iOS. Accept the stronger function-level cfg introduced by R15, while
# still accepting the original R14 statement-level guard for compatibility.
function_level = '''#[cfg(desktop)]\nfn focus_main_window(app: &tauri::AppHandle) {''' in s
statement_level = '''#[cfg(desktop)]\n        {\n            let _ = window.unminimize();\n        }''' in s
assert function_level or statement_level, 'desktop cfg isolation missing around unminimize()'

if function_level:
    desktop_start = s.index('#[cfg(desktop)]\nfn focus_main_window(app: &tauri::AppHandle) {')
    mobile_marker = '#[cfg(mobile)]\nfn focus_main_window(_app: &tauri::AppHandle) {'
    assert mobile_marker in s, 'mobile focus_main_window stub missing'
    mobile_start = s.index(mobile_marker, desktop_start)
    desktop_body = s[desktop_start:mobile_start]
    assert 'window.unminimize()' in desktop_body, 'desktop unminimize behavior missing'
    assert 'window.unminimize()' not in s[mobile_start:], 'unminimize leaked into mobile code path'

assert 'let mut builder = tauri::Builder::default()' not in s, 'mobile-only unused mut builder regression'
assert 'let builder = tauri::Builder::default()' in s
assert '#[cfg(desktop)]\n    let builder = builder.plugin(tauri_plugin_single_instance::init' in s
print('ANDROID_WINDOW_API_R14_INVARIANTS_PASS')
PY

echo "[2/6] JSON/TOML"
python3 - <<'PY'
import json, tomllib
from pathlib import Path
json.loads(Path('safebox-desktop/package.json').read_text())
json.loads(Path('safebox-desktop/package-lock.json').read_text())
tomllib.loads(Path('safebox-desktop/src-tauri/Cargo.toml').read_text())
print('JSON_TOML_PASS')
PY

echo "[3/6] Rust format"
cargo fmt --all -- --check

echo "[4/6] Desktop Rust regression check"
cargo check -p safebox-desktop --locked

echo "[5/6] Core security tests"
cargo test -p safebox-core --locked

echo "[6/6] R13 platform gate"
bash verification/verify_v022c_android_auto_init_r13.sh

echo "SAFEBOX_V022C_ANDROID_WINDOW_API_R14_VERIFY_PASS"
