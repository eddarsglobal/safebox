# SafeBox v0.2.6 — iOS Direct Simulator Runtime R34

## Why R34 exists

R33 retained the correct iOS security foundation and selected the correct Intel simulator Rust target, but used `tauri ios build --no-sign`. On the reference Mac the Tauri command entered an `iphoneos` archive path (`ArchiveIntermediates/.../debug-iphoneos`) and failed because an archive requires device-signing context. The same log already proved that the earlier direct `xcodebuild ... -sdk iphonesimulator ... build` action completed successfully.

R34 therefore separates the simulator gate from device/archive packaging.

## Runtime contract

- Tauri still generates the Apple/Xcode project.
- The frontend dev server is started explicitly on `127.0.0.1:1420` when needed.
- The simulator is selected and booted with `simctl`.
- Xcode is invoked directly with `-sdk iphonesimulator`, an explicit simulator destination, debug configuration and active architecture.
- The output is written to disposable DerivedData outside the source tree.
- The resulting `.app` is installed and launched with `simctl`.
- No `archive`, `iphoneos`, IPA export, provisioning profile or Apple Development Team is used in the simulator path.
- Real iPhone/App Store signing remains a separate future release gate.

## Security invariants retained

- R31 security-scoped Files picker and private staging retained.
- security-scoped resource release retained.
- SBX crypto/format unchanged.
- iOS documents are not edited in place.
- no secret code is passed to shell tooling.
- simulator tooling does not bypass signing requirements for physical devices.

## 9-council checkpoint review

1. **Security Council:** PASS — no crypto/SBX changes.
2. **Defensive HACKER / Red Team:** PASS — simulator-only path is explicit; no device signing bypass.
3. **Platform Council:** PASS — build action is pinned to `iphonesimulator` + selected UDID.
4. **Rust Council:** PASS — Rust target preflight retained.
5. **Apple/iOS Council:** PASS — no archive for simulator runtime validation.
6. **Frontend Council:** PASS — Vite lifecycle owned/reused deterministically.
7. **QA Council:** PASS — deterministic PASS markers added before install/launch.
8. **Release Council:** PASS — DerivedData kept outside the checkpoint source.
9. **Product Council:** PASS — no UI/product regression introduced.

## Expected runtime markers

```text
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_BEGIN
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```

Status after source verification: **DIRECT_SIMULATOR_RUNTIME_READY_FOR_MAC_GATE**.
