# SAFEBOX v0.2.8 — iOS Native Share Extension R51

## Runtime evidence that triggered R51

R50's Xcode build succeeded, but its own pre-embed proof stopped with `containing app missing build-time App Group entitlement`.

The full Xcode log shows why that proof was incorrect on Simulator: Xcode generated `SafeBox.app.xcent` with an empty entitlement dictionary for outer code signing, **and separately generated `SafeBox.app-Simulated.xcent` containing both the application identifier and `group.com.safebox.desktop.share`**. The linker injects the simulated entitlement payload into the simulator executable.

## Root cause

R50 tested `codesign -d --entitlements` on the outer app bundle as if it were the authoritative simulator capability source. On Xcode 16 simulator builds, App Group capability is represented in `*-Simulated.xcent` and linked into the executable's simulator entitlement section. This is consistent with the Share Extension behavior already observed: the extension could stage into the App Group even though its ordinary outer signing xcent was not the runtime capability source.

## R51 decision

- Keep R50's Xcode-time `CODE_SIGN_ENTITLEMENTS` injection.
- Fail closed on the generated `SafeBox.app-Simulated.xcent` App Group and application identifier.
- Prove the group string is embedded in the built `SafeBox` simulator executable.
- Preserve the Share Extension's Xcode-produced signature instead of rewriting its entitlements post-build.
- After embedding the extension, re-sign only the containing app outer bundle using Xcode's own `SafeBox.app.xcent` so the new PlugIns resource seal is valid.
- Re-prove that the main executable still contains the simulated App Group entitlement after final signing.

## Security invariants

- App Group identifier unchanged.
- Share Extension remains ingestion-only.
- External provider files are copied, never deleted.
- Ads/UMP/linker validated R42 surfaces unchanged.
- Crypto/SBX unchanged.
- No path or filename is emitted in runtime markers.
