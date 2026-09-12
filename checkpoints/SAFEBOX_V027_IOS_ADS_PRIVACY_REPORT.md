# SafeBox v0.2.7 — iOS Ads & Privacy

## Scope
- AdMob footer banner on iOS only.
- Google UMP consent update on every app launch.
- No ad request before `canRequestAds == true`.
- Privacy options entry point in Settings.
- Google's official test app/banner IDs in development.
- Ads are best-effort and never gate Create/Unlock/Save.
- No SBX metadata, filename, password, code, path or file bytes are passed to ads.

## SDK pinning
SafeBox intentionally pins Google Mobile Ads SDK **13.3.0** and UMP **3.1.0** for this checkpoint. GMA 13.4.0 raised the minimum Xcode version to 26.2, while the reference Mac currently uses Xcode 16.2.

## Internal 9-council review
1. Security — PASS: no secret/file inputs to ads.
2. Privacy — PASS: UMP before ads; privacy choices present.
3. Crypto — PASS: `safebox-core` unchanged.
4. Platform — PASS: iOS-only FFI.
5. UX — PASS: footer banner, hidden in Settings/Help.
6. Reliability — PASS: ad failure cannot block crypto.
7. Supply chain — PASS: exact SDK pins.
8. Release — TEST MODE only until real AdMob IDs are supplied.
9. Maintainability — PASS: one canonical native bridge + installer.

## Defensive HACKER / Red Team
PASS for this slice: the ads surface has no access to codes, metadata, file paths, plaintext, ciphertext or restored files. Generic ad requests only.

## Runtime CocoaPods target hardening
- The generated runtime Podfile is rewritten deterministically for `safebox-desktop_iOS` only.
- Any stale/generated `safebox-desktop_macOS` target is rejected and never passed to CocoaPods.
- CocoaPods workspace remains authoritative for the simulator build after Ads/UMP attachment.

## iOS native-link correction
- Runtime evidence showed the forced `cargo rustc --crate-type staticlib` workaround was incorrect: it produced `libapp.a` with duplicate copies of Tauri/Swift support objects and Xcode reported 426 duplicate symbols.
- SafeBox now follows the normal Tauri mobile library build path again: `cargo build --locked -p safebox-desktop --lib --target <ios-target>`.
- Ads/UMP no longer uses unresolved Rust -> Objective-C symbols. `SafeBoxAdsBridge.mm` registers a small callback table into Rust from generated `main.mm` immediately before `ffi::start_app()` (`native -> Rust`), so Cargo can build all manifest crate types normally and Xcode remains the only final native linker.
- The callback ABI uses fixed-width `uint8_t`/`u8` values for booleans and carries only Ads visibility/privacy state; no filename, code, metadata, path, plaintext or ciphertext crosses it.
- The Rust bridge performs an archive regression check before Xcode linking and refuses a library containing duplicate `Tauri.swift.o`, `Invoke.swift.o`, `Plugin.swift.o`, `Channel.swift.o` or `Logger.swift.o` members.
- No crypto, SBX format, file I/O, password/code handling, or ad-data isolation semantics changed.

## Final native Objective-C++ compile hardening
- Uses explicit CocoaPods framework headers instead of fragile `@import` directives.
- Direct simulator Xcode build explicitly enables Clang modules and Objective-C ARC for generated Objective-C++ sources.

## Canonical linker closure
- CocoaPods workspace stays authoritative after Ads/UMP attachment.
- The canonical Tauri Externals directory is explicitly appended to `LIBRARY_SEARCH_PATHS` with `$(inherited)` preserved, so `libapp.a` and CocoaPods/Google frameworks are all visible to the final Xcode link.
- No SafeBox crypto/SBX code changed.

## R37 runtime correction — 2026-08-29

The first consolidated runtime candidate was rejected by the reference Mac. Its normal `cargo build --locked -p safebox-desktop --lib --target x86_64-apple-ios` completed, but the resulting aggregate Rust static archive still contained two copies each of `Tauri.swift.o`, `Invoke.swift.o`, `Plugin.swift.o`, `Channel.swift.o`, and `Logger.swift.o`. Therefore the earlier attribution to the forced `cargo rustc --crate-type staticlib` path alone was incomplete.

R37 keeps the normal Cargo/Tauri build and introduces one explicit Darwin archive normalization boundary before `libapp.a` enters Xcode. It never mutates Cargo's source archive. For the five known Tauri Swift support members it accepts either one copy, or exactly two copies that are byte-identical; if Swift debug paths are the only difference, Apple `strip -S` must make the two objects byte-identical while preserving linkable code, relocations and non-debug symbols. Only the second proven-equivalent copy is removed. Missing members, more than two copies, extraction failure, or non-equivalent duplicate payloads fail closed. The archive symbol table is rebuilt, the normalized output is re-counted to exactly one copy per member, then that output alone becomes Xcode's `Externals/.../libapp.a`.

This is intentionally narrower than a generic duplicate remover: SafeBox does not suppress linker diagnostics, does not delete arbitrary duplicate symbols, and does not modify SBX/crypto code. A synthetic executable verifier proves both the accepted identical-duplicate case and rejection of divergent duplicates.

### Internal 9-council review — R37 addendum

1. Architecture: PASS — Cargo output and Xcode input are separated by a deterministic normalization boundary.
2. Security: PASS — fail-closed on divergent or unexpected multiplicity; no secret/user data enters the bridge.
3. Crypto/SBX: PASS — core cryptographic baseline hashes remain unchanged.
4. iOS runtime: PASS static — simulator-only platform boundary and canonical `libapp.a` path remain enforced.
5. Supply chain: PASS — pinned GMA 13.3.0 and UMP 3.1.0 unchanged.
6. Privacy: PASS — UMP-before-ads gate unchanged.
7. UI/product: PASS — Ads footer/privacy UI unchanged.
8. Reliability: PASS static — archive normalizer has positive and negative synthetic regression tests.
9. Release discipline: PASS — package A is superseded; R37/B is the sole replacement candidate.

### Defensive HACKER / Red Team — R37 addendum

Attempted failure classes are explicitly blocked: physical-device misuse of the standalone bridge, malformed Xcode argv, missing Rust target/SDK, missing Tauri members, third or later copies, non-identical duplicate Swift objects, failed extraction, stale output replacement, and crypto baseline drift. Runtime boot and Ads checks remain empirical gates and are not claimed PASS until the reference Mac emits their markers.


## R38 archive portability
See `SAFEBOX_V027_IOS_ARCHIVE_NORMALIZER_R38_REPORT.md`. Runtime acceptance is still pending the reference Mac.

## R39 runtime correction — 2026-08-29

R38 was rejected by the reference Mac after Cargo successfully completed: SafeBox's own normalizer found two non-equivalent `Tauri.swift.o` archive members and stopped before native linking. The previous assumption that duplicate `ar` member names imply duplicate linker symbols is withdrawn.

R39 performs byte-for-byte archive passthrough, reports Tauri member-name counts only as diagnostics, and delegates the actual ABI/unresolved/duplicate-symbol decision to Apple's Xcode linker. No archive member is deleted or rewritten. Source/output SHA-256 equality is mandatory. No SBX format or crypto change.

### Internal 9-council review — R39
All nine councils approve replacing heuristic archive surgery with immutable passthrough plus real linker authority.

### Defensive HACKER / Red Team — R39
Malformed archives and passthrough byte mismatches fail closed. Duplicate member names alone do not bypass linker validation; actual duplicate linker symbols remain a hard Xcode failure.

## R40 runtime correction — 2026-08-29 — scoped Google `-ObjC`

R39 deliberately stopped rewriting `libapp.a` and let the Apple linker arbitrate the archive. The reference Mac then exposed the real failure: `ld` reported 426 duplicate Swift symbols from two Tauri/SwiftRs support groups inside the same `libapp.a`. The effective Xcode link command contains ordinary `-lapp` and no `-all_load`/`-force_load`, but CocoaPods injects a global `-ObjC` through Google Mobile Ads.

Apple's linker semantics make this material: `-ObjC` loads archive members implementing Objective-C classes/categories **or Swift structs/classes/extensions**. That global load-all behavior therefore reaches Tauri's static archive as well as Google Mobile Ads. SafeBox must not solve this by deleting non-equivalent Tauri objects.

R40 keeps the Cargo/Tauri archive byte-for-byte and changes only the generated CocoaPods user-target link scope after `pod install`:

- the standalone global `-ObjC` token is removed from the debug/release aggregate xcconfigs;
- the Google Mobile Ads static framework receives a targeted `-force_load` via `$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds`;
- all other GMA/UMP/system linker flags are preserved;
- the rewrite is idempotent and fail-closed when the expected GMA linker surface is absent;
- the simulator path verifies that global `-ObjC` has not reappeared before the expensive Rust/Xcode build;
- `libapp.a` remains R39 byte-for-byte passthrough; no Swift/Tauri object is stripped, deleted or rewritten.

### Internal 9-council review — R40 addendum

1. **Architecture:** approved — fix is applied at the dependency/link-scope boundary that introduced the global behavior.
2. **iOS/Xcode:** approved for runtime validation — targeted `-force_load` is scoped to the Google static framework; Xcode remains the ABI/link authority.
3. **Rust/Tauri:** approved — Cargo output is not modified.
4. **Crypto/SBX:** approved — no SBX format, crypto, KDF, AEAD, metadata or key path changed.
5. **Privacy/Ads:** approved — UMP-before-GMA gate and pinned SDK versions remain unchanged.
6. **Supply chain:** approved — CocoaPods pins remain GMA 13.3.0 / UMP 3.1.0 and generated linker state is checked deterministically.
7. **QA/Regression:** approved — synthetic positive, idempotency and fail-closed tests cover the scope transform; R35/R36/R39 regressions remain PASS.
8. **Operations:** approved — pre-build markers expose linker-scope drift before a long build.
9. **Product/UI:** no behavior change — banner/privacy UI remains untouched.

### Defensive HACKER / Red Team — R40 addendum

- Reject arbitrary deletion of duplicate Swift archive members.
- Reject a simultaneous global `-ObjC` plus targeted GMA force-load state.
- Reject xcconfigs that do not contain the expected Google Mobile Ads linker surface.
- Preserve all non-`-ObjC` linker flags verbatim.
- Keep the source Rust archive byte-for-byte untouched.

R40 is **ready for empirical Mac runtime validation**, not yet declared runtime PASS. Required next gates remain `SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS`, `SAFEBOX_IOS_RUNTIME_BOOT_PASS`, then UMP/GMA/banner runtime verification.


## R41 source-slice linker scope

R40 removed the global `-ObjC` collision but targeted a generated XCFrameworkIntermediates binary that Xcode rejected as a build input. R41 keeps the scoped strategy and points `-force_load` to the pinned GoogleMobileAds source slice already present under `$(PODS_ROOT)`, with separate simulator/device paths and fail-closed existence checks.

## R42 — current-session Ads runtime proof
R41 reference-Mac build/runtime passed. Its Ads checker produced a false negative after more than ten minutes because `UMP_UPDATE_BEGIN` and `GMA_INIT_PASS` are one-shot startup events while banner load events refresh later. R42 records the exact runtime launch boundary and verifies UMP -> GMA -> banner ordering from that current session. No application/crypto behavior changes.
