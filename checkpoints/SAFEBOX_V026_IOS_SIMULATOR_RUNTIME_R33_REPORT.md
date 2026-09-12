# SAFEBOX v0.2.6 — iOS Simulator Runtime R33

## Evidence entering R33

R32 reached a successful iPhone Simulator Xcode build, then Tauri entered an archive step that failed because no Apple Development Team was configured. The same archive attempt forced `ARCHS=x86_64` even though Xcode reported x86_64 excluded for that simulator. This is a launcher/tooling failure, not a SafeBox crypto or frontend build failure.

## Changes

- Added `scripts/ios_simulator_run.sh`.
- `ios:cold-dev` now uses the hardened simulator-only path.
- Detects native Apple Silicon even when Terminal/Node runs under Rosetta (`hw.optional.arm64` / `sysctl.proc_translated`).
- Uses explicit Tauri simulator target: `aarch64-sim` on Apple Silicon, `x86_64` on Intel.
- Uses `tauri ios build --debug --target ... --no-sign`; no Development Team is required for this simulator gate.
- Boots the selected iPhone Simulator, ad-hoc signs the local simulator `.app`, installs it with `simctl`, and launches `com.safebox.desktop`.
- Physical-device signing is intentionally not bypassed and remains a separate future gate.
- Added `Info.ios.plist` with `LSSupportsOpeningDocumentsInPlace=false`, matching SafeBox's security-scoped-copy-to-private-staging model.
- No SBX format, Argon2id, XChaCha20-Poly1305, Create, Unlock, or Android behavior changed.

## 9-council checkpoint review

1. **Security Council — PASS:** no weakening of crypto or file transaction semantics.
2. **Defensive HACKER / Red Team — PASS:** simulator-only no-sign path cannot silently become the physical-device distribution path; explicit target avoids translated-host architecture confusion.
3. **iOS Platform Council — PASS:** simulator is booted and installed with `simctl`; provider documents are declared not-open-in-place.
4. **Architecture Council — PASS:** native CPU detection is independent from a Rosetta-translated shell.
5. **Privacy Council — PASS:** no additional network, telemetry, or persistent provider access.
6. **QA Council — READY:** next evidence is runtime install/launch marker and then Files E2E.
7. **Design/UI Council — unchanged:** R29 password-eye/footer Settings retained.
8. **Release Council — NOT DONE:** iOS remains runtime/E2E validation stage.
9. **Cross-platform Council — PASS:** Android v0.2.4 remains frozen.

## Expected markers

- `SAFEBOX_IOS_NATIVE_SIM_TARGET: ...`
- `SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop`
- `SAFEBOX_IOS_RUNTIME_BOOT_PASS`
- `SAFEBOX_V026_IOS_SIMULATOR_RUNTIME_R33_VERIFY_PASS`
