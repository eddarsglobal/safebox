#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: $*" >&2; exit 1; }
[[ "$#" -ge 1 ]] || fail 'xcconfig path required'
command -v python3 >/dev/null 2>&1 || fail 'python3 missing'

python3 - "$@" <<'PY_SCOPE'
from pathlib import Path
import re
import sys

SIM_VAR = 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphonesimulator*]'
DEV_VAR = 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphoneos*]'
SIM_PATH = '$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds'
DEV_PATH = '$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64/GoogleMobileAds.framework/GoogleMobileAds'
FORCE_VAR = '$(SAFEBOX_GMA_FORCE_LOAD_BINARY)'
FORCE_FLAGS = f'-Xlinker -force_load -Xlinker "{FORCE_VAR}"'
OLD_R40_PATH = '$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds'
objc_token = re.compile(r'(?<!\S)-ObjC(?!\S)')

def strip_var_defs(lines):
    prefixes=(SIM_VAR+' =', DEV_VAR+' =')
    return [line for line in lines if not line.lstrip().startswith(prefixes)]

for raw in sys.argv[1:]:
    p = Path(raw)
    if not p.is_file():
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: xcconfig missing: {p}')
    original = p.read_text()
    lines = original.splitlines(keepends=True)
    idxs = [i for i, line in enumerate(lines) if re.match(r'^\s*OTHER_LDFLAGS\s*=', line)]
    if len(idxs) != 1:
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: expected one OTHER_LDFLAGS assignment in {p}, found {len(idxs)}')
    i = idxs[0]
    line = lines[i]

    # Only the aggregate iOS user target that actually links pinned GMA may be
    # rewritten. Never weaken ObjC loading for unrelated targets.
    if 'GoogleMobileAds' not in line or 'Google-Mobile-Ads-SDK' not in line:
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: Google Mobile Ads linker surface missing in {p}')

    objcs = len(objc_token.findall(line))
    already_r41 = FORCE_VAR in line and '-force_load' in line
    r40_state = OLD_R40_PATH in line and '-force_load' in line

    if already_r41:
        if objcs:
            raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: targeted force-load and global -ObjC coexist in {p}')
        rewritten = line
    elif r40_state:
        if objcs:
            raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: R40 force-load and global -ObjC coexist in {p}')
        rewritten = line.replace(OLD_R40_PATH, FORCE_VAR)
    else:
        if objcs != 1:
            raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: expected exactly one global -ObjC in {p}, found {objcs}')
        rewritten = objc_token.sub(FORCE_FLAGS, line, count=1)

    if objc_token.search(rewritten):
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: global -ObjC survived in {p}')
    if OLD_R40_PATH in rewritten or 'PODS_XCFRAMEWORKS_BUILD_DIR' in rewritten and '-force_load' in rewritten:
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: generated XCFrameworkIntermediates force-load survived in {p}')
    for required in ('-force_load', FORCE_VAR, 'GoogleMobileAds', 'Google-Mobile-Ads-SDK'):
        if required not in rewritten:
            raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: required token missing after rewrite ({required}) in {p}')

    # Rebuild definitions deterministically so repeated invocations cannot
    # accumulate stale R40/R41 variable assignments.
    lines[i] = rewritten
    lines = strip_var_defs(lines)
    idxs2 = [j for j, x in enumerate(lines) if re.match(r'^\s*OTHER_LDFLAGS\s*=', x)]
    if len(idxs2) != 1:
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: OTHER_LDFLAGS lost while rewriting {p}')
    j = idxs2[0]
    defs = [
        f'{SIM_VAR} = {SIM_PATH}\n',
        f'{DEV_VAR} = {DEV_PATH}\n',
    ]
    lines[j:j] = defs
    updated=''.join(lines)

    # Static text gate: both source slices and the scoped variable must be
    # present; the generated-products path must never be the force-load input.
    for required in (SIM_VAR, SIM_PATH, DEV_VAR, DEV_PATH, FORCE_VAR):
        if required not in updated:
            raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: source-slice token missing ({required}) in {p}')
    if OLD_R40_PATH in updated:
        raise SystemExit(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FAIL: obsolete R40 generated path remains in {p}')

    if updated != original:
        p.write_text(updated)
    print(f'SAFEBOX_IOS_GMA_LINK_SCOPE_FILE_PASS: {p.name}')

print(f'SAFEBOX_IOS_GMA_FORCE_LOAD_SIM_SOURCE: {SIM_PATH}')
print(f'SAFEBOX_IOS_GMA_FORCE_LOAD_DEVICE_SOURCE: {DEV_PATH}')
print('SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_PASS')
print('SAFEBOX_IOS_GMA_OBJC_SCOPE_PATCH_PASS')
PY_SCOPE
