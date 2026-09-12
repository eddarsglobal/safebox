#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
cd "$D"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
KEYTOOL="$JAVA_HOME/bin/keytool"
[ -x "$KEYTOOL" ] || { echo "SAFEBOX_ANDROID_R86_SIGNING_FAIL: keytool missing" >&2; exit 1; }
GEN=src-tauri/gen/android
[ -f "$GEN/gradlew" ] || { echo 'Run android_release_prepare.sh first.' >&2; exit 1; }
KEYDIR="$HOME/.safebox/android-signing"
KEYSTORE="$KEYDIR/upload-keystore.jks"
ALIAS=upload
DNAME='CN=Mr Eddars Noureddine, OU=EDDARS Studio, O=EDDARS, L=Zurich, ST=Zurich, C=CH'
mkdir -p "$KEYDIR"
chmod 700 "$KEYDIR"

# If an interrupted keytool run left an empty file, it is safe to remove it.
if [ -e "$KEYSTORE" ] && [ ! -s "$KEYSTORE" ]; then
  rm -f "$KEYSTORE"
  echo 'SAFEBOX_ANDROID_R86_RC2_EMPTY_KEYSTORE_RECOVERED_PASS'
fi

read -r -s -p 'SafeBox upload-key password: ' PASS; echo
[ -n "$PASS" ] || { echo 'SAFEBOX_ANDROID_R86_SIGNING_FAIL: empty password' >&2; exit 1; }
read -r -s -p 'Confirm SafeBox upload-key password: ' PASS2; echo
[ "$PASS" = "$PASS2" ] || { echo 'SAFEBOX_ANDROID_R86_SIGNING_FAIL: passwords do not match' >&2; exit 1; }
unset PASS2
export SAFEBOX_KEYSTORE_PASSWORD="$PASS"
trap 'unset SAFEBOX_KEYSTORE_PASSWORD PASS 2>/dev/null || true' EXIT

if [ ! -f "$KEYSTORE" ]; then
  echo 'Creating the permanent SafeBox Play upload key non-interactively.'
  echo 'Identity: Mr Eddars Noureddine · EDDARS Studio · Zurich · CH'
  "$KEYTOOL" -genkeypair -v \
    -keystore "$KEYSTORE" \
    -storetype JKS \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias "$ALIAS" \
    -dname "$DNAME" \
    -storepass:env SAFEBOX_KEYSTORE_PASSWORD \
    -keypass:env SAFEBOX_KEYSTORE_PASSWORD
  chmod 600 "$KEYSTORE"
  echo 'SAFEBOX_ANDROID_R86_RC2_KEYSTORE_CREATE_PASS'
else
  echo "SAFEBOX_ANDROID_R86_KEYSTORE_REUSED: $KEYSTORE"
fi

# Never overwrite a pre-existing valid key with a different password/alias.
if ! "$KEYTOOL" -list \
  -keystore "$KEYSTORE" \
  -storepass:env SAFEBOX_KEYSTORE_PASSWORD \
  -alias "$ALIAS" >/dev/null 2>&1; then
  echo 'SAFEBOX_ANDROID_R86_SIGNING_FAIL: existing keystore cannot be opened with this password or upload alias is missing.' >&2
  echo "Do NOT delete a valid Play upload key. Verify the password for: $KEYSTORE" >&2
  exit 1
fi
echo 'SAFEBOX_ANDROID_R86_RC2_KEYSTORE_VERIFY_PASS'

cat > "$GEN/keystore.properties" <<EOF2
storePassword=$PASS
keyPassword=$PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF2
chmod 600 "$GEN/keystore.properties"

APP="$GEN/app/build.gradle.kts"
python3 - "$APP" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); s=p.read_text()
# Gradle Kotlin DSL exposes an Android `java` extension; alias imports prevent
# `java.util` / `java.io` from being resolved against that DSL receiver.
imports = (
    'import java.util.Properties as SafeBoxProperties\n'
    'import java.io.FileInputStream as SafeBoxFileInputStream\n'
)
if 'import java.util.Properties as SafeBoxProperties' not in s:
    s = imports + s
marker='// SAFEBOX_R86_RELEASE_SIGNING_BEGIN'
end_marker='// SAFEBOX_R86_RELEASE_SIGNING_END'
block='''
// SAFEBOX_R86_RELEASE_SIGNING_BEGIN
signingConfigs {
    create("release") {
        val f = rootProject.file("keystore.properties")
        val props = SafeBoxProperties()
        props.load(SafeBoxFileInputStream(f))
        keyAlias = props["keyAlias"] as String
        keyPassword = props["keyPassword"] as String
        storeFile = file(props["storeFile"] as String)
        storePassword = props["storePassword"] as String
    }
}
// SAFEBOX_R86_RELEASE_SIGNING_END

'''
if marker in s and end_marker in s:
    start=s.index(marker)
    end=s.index(end_marker, start)+len(end_marker)
    # Self-heal R86/RC2 generated Gradle files that used bare FileInputStream/Properties.
    s=s[:start]+block.strip()+s[end:]
else:
    m=re.search(r'\bbuildTypes\s*\{', s)
    if not m:
        raise SystemExit('buildTypes block not found')
    s=s[:m.start()]+block+s[m.start():]
# Attach the release signing config only if not already present.
s=re.sub(
    r'(getByName\("release"\)\s*\{)(?![^}]*signingConfig)',
    r'\1\n            signingConfig = signingConfigs.getByName("release")',
    s,
    count=1,
    flags=re.S,
)
p.write_text(s)
PY

grep -Fq 'SAFEBOX_R86_RELEASE_SIGNING_BEGIN' "$APP" || { echo 'SAFEBOX_ANDROID_R86_SIGNING_FAIL: signing patch missing' >&2; exit 1; }
grep -Fq 'import java.util.Properties as SafeBoxProperties' "$APP" || { echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_IMPORT_FAIL: Properties alias import missing' >&2; exit 1; }
grep -Fq 'import java.io.FileInputStream as SafeBoxFileInputStream' "$APP" || { echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_IMPORT_FAIL: FileInputStream alias import missing' >&2; exit 1; }
grep -Fq 'val props = SafeBoxProperties()' "$APP" || { echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_IMPORT_FAIL: Properties alias use missing' >&2; exit 1; }
grep -Fq 'props.load(SafeBoxFileInputStream(f))' "$APP" || { echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_IMPORT_FAIL: FileInputStream alias use missing' >&2; exit 1; }
echo 'SAFEBOX_ANDROID_R86_RC4_GRADLE_ALIAS_IMPORT_PASS'
echo 'SAFEBOX_ANDROID_R86_SIGNING_CONFIG_PASS'
echo 'SAFEBOX_ANDROID_R86_RC2_NONINTERACTIVE_DNAME_PASS'
echo "SAFEBOX_ANDROID_R86_KEYSTORE_PATH: $KEYSTORE"
echo 'SAFEBOX_ANDROID_R86_SIGNING_SETUP_PASS'
