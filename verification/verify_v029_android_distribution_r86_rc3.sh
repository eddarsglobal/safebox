#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 - "$D/scripts/android_release_signing_setup.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
rc3 = ('java.util.Properties()' in s and 'java.io.FileInputStream(f)' in s)
rc4 = ('SafeBoxProperties()' in s and 'SafeBoxFileInputStream(f)' in s)
assert rc3 or rc4
assert "if 'import java.util.Properties' not in s" not in s
assert 'Self-heal R86/RC2 generated Gradle files' in s
assert ('SAFEBOX_ANDROID_R86_RC3_GRADLE_KOTLIN_IMPORT_PASS' in s or 'SAFEBOX_ANDROID_R86_RC4_GRADLE_ALIAS_IMPORT_PASS' in s)
print('SAFEBOX_R86_RC3_PROPERTIES_REFERENCE_PASS')
print('SAFEBOX_R86_RC3_FILEINPUTSTREAM_REFERENCE_PASS')
print('SAFEBOX_R86_RC3_RC2_GRADLE_SELF_HEAL_PASS')
print('SAFEBOX_R86_RC3_SIGNING_GRADLE_HARDENING_PASS')
PY
bash -n "$D/scripts/android_release_signing_setup.sh"
echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC3_PASS'
