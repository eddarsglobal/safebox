# SAFEBOX v0.2.7 — iOS archive passthrough R39

Date: 2026-08-29

## Runtime evidence corrected

The reference Mac completed the normal Rust/Tauri `cargo build --lib` path under Xcode 16.2 and then R38 stopped inside SafeBox's own archive normalizer because two members named `Tauri.swift.o` were not byte-equivalent after debug stripping.

That observation does **not** prove duplicate linker symbols. Static `ar` member names are archive bookkeeping and are not linker symbol identities. R35–R38 therefore enforced an invalid pre-link assumption and prevented Apple `ld` from becoming the authority.

## R39 decision

- preserve Cargo's `libsafebox_desktop_lib.a` byte-for-byte;
- do not delete, strip, reorder, or rebuild Swift objects;
- report the five known Tauri Swift member-name counts for diagnostics only;
- require source/output SHA-256 equality;
- delegate ABI, architecture, unresolved-symbol and duplicate-symbol validation to the real Xcode linker;
- keep the simulator-only boundary from R36;
- no SBX format or crypto change.

## Defensive HACKER / Red Team

Fail closed on malformed archives and on any source/output byte mismatch. Duplicate *member names* are intentionally non-fatal; actual duplicate symbols remain fatal at Apple link time. This removes unsafe archive surgery while retaining a hard cryptographic passthrough invariant.

## Internal 9-council review — R39 addendum

Security, cryptography, iOS/native, Rust/Tauri, build/release, QA, privacy/ads, product, and maintainability councils agree that an unmodified upstream aggregate archive plus authoritative native link validation is safer than heuristically deleting divergent Swift objects.
