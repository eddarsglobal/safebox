# SafeBox v0.2.6 — iOS Standalone Rust Bridge R35

## Why R35 exists

R34 correctly moved the runtime gate to a direct `xcodebuild ... -sdk iphonesimulator ... build`, but the generated Xcode `Build Rust Code` phase still invoked Tauri's hidden `ios xcode-script` command. In normal `tauri ios dev/build` operation that command reads `CliOptions` from a parent Tauri WebSocket server. A direct Xcode build has no such parent; the reference Mac therefore failed with `failed to read CLI options` / `Connection refused` before Cargo compilation.

R35 keeps the direct Simulator build and replaces only that nested simulator build phase with a SafeBox-local Rust bridge.

## Runtime contract

- Tauri still owns Apple/Xcode project generation.
- Xcode still owns the native iOS Simulator application build/link/install boundary.
- `SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT=1` is set only around the direct Simulator `xcodebuild` process.
- `safebox_tauri.sh` intercepts `ios xcode-script` only when that flag is present.
- The bridge refuses any platform other than exactly `iOS Simulator`.
- Intel Simulator: `x86_64` → `x86_64-apple-ios`.
- Apple Silicon Simulator: Xcode `arm64` → Rust `aarch64-apple-ios-sim`.
- Cargo builds the SafeBox Rust library with `--locked --lib`.
- The resulting `libsafebox_desktop_lib.a` is copied transactionally to the Xcode-generated `Externals/<arch>/<configuration>/libapp.a` location expected by Tauri's project template.
- The copy is SHA-256 verified before the bridge returns PASS.
- A `start_app` symbol check is performed when `nm` is available.

## Security invariants retained

- No SBX format or crypto change.
- No access code/password is passed to the build tooling.
- R31 security-scoped Files + private staging boundary remains unchanged.
- The bridge is Simulator-only and cannot be used to bypass physical-device signing.
- Production/real-iPhone `ios xcode-script` invocations continue to the stock Tauri CLI.
- Cargo lock is enforced with `--locked`.
- Rust output is copied using a temporary file + atomic rename within the Externals directory.

## 9-council checkpoint review

1. **Security Council:** PASS — no cryptographic or SBX changes.
2. **Defensive HACKER / Red Team:** PASS — explicit Simulator-only refusal protects device signing boundary.
3. **Apple/iOS Council:** PASS — output path matches Tauri 2.11.4's `libapp.a` Xcode contract.
4. **Rust Council:** PASS — locked static-library cross-build with target-specific iOS SDK flags.
5. **Build/Tooling Council:** PASS — no dependency mutation inside the nested Xcode phase.
6. **Frontend Council:** PASS — R34 deterministic Vite lifecycle retained.
7. **QA Council:** PASS — Rust bridge emits begin/hash/output/PASS markers.
8. **Release Council:** PASS — production device/signing route is untouched.
9. **Product Council:** PASS — no UI or product behavior regression introduced.

## Expected runtime markers

```text
SAFEBOX_IOS_RUST_BRIDGE_BEGIN: x86_64-apple-ios debug
SAFEBOX_IOS_RUST_BRIDGE_SHA256: <sha256>
SAFEBOX_IOS_RUST_BRIDGE_OUTPUT: .../Externals/x86_64/debug/libapp.a
SAFEBOX_IOS_RUST_BRIDGE_PASS
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```

On Apple Silicon the bridge target is `aarch64-apple-ios-sim` and the Externals architecture is `arm64`.

Status after source verification: **STANDALONE_RUST_BRIDGE_READY_FOR_MAC_RUNTIME_GATE**.
