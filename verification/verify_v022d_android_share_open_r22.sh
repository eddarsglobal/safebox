#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/3] R22 rustfmt regression invariant"
python3 - <<'PY'
from pathlib import Path
r=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
expected='''fn get_initial_sbx_path(state: State<'_, OpenFileState>) -> Option<String> {\n    state.initial_opened_paths.lock().ok().and_then(|paths| {\n        paths\n            .iter()\n            .find(|path| path.to_ascii_lowercase().ends_with(".sbx"))\n            .cloned()\n    })\n}\n'''
assert expected in r, 'R22 get_initial_sbx_path rustfmt form missing'
print('ANDROID_SHARE_OPEN_RUSTFMT_R22_PASS')
PY

echo "[2/3] R21 complete baseline gate"
bash verification/verify_v022d_android_share_open_r21.sh

echo "[3/3] R22 marker"
echo "SAFEBOX_V022D_ANDROID_SHARE_OPEN_R22_VERIFY_PASS"
