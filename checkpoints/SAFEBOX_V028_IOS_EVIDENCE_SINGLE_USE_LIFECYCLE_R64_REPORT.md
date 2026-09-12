# SAFEBOX v0.2.8 — iOS Evidence Single-Use Lifecycle R64

R64 closes the lifecycle of R63 durable replay evidence without changing SafeBox runtime behavior.

After the R63 integrity and replay contract validates, `ios:replay-recovery-check` now commits a consumed receipt before retiring the current evidence files. The receipt is written atomically with mode 0600 and fsync, is bound to the exact arm/package/runtime/route/device/PIDs and the R63 evidence/manifest hashes, and expires after 24 hours. The receipt is the one-way commit point: if cleanup is interrupted after receipt creation, reuse is still blocked fail-closed.

A successful replay gate removes the current evidence log and metadata. Re-running the replay gate for the same arm is rejected as already consumed. `ios:evidence-lifecycle-check` validates the consumed receipt and proves that current evidence has been retired. A new arm deterministically rotates the old current evidence and consumed receipt before creating the next transaction.

R59 runtime implementation, R58 intake hardening, R63 evidence producer/validator, Share Extension, Ads, cold-open bridge, crypto and SBX format remain unchanged.
