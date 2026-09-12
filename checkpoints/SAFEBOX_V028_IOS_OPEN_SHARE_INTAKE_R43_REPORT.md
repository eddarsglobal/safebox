# SAFEBOX v0.2.8 — iOS Open/Share Intake Foundation — R43

## Scope

R43 starts from the empirically validated v0.2.7/R42 iOS Ads & Privacy baseline. It does **not** add a native Share Extension target yet. It closes the safer prerequisite first: SafeBox can be registered by iOS as an alternate handler for ordinary `public.data` documents, preserve incoming `file://` URLs, and route them through the existing security-scoped mobile staging path.

### Routing contract

- incoming `.sbx` file URL -> Receiver / Unlock;
- incoming ordinary file URL -> Protect / Create SBX;
- non-`file://` URL on iOS -> rejected by the intake helper;
- only the first of multiple opened files is processed, matching the existing one-file-at-a-time product contract.

## iOS document registration

`Info.ios.plist` now declares both:

1. `com.safebox.desktop.sbx` as the SafeBox encrypted document type;
2. `public.data` as an alternate ordinary-document import/open surface named `Protect with SafeBox`.

`LSSupportsOpeningDocumentsInPlace` remains `false`: SafeBox never edits provider-owned documents in place. The custom SBX UTI conforms to both `public.data` and `public.content`.

## Security boundary

Incoming iOS URLs remain `file://` URLs until they reach the existing `tauri-plugin-fs` document adapter. SafeBox acquires security-scoped access only for the copy operation, stages into its private cache workspace, creates staged files with mode `0600` on Unix, and releases the scope through `SecurityScopedAccessGuard`. External provider documents are never burn-deleted; burn applies only to the private working copy.

The new runtime marker logs only `route=protect` or `route=unlock`; it never logs the incoming filename, path, URL, code, metadata, plaintext or ciphertext.

## Validated R42 surface preservation

R43 does not modify:

- `SafeBoxAdsBridge.mm`;
- UMP/GMA installer and linker-scope scripts;
- Ads runtime-session checker;
- Rust/Xcode archive bridge;
- SafeBox crypto/SBX implementation.

The verifier pins SHA-256 hashes for the validated R42 Ads/link runtime surface and reruns the v0.2.7 static verifier.

## Internal 9-council review

1. Security — PASS static: file-only scheme allowlist, private staging, no external deletion.
2. Privacy — PASS static: runtime logs contain route only, no document identity.
3. Crypto — PASS: no `safebox-core` change.
4. iOS platform — PASS static: document types + Tauri `RunEvent::Opened` path are aligned.
5. UX — PASS static: `.sbx` opens Receiver; ordinary document opens Protect.
6. Reliability — PASS static: cold/warm open paths reuse existing stored-state + emitted-event mechanism.
7. Ads/Privacy regression — PASS static: validated R42 native/linker surfaces are byte-identical.
8. Maintainability — PASS: no second native target or App Group introduced in this slice.
9. Release discipline — PASS: empirical iOS Open-in runtime remains a required acceptance gate.

## Defensive HACKER / Red Team

R43 rejects non-file URL schemes on the iOS open-document path, retains the security-scoped URL instead of converting it early to an unscoped path, refuses to delete provider-owned input even when Burn After Unlock is requested, and does not log the external filename or URL. The runtime checker is scoped to the exact R42-style simulator session boundary.

## Runtime acceptance still required

On the reference Mac/iPhone simulator:

1. run `npm run ios:cold-dev`;
2. open/share an ordinary file to SafeBox and confirm the Protect screen receives it;
3. run `npm run ios:open-check -- protect`;
4. open a `.sbx` file to SafeBox and confirm Receiver mode;
5. run `npm run ios:open-check -- unlock`.

Required final markers:

- `SAFEBOX_IOS_OPEN_IN_PROTECT_PASS`
- `SAFEBOX_IOS_OPEN_IN_UNLOCK_PASS`
- `SAFEBOX_IOS_OPEN_IN_RUNTIME_PASS`

A native iOS Share Extension remains a later slice because it introduces a second app-extension target, entitlements and likely an App Group; it must not be smuggled into this foundation without a separate security review.
