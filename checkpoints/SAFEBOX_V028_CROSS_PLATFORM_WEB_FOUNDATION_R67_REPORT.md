# SAFEBOX v0.2.8 — R67 Cross-Platform Rebaseline & Web Foundation

## Decision
R66 closes the iOS hardening streak. From R67 onward, iOS is maintenance-only unless a regression is found.

## macOS / Windows rebaseline
- Windows cold-start `.sbx` handling remains argument-based, matching Tauri's desktop file-association model.
- Desktop warm-open remains covered by the single-instance plugin.
- macOS keeps `RunEvent::Opened` for Launch Services events.
- Added platform-specific bundle configs so the inherited base `bundle.targets=["app"]` can no longer accidentally suppress the Windows installer target: Windows => NSIS, macOS => app.
- Desktop open/reveal uses direct `Command::new` invocation; no cmd.exe / PowerShell shell interpolation.
- Unix private file creation remains `0600`; Windows reserved output names remain rejected cross-platform.

## Known macOS platform risk
Tauri/Tao has a current macOS 26 issue where warm-open of some quarantined files can be dropped by Launch Services before `RunEvent::Opened`. This is an OS/runtime integration risk, not an SBX crypto regression. It is recorded for later targeted runtime testing; it does not block the web transition.

## Web foundation
- Browser runtime is detected without invoking Tauri IPC.
- Browser mode has its own capability fallback and native Tauri event listeners are skipped.
- Browser Choose/drag-drop intake now works with real `File` objects held only in memory.
- Web mode fails closed for Protect/Unlock until an SBX-compatible Argon2id + XChaCha20-Poly1305 engine is present. It does not substitute weaker WebCrypto algorithms.
- Vite static base is relative and runtime logo assets are subpath-safe for static hosting/GitHub Pages-style deployments.
- `npm run web:build` is now an explicit target.

## Next
R68: refactor SBX core into stream/memory primitives and expose the exact format to WebAssembly. No format change, no crypto downgrade.
