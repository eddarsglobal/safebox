# SAFEBOX v0.2.8 — iOS Replay Transaction Scope R61

Package: `v0.2.8-ios-replay-transaction-scope-r61-20260830A`

## Runtime evidence that triggered R61
R59 runtime functionality was already proven on the reference Mac. R60 corrected cross-stream log ordering, but its shell checker still retrieved evidence from the broader runtime-session `log_start`. After unpacking R60 later, that session window no longer reliably represented the exact cold-share transaction and the checker reported `stage missing`.

## R61 closure
- Runtime implementation from R59 remains byte-for-byte unchanged.
- Replay proof now reads `/tmp/safebox-ios-cold-share-arm-<uid>.json`, the same metadata produced by `ios:cold-share-arm`.
- Unified logs are queried from exact `armed_at`, not from the build/runtime session start.
- The expected route (`protect` or `unlock`) is carried from arm metadata into the contract parser.
- The parser uses the latest Share Extension stage within that armed transaction.
- Causal native order remains `CLAIM -> NATIVE_ACK -> DELIVERY_RECEIPT -> count=1 -> later count=0`.
- A second native `count=1` after the accepted delivery fails closed.
- Rust ACK/accept remain cross-stream presence requirements, never text-order requirements.

## Security invariants
No change to Share Extension staging, R58 atomic claim/quota/cleanup, R59 ACK/receipt implementation, Ads/UMP, cold-open bridge, SBX crypto, or SBX format.
