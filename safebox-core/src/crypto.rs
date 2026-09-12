use crate::error::{Result, SbxError};
use crate::format::KdfParams;
use crate::validation::validate_kdf_params;
use argon2::{Algorithm, Argon2, Block, Params, Version};
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{Key, XChaCha20Poly1305, XNonce};
use zeroize::Zeroize;
#[cfg(not(target_arch = "wasm32"))]
use rand_core::{OsRng, RngCore};

pub const KEY_LEN: usize = 32;
pub const SALT_LEN: usize = 16;
pub const XNONCE_LEN: usize = 24;
pub const CHUNK_NONCE_PREFIX_LEN: usize = 16;

pub const AAD_FILE_KEY: &[u8] = b"SBX_FILE_KEY_V1";
pub const AAD_METADATA: &[u8] = b"SBX_METADATA_V1";
pub const AAD_CHUNK: &[u8] = b"SBX_CHUNK_V1";

#[cfg(not(target_arch = "wasm32"))]
pub fn random_array<const N: usize>() -> [u8; N] {
    let mut out = [0u8; N];
    OsRng.fill_bytes(&mut out);
    out
}

pub fn derive_code_key(code: &str, salt: &[u8], kdf: &KdfParams) -> Result<[u8; KEY_LEN]> {
    if code.is_empty() {
        return Err(SbxError::EmptyCode);
    }

    validate_kdf_params(kdf, KEY_LEN)?;

    let params = Params::new(
        kdf.memory_kib,
        kdf.time_cost,
        kdf.parallelism,
        Some(KEY_LEN),
    )?;
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = [0u8; KEY_LEN];

    // Keep Argon2's RNG-bearing `alloc`/password-hash feature path disabled for
    // WebAssembly. `hash_password_into` is only an allocation convenience
    // wrapper in argon2 0.5.3; it allocates exactly `params().block_count()`
    // Blocks and then calls `hash_password_into_with_memory`. We do the same
    // allocation explicitly so the cryptographic algorithm and output remain
    // identical while the wasm dependency graph stays RNG-free.
    let mut memory_blocks = vec![Block::default(); argon2.params().block_count()];
    let hash_result = argon2.hash_password_into_with_memory(
        code.as_bytes(),
        salt,
        &mut key,
        &mut memory_blocks,
    );
    memory_blocks.zeroize();

    if let Err(err) = hash_result {
        key.zeroize();
        return Err(err.into());
    }

    Ok(key)
}

pub fn encrypt_aead(
    key_bytes: &[u8; KEY_LEN],
    nonce_bytes: &[u8; XNONCE_LEN],
    plaintext: &[u8],
    aad: &[u8],
) -> Result<Vec<u8>> {
    let cipher = XChaCha20Poly1305::new(Key::from_slice(key_bytes));
    let nonce = XNonce::from_slice(nonce_bytes);
    let ciphertext = cipher.encrypt(
        nonce,
        Payload {
            msg: plaintext,
            aad,
        },
    )?;
    Ok(ciphertext)
}

pub fn decrypt_aead(
    key_bytes: &[u8; KEY_LEN],
    nonce_bytes: &[u8; XNONCE_LEN],
    ciphertext: &[u8],
    aad: &[u8],
) -> Result<Vec<u8>> {
    let cipher = XChaCha20Poly1305::new(Key::from_slice(key_bytes));
    let nonce = XNonce::from_slice(nonce_bytes);
    let plaintext = cipher.decrypt(
        nonce,
        Payload {
            msg: ciphertext,
            aad,
        },
    )?;
    Ok(plaintext)
}

pub fn chunk_aad(counter: u64) -> Vec<u8> {
    let mut aad = Vec::with_capacity(AAD_CHUNK.len() + 8);
    aad.extend_from_slice(AAD_CHUNK);
    aad.extend_from_slice(&counter.to_le_bytes());
    aad
}

pub fn chunk_nonce(prefix: &[u8; CHUNK_NONCE_PREFIX_LEN], counter: u64) -> [u8; XNONCE_LEN] {
    let mut nonce = [0u8; XNONCE_LEN];
    nonce[..CHUNK_NONCE_PREFIX_LEN].copy_from_slice(prefix);
    nonce[CHUNK_NONCE_PREFIX_LEN..].copy_from_slice(&counter.to_le_bytes());
    nonce
}

pub fn decode_hex_fixed<const N: usize>(value: &str, field: &str) -> Result<[u8; N]> {
    let bytes = hex::decode(value)
        .map_err(|_| SbxError::InvalidFormat(format!("invalid hex field: {field}")))?;
    if bytes.len() != N {
        return Err(SbxError::InvalidFormat(format!(
            "invalid length for field: {field}"
        )));
    }
    let mut out = [0u8; N];
    out.copy_from_slice(&bytes);
    Ok(out)
}
