# SafeBox v0.2.4 — Android Storage Recovery R30

## Trigger
The revised R29 verifier passed, but Android installation failed after build with:

`INSTALL_FAILED_INSUFFICIENT_STORAGE: Failed to override installation location`

This is an emulator capacity failure, not a SafeBox compile/runtime/crypto failure.

## R30 changes
- Adds a `/data` free-space preflight before `tauri android dev` on emulators.
- Requires 512 MiB free by default (`SAFEBOX_ANDROID_MIN_FREE_KB` can override for development).
- On low space, reclaims only SafeBox development/test state:
  - Android cache trim request;
  - uninstall `com.safebox.desktop` development app;
  - remove `/sdcard/Download/SafeBox-E2E` fixtures.
- Never runs this automatic cleanup on physical devices.
- Adds `npm run android:storage-recover` for explicit emulator-only recovery.
- Adds instructions to `howtoinstall.md`.

## Security / product invariants
No SBX format, cryptography, Create/Unlock, retention, Share/Open, password-eye UI, or footer Settings semantics changed.

## Status
R29 Android v0.2.4 product closure remains valid. R30 is development/runtime resilience around emulator storage only.
