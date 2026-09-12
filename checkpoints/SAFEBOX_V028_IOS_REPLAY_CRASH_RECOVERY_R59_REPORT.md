# SAFEBOX v0.2.8 — iOS Replay / Crash Recovery R59

Package: `v0.2.8-ios-replay-crash-recovery-r59-20260830A`

## Baseline
R58 is runtime validated on the reference Mac: cold-share unlock and intake hardening policy/atomic/claim runtime gates passed.

## R59 closure
- Native → Rust share delivery now has an explicit `uint8_t/u8` ACK contract.
- Native does not finalize a claimed request unless Rust returns ACK=1.
- After Rust ACK, native writes an atomic hardened `DELIVERED` receipt inside the claimed request before deletion.
- A crash after ACK but before deletion leaves a receipt-bearing claim; next cleanup deletes it without replay.
- A crash before ACK leaves an unacknowledged claim in `ShareProcessing`; it is never replayed automatically and expires fail-closed after the R58 one-hour processing retention.
- Rust queue capacity/locking rejection now returns NACK instead of being silently treated as accepted.
- Repeated lifecycle drains after the accepted request must return `count=0`.

## Security invariants
No provider file deletion, no path/name logging, no Ads/UMP changes, and no SBX crypto/format changes.
