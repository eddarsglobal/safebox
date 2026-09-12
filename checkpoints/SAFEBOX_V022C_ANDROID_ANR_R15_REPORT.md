# SafeBox v0.2.2C — Android ANR / UI-thread hardening R15

## Trigger
Android build/install succeeds, but Android repeatedly reports “SafeBox isn't responding”. The R14 UI also still displayed a macOS sample path placeholder.

## 9-Council decision
- **Platform Council:** blocking filesystem/content-URI/crypto/export work must never run in a synchronous mobile IPC handler.
- **Android Council:** `read_sbx_public_info`, Create, Unlock and Save are async Tauri commands whose blocking work runs via `tauri::async_runtime::spawn_blocking`.
- **UI Council:** legacy 1.0–1.2 s maintenance loops are desktop-only; Android/iOS do not register them.
- **UX Council:** remove macOS-specific sample path from mobile-visible UI.
- **Security Council:** cryptographic algorithms, SBX format, KDF limits and burn policy are unchanged.
- **Privacy Council:** no filename/code/content logging was added.
- **Reliability Council:** mobile lifecycle/open-file handling no longer calls desktop focus/show/unminimize behavior.
- **QA Council:** verifier enforces async/background and mobile-loop invariants and chains the full R14 baseline gate.
- **Defensive HACKER Council:** generated-file allow-list and byte-for-byte export verification remain intact; moving work off the UI thread does not expand the file access surface.

## R15 changes
1. Heavy SafeBox commands run on blocking worker threads rather than the UI/IPC path.
2. Mobile `focus_main_window` is a no-op; desktop keeps show/unminimize/focus.
3. The four recurring legacy DOM maintenance jobs are not registered on Android/iOS.
4. The Help MutationObserver is not installed on mobile and self-disconnects if the runtime becomes mobile.
5. Original-file placeholder is now `Select a file` instead of `/Users/noury/Desktop/test.png`.

## Validation target
`SAFEBOX_V022C_ANDROID_ANR_R15_VERIFY_PASS`
