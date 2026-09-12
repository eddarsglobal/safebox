# SafeBox v0.2.2d — Android Dev Runtime R25

## 9 Councils decision
R25 is a release-engineering/platform hardening checkpoint. It does not alter SBX cryptography, file format, unlock policy, Android Share/Open semantics, or UI behavior.

## Problem observed
After Android APK installation and MainActivity start, the Vite dev server restarted and failed with `Cannot find module 'vite'`. The Android build used nested/concurrent `npx tauri` invocations while Vite was already running.

## Fix
- Added `scripts/ensure_frontend_toolchain.sh`.
- Locked runtime toolchain validation: Vite 8.1.3, Tauri CLI 2.11.4, TypeScript 7.0.2.
- Any missing/corrupt toolchain is restored with one `npm ci` **before** Android runtime starts.
- Replaced runtime `npx tauri` calls with the already-installed local `node_modules/.bin/tauri` binary.
- The nested Gradle `android android-studio-script` invocation is explicitly forbidden from running `npm ci` or mutating `node_modules` while Vite is alive.
- `android_cold_dev.sh` contains no direct `npm ci`; dependency mutation cannot occur after Tauri/Vite launch.
- Inherits R24 PostCSS 8.5.24 and nanoid 3.3.18 supply-chain pins.

## Security invariant
No received Android file triggers encryption or decryption automatically. User action remains mandatory.
