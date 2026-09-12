# SAFEBOX v0.2.9 — Android Distribution R86 RC6

## Release purpose
R86 RC6 closes the physical-device blocker where the installed Android APK displayed the landing page but the **Create a SafeBox** and **Open a SafeBox** CTAs could not reach the crypto application.

## Root cause
The public web deployment is intentionally multi-page (`index.html` landing + `app.html` crypto app), but the Vite multi-page `rollupOptions.input` was enabled only in `mode === "web"`.

Tauri Android runs the normal `npm run build` / `vite build` path, so the signed APK could contain `dist/index.html` while omitting `dist/app.html`. The landing CTAs target `./app.html?mode=create` and `./app.html?mode=open`; therefore the installed APK had no packaged destination for those actions.

## RC6 correction
- Make the Vite multi-page input unconditional for native and web builds.
- Add a fail-closed post-build check that requires both `dist/index.html` and `dist/app.html` and verifies that `app.html` contains a built JavaScript asset.
- Keep the validated R86/RC2/RC3/RC4/RC5 signing and Gradle/Tauri BuildTask fixes.
- Add Android file-dialog resilience after the crypto app becomes reachable:
  - remove custom `.sbx` extension filtering on Android document providers;
  - guarded second `open()` attempt if the first Android callback leaves the WebView foregrounded;
  - visible picker error instead of a silent failure;
  - route selected SBX documents directly to receiver mode.

## Security / crypto scope
No SBX format, KDF, AEAD, password handling, encryption, decryption, or cryptographic metadata behavior is changed by RC6.

The permanent Play upload keystore is not contained in the archive and must be reused from the developer machine.

## Acceptance gates
- Normal native Vite bundle has `app.html` input: PASS (static gate)
- Native post-build app-entry fail-closed check: PASS (static gate)
- Android first-dialog callback recovery guard: PASS (static gate)
- Android custom extension filter removed: PASS (static gate)
- Android picker visible error path: PASS (static gate)
- RC5 build pipeline preserved: PASS (static gate)

## Environment limitation
The container cannot complete `npm ci` because the npm registry is unavailable. Therefore RC6 is **not claimed as physical-device PASS** here. Final acceptance requires a fresh signed Android build on the reference Mac and a real-device test of Create → choose file → create SBX → Open → choose SBX → unlock.
