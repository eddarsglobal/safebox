# SAFEBOX v0.2.8 — iOS Native Share Extension R45

## Scope
R45 is a build-environment hardening slice over R44. The native Share Extension,
App Group inbox design, Rust/Tauri routing, Ads/UMP R42 runtime surface, R41 linker
scope and SBX crypto format are unchanged.

## Reference-Mac failure corrected
R44 stopped before the Share Extension target was created because the installer
called the default `ruby` and required `xcodeproj` from the default gem path.
The reference Mac has a working CocoaPods executable, but CocoaPods' `xcodeproj`
dependency is not necessarily exposed to Apple's/system Ruby gem path.

## R45 decision
The installer now resolves the Ruby/xcodeproj runtime from CocoaPods itself:
1. Resolve the real `pod` executable and its Ruby shebang when absolute.
2. Probe safe Ruby candidates without installing or mutating gems.
3. Discover a private CocoaPods/Homebrew gem root containing `xcodeproj-*`.
4. Validate `require "xcodeproj"` before use.
5. If needed, invoke Ruby with a scoped `GEM_HOME`/`GEM_PATH` only for the project patch.
6. Fail closed if no valid xcodeproj runtime exists.

No `gem install`, `sudo`, system-Ruby mutation or global environment mutation is used.

## Security / integrity
- No crypto/SBX source is changed by this slice.
- No validated R42 Ads runtime or R41 linker script is changed.
- Ruby/gem overrides are process-local to the Xcode project patch.
- The Xcode project is patched only after `xcodeproj` was proven loadable.
- Failure remains fail-closed before any runtime claim.

## Status
Static/package verification: PASS.
Reference-Mac runtime/build validation: REQUIRED.
