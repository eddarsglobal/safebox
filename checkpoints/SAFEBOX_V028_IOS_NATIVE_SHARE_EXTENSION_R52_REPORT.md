# SAFEBOX v0.2.8 — iOS Native Share Extension R52

## Runtime evidence that triggered R52

R51 proved the App Group capability is now genuinely usable by the containing app: `SAFEBOX_IOS_SHARE_INBOX_CONTAINER_PASS` and a setup drain completed with `count=0`. A later real Share Extension invocation emitted `SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS`, but returning to SafeBox did not emit Tauri `RunEvent::Resumed`, so no second drain occurred.

## Root cause

`RunEvent::Resumed` is not a reliable foreground boundary for this Tauri/iOS Share Extension return path on the reference Xcode 16.2 / iOS 18.3 simulator. The data path and App Group are healthy; only the foreground trigger was missing.

## R52 decision

- Keep the R49 native-to-Rust registered drain API.
- Install native UIKit foreground observers before `start_app()` for `UIApplicationDidBecomeActiveNotification` and, on iOS 13+, `UISceneDidActivateNotification`.
- Native activation calls exported Rust `safebox_ios_share_foreground()`.
- Rust emits `trigger=native-foreground` and invokes the already-registered native drain callback.
- Keep Tauri `RunEvent::Resumed` only as a non-authoritative fallback.
- Runtime checker requires strict ordering: Share Extension stage -> native foreground drain -> route accept.

## Security invariants

- App Group identifier unchanged.
- Share Extension remains ingestion-only.
- External provider files are copied, never deleted.
- App Group/private staging permissions unchanged.
- Ads/UMP/linker validated R42 surfaces unchanged.
- Crypto/SBX unchanged.
- Runtime markers disclose no path or filename.
