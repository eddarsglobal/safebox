# SafeBox v0.2.6 — iOS Bridge argv hardening R36

## Scope

R36 fixes two tooling defects exposed by the real iPhone Simulator run of R35:

1. the generated Xcode build phase expands `--platform iOS Simulator` without shell quoting, so the standalone bridge must reconstruct multi-token option values;
2. the R35 verifier accidentally expanded `$PLATFORM` under `set -u`, producing `PLATFORM: unbound variable` before the defensive gate could run.

No SBX format or crypto change.

## Security boundary

The standalone Rust bridge is still Simulator-only. R36 requires all of these independent signals before compiling:

- reconstructed CLI platform exactly `iOS Simulator`;
- Xcode `PLATFORM_NAME=iphonesimulator`;
- Xcode `EFFECTIVE_PLATFORM_NAME=-iphonesimulator`;
- SDK path under `iPhoneSimulator.platform`.

Any physical-device signal is rejected. Apple device signing/provisioning is not bypassed.

## Runtime parser

R36 reconstructs the generated Xcode argv groups for platform, framework search paths, header search paths and GCC preprocessor definitions. Only known architecture tokens can remain positional after parsing.

The verifier replays the exact argument shape observed on the reference Mac:

`--platform iOS Simulator --sdk-root ... --framework-search-paths ... . --header-search-paths ... --gcc-preprocessor-definitions DEBUG=1 --configuration debug x86_64`

with a mocked Rust toolchain and requires `SAFEBOX_IOS_RUST_BRIDGE_PASS`.

## 9-council checkpoint review

1. **Crypto Council — PASS:** Argon2id/XChaCha20/SBX unchanged.
2. **Platform Council — PASS:** parser matches actual generated Xcode invocation.
3. **iOS Council — PASS:** direct `iphonesimulator` build retained.
4. **Security Council — PASS:** four independent Simulator assertions.
5. **QA Council — PASS:** exact argv replay added.
6. **Release Council — PASS:** checkpoint contains no generated Apple project/build output.
7. **Design/UI Council — PASS:** no UI change.
8. **Privacy Council — PASS:** no network/ads/secret behavior introduced.
9. **Architecture Council — PASS:** physical-device flow remains stock Tauri/Apple signing path.

### Defensive HACKER / Red Team

- malformed multi-token platform cannot silently become an architecture;
- unexpected positional values fail closed;
- `iphoneos` / physical-device environment is explicitly rejected;
- no Development Team or code-signing bypass is added;
- access codes/passwords are never passed through the bridge.

## Runtime gate

After the verifier PASS, run:

```bash
cd safebox-desktop
npm run ios:cold-dev
```

Expected runtime sequence includes:

```text
SAFEBOX_IOS_RUST_BRIDGE_ARGV_PASS: iOS Simulator | <rust-target>
SAFEBOX_IOS_RUST_BRIDGE_PASS
SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS
SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: com.safebox.desktop
SAFEBOX_IOS_RUNTIME_BOOT_PASS
```
