# SAFEBOX v0.2.2C R10 — Android Emulator Recovery

- R9 Android document I/O remains unchanged.
- Fixes Intel/macOS AVD boot loops caused by corrupt Quick Boot snapshots.
- New `npm run android:cold-dev` starts the selected AVD with `-no-snapshot-load -no-snapshot-save`, resets ADB, waits for `sys.boot_completed=1`, then starts Tauri against the already-running AVD.
- `SAFEBOX_ANDROID_AVD` can override the selected AVD; otherwise the first installed AVD is used.
- Existing connected healthy device/emulator is reused.
- Removed the unused `PreparedLocalInput.display_name` field that produced the R9 Rust warning.
- Dependency audit findings remain a separate gate; no blind `npm audit fix` is applied.
