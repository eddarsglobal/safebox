# SAFEBOX v0.2.8 — iOS Direct `.sbx` Single Registration R55

## Baseline
R52 remains the validated Share Intake baseline. R53 cold-start capture/staging/Rust delivery remains unchanged. R54 proved the next failure was in the installed document registration, not in the cold-start bridge.

## R54 reference-Mac finding
The Xcode build, R52 Share Extension and App Group gates all passed, then the runtime stopped at:
`SAFEBOX_IOS_SIM_RUN_FAIL: installed SBX document role is not Editor`.

Root cause: two independent SBX registration sources were present. `Info.ios.plist` declared `Editor/Owner/application/x-safebox`, while `tauri.conf.json -> bundle.fileAssociations` still declared the historical `Viewer/Alternate/application/octet-stream`. Tauri generated the old association into the application bundle, creating a conflicting LaunchServices contract.

## R55 decision
`tauri.conf.json -> bundle.fileAssociations` is now the single source of truth for the proprietary SBX type:
- extension: `sbx`;
- UTI: `com.safebox.desktop.sbx`;
- role: `Editor`;
- rank: `Owner`;
- MIME: `application/x-safebox`;
- conformance: exactly `public.data`.

`Info.ios.plist` no longer duplicates `CFBundleDocumentTypes` or `UTExportedTypeDeclarations`; it retains iOS-only supplemental keys such as `LSSupportsOpeningDocumentsInPlace` and Ads privacy configuration.

## Installed-bundle proof
A shared plistlib validator inspects the actual installed `SafeBox.app/Info.plist`. It requires exactly one SBX document registration and exactly one exported SBX UTI, rejecting duplicates/conflicts. The same validator is used during `ios:cold-dev` and again by `ios:cold-open-arm`.

## Security / compatibility
R53 private staging, security-scoped access, regular-file/symlink checks, 0700/0600 permissions, `NSFileProtectionComplete`, route-only logs and unlock-only Rust routing are unchanged. R52 Share Extension, Ads R42, crypto and SBX format are unchanged.

## Runtime proof
1. `npm run ios:cold-dev`
2. require `SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_INSTALL_PASS`
3. `npm run ios:cold-open-arm`
4. require `SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_PASS`
5. tap a real `.sbx` directly in Simulator Files, not Share
6. `npm run ios:cold-open-check`

Final target remains `SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS`.
