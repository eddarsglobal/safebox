# SAFEBOX v0.2.8 — iOS Native Share Extension R44

## Status
Ready for reference-Mac runtime validation. R42 remains the last fully validated baseline until R44 passes on Xcode/iOS Simulator.

## Why R44 exists
R43 correctly implemented Tauri `RunEvent::Opened` for document associations, but the reference iOS 18.3 Files UI showed that ordinary files are offered through the Share Sheet rather than a separate “Open With” menu. `CFBundleDocumentTypes` is therefore retained only for the SafeBox `.sbx` association. Ordinary files now use a real `com.apple.share-services` extension.

## Architecture decision
- `.sbx` direct association: Tauri/`RunEvent::Opened`.
- arbitrary file from Files/Photos/etc.: native Share Extension.
- extension and containing app exchange only a copied payload through `group.com.safebox.desktop.share`.
- no unsupported attempt to launch the containing app from the Share Extension.
- containing app drains the App Group inbox at process startup and every `UIApplicationDidBecomeActiveNotification`.
- App Group payload is copied into the containing app private temporary staging before Rust sees it, then the App Group request is deleted.

## Security boundary
- extension input is copied; the user's original file is never removed or modified;
- only regular non-symlink files are accepted;
- inbox request directories use mode 0700;
- payload/READY files use mode 0600 and `NSFileProtectionComplete`;
- UUID request directory avoids attacker-controlled directory names;
- READY is written last so incomplete writes are ignored;
- native bridge refuses multiple payloads in one request;
- logs contain route/status markers only, never filename/path/URL;
- native main bridge moves the shared copy into private app staging before Rust/UI routing;
- Ads/UMP/linker R42 surfaces are unchanged;
- SafeBox crypto/SBX format is unchanged.

## Apple constraints respected
Apple documents App Groups/shared containers as the supported data-sharing path between an extension and its containing app. Apple also documents that opening the containing app is not generally supported by the Share extension point, so R44 does not use responder-chain or UIApplication hacks.

## Runtime acceptance
1. `npm run ios:cold-dev` must build and embed `SafeBoxShareExtension.appex`.
2. Files → Share must show SafeBox.
3. Sharing a normal file must emit `SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS`.
4. Returning/opening SafeBox must emit `SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=protect`.
5. `npm run ios:share-check -- protect` must end in `SAFEBOX_IOS_SHARE_RUNTIME_PASS`.
6. Repeat with `.sbx` and `-- unlock`.
