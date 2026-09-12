#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/4] R23 OpenFileState lifetime invariant"
python3 - <<'PY'
from pathlib import Path
r=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
for signature in (
    'fn store_initial_opened_paths(app: &tauri::AppHandle, paths: &[String])',
    'fn store_initial_opened_paths_from_app(app: &tauri::App, paths: &[String])',
):
    start=r.index(signature)
    chunk=r[start:r.index('\n}\n', start)+3]
    assert 'state.initial_opened_paths.lock()' in chunk
    assert '    };\n}' in chunk, f'lifetime guard terminator missing for {signature}'
print('ANDROID_SHARE_OPEN_LIFETIME_R23_PASS')
PY

echo "[2/4] Shell syntax"
bash -n verification/verify_v022d_android_share_open_r23.sh

echo "[3/4] R22 complete baseline gate"
bash verification/verify_v022d_android_share_open_r22.sh

echo "[4/4] R23 marker"
echo "SAFEBOX_V022D_ANDROID_SHARE_OPEN_R23_VERIFY_PASS"
