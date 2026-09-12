# SAFEBOX v0.2.8 — iOS Direct `.sbx` Cold-Start Intake R53

## Baseline
R52 is retained as the validated native Share Extension baseline. R53 does not change Ads R42, the Share Extension, the Share App Group bridge, cryptography, or the SBX format.

## Problem closed by this slice
A direct `.sbx` document launch can reach iOS through launch-time scene connection options before/without Tauri delivering `RunEvent::Opened`. R53 adds a narrow native intake path for the initial `.sbx` only.

## Native launch capture
- observes `UIApplicationDidFinishLaunchingNotification` before the app lifecycle completes;
- supports legacy `UIApplicationLaunchOptionsURLKey` when scenes are not active;
- hooks the app delegate `application:configurationForConnectingSceneSession:options:` boundary to inspect `UISceneConnectionOptions.URLContexts`;
- also hooks `TaoSceneDelegate scene:willConnectToSession:options:` as a defensive scene-level fallback;
- capture is one-shot for the cold-start window and accepts only `file://` URLs ending in `.sbx`.

## Security staging
The provider URL is never forwarded directly from the native launch callback. SafeBox:
- starts security-scoped access when available;
- uses `NSFileCoordinator` for the provider read;
- rejects non-regular files and symlinks;
- copies only, never moves/deletes the provider source;
- stages under `NSTemporaryDirectory()/SafeBoxColdOpenIntake/<UUID>/payload.sbx`;
- uses 0700 directories, 0600 payload and `NSFileProtectionComplete`;
- never logs the provider filename, URL, or private path.

## Rust delivery
Native calls only `safebox_ios_cold_open_accept(path)`. Rust validates `.sbx`, emits route-only `route=unlock`, and either stores it in a bounded pre-AppHandle queue or delivers it through the existing opened-file state/event surface.

## Runtime proof required on reference Mac
1. `npm run ios:cold-dev`
2. keep the dev Terminal active
3. `npm run ios:cold-open-arm` (this terminates SafeBox)
4. in Simulator Files, tap a real `.sbx` directly — do not use Share
5. `npm run ios:cold-open-check`

Final marker: `SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS`.
