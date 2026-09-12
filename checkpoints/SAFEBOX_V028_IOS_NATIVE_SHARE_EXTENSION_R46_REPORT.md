# SAFEBOX v0.2.8 — iOS Native Share Extension R46

## Trigger
Reference Mac R45 reached the generated Apple project, Ads/UMP installation and R41 linker scope, then failed before the Share Extension build with:
`SAFEBOX_IOS_SHARE_INSTALL_FAIL: xcodeproj runtime unavailable in CocoaPods Ruby environment`.

## Decision
R46 removes Ruby/xcodeproj from the runtime path entirely. The extension is generated as a standalone Xcode project using the already-required `xcodegen` binary, built separately for the active simulator architecture, copied into the containing app at `PlugIns/SafeBoxShareExtension.appex`, then signed with matching App Group entitlements.

## Security / integrity
- R42 Ads/UMP and R41 linker surfaces remain unchanged.
- No mutation of Tauri's generated `.pbxproj`.
- No Ruby gem installation, `sudo`, or system-gem mutation.
- Share payload staging remains copy-only, regular-file-only, 0700/0600, Data Protection Complete.
- Containing app drains the App Group inbox into private staging before Rust/Tauri routing.
- Existing simulator entitlements are merged, not discarded, before re-signing.
- Share Extension and containing app signatures are verified after App Group entitlement injection.

## Acceptance
Static/package gates can validate structure in the assembly environment. Runtime acceptance requires the reference Mac to prove:
1. main SafeBox simulator build PASS;
2. standalone Share Extension build PASS;
3. App Group runtime entitlement PASS;
4. embedded `.appex` PASS;
5. app install + runtime boot PASS;
6. Files -> Share -> SafeBox -> Protect/Unlock runtime gate PASS.
