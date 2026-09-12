# SafeBox v0.2.2C R17 — Android Official Launcher Icon

## 9-Council decision

R17 closes the Android launcher-branding gap before further ANR/runtime testing.

- **Product / Brand:** the official SafeBox app icon is the Android launcher source of truth.
- **Android / Platform:** use the official Tauri `icon` pipeline after `android init`; do not hand-edit one emulator build only.
- **UI / Design:** preserve SafeBox visual identity across launcher, app drawer, recents and system surfaces supported by Android.
- **Security / Supply Chain:** icon generation uses the pinned project Tauri CLI from the lockfile; no remote icon asset is fetched.
- **QA:** every Android density must contain normal, round and foreground launcher resources.
- **Release Engineering:** generated `gen/android` remains excluded from checkpoints; the launcher reapplies icons deterministically after auto-init.
- **Performance:** a SHA-256 stamp prevents regenerating icons on every dev launch when the source and resources are unchanged.
- **Privacy:** no change.
- **Defensive HACKER / Red Team:** failure to create any required launcher resource is a hard error; build does not silently continue with default Tauri branding.

## Source of truth

`assets/safebox-app-icon-source.png`

The PNG is square, RGBA/alpha-capable and is passed to `npx tauri icon` only after the generated Android Studio project exists.

## Runtime markers

- `SAFEBOX_ANDROID_ICON_READY:<sha256>` — official resources generated and verified.
- `SAFEBOX_ANDROID_ICON_REUSED:<sha256>` — verified resources already match the official source.

## No product-behavior change

R17 does not modify SBX crypto, SBX format, create/unlock semantics or the R16 Android ANR hardening.
