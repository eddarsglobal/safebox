#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 - <<PY
from pathlib import Path
import json
root=Path(r'''$ROOT'''); d=root/'safebox-desktop'
a=json.loads((d/'src-tauri/tauri.android.conf.json').read_text())
assert a['identifier']=='com.safebox.desktop'
assert a['version']=='0.2.9'
assert a['bundle']['android']['versionCode']==2009
assert a['bundle']['android']['minSdkVersion']==24
for f in ['android_release_doctor.sh','android_release_prepare.sh','android_release_signing_setup.sh','android_release_build.sh']:
    s=(d/'scripts'/f).read_text()
    assert 'SAFEBOX_ANDROID_R86_' in s
prep=(d/'scripts/android_release_prepare.sh').read_text()
assert 'compileSdk = 36' in prep and 'targetSdk = 36' in prep
build=(d/'scripts/android_release_build.sh').read_text()
assert '-- --apk' in build and '-- --aab' in build
assert 'SafeBox-v0.2.9-universal.apk' in build and 'SafeBox-v0.2.9-play.aab' in build
print('SAFEBOX_R86_ANDROID_ID_VERSION_PASS')
print('SAFEBOX_R86_ANDROID_API36_POLICY_PASS')
print('SAFEBOX_R86_ANDROID_SIGNING_PIPELINE_PASS')
print('SAFEBOX_R86_ANDROID_APK_AAB_PIPELINE_PASS')
print('SAFEBOX_R86_ANDROID_DISTRIBUTION_FOUNDATION_PASS')
PY
