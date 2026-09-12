# SAFEBOX V0.2.8 — Web Browser Public Format Semantics R80

R79 successfully reached the real browser E2E and proved that the engine loads and Protect executes. The browser gate then failed on the test-only assertion `publicInfo.format !== "SBX1"`.

That assertion mixed two distinct canonical format concepts:

- `SBX1` is the four-byte binary envelope magic (`53 42 58 31`).
- `SBX` is the canonical `format` value stored in the JSON SBX header and returned by `read_public_metadata_from_bytes` / `sbx_public_info`.

R80 fixes only the browser validation contract. It does not change the SBX format, Rust core, WASM binary contract, KDF, AEAD, desktop runtime, iOS runtime, or deployment headers.

The E2E now validates both semantics explicitly:

1. protected output begins with the exact `SBX1` magic;
2. public-info returns header `format === "SBX"`;
3. public metadata remains verified;
4. wrong-code, tamper, unlock, restored-byte equality and Blob boundary tests continue unchanged.

New runtime markers:

- `SAFEBOX_WEB_BROWSER_MAGIC_SBX1_PASS`
- `SAFEBOX_WEB_BROWSER_PUBLIC_FORMAT_SBX_PASS`

Security decision: do not modify production data merely to satisfy a faulty test expectation. The test is aligned to the already canonical format instead.
