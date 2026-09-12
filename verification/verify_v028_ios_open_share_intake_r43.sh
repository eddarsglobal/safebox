#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
LIB="$APP/src-tauri/src/lib.rs"
MAIN="$APP/src/main.ts"
INFO="$APP/src-tauri/Info.ios.plist"
CHECKER="$APP/scripts/ios_open_intake_check.sh"
fail(){ echo "SAFEBOX_V028_IOS_OPEN_SHARE_R43_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/9] package + validated v0.2.7 baseline retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-open-share-intake-foundation-r43-20260829A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'v0.2.8 package identity mismatch'
SAFEBOX_VERIFY_SKIP_TOOLCHAIN=1 bash "$ROOT/verification/verify_v027_ios_ads_privacy.sh" >/dev/null
printf '%s\n' 'SAFEBOX_V028_V027_BASELINE_RETAINED_PASS'

printf '%s\n' '[2/9] Ads/link runtime implementation unchanged from validated R42'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/9] iOS all-file open intake preserves file URL'
grep -Fq 'fn ios_opened_path_from_url(url: &tauri::Url) -> Option<String>' "$LIB" || fail 'iOS intake helper missing'
grep -Fq 'if url.scheme() != "file"' "$LIB" || fail 'non-file scheme rejection missing'
grep -Fq 'Some(url.to_string())' "$LIB" || fail 'security-scoped URL preservation missing'
grep -Fq 'SAFEBOX_IOS_OPEN_IN_ACCEPT: route={route}' "$LIB" || fail 'route-only runtime marker missing'
! grep -Fq 'SAFEBOX_IOS_OPEN_IN_ACCEPT: url=' "$LIB" || fail 'URL leakage in runtime log marker'
! grep -Fq 'SAFEBOX_IOS_OPEN_IN_ACCEPT: path=' "$LIB" || fail 'path leakage in runtime log marker'
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_URL_PRESERVATION_PASS'

printf '%s\n' '[4/9] iOS document registration'
python3 - "$INFO" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    p=plistlib.load(f)
assert p.get('LSSupportsOpeningDocumentsInPlace') is False
entries=p.get('CFBundleDocumentTypes') or []
assert len(entries) >= 2
content_sets=[set(e.get('LSItemContentTypes') or []) for e in entries]
assert {'com.safebox.desktop.sbx'} in content_sets
assert {'public.data'} in content_sets
for e in entries:
    if set(e.get('LSItemContentTypes') or []) in ({'com.safebox.desktop.sbx'}, {'public.data'}):
        assert e.get('CFBundleTypeRole') == 'Viewer'
        assert e.get('LSHandlerRank') == 'Alternate'
exports=p.get('UTExportedTypeDeclarations') or []
sbx=next(x for x in exports if x.get('UTTypeIdentifier') == 'com.safebox.desktop.sbx')
assert {'public.data','public.content'}.issubset(set(sbx.get('UTTypeConformsTo') or []))
assert 'sbx' in (sbx.get('UTTypeTagSpecification') or {}).get('public.filename-extension', [])
PY
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_DOCUMENT_TYPES_PASS'

printf '%s\n' '[5/9] frontend routes sbx->unlock and ordinary file->protect'
grep -Fq 'const isSbx = displayName.toLowerCase().endsWith(".sbx") || cleaned.toLowerCase().endsWith(".sbx");' "$MAIN" || fail 'frontend route discriminator missing'
grep -Fq 'enterReceiverMode(cleaned);' "$MAIN" || fail 'SBX receiver route missing'
grep -Fq 'setInput("#createInput", cleaned);' "$MAIN" || fail 'ordinary-file protect route missing'
grep -Fq 'First shared file loaded.' "$MAIN" || fail 'multi-file one-at-a-time UX missing'
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_FRONTEND_ROUTE_PASS'

printf '%s\n' '[6/9] security-scoped staging boundary'
grep -Fq '(cfg!(target_os = "ios") && trimmed.starts_with("file://"))' "$LIB" || fail 'iOS external-document detector missing'
grep -Fq 'SecurityScopedAccessGuard::new(app, file_path)' "$LIB" || fail 'security-scoped guard missing'
grep -Fq 'let work_dir = create_mobile_work_dir(app)?;' "$LIB" || fail 'private staging directory missing'
grep -Fq 'options.mode(0o600);' "$LIB" || fail 'private staged-file mode missing'
grep -Fq 'options.burn_after_unlock = requested_source_delete && !prepared.external_document;' "$LIB" || fail 'external source deletion guard missing'
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_PRIVATE_STAGING_PASS'

printf '%s\n' '[7/9] current-session runtime checker'
bash -n "$CHECKER"
grep -Fq -- '--start "$LOG_START"' "$CHECKER" || fail 'session launch-boundary log scope missing'
grep -Fq 'SAFEBOX_IOS_OPEN_IN_ACCEPT: route=$EXPECTED_ROUTE' "$CHECKER" || fail 'expected-route marker gate missing'
grep -Fq 'SAFEBOX_IOS_OPEN_IN_RUNTIME_SESSION_SCOPE_PASS' "$CHECKER" || fail 'session scope marker missing'
grep -Fq 'SAFEBOX_IOS_OPEN_IN_RUNTIME_PASS' "$CHECKER" || fail 'runtime pass marker missing'
grep -Fq '"ios:open-check": "bash scripts/ios_open_intake_check.sh"' "$APP/package.json" || fail 'npm runtime checker command missing'
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_RUNTIME_CHECKER_R43_PASS'

printf '%s\n' '[8/9] compile/static regression'
if [[ "${SAFEBOX_VERIFY_SKIP_TOOLCHAIN:-0}" == "1" ]]; then
  printf '%s\n' 'SAFEBOX_V028_TOOLCHAIN_SKIPPED_FOR_PACKAGE_ASSEMBLY'
else
  cargo fmt --all -- --check
  (cd "$ROOT" && cargo test --locked -p safebox-desktop ios_open_intake_tests --no-fail-fast)
  (cd "$APP" && npm ci --ignore-scripts >/dev/null && npm run build >/dev/null)
fi
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_STATIC_BUILD_R43_PASS'

printf '%s\n' '[9/9] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_OPEN_SHARE_INTAKE_R43_REPORT.md" ]] || fail 'checkpoint report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then
    fail "packaged build artifact: $bad"
  fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_OPEN_IN_HYGIENE_R43_PASS'

printf '%s\n' 'IOS_V028_STATUS: OPEN_SHARE_INTAKE_FOUNDATION_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_OPEN_SHARE_INTAKE_R43_VERIFY_PASS'
