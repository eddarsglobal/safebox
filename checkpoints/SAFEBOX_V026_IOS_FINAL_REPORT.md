# SafeBox v0.2.6 — iOS final baseline

## Runtime evidence

The iPhone Simulator runtime reached Xcode `BUILD SUCCEEDED`, simulator install PASS and runtime boot PASS. The manual iOS product flow was then confirmed PASS for steps 1–7: Files selection, Create, Save `.sbx`, Open-In, wrong-code rejection without output, correct unlock, and restored-file save.

The remaining visible defect was the launcher icon. This checkpoint fixes only that presentation/runtime packaging defect and folds the already-proven Xcode-linker ABI bridge correction into the distributable baseline.

## Official iOS icon

- Canonical artwork remains `assets/safebox-app-icon.svg` / SafeBox app icon.
- A deterministic 1024×1024 RGB/no-alpha source is packaged as `assets/safebox-app-icon-ios-1024.png`.
- After every `tauri ios init`, `scripts/install_ios_app_icon.sh` replaces every image referenced by Xcode's generated `AppIcon.appiconset/Contents.json` at its declared pixel size.
- Tauri/Xcode keep ownership of `Contents.json`; SafeBox only replaces image payloads.
- The simulator runner installs the official icon before `xcodebuild` and already uninstalls the old bundle before reinstalling it, preventing stale app-bundle artwork from being reused.

## Runtime bridge consolidation

The standalone Simulator bridge remains strictly bounded to `iphonesimulator`. The previous shell-level `nm | grep` ABI probe was removed after the real Xcode link successfully proved `-lapp` compatibility. ABI failure is delegated to the native linker, which is authoritative and fail-closed.

## 9-council checkpoint review

1. Product: correct SafeBox branding on iOS.
2. UI: no application layout change.
3. iOS: full AppIcon set is refreshed after project generation.
4. Build: Xcode remains the source of truth for the asset catalog.
5. Runtime: stale installed bundle is removed before install.
6. Security: no signing bypass added; Simulator-only bridge retained.
7. Crypto: no SBX format, KDF, AEAD, key, metadata, or restore behavior changed.
8. Supply chain: no dependency upgrade and no new package manager mutation.
9. Release: one consolidated v0.2.6 iOS baseline; no new R-number churn.

## Defensive HACKER / Red Team

- No external path or security-scoped permission semantics were weakened.
- No secrets are introduced into scripts or icon metadata.
- Physical-device builds cannot enter the standalone Simulator bridge.
- Asset generation reads only the packaged official icon and generated Xcode `Contents.json`.
- The ABI check remains fail-closed at the real native linker.

No SBX format or crypto change.
