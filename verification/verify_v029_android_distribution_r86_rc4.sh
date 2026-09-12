#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 - "$D/scripts/android_release_signing_setup.sh" "$D/scripts/android_release_rc4_gradle_hotfix.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
h=Path(sys.argv[2]).read_text()
assert 'import java.util.Properties as SafeBoxProperties' in s
assert 'import java.io.FileInputStream as SafeBoxFileInputStream' in s
assert 'val props = SafeBoxProperties()' in s
assert 'props.load(SafeBoxFileInputStream(f))' in s
assert 'java.util.Properties()' not in s
assert 'java.io.FileInputStream(f)' not in s
assert 'SAFEBOX_ANDROID_R86_RC4_GRADLE_ALIAS_IMPORT_PASS' in s
assert 'SAFEBOX_ANDROID_R86_RC4_GRADLE_DSL_SHADOWING_FIX_PASS' in h
print('SAFEBOX_R86_RC4_GRADLE_DSL_JAVA_SHADOWING_CLOSED_PASS')
print('SAFEBOX_R86_RC4_PROPERTIES_ALIAS_IMPORT_PASS')
print('SAFEBOX_R86_RC4_FILEINPUTSTREAM_ALIAS_IMPORT_PASS')
print('SAFEBOX_R86_RC4_CURRENT_RC3_HOTFIX_PASS')
PY
bash -n "$D/scripts/android_release_signing_setup.sh"
bash -n "$D/scripts/android_release_rc4_gradle_hotfix.sh"
# Compile a Kotlin fixture with a receiver property named `java` to prove the alias imports remain unambiguous.
if command -v kotlinc >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  cat > "$TMP/Test.kt" <<'KT'
import java.io.File
import java.util.Properties as SafeBoxProperties
import java.io.FileInputStream as SafeBoxFileInputStream
class GradleLikeReceiver { val java: String = "dsl-shadow" }
fun GradleLikeReceiver.load(f: File): String {
    val props = SafeBoxProperties()
    SafeBoxFileInputStream(f).use { props.load(it) }
    return props.getProperty("k") ?: ""
}
KT
  kotlinc "$TMP/Test.kt" -d "$TMP/test.jar" >/dev/null 2>&1
  echo 'SAFEBOX_R86_RC4_KOTLIN_ALIAS_SHADOW_FIX_COMPILE_PASS'
fi
echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC4_PASS'
