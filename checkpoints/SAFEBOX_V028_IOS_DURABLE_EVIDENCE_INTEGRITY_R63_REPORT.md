# SAFEBOX v0.2.8 — iOS Durable Evidence Integrity R63

R63 promotes R62 durable replay evidence to schema v2 and binds each proof to the exact arm, package and replay runtime implementation.

Security contract: atomic 0600 arm/evidence writes with fsync; regular/non-symlink/single-link/current-user files only; 2 MiB evidence cap; exact 24 h expiry; device/bundle/process/route/timestamp/PID binding; package-id binding; runtime-contract SHA-256 over `SafeBoxShareInboxBridge.mm` + `lib.rs`; canonical arm SHA-256; manifest seal over metadata + evidence + arm; fail-closed on mismatch. New arm invalidates prior current evidence.

The SHA-256 manifest seal is tamper-evident for accidental/unauthorized modification without recomputing all bound inputs; it is not a secret-key authenticity guarantee against an attacker with full control of the same host user account.

R59 runtime behavior, Ads, cold-open bridge, crypto and SBX format remain unchanged.
