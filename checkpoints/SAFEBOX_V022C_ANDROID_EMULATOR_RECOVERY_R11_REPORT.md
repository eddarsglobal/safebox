# SAFEBOX v0.2.2C R11 — Android Emulator Recovery / rustfmt closure

- R10 emulator cold-boot recovery is unchanged.
- Closes every `cargo fmt --check` diff reported by the Mac in `safebox-desktop/src-tauri/src/lib.rs`.
- No crypto, SBX format, Android document I/O, or save/verification semantics changed.
- Keeps the R10 removal of the unused `PreparedLocalInput.display_name` field.
- Verification marker: `SAFEBOX_V022C_ANDROID_EMULATOR_RECOVERY_R11_VERIFY_PASS`.
