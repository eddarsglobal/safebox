# SafeBox v0.2.2C — Android Document I/O / R9

## Scope

- Android Storage Access Framework `content://` inputs are consumed through the official Tauri filesystem plugin.
- Public SBX metadata is read directly from the Android document stream without copying the full SBX.
- Create/unlock operations stage external Android documents into a private per-operation SafeBox cache directory before passing them to the path-based cryptographic core.
- The Android display filename is resolved through Tauri's mobile path resolver instead of deriving a fake name from the URI.
- Generated SBX/restored files are registered server-side as exportable files for the current application session.
- Android Save uses the native save dialog and copies through the official filesystem plugin.
- A Save is reported successful only after byte-for-byte read-back verification of the destination.
- External Android provider documents are never falsely reported as deleted. If deletion is requested, only the private staging copy is disposable and a warning is returned.
- iOS Save/Share remains gated off until its security-scoped resource lifecycle is implemented explicitly.

## Security boundaries

- `save_generated_file` refuses arbitrary source paths: only files generated and registered by SafeBox in the current session are exportable.
- Staging files are created with create-new semantics and mode 0600 on Unix targets.
- Per-operation work directories use create-directory semantics and mode 0700 on Unix targets.
- No frontend filesystem permission was added for the Tauri fs plugin; document operations stay in the Rust backend.
- The active core no longer uses a synthetic `document.sbx` visible-name fallback.

## Next slice

- Physical/emulator Android validation of file picker -> content URI -> Create -> Save -> reopen -> Unlock -> Save original.
- Native Android Share Sheet bridge after the Save path is validated.
- iOS security-scoped Files/Save/Share adapter.
- Dependency audit remediation (current Mac npm output reported 2 high advisories in the build tool dependency tree).
