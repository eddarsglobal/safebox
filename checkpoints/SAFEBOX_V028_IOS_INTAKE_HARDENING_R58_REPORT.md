# SAFEBOX v0.2.8 — iOS Intake Hardening R58

Package: `v0.2.8-ios-intake-hardening-r58-20260830A`

## Scope
R58 hardens the R57-validated iOS Share / cold-start intake pipeline without changing SBX cryptography, SBX format, Ads/UMP, or the direct cold-open bridge.

## Intake policy
- Maximum payload: 512 MiB.
- Maximum ready requests in ShareInbox: 8.
- Maximum aggregate ready payload bytes in ShareInbox: 1 GiB.
- Incomplete ShareInbox request expiry: 1 hour.
- Ready ShareInbox request expiry: 24 hours.
- Claimed ShareProcessing request expiry: 1 hour, fail-closed (no automatic replay).
- Private SafeBoxShareIntake retention: 24 hours.
- One provider attachment per Share Extension invocation.

## Atomicity and replay resistance
The Share Extension copies to `.payload.partial`, hardens and verifies it, atomically renames it to the final payload name, then writes `READY` last. The containing app atomically claims each request by moving it from `ShareInbox` to `ShareProcessing` before reading/copying it. Concurrent drains therefore cannot claim the same request twice. Abandoned claims are expired rather than replayed automatically.

## File security
- Provider source is never deleted or modified.
- Only SafeBox-owned App Group/private staging is cleaned.
- Regular-file and symlink checks exist at both extension and containing-app boundaries.
- Directories remain 0700; files remain 0600 with `NSFileProtectionComplete`.
- Shared filenames/paths are not emitted in logs.
- `READY` remains the final commit marker.

## Runtime evidence expected on reference Mac
A normal Share / cold-share run must emit:
- `SAFEBOX_IOS_SHARE_HARDENING_CLEANUP_PASS`
- `SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS`
- `SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS`
- `SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS`
- `SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS`
- `SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=...`
- `SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_PASS`

Static/container validation is not a substitute for the Xcode/iOS Simulator runtime test on the reference Mac.
