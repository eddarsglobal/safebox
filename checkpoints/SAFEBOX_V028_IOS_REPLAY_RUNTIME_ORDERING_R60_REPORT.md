# SAFEBOX v0.2.8 — iOS Replay Runtime Ordering R60

Package: `v0.2.8-ios-replay-runtime-ordering-r60-20260830A`

## Runtime evidence that triggered R60
R59 functional runtime passed on the reference Mac: the latest transaction showed native ACK, atomic delivery receipt, accepted drain `count=1`, subsequent drains `count=0`, and a Rust ACK marker. The R59 checker nevertheless failed because unified logging displayed Rust `stderr` after native `NSLog` markers even though the native ACK can only execute after the Rust callback returns `1`.

## R60 closure
- R59 delivery/recovery implementation is byte-for-byte unchanged.
- The runtime contract parser now separates log streams.
- Rust `ACCEPT` and `RUST_ACK` must exist after the latest Share Extension stage, but their textual position is not compared to native `NSLog` markers.
- Causal ordering is asserted only inside the native bridge stream: `CLAIM -> NATIVE_ACK -> DELIVERY_RECEIPT -> count=1 -> later count=0`.
- Any Rust NACK, native NACK or receipt failure after the latest stage still fails closed.
- Synthetic regression tests include the exact class of interleaving seen on the reference Mac and negative tests for bad native order, missing zero-replay proof and NACK.

## Security invariants
No change to Share Extension intake, native claim/receipt implementation, Rust ACK ABI, Ads/UMP, cold-open bridge, SBX crypto, or SBX format.
