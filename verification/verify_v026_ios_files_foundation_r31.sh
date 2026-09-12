#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"; LIB="$D/src-tauri/src/lib.rs"; MAIN="$D/src/main.ts"; CONF="$D/src-tauri/tauri.conf.json"

echo '[1/6] iOS security-scoped picker'
grep -F 'pickerMode: iosScoped ? "document" : undefined' "$MAIN" >/dev/null
grep -F 'fileAccessMode: iosScoped ? "scoped" : undefined' "$MAIN" >/dev/null
grep -F 'filters: sbxOnly && !iosScoped' "$MAIN" >/dev/null
echo 'SAFEBOX_IOS_SCOPED_PICKER_R31_PASS'

echo '[2/6] iOS private staging + scope release'
grep -F 'cfg!(target_os = "ios") && trimmed.starts_with("file://")' "$LIB" >/dev/null
grep -F 'create_mobile_work_dir(app)?' "$LIB" >/dev/null
grep -F 'create_private_new_file(&staged_path)?' "$LIB" >/dev/null
grep -F 'stop_accessing_security_scoped_resource' "$LIB" >/dev/null
echo 'SAFEBOX_IOS_PRIVATE_STAGING_R31_PASS'

echo '[3/6] iOS Save + Open-In'
grep -F 'let mobile_save_required = cfg!(any(target_os = "android", target_os = "ios"));' "$LIB" >/dev/null
grep -F 'Preserve the security-scoped file URL' "$LIB" >/dev/null
grep -F 'verify_export_bytes(&app, &source, destination_path)?;' "$LIB" >/dev/null
echo 'SAFEBOX_IOS_SAVE_OPEN_IN_R31_PASS'

echo '[4/6] custom SBX type + physical-device dev host'
python3 - "$CONF" "$D/package.json" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); fa=j['bundle']['fileAssociations'][0]
assert fa['ext']==['sbx'] and fa['role']=='Viewer'
assert fa['mimeType']=='application/octet-stream'
assert fa['exportedType']['identifier']=='com.safebox.desktop.sbx'
assert 'public.data' in fa['exportedType']['conformsTo']
p=json.load(open(sys.argv[2])); assert p['scripts']['ios:doctor']; assert p['scripts']['ios:cold-dev']
PY
grep -F 'const host = process.env.TAURI_DEV_HOST;' "$D/vite.config.ts" >/dev/null
echo 'SAFEBOX_IOS_FILE_TYPE_DEV_HOST_R31_PASS'

echo '[5/6] shell/tooling syntax'
bash -n "$D/scripts/ios_doctor.sh"; bash -n "$D/scripts/ios_cold_dev.sh"
grep -F '"$TAURI_BIN" ios init' "$D/scripts/ios_cold_dev.sh" >/dev/null
grep -F 'exec "$TAURI_BIN" ios dev "$DEVICE"' "$D/scripts/ios_cold_dev.sh" >/dev/null
echo 'SAFEBOX_IOS_TOOLING_R31_PASS'

echo '[6/7] 9-council + Defensive HACKER gate'
grep -F '## 9-council checkpoint review' "$ROOT/checkpoints/SAFEBOX_V026_IOS_FILES_FOUNDATION_R31_REPORT.md" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$ROOT/checkpoints/SAFEBOX_V026_IOS_FILES_FOUNDATION_R31_REPORT.md" >/dev/null
grep -F 'R32 must provide simulator E2E evidence' "$ROOT/checkpoints/SAFEBOX_V026_IOS_FILES_FOUNDATION_R31_REPORT.md" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R31_PASS'

echo '[7/7] frontend + Rust host validation'
cd "$D"; bash scripts/ensure_frontend_toolchain.sh; npm run build
cd "$ROOT"; cargo fmt --all; cargo fmt --all -- --check; cargo check -p safebox-desktop

echo 'IOS_V026_STATUS: FOUNDATION_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V026_IOS_FILES_FOUNDATION_R31_VERIFY_PASS'
