# SAFEBOX v0.2.8 — iOS Durable Replay Evidence R62

Package: `v0.2.8-ios-durable-replay-evidence-r62-20260830A`

## Trigger
R61 correctly scoped replay proof to the latest cold-share `armed_at`, but the reference Simulator had already purged the Share Extension stage marker from Unified Logging about twenty minutes after the transaction. The arm metadata survived while the volatile log evidence did not, producing `stage missing in armed transaction` despite the previously observed valid R59 transaction.

## R62 closure
- `ios:cold-share-check` persists the already validated armed transaction immediately after its normal runtime proof.
- Persisted evidence contains only lines containing `SAFEBOX_IOS_SHARE_`; no shared filename, provider path, URL or payload bytes are written.
- Evidence log and metadata are mode 0600 and are written atomically using same-directory temporary files, `fsync`, and `os.replace`.
- Metadata binds evidence to `device_udid`, `armed_at`, `expected_route`, old/new PID, SHA-256 and byte length.
- A new `ios:cold-share-arm` removes old evidence before terminating/rearming SafeBox.
- `ios:replay-recovery-check` requires evidence metadata to match the current arm and verifies SHA-256 + length before the R60/R61 causal parser runs.
- Replay proof is therefore independent from later Unified Logging retention.

## Security invariants
No runtime intake, R59 ACK/receipt, R58 atomic claim/quota/cleanup, Ads/UMP, cold-open bridge, SBX crypto, or SBX format change.
