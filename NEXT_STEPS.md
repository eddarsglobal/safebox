# SafeBox Next Steps

## Sprint 1: Core hardening

- Add automated tests for create/unlock roundtrip.
- Add wrong-code tests.
- Add corrupted-header tests.
- Add corrupted-chunk tests.
- Add large-file streaming tests.
- Add overwrite/duplicate filename tests.
- Add safe temp-file handling per OS.

## Sprint 2: Desktop app

Recommended: Tauri + Rust core.

Screens:

1. Home
   - Protect file
   - Open SBX file

2. Protect
   - Drag/drop file
   - Visible SBX name: document.sbx by default
   - Code field
   - Create SBX

3. Unlock
   - Only logo + code field + Unlock
   - File info hidden behind small info button

4. Settings
   - Theme: System / Light / Dark
   - Language: EN / FR / DE / ES / HR / AR / HI / ZH
   - Default SBX visible name: document
   - Burn after unlock: on by default

## Sprint 3: File association

- Windows: register `.sbx` extension and icon.
- macOS: declare document type in app bundle.
- Linux: `.desktop` MIME association.

## Sprint 4: Mobile

- Android share sheet: Share -> SafeBox -> Create SBX -> Share again.
- Android open with: document.sbx -> SafeBox -> code -> restore.
- iOS share extension later.

## Sprint 5: Pro security

- Contact codes.
- Multi-recipient slots.
- SafeBox identity public/private key.
- Online true one-time unlock.
- Expiration and revocation.

## Current mobile continuation — v0.2.8 R43

- iOS Open/Share Intake Foundation: ordinary `public.data` -> Protect; `.sbx` -> Unlock.
- Preserve security-scoped `file://` until private staging.
- Runtime acceptance on reference Mac still required.
- Native iOS Share Extension target follows only after this foundation is empirically validated.

## v0.2.8 R45 — Share Extension CocoaPods Ruby hardening
R45 supersedes R44 for runtime testing. It keeps the R44 Share Extension architecture
but resolves `xcodeproj` from CocoaPods/Homebrew's own Ruby gem environment instead of
assuming the system Ruby can require it.

## v0.2.8 R46 — iOS Native Share Extension standalone XcodeGen build
R45 failed on the reference Mac because the CocoaPods `xcodeproj` gem was not loadable as a Ruby runtime. R46 removes Ruby/xcodeproj entirely: the Share Extension is generated/built as a standalone XcodeGen project, embedded after the proven main app build, and both app/extension receive verified matching App Group simulator entitlements. Runtime validation pending reference Mac.

## v0.2.8 R48 — iOS Native Share Extension bundle identity closure
- R47 reference-Mac extension build/point/App Group/embed PASS; simulator install failed with `Missing bundle ID`.
- R48 explicitly declares and runtime-validates the compiled `.appex` bundle identity contract before embed/install.
- Acceptance: `ios:cold-dev` install + boot PASS, then real Files → Share → SafeBox → Protect runtime gate.


## v0.2.8 R49 — iOS Share Inbox lifecycle closure
- R48 reference-Mac build, extension bundle contract, App Group entitlement, embed, install and runtime boot PASS.
- Real Share Extension staging PASS, but containing SafeBox did not accept staged files after foreground.
- R49 replaces the early UIKit observer/drain call with a native -> Rust registered drain callback, invoked after AppHandle setup and on Tauri `RunEvent::Resumed`.
- Runtime checker now distinguishes registration, lifecycle, App Group container and route failures.
- Crypto/SBX and the validated R42 Ads/linker surfaces remain unchanged.

## Current iOS continuation — v0.2.8 R50
- R49 runtime isolated containing-app App Group container denial.
- R50 moves the containing-app App Group entitlement into the Xcode signing phase and verifies it before embed and after final signing.
- Runtime acceptance still required on the reference Mac.

## v0.2.8 R53 — iOS direct `.sbx` cold-start intake
R52 remains the validated Share baseline. R53 adds a separate one-shot native launch bridge for `.sbx` opened directly from Files when SafeBox is not running. Runtime validation requires `ios:cold-open-arm` then a direct Files tap and `ios:cold-open-check`.

## iOS v0.2.8 R56
Direct `.sbx` cold-start now uses an explicit generated Info.plist registration patch; runtime validation pending on the reference Mac.

## iOS v0.2.8 R61 — replay proof transaction scoping
- R59 runtime delivery/recovery implementation remains unchanged.
- Replay verification is now scoped to the exact latest `ios:cold-share-arm` transaction (`armed_at` + expected route), rather than the broader runtime-session start.
- This prevents false `stage missing` results after package re-extraction and prevents stale earlier shares from satisfying the checker.

## iOS v0.2.8 R62 — durable replay evidence
- Persist the exact validated cold-share transaction immediately after `ios:cold-share-check`.
- Evidence contains SAFEBOX markers only, mode 0600, with SHA-256 + byte length metadata.
- A new `ios:cold-share-arm` deletes older evidence before arming so stale proof cannot satisfy a new transaction.
- `ios:replay-recovery-check` no longer depends on Simulator unified-log retention; it requires evidence metadata to match the current arm exactly and rejects corruption/staleness.
- R59 runtime ACK/receipt implementation, R58 intake hardening, Ads/UMP, direct cold-open, SBX crypto and format remain unchanged.

## Web v0.2.8 R68 — Canonical Rust/WASM SBX core
- R67 desktop audit and Web static foundation are validated on the reference Mac.
- Browser Protect/Unlock now routes into the same Rust SBX1 format/Argon2id/XChaCha20-Poly1305 implementation through a memory API and a small manual WebAssembly ABI.
- No CDN crypto, no JavaScript crypto reimplementation, no wasm-bindgen glue runtime.
- Browser entropy comes from `crypto.getRandomValues`; code/entropy/input copies and WASM result buffers are cleared after operations.
- R68 memory engine is fail-closed above 128 MiB; streaming/large-file Web I/O is the next Web optimization, not a format fork.
- Reference-Mac acceptance requires `npm run web:build`, then real browser Protect -> desktop/macOS Unlock and desktop-created SBX -> browser Unlock interoperability.
