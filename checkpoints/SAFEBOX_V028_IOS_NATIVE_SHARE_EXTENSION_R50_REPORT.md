# SAFEBOX v0.2.8 — iOS Native Share Extension R50

## Runtime evidence that triggered R50

R49 proved native registration and drain invocation but the containing app logged `SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL`, while the Share Extension continued to log `SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS`. This isolates the failure to the containing app's App Group capability.

## Root cause

R46–R49 added the App Group to `SafeBox.app` only during a post-build ad-hoc re-sign. `codesign -d` could display the entitlement, but Simulator still denied `containerURL(forSecurityApplicationGroupIdentifier:)` to the containing app.

## R50 decision

Inject `SafeBoxAppGroups.entitlements` into the containing app's **Xcode build signing phase** via `CODE_SIGN_ENTITLEMENTS`, then fail closed unless the built app already carries `group.com.safebox.desktop.share` before extension embed. Re-verify the same entitlement after the final nested-bundle signature.

## Security invariants

- App Group identifier unchanged.
- Share Extension remains ingestion-only.
- External provider files are copied, never deleted.
- Ads/UMP/linker validated R42 surfaces unchanged.
- Crypto/SBX unchanged.
- No path/filename is added to runtime diagnostic markers.
