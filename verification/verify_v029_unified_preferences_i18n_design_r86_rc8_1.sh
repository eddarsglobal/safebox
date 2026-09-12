#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$ROOT/verification/verify_v029_unified_preferences_i18n_design_r86_rc8.sh"
CHECK="$ROOT/safebox-desktop/scripts/web_experience_check.py"
LANDING="$ROOT/safebox-desktop/src/landing.ts"
grep -Fq "resultLocal" "$CHECK"
grep -Fq "resultEncrypted" "$CHECK"
grep -Fq "resultPortable" "$CHECK"
grep -Fq 'data-i=\"resultLocal\"' "$CHECK"
grep -Fq 'data-i="resultLocal"' "$LANDING"
grep -Fq 'data-i="resultEncrypted"' "$LANDING"
grep -Fq 'data-i="resultPortable"' "$LANDING"
if grep -Fq "'LOCAL · ENCRYPTED · PORTABLE'" "$CHECK"; then
  echo 'SAFEBOX_R86_RC8_1_VERIFY_FAIL: stale English-only finale gate remains' >&2
  exit 1
fi
echo SAFEBOX_R86_RC8_1_I18N_FINALE_GATE_PASS
echo SAFEBOX_V029_UNIFIED_PREFERENCES_I18N_DESIGN_R86_RC8_1_PASS
