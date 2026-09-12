# SAFEBOX v0.2.8 — iOS Native Share Extension R49

## Scope
Close the final Share Extension inbox lifecycle gap observed on the reference Mac after R48.

## Reference-Mac evidence inherited from R48
- Share Extension build: PASS
- `NSExtensionPointIdentifier=com.apple.share-services`: PASS
- bundle identifier/executable/package/version contract: PASS
- App Group runtime entitlements: PASS
- `.appex` embed: PASS
- simulator install: PASS
- SafeBox runtime boot: PASS
- real Files -> Share -> SafeBox staging: PASS
- containing-app inbox acceptance after foreground: FAIL

## R49 change
The old bridge installed a UIKit `UIApplicationDidBecomeActiveNotification` observer before Tauri entered Rust. R49 removes lifecycle ownership from that pre-start native hook. Native code now registers a resolved `SBXDrainShareInboxNow` function pointer into Rust before `start_app()`. Rust invokes it only after `AppHandle` is installed and again whenever Tauri emits `RunEvent::Resumed`.

This preserves the proven native -> Rust link direction used by the Ads bridge and avoids unresolved Rust -> Objective-C symbols during Cargo's mobile library build.

## Diagnostics / fail-closed behavior
Runtime markers distinguish:
- native registration
- Rust registration
- setup/resumed drain request
- App Group container availability
- drain begin/pass
- route acceptance

The checker fails separately for missing registration, missing Resumed lifecycle, inaccessible App Group container, or missing Protect/Unlock route.

## Security
- no crypto/SBX format change
- no Ads/UMP/linker change
- no user filenames or paths added to logs
- external shared source remains copy-only
- private staging permissions remain 0700/0600
- App Group inbox remains fail-closed

## Runtime acceptance
On the reference Mac:
1. `npm run ios:cold-dev`
2. Files -> Share -> SafeBox with a normal file
3. return to SafeBox
4. `npm run ios:share-check -- protect`

Expected final marker: `SAFEBOX_IOS_SHARE_RUNTIME_PASS`.
