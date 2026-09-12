# SAFEBOX v0.2.8 — iOS Direct `.sbx` Document Owner R54

## Baseline
R52 remains the validated Share Intake baseline. R53's native cold-start capture/staging/Rust delivery infrastructure is retained unchanged. R54 changes only the iOS document-type declaration and its runtime proof.

## R53 reference-Mac finding
`ios:cold-open-arm` successfully terminated SafeBox, but a direct tap on `.sbx` produced no new SafeBox process. Therefore the failure occurred before the R53 bridge: Files/LaunchServices did not dispatch the document to SafeBox.

## R54 LaunchServices contract
For the proprietary encrypted `.sbx` format SafeBox now declares:
- `CFBundleTypeRole = Editor`;
- `LSHandlerRank = Owner`;
- explicit legacy extension `sbx` plus `LSItemContentTypes = com.safebox.desktop.sbx`;
- exported UTI `com.safebox.desktop.sbx`;
- conformance only to `public.data` (encrypted bytes are not advertised as user-viewable `public.content`);
- MIME `application/x-safebox` instead of generic `application/octet-stream`.

The simulator pipeline and arming script verify these values from the **installed** `SafeBox.app/Info.plist`, after uninstall/reinstall, so the test cannot proceed on a stale or malformed bundle declaration.

## Security / compatibility
R53 staging, security-scoped access, anti-symlink/regular-file checks, 0700/0600 permissions, NSFileProtectionComplete, route-only logging and unlock-only Rust routing are unchanged. R52 Share Extension, Ads R42 and crypto/SBX are unchanged.

## Runtime proof
1. `npm run ios:cold-dev`
2. require `SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_INSTALL_PASS`
3. `npm run ios:cold-open-arm`
4. require `SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_PASS`
5. tap a real `.sbx` directly in Simulator Files, not Share
6. `npm run ios:cold-open-check`

Final marker remains `SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS`.
