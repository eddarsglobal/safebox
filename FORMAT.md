# SBX Format v0.1

SBX is a secure file capsule. It is not meant to reveal the original filename, extension, MIME type, or content before a valid code is entered.

## Visible file

Default:

```text
document.sbx
```

The sender may choose another visible name:

```text
private.sbx
invoice.sbx
family.sbx
```

This visible name is not the original file name.

## Binary layout

```text
4 bytes   magic: SBX1
2 bytes   format version: u16 little-endian
4 bytes   header JSON length: u32 little-endian
N bytes   header JSON UTF-8
repeated encrypted chunks:
  4 bytes ciphertext length: u32 little-endian
  M bytes ciphertext
```

## Header JSON

The header is plaintext but contains no original filename/extension/content.

It contains:

```json
{
  "format": "SBX",
  "version": 1,
  "kdf": {
    "name": "argon2id",
    "memory_kib": 32768,
    "time_cost": 3,
    "parallelism": 1,
    "output_len": 32
  },
  "salt_hex": "...",
  "wrapped_key_nonce_hex": "...",
  "wrapped_file_key_hex": "...",
  "metadata_nonce_hex": "...",
  "encrypted_metadata_hex": "...",
  "chunk_nonce_prefix_hex": "...",
  "chunk_size": 1048576
}
```

## Encrypted metadata

Only visible after correct code:

```json
{
  "original_file_name": "photo.jpg",
  "original_extension": "jpg",
  "original_size": 123456,
  "created_utc": "2026-07-08T18:00:00Z",
  "visible_sbx_name": "photo.sbx",
  "burn_after_unlock": false
}
```

## Crypto model v0.1

1. Generate a random 32-byte file key.
2. Derive a 32-byte code key from the receiver code using Argon2id.
3. Encrypt/wrap the file key with the code key.
4. Encrypt metadata with the file key.
5. Encrypt payload chunks with the file key.
6. On correct code, unwrap file key, decrypt metadata, decrypt payload chunks, restore original file.
7. SafeBox keeps the `.sbx` by default. If burn-after-unlock is explicitly enabled, delete the local `.sbx` only after successful durable restore.

## Offline burn limitation

Offline burn deletes only the local `.sbx` copy that SafeBox opened. If another copy exists in WhatsApp, email, Telegram, cloud, USB, or another folder, offline mode cannot destroy that remote copy.

True one-time global destruction requires an online key server in a later Pro mode.
