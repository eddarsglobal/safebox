# SAFEBOX v0.2.8 — iOS Evidence Ledger & Bounded Audit Trail R65

R65 keeps the R64 single-use evidence lifecycle and SafeBox runtime byte-for-byte unchanged while adding a local verification ledger for consumed replay-evidence transactions.

The ledger stores no device UDID, bundle/process identity, PID, provider/source path, filename, URL, SBX filename or payload content. Each entry is limited to an event type, route, package identifier, runtime-contract hash, consumption timestamp and cryptographic transaction/receipt hashes. Entries are hash-chained. The ledger itself is sealed, written atomically with fsync, restricted to mode 0600, rejects symlinks/hardlinks, and is capped at 32 entries / 128 KiB. Rotation advances an anchor hash instead of growing without bound.

A new cold-share arm validates ledger continuity but does not erase the ledger. Replay recovery first commits the R64 consumed receipt, retires evidence, then appends the transaction to the ledger. The consumed receipt remains authoritative; `ios:evidence-ledger-check` performs idempotent reconciliation if a crash/interruption occurs after the receipt commit but before ledger append.

R59 runtime, R58 intake hardening, R63 integrity binding, R64 single-use semantics, Share Extension, Ads, cold-open bridge, crypto and SBX format remain unchanged.
