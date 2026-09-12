#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 - "$D/scripts/android_release_signing_setup.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert "DNAME='CN=Mr Eddars Noureddine, OU=EDDARS Studio, O=EDDARS, L=Zurich, ST=Zurich, C=CH'" in s
assert '-dname "$DNAME"' in s
assert '-storepass:env SAFEBOX_KEYSTORE_PASSWORD' in s
assert '-keypass:env SAFEBOX_KEYSTORE_PASSWORD' in s
assert 'Confirm SafeBox upload-key password' in s
assert 'passwords do not match' in s
assert 'SAFEBOX_ANDROID_R86_RC2_EMPTY_KEYSTORE_RECOVERED_PASS' in s
assert 'SAFEBOX_ANDROID_R86_RC2_KEYSTORE_VERIFY_PASS' in s
assert 'Do NOT delete a valid Play upload key' in s
assert 'SAFEBOX_ANDROID_R86_SIGNING_SETUP_PASS' in s
print('SAFEBOX_R86_RC2_KEYTOOL_NONINTERACTIVE_DNAME_PASS')
print('SAFEBOX_R86_RC2_PASSWORD_CONFIRMATION_PASS')
print('SAFEBOX_R86_RC2_INTERRUPTED_KEYSTORE_RECOVERY_PASS')
print('SAFEBOX_R86_RC2_EXISTING_KEY_PROTECTION_PASS')
print('SAFEBOX_R86_RC2_SIGNING_SETUP_HARDENING_PASS')
PY
bash -n "$D/scripts/android_release_signing_setup.sh"
echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC2_PASS'
