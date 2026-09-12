#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
fail(){ echo "SAFEBOX_WEB_RC7_2_FAIL: $*" >&2; exit 1; }

MAIN_SHA="$(shasum -a 256 "$D/src/main.ts" | awk '{print $1}')"
[[ "$MAIN_SHA" == "3b7408aad7f8c7d163589a8318a4ce156b324330784a9567cc2945f1ca489e16" ]] || fail "unexpected src/main.ts hash: $MAIN_SHA"
grep -Fq 'D / "src/main.ts": "3b7408aad7f8c7d163589a8318a4ce156b324330784a9567cc2945f1ca489e16"' "$D/scripts/web_deployment_check.py" || fail "deployment gate still pins obsolete main.ts hash"

echo SAFEBOX_WEB_RC7_2_MAIN_RUNTIME_HASH_PASS
python3 "$D/scripts/web_deployment_check.py" >/tmp/safebox_web_rc7_2_deployment_check.log
cat /tmp/safebox_web_rc7_2_deployment_check.log
grep -Fq 'SAFEBOX_WEB_DEPLOYMENT_READINESS_R85_PASS' /tmp/safebox_web_rc7_2_deployment_check.log || fail "deployment readiness marker missing"
echo SAFEBOX_WEB_RC7_2_DEPLOYMENT_GATE_PASS
