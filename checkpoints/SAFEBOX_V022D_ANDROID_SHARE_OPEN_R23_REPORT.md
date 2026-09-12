# SafeBox v0.2.2D — Android Share/Open R23

## Scope
R23 fixes the Rust lifetime regression found by the Mac verification of R22 in the two `OpenFileState` mutex update helpers.

## Fix
Both mutex-lock `if let` blocks now end with an explicit semicolon so the temporary `Result<MutexGuard<...>>` is dropped before the local Tauri state handle. No functional Share/Open, SBX, crypto, UI, or permission behavior changes.

## 9-Council gate
- Crypto/Security: no cryptographic changes.
- Defensive HACKER: no automatic Create/Unlock path introduced.
- Android Platform: lifetime compile blocker fixed.
- iOS Platform: no behavior change.
- Web: no behavior change.
- Desktop: same source remains desktop-checkable through inherited R22/R21/R20 gates.
- Design/UI: no UI change.
- Privacy/Ads: no network or advertising change.
- QA/Release: R23 adds an early lifetime regression invariant and inherits the complete R22 baseline verifier.

## Required Mac marker
`SAFEBOX_V022D_ANDROID_SHARE_OPEN_R23_VERIFY_PASS`
