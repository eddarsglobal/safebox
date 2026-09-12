# SAFEBOX v0.2.8 — iOS Native Share Extension R47

## Trigger
Reference Mac R46 built the standalone Share Extension successfully and emitted `SAFEBOX_IOS_SHARE_EXTENSION_TARGET_PASS`, then failed before embedding with `SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension point mismatch`.

## Root cause
The canonical `ios-share/Info.plist` declares `NSExtensionPointIdentifier = com.apple.share-services`, but the R46 XcodeGen spec used an `info:` generation block. That allowed XcodeGen to manage the generated plist instead of treating the canonical plist as immutable input. Runtime validation correctly rejected the compiled `.appex` when its extension point no longer matched the Share Extension contract.

## R47 decision
- remove XcodeGen `info:` generation for the extension;
- set `INFOPLIST_FILE = Info.plist` explicitly;
- set `GENERATE_INFOPLIST_FILE = NO`;
- fail closed unless the canonical plist already contains `com.apple.share-services`;
- hash `Info.plist` before and after XcodeGen and reject any mutation;
- print and validate the extension point from the actually compiled `.appex` before embedding/signing.

## Security / integrity
- R42 Ads/UMP and R41 linker surfaces unchanged;
- no Ruby/xcodeproj runtime dependency;
- no mutation of Tauri's generated `.pbxproj`;
- App Group staging and 0700/0600/Data Protection contract unchanged;
- no crypto/SBX format changes;
- extension is embedded only after its compiled plist passes the exact extension-point gate.

## Acceptance
Reference Mac must prove: main app build PASS, extension build PASS, `SAFEBOX_IOS_SHARE_EXTENSION_POINT: com.apple.share-services`, `SAFEBOX_IOS_SHARE_EXTENSION_POINT_PASS`, App Group runtime entitlements PASS, embed PASS, install/boot PASS, then Share -> SafeBox -> Protect runtime PASS.
