#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$D/src-tauri/gen/android"
BUILD_TASK="$(find "$GEN/buildSrc/src/main/java" -type f -name BuildTask.kt 2>/dev/null | head -n1 || true)"
[ -n "$BUILD_TASK" ] && [ -f "$BUILD_TASK" ] || { echo 'SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_FAIL: BuildTask.kt missing' >&2; exit 1; }
python3 - "$BUILD_TASK" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
orig = s
# Tauri can generate `node tauri android ...`; Node then treats `tauri` as a JS file
# in src-tauri and fails with MODULE_NOT_FOUND. For this npm project, use the npm
# package-script invocation expected by the Tauri Android template.
s = re.sub(r'val\s+executable\s*=\s*"""node"""\s*;?', 'val executable = """npm""";', s, count=1)
s = re.sub(
    r'val\s+args\s*=\s*listOf\(\s*"tauri"\s*,\s*"android"\s*,\s*"android-studio-script"\s*\)\s*;?',
    'val args = listOf("run", "--", "tauri", "android", "android-studio-script");',
    s,
    count=1,
)
p.write_text(s)
if s != orig:
    print('SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_PATCHED_PASS')
else:
    print('SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_ALREADY_ALIGNED')
PY
grep -Fq 'val executable = """npm"""' "$BUILD_TASK" || { echo 'SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_FAIL: npm executable missing' >&2; exit 1; }
grep -Fq 'listOf("run", "--", "tauri", "android", "android-studio-script")' "$BUILD_TASK" || { echo 'SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_FAIL: npm tauri args missing' >&2; exit 1; }
if grep -Fq 'val executable = """node"""' "$BUILD_TASK"; then
  echo 'SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_FAIL: node tauri launcher still present' >&2
  exit 1
fi
echo "SAFEBOX_ANDROID_R86_RC5_BUILD_TASK_PATH: $BUILD_TASK"
echo 'SAFEBOX_ANDROID_R86_RC5_NODE_TAURI_MODULE_RESOLUTION_PASS'
