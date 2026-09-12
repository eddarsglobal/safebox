# SafeBox v0.2.1 — Core Security Foundation

Status: **SOURCE CANDIDATE — Rust execution pending on reference Mac**

Implemented:
- bounded Argon2id KDF parameters before derivation;
- bounded header/chunk sizes before allocation;
- strict header field length validation;
- RAII zeroization for access codes, derived keys, file keys, plaintext metadata and plaintext chunk buffers;
- exclusive `create_new` output/temp creation;
- random restore temp names with private Unix permissions;
- durable flush + `sync_all` before commit;
- destination replacement transaction with rollback path;
- SBX deletion only after successful restored-file commit;
- burn failure is non-fatal and returned as a warning;
- reader is closed before local SBX deletion (Windows-safe lifecycle);
- typed/stable core error codes surfaced to Tauri UI;
- receiver distinguishes access failure, integrity failure, unsupported version, KDF rejection and I/O failure;
- Windows `cmd /C start` removed;
- Linux-only `xdg-open` branches (no iOS/Android fall-through);
- Android `content://` launch URI preserved for the v0.2.2 document adapter;
- secret codes removed from browser `sessionStorage`; session codes now process-memory only;
- CLI no longer accepts `--code`; secret is prompted at runtime;
- production CSP enabled;
- direct JS/Rust dependencies pinned to checkpoint-resolved versions;
- Unicode-safe visible SBX naming;
- cross-platform unsafe/reserved restored filename checks;
- new hostile-format and roundtrip security tests.

Required validation on reference Mac:
1. `bash verification/verify_v021_security_foundation.sh`
2. macOS Tauri build/run regression
3. Windows build regression on Windows runner/device
4. Android/iOS compile gates after v0.2.2 I/O adapter lands
