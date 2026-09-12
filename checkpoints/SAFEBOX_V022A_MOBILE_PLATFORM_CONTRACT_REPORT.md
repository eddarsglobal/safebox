# SafeBox v0.2.2A — Mobile Platform Contract

## Implemented
- Fixed mobile/narrow header placement: Settings stays at toolbar edge instead of becoming a centered full-width action row.
- Added explicit platform capabilities command for Android/iOS/macOS/Windows/Linux.
- Mobile UI hides unsupported folder picker fields.
- Restored-file actions are platform-aware; Finder/folder reveal is desktop-only.
- Added explicit `content://` guard so Android URIs are never silently treated as filesystem `PathBuf`s.
- Preserved Android `content://` open events for the upcoming native document adapter.
- Removed the remaining SafeBox core unused-import warning.
- Added runtime npm audit gate to the v0.2.2A verifier.

## Next slice
Implement the Android Storage Access Framework adapter that consumes `content://` streams without converting them into local filesystem paths, then the equivalent iOS Files/Share adapter.
