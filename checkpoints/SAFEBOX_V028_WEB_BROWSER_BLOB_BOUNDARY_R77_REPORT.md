# SAFEBOX v0.2.8 — Web Browser Blob Boundary R77

## Scope
R77 is a minimal Web UI build closure on top of R76.

The canonical Rust/WASM SBX engine, Argon2id parameters, XChaCha20-Poly1305,
SBX format, desktop runtime, Android runtime and iOS runtime are unchanged.

## Defect closed
TypeScript 7 rejects a generic `Uint8Array<ArrayBufferLike>` as a `BlobPart`
because its backing buffer could be a `SharedArrayBuffer`.

R77 copies outgoing download bytes into a fresh ordinary `ArrayBuffer` and
passes that buffer to `Blob`. This is a browser type/runtime boundary fix only;
no cryptographic bytes are changed.

## Security properties
- no SharedArrayBuffer is passed to the download Blob;
- no unsafe type cast is used to silence TypeScript;
- no change to SBX parsing, encryption, decryption or metadata;
- no change to the WASM ABI;
- R76 crypto/core and historical desktop/iOS invariants remain byte-for-byte.
