#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
BRIDGE="$APP/src-tauri/ios/SafeBoxAdsBridge.mm"
INSTALLER="$APP/scripts/install_ios_ads_privacy.sh"
LIB="$APP/src-tauri/src/lib.rs"
MAIN="$APP/src/main.ts"
INFO="$APP/src-tauri/Info.ios.plist"
fail(){ echo "SAFEBOX_V027_VERIFY_FAIL: $*" >&2; exit 1; }
grep -Fq 'SAFEBOX_V027_PACKAGE_ID=v0.2.7-ios-ads-privacy-consolidated-r42-20260829G' "$ROOT/SAFEBOX_V027_PACKAGE_ID.txt" || fail 'package identity mismatch'
echo 'SAFEBOX_V027_CONSOLIDATED_PACKAGE_ID_PASS'

echo '[1/8] crypto baseline unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "crypto baseline changed: $1"; }
check_sha "$ROOT/safebox-core/src/create.rs" a1a9d0b8372b359f5a1313b168df8114992a946f450a791c91d0524b75a8053c
check_sha "$ROOT/safebox-core/src/crypto.rs" d30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c
check_sha "$ROOT/safebox-core/src/error.rs" b76df35fc665ec3f95507fc6f3cfc7df1f7152bde20c71c5bc6ba33b8e89f89c
check_sha "$ROOT/safebox-core/src/format.rs" 26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1
check_sha "$ROOT/safebox-core/src/lib.rs" 3932c21094326d8d9227d2b5959076f41497fe710201febbccac9a7b97fcd55a
check_sha "$ROOT/safebox-core/src/unlock.rs" 339ff8516937ebc4f13c7b10781a5e9818e91730ede9b2daa0b72a2d95e6fafb
check_sha "$ROOT/safebox-core/src/validation.rs" 8ae9df9563a7d8bf0fb0d3399c4642a0ca4e796f284b5681a3cd1f02237f209b
echo 'SAFEBOX_IOS_CRYPTO_UNCHANGED_V027_PASS'

echo '[2/8] UMP-before-ads consent gate'
python3 - "$BRIDGE" <<'PY_VERIFY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
for x in ['requestConsentInfoUpdateWithParameters','loadAndPresentIfRequiredFromViewController','canRequestAds','startWithCompletionHandler','presentPrivacyOptionsFormFromViewController']:
    assert x in s, x
assert s.index('canRequestAds') < s.index('startWithCompletionHandler')
PY_VERIFY
echo 'SAFEBOX_IOS_UMP_CONSENT_GATE_V027_PASS'

echo '[3/8] ads/data isolation'
for forbidden in create_sbx unlock_sbx sender_label public_note access_profile original_file_name input_path output_path receiverCode createCode; do
  ! grep -Fq "$forbidden" "$BRIDGE" || fail "ads bridge references forbidden data: $forbidden"
done
grep -Fq '[GADRequest request]' "$BRIDGE" || fail 'generic GADRequest missing'
grep -Fq '#import <GoogleMobileAds/GoogleMobileAds.h>' "$BRIDGE" || fail 'explicit GMA header import missing'
grep -Fq '#import <UserMessagingPlatform/UserMessagingPlatform.h>' "$BRIDGE" || fail 'explicit UMP header import missing'
! grep -Fq '@import GoogleMobileAds' "$BRIDGE" || fail 'fragile GMA module import remains'
! grep -Fq '@import UserMessagingPlatform' "$BRIDGE" || fail 'fragile UMP module import remains'
echo 'SAFEBOX_IOS_ADS_DATA_ISOLATION_V027_PASS'

echo '[4/8] pinned SDK + test IDs'
grep -Fq "pod 'Google-Mobile-Ads-SDK', '13.3.0'" "$INSTALLER" || fail 'GMA pin missing'
grep -Fq "pod 'GoogleUserMessagingPlatform', '3.1.0'" "$INSTALLER" || fail 'UMP pin missing'
grep -Fq "target 'safebox-desktop_iOS'" "$INSTALLER" || fail 'deterministic iOS Podfile target missing'
! grep -Fq "target 'safebox-desktop_macOS'" "$INSTALLER" || fail 'macOS target leaked into iOS installer'
grep -Fq 'SAFEBOX_IOS_PODFILE_TARGET_PASS: safebox-desktop_iOS' "$INSTALLER" || fail 'Podfile runtime target gate missing'
grep -Fq 'ios_scope_gma_objc_linker.sh' "$INSTALLER" || fail 'R41 GMA linker scope integration missing'
grep -Fq 'SAFEBOX_IOS_GLOBAL_OBJC_LINK_FLAG_REMOVED_PASS' "$INSTALLER" || fail 'R41 global ObjC removal marker missing'
grep -Fq 'SAFEBOX_IOS_GMA_TARGETED_FORCE_LOAD_PASS' "$INSTALLER" || fail 'R41 targeted GMA force-load marker missing'
grep -Fq 'SAFEBOX_IOS_GMA_SOURCE_SLICE_PRECHECK_PASS' "$INSTALLER" || fail 'R41 source-slice precheck marker missing'
grep -Fq 'ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds' "$INSTALLER" || fail 'R41 simulator source slice missing'
grep -Fq 'ios-arm64/GoogleMobileAds.framework/GoogleMobileAds' "$INSTALLER" || fail 'R41 device source slice missing'
grep -Fq 'ca-app-pub-3940256099942544~1458002511' "$INFO" || fail 'sample app ID missing'
grep -Fq 'ca-app-pub-3940256099942544/2435281174' "$BRIDGE" || fail 'sample banner ID missing'
echo 'SAFEBOX_IOS_ADS_SUPPLY_CHAIN_V027_PASS'

echo '[5/8] iOS native registration boundary'
grep -Fq '#[cfg(target_os = "ios")]' "$LIB" || fail 'iOS cfg missing'
grep -Fq 'bootstrap_ios_ads();' "$LIB" || fail 'bootstrap missing'
grep -Fq 'ios_ads_show_privacy_options' "$LIB" || fail 'privacy command missing'
grep -Fq 'pub unsafe extern "C" fn safebox_ios_ads_register' "$LIB" || fail 'Rust native registration entry point missing'
grep -Fq 'IOS_ADS_NATIVE_API' "$LIB" || fail 'registered native API state missing'
! grep -Fq 'fn safebox_ios_ads_bootstrap();' "$LIB" || fail 'old unresolved Rust->native Ads FFI remains'
grep -Fq 'extern "C" void SBXAdsRegisterNativeBridge(void)' "$BRIDGE" || fail 'native registration entry point missing'
grep -Fq 'safebox_ios_ads_register(' "$BRIDGE" || fail 'native->Rust registration call missing'
grep -Fq "grep -Fq 'SBXAdsRegisterNativeBridge();' \"\$MAIN_MM\"" "$INSTALLER" || fail 'generated main registration injection gate missing'
grep -Fq 'CARGO_ARGS=(build --locked -p safebox-desktop --lib --target "$RUST_TARGET")' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'Tauri-compatible cargo build path missing'
! grep -Fq 'CARGO_ARGS=(rustc ' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'forced cargo rustc path remains'
grep -Fq 'SAFEBOX_IOS_RUST_TAURI_BUILD_PATH_PASS' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'Tauri build path marker missing'
grep -Fq 'ios_archive_passthrough.sh' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'R39 archive passthrough integration missing'
! grep -Fq 'ios_normalize_tauri_archive.sh' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'obsolete archive mutation still integrated in bridge'
grep -Fq 'cmp -s "$SRC" "$DST"' "$APP/scripts/ios_archive_passthrough.sh" || fail 'byte-for-byte passthrough gate missing'
grep -Fq 'Duplicate member *names* inside an ar archive are legal' "$APP/scripts/ios_archive_passthrough.sh" || fail 'archive-name/linker-symbol distinction missing'
grep -Fq 'SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_PASS' "$APP/scripts/ios_archive_passthrough.sh" || fail 'archive passthrough marker missing'
grep -Fq 'SAFEBOX_IOS_ABI_VALIDATION: XCODE_LINKER' "$APP/scripts/ios_xcode_rust_bridge.sh" || fail 'Xcode linker authority missing'
bash "$ROOT/verification/verify_v027_ios_archive_passthrough_r39.sh"
bash "$ROOT/verification/verify_v027_ios_gma_link_scope_r41.sh"
bash "$ROOT/verification/verify_v027_ios_ads_runtime_session_r42.sh"
echo 'SAFEBOX_IOS_ADS_FFI_V027_PASS'

echo '[6/8] privacy UI + footer behavior'
grep -Fq 'iosPrivacyChoicesBtn' "$MAIN" || fail 'privacy UI missing'
grep -Fq 'setIosAdVisible(false)' "$MAIN" || fail 'modal hide missing'
grep -Fq 'setIosAdVisible(true)' "$MAIN" || fail 'operational show missing'
grep -Fq 'data-ios-ad-visible' "$APP/src/style.css" || fail 'footer spacing missing'
echo 'SAFEBOX_IOS_ADS_UI_V027_PASS'

echo '[7/8] shell + static build'
bash -n "$INSTALLER"
bash -n "$APP/scripts/ios_ads_runtime_check.sh"
bash -n "$APP/scripts/ios_scope_gma_objc_linker.sh"
bash -n "$APP/scripts/ios_simulator_run.sh"
grep -Fq 'CLANG_ENABLE_MODULES=YES' "$APP/scripts/ios_simulator_run.sh" || fail 'Objective-C++ module build setting missing'
grep -Fq 'CLANG_ENABLE_OBJC_ARC=YES' "$APP/scripts/ios_simulator_run.sh" || fail 'Objective-C++ ARC build setting missing'
grep -Fq 'EXTERNAL_LIB_DIR="$APPLE_DIR/Externals/$XCODE_SIM_ARCH/debug"' "$APP/scripts/ios_simulator_run.sh" || fail 'libapp Externals path missing'
grep -Fq 'XCODE_INHERITED=' "$APP/scripts/ios_simulator_run.sh" || fail 'Xcode inherited search path literal missing'
grep -Fq 'LIBRARY_SEARCH_PATHS=$XCODE_INHERITED $EXTERNAL_LIB_DIR' "$APP/scripts/ios_simulator_run.sh" || fail 'libapp library search path injection missing'
grep -Fq 'SAFEBOX_IOS_GLOBAL_OBJC_LINK_FLAG_REMOVED_PASS' "$APP/scripts/ios_simulator_run.sh" || fail 'R41 simulator ObjC scope preflight missing'
grep -Fq 'SAFEBOX_IOS_GMA_TARGETED_FORCE_LOAD_PASS' "$APP/scripts/ios_simulator_run.sh" || fail 'R41 simulator GMA force-load preflight missing'
grep -Fq 'SAFEBOX_IOS_GMA_SOURCE_SLICE_PRECHECK_PASS' "$APP/scripts/ios_simulator_run.sh" || fail 'R41 simulator source-slice preflight missing'
grep -Fq 'SAFEBOX_IOS_RUNTIME_SESSION_CAPTURE_PASS' "$APP/scripts/ios_simulator_run.sh" || fail 'R42 runtime-session capture missing'
grep -Fq -- '--start "$LOG_START"' "$APP/scripts/ios_ads_runtime_check.sh" || fail 'R42 session-start log scope missing'
grep -Fq 'SAFEBOX_IOS_ADS_ORDER_PASS' "$APP/scripts/ios_ads_runtime_check.sh" || fail 'R42 ads-order runtime gate missing'
! grep -Fq -- '--last 10m' "$APP/scripts/ios_ads_runtime_check.sh" || fail 'obsolete rolling 10-minute runtime window remains'
if [[ "${SAFEBOX_VERIFY_SKIP_TOOLCHAIN:-0}" == "1" ]]; then
  echo 'SAFEBOX_IOS_ADS_TOOLCHAIN_SKIPPED_FOR_PACKAGE_ASSEMBLY'
else
  (cd "$APP" && npm ci --ignore-scripts >/dev/null && npm run build >/dev/null)
  (cd "$ROOT" && cargo check --locked -p safebox-core >/dev/null)
  (cd "$ROOT" && cargo check --locked -p safebox-desktop >/dev/null)
fi
echo 'SAFEBOX_IOS_ADS_STATIC_BUILD_V027_PASS'

echo '[8/8] council + red-team'
grep -Fq 'Internal 9-council review' "$ROOT/checkpoints/SAFEBOX_V027_IOS_ADS_PRIVACY_REPORT.md" || fail 'council report missing'
grep -Fq 'Defensive HACKER / Red Team' "$ROOT/checkpoints/SAFEBOX_V027_IOS_ADS_PRIVACY_REPORT.md" || fail 'red-team report missing'
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_V027_PASS'

echo 'IOS_V027_STATUS: ADS_PRIVACY_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V027_IOS_ADS_PRIVACY_VERIFY_PASS'
