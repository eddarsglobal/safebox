# SAFEBOX v0.2.8 — iOS Evidence Ledger Concurrency & Crash-Safe Locking R66

R66 keeps the R65 validated ledger format, R64 single-use receipt semantics, R59 runtime intake implementation, Share Extension, Ads, cold-open bridge, crypto and SBX format unchanged.

The R65 ledger writer was atomic but did not serialize multiple processes. Two concurrent reconciliation/writer processes could read the same head and replace the ledger independently, creating a lost-update race even though each individual file replacement was atomic.

R66 closes that race with a dedicated adjacent empty lock file and OS advisory `flock`:

- record operations take an exclusive lock for the entire read/verify/append/rotate/fsync transaction;
- inspect/verify operations take a shared lock;
- lock creation uses exclusive create plus `O_NOFOLLOW` where available;
- the lock must be a regular zero-byte file, owned through the existing execution context, mode 0600 and link count exactly 1;
- symlink, hardlink, broad-permission and non-empty lock files fail closed;
- the operating system releases the lock automatically if a writer crashes, so no stale lock recovery or unsafe forced-unlock path exists.

A new adversarial checker launches 16 unique writers concurrently, 8 identical writers concurrently to prove idempotency, kills a live lock holder to prove crash release, and rejects unsafe lock-file constructions. It only uses synthetic verification receipts in temporary directories and never touches provider files or SBX payload content.

The real bounded ledger remains capped at 32 entries / 128 KiB and retains the R65 privacy contract.
