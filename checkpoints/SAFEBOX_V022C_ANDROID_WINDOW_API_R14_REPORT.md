# SafeBox v0.2.2C R14 — Android Window API Gate

## 9 Councils decision

- Platform Council: desktop-only window operations must be compile-time isolated from Android/iOS.
- Security Council: no crypto, SBX format, code handling, or file-content behavior changed.
- Mobile Council: Android/iOS keep only cross-platform window operations (`show`, `set_focus`).
- Desktop Council: `unminimize` remains available on desktop builds only.
- QA Council: add an invariant preventing `unminimize()` from escaping its desktop cfg guard.
- Architecture Council: use cfg-based builder shadowing instead of a mobile `mut` that exists only for desktop plugin wiring.
- Reliability Council: preserve R13 auto-init and duplicate-AVD recovery unchanged.
- UX Council: opening an SBX continues to bring the main SafeBox surface forward where supported.
- Defensive Red-Team Council: cross-target compilation is a release gate; desktop-only APIs must not leak into mobile targets.

## Fixes

1. Guarded `WebviewWindow::unminimize()` with `#[cfg(desktop)]`.
2. Reworked Tauri builder wiring so `tauri-plugin-single-instance` remains desktop-only without `unused_mut` on mobile.
3. Added `verification/verify_v022c_android_window_api_r14.sh`.

## Expected next Android gate

`npm run android:cold-dev` must compile `safebox-desktop` for `x86_64-linux-android` past the former `unminimize` error.
