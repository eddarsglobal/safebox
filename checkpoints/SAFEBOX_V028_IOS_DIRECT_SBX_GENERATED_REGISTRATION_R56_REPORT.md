# SAFEBOX v0.2.8 — iOS Direct `.sbx` Generated Registration R56

## Baseline
R52 remains the validated iOS Share Intake baseline. R53 cold-start capture/staging/Rust delivery remains unchanged. R55 proved that the configured Tauri `bundle.fileAssociations` entry is not emitted as an iOS `CFBundleDocumentTypes` registration by the reference Tauri/Xcode generation path: the installed bundle contained zero SBX document registrations.

## R55 reference-Mac finding
The application and Share Extension built successfully and the R52 App Group gates passed. The fail-closed installed-bundle validator then reported `expected exactly one SBX document registration, found 0`. This is before cold-open dispatch and before the R53 bridge.

## R56 decision
Do not depend on Tauri's cross-platform file association translation for iOS LaunchServices. After `tauri ios init` and after Ads/Share setup, `install_ios_cold_open_intake.sh` patches the generated application `Info.plist` atomically using a canonical iOS-only `SafeBoxDocumentRegistration.plist`.

The patch is replacement-based: it deletes any generated/legacy `CFBundleDocumentTypes` and `UTExportedTypeDeclarations`, then installs exactly one canonical SBX registration. This prevents both R54's duplicate/conflicting registration and R55's zero-registration failure while retaining desktop file-association configuration.

Canonical iOS contract:
- extension `sbx`;
- UTI `com.safebox.desktop.sbx`;
- role `Editor`;
- handler rank `Owner`;
- MIME `application/x-safebox`;
- conformance exactly `public.data`.

The existing validator proves the generated plist immediately after the patch, the installed application bundle before launch, and the installed bundle again when `ios:cold-open-arm` is executed.

## Security / compatibility
The patch modifies only the two LaunchServices registration keys and preserves unrelated generated plist keys such as Ads configuration. R53 private staging, security-scoped access, regular-file/symlink checks, 0700/0600 permissions, `NSFileProtectionComplete`, route-only logging and unlock-only routing are unchanged. R52 Share Extension, Ads R42, crypto and SBX format are unchanged.

## Runtime target
1. `npm run ios:cold-dev`
2. require generated contract + installed contract PASS markers
3. `npm run ios:cold-open-arm`
4. tap a real `.sbx` directly in Simulator Files, not Share
5. `npm run ios:cold-open-check`
6. final target: `SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS`
