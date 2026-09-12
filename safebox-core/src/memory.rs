use crate::crypto::{
    chunk_aad, chunk_nonce, decode_hex_fixed, decrypt_aead, derive_code_key, encrypt_aead,
    AAD_FILE_KEY, AAD_METADATA, CHUNK_NONCE_PREFIX_LEN, KEY_LEN, SALT_LEN, XNONCE_LEN,
};
use crate::error::{Result, SbxError};
use crate::format::{
    read_header, read_next_chunk, write_chunk, write_header, KdfParams, Metadata, PublicMetadata,
    SbxHeader, DEFAULT_CHUNK_SIZE,
};
use crate::validation::{validate_create_chunk_size, validate_kdf_params, validate_public_metadata};
use std::io::Cursor;
use zeroize::Zeroizing;

pub const WEB_ENTROPY_LEN: usize =
    SALT_LEN + XNONCE_LEN + XNONCE_LEN + CHUNK_NONCE_PREFIX_LEN + KEY_LEN;

#[derive(Debug, Clone)]
pub struct MemoryCreateOptions {
    pub original_file_name: String,
    pub visible_sbx_name: String,
    pub code: String,
    pub burn_after_unlock: bool,
    pub chunk_size: usize,
    pub kdf_profile: crate::profile::KdfProfile,
    pub public_metadata: Option<PublicMetadata>,
    pub created_utc: String,
    pub entropy: [u8; WEB_ENTROPY_LEN],
}

impl MemoryCreateOptions {
    pub fn new(
        original_file_name: impl Into<String>,
        visible_sbx_name: impl Into<String>,
        code: impl Into<String>,
        created_utc: impl Into<String>,
        entropy: [u8; WEB_ENTROPY_LEN],
    ) -> Self {
        Self {
            original_file_name: original_file_name.into(),
            visible_sbx_name: visible_sbx_name.into(),
            code: code.into(),
            burn_after_unlock: false,
            chunk_size: DEFAULT_CHUNK_SIZE,
            kdf_profile: crate::profile::KdfProfile::default(),
            public_metadata: None,
            created_utc: created_utc.into(),
            entropy,
        }
    }
}

#[derive(Debug, Clone)]
pub struct MemoryCreateReport {
    pub sbx_bytes: Vec<u8>,
    pub original_file_name: String,
    pub original_size: u64,
    pub visible_sbx_name: String,
    pub encrypted_chunks: u64,
}

#[derive(Debug, Clone)]
pub struct MemoryUnlockReport {
    pub restored_bytes: Vec<u8>,
    pub original_file_name: String,
    pub original_size: u64,
    pub visible_sbx_name: String,
    pub decrypted_chunks: u64,
    pub burn_after_unlock: bool,
    pub public_metadata: Option<PublicMetadata>,
}

pub fn create_sbx_bytes(input: &[u8], options: MemoryCreateOptions) -> Result<MemoryCreateReport> {
    let MemoryCreateOptions {
        original_file_name,
        visible_sbx_name,
        code,
        burn_after_unlock,
        chunk_size,
        kdf_profile,
        public_metadata,
        created_utc,
        entropy,
    } = options;

    let code = Zeroizing::new(code);
    if code.is_empty() {
        return Err(SbxError::EmptyCode);
    }
    validate_create_chunk_size(chunk_size)?;
    validate_public_metadata(&public_metadata)?;
    validate_memory_file_name(&original_file_name)?;
    validate_visible_sbx_name(&visible_sbx_name)?;
    validate_created_utc(&created_utc)?;

    let original_size = u64::try_from(input.len())
        .map_err(|_| SbxError::InvalidFormat("input size exceeds SBX limits".to_string()))?;
    let original_extension = original_file_name
        .rsplit_once('.')
        .map(|(_, ext)| ext.to_string())
        .unwrap_or_default();

    let mut offset = 0usize;
    let salt = take_entropy::<SALT_LEN>(&entropy, &mut offset)?;
    let wrapped_key_nonce = take_entropy::<XNONCE_LEN>(&entropy, &mut offset)?;
    let metadata_nonce = take_entropy::<XNONCE_LEN>(&entropy, &mut offset)?;
    let chunk_nonce_prefix = take_entropy::<CHUNK_NONCE_PREFIX_LEN>(&entropy, &mut offset)?;
    let file_key = Zeroizing::new(take_entropy::<KEY_LEN>(&entropy, &mut offset)?);
    if offset != WEB_ENTROPY_LEN {
        return Err(SbxError::InvalidFormat("invalid entropy layout".to_string()));
    }

    let kdf = KdfParams {
        name: "argon2id".to_string(),
        memory_kib: kdf_profile.memory_kib,
        time_cost: kdf_profile.time_cost,
        parallelism: kdf_profile.parallelism,
        output_len: KEY_LEN,
    };
    validate_kdf_params(&kdf, KEY_LEN)?;

    let code_key = Zeroizing::new(derive_code_key(code.as_str(), &salt, &kdf)?);
    let wrapped_file_key = encrypt_aead(&*code_key, &wrapped_key_nonce, &*file_key, AAD_FILE_KEY)?;

    let encrypted_metadata = {
        let metadata = Metadata {
            original_file_name: original_file_name.clone(),
            original_extension,
            original_size,
            created_utc,
            visible_sbx_name: visible_sbx_name.clone(),
            burn_after_unlock,
        };
        let json = Zeroizing::new(serde_json::to_vec(&metadata)?);
        encrypt_aead(&*file_key, &metadata_nonce, json.as_slice(), AAD_METADATA)?
    };

    let header = SbxHeader {
        format: "SBX".to_string(),
        version: crate::format::VERSION,
        kdf,
        salt_hex: hex::encode(salt),
        wrapped_key_nonce_hex: hex::encode(wrapped_key_nonce),
        wrapped_file_key_hex: hex::encode(wrapped_file_key),
        metadata_nonce_hex: hex::encode(metadata_nonce),
        encrypted_metadata_hex: hex::encode(encrypted_metadata),
        chunk_nonce_prefix_hex: hex::encode(chunk_nonce_prefix),
        chunk_size,
        public: public_metadata,
    };

    let estimated = input.len().saturating_add(64 * 1024);
    let mut output = Vec::with_capacity(estimated);
    write_header(&mut output, &header)?;

    let mut counter = 0u64;
    for chunk in input.chunks(chunk_size) {
        if chunk.is_empty() {
            continue;
        }
        let nonce = chunk_nonce(&chunk_nonce_prefix, counter);
        let aad = chunk_aad(counter);
        let ciphertext = encrypt_aead(&*file_key, &nonce, chunk, &aad)?;
        write_chunk(&mut output, &ciphertext, chunk_size)?;
        counter = counter
            .checked_add(1)
            .ok_or_else(|| SbxError::InvalidFormat("chunk counter overflow".to_string()))?;
    }

    Ok(MemoryCreateReport {
        sbx_bytes: output,
        original_file_name,
        original_size,
        visible_sbx_name,
        encrypted_chunks: counter,
    })
}

pub fn unlock_sbx_bytes(sbx: &[u8], code: &str) -> Result<MemoryUnlockReport> {
    if code.is_empty() {
        return Err(SbxError::EmptyCode);
    }

    let mut reader = Cursor::new(sbx);
    let header = read_header(&mut reader)?;
    let public_metadata = header.public.clone();

    let salt = decode_hex_fixed::<SALT_LEN>(&header.salt_hex, "salt_hex")?;
    let wrapped_key_nonce =
        decode_hex_fixed::<XNONCE_LEN>(&header.wrapped_key_nonce_hex, "wrapped_key_nonce_hex")?;
    let metadata_nonce =
        decode_hex_fixed::<XNONCE_LEN>(&header.metadata_nonce_hex, "metadata_nonce_hex")?;
    let chunk_nonce_prefix = decode_hex_fixed::<CHUNK_NONCE_PREFIX_LEN>(
        &header.chunk_nonce_prefix_hex,
        "chunk_nonce_prefix_hex",
    )?;

    let wrapped_file_key = Zeroizing::new(
        hex::decode(&header.wrapped_file_key_hex)
            .map_err(|_| SbxError::InvalidFormat("invalid wrapped file key hex".to_string()))?,
    );
    let encrypted_metadata = Zeroizing::new(
        hex::decode(&header.encrypted_metadata_hex)
            .map_err(|_| SbxError::InvalidFormat("invalid encrypted metadata hex".to_string()))?,
    );

    let code_key = Zeroizing::new(derive_code_key(code, &salt, &header.kdf)?);
    let file_key_vec = Zeroizing::new(
        decrypt_aead(
            &*code_key,
            &wrapped_key_nonce,
            wrapped_file_key.as_slice(),
            AAD_FILE_KEY,
        )
        .map_err(|_| SbxError::AccessDenied)?,
    );
    if file_key_vec.len() != KEY_LEN {
        return Err(SbxError::InvalidFormat(
            "invalid unwrapped file key length".to_string(),
        ));
    }
    let mut file_key_array = [0u8; KEY_LEN];
    file_key_array.copy_from_slice(&file_key_vec);
    let file_key = Zeroizing::new(file_key_array);

    let metadata_plain = Zeroizing::new(
        decrypt_aead(
            &*file_key,
            &metadata_nonce,
            encrypted_metadata.as_slice(),
            AAD_METADATA,
        )
        .map_err(|_| SbxError::IntegrityFailed("metadata authentication failed".to_string()))?,
    );
    let metadata: Metadata = serde_json::from_slice(metadata_plain.as_slice())
        .map_err(|_| SbxError::IntegrityFailed("metadata is not valid JSON".to_string()))?;
    validate_memory_file_name(&metadata.original_file_name)?;

    let expected_chunks = expected_chunk_count(metadata.original_size, header.chunk_size)?;
    let capacity = usize::try_from(metadata.original_size)
        .map_err(|_| SbxError::InvalidFormat("restored size exceeds browser memory".to_string()))?;
    let mut restored = Zeroizing::new(Vec::with_capacity(capacity));
    let mut counter = 0u64;

    while let Some(ciphertext) = read_next_chunk(&mut reader, header.chunk_size)? {
        if counter >= expected_chunks {
            return Err(SbxError::IntegrityFailed(
                "unexpected extra encrypted chunk".to_string(),
            ));
        }
        let nonce = chunk_nonce(&chunk_nonce_prefix, counter);
        let aad = chunk_aad(counter);
        let plaintext = Zeroizing::new(
            decrypt_aead(&*file_key, &nonce, &ciphertext, &aad).map_err(|_| {
                SbxError::IntegrityFailed(format!("chunk authentication failed at index {counter}"))
            })?,
        );
        if plaintext.is_empty() || plaintext.len() > header.chunk_size {
            return Err(SbxError::IntegrityFailed(
                "decrypted chunk size outside declared limits".to_string(),
            ));
        }
        restored.extend_from_slice(plaintext.as_slice());
        if restored.len() as u64 > metadata.original_size {
            return Err(SbxError::IntegrityFailed(
                "decrypted content exceeds declared original size".to_string(),
            ));
        }
        counter = counter
            .checked_add(1)
            .ok_or_else(|| SbxError::IntegrityFailed("chunk counter overflow".to_string()))?;
    }

    if counter != expected_chunks {
        return Err(SbxError::IntegrityFailed(format!(
            "missing encrypted chunks: expected {expected_chunks}, got {counter}"
        )));
    }
    if restored.len() as u64 != metadata.original_size {
        return Err(SbxError::IntegrityFailed(format!(
            "restored size mismatch: expected {}, got {}",
            metadata.original_size,
            restored.len()
        )));
    }

    Ok(MemoryUnlockReport {
        restored_bytes: std::mem::take(&mut *restored),
        original_file_name: metadata.original_file_name,
        original_size: metadata.original_size,
        visible_sbx_name: metadata.visible_sbx_name,
        decrypted_chunks: counter,
        burn_after_unlock: metadata.burn_after_unlock,
        public_metadata,
    })
}

pub fn read_public_metadata_from_bytes(sbx: &[u8]) -> Result<(String, Option<PublicMetadata>)> {
    let mut reader = Cursor::new(sbx);
    let header = read_header(&mut reader)?;
    Ok((header.format, header.public))
}

fn take_entropy<const N: usize>(source: &[u8; WEB_ENTROPY_LEN], offset: &mut usize) -> Result<[u8; N]> {
    let end = offset
        .checked_add(N)
        .ok_or_else(|| SbxError::InvalidFormat("entropy offset overflow".to_string()))?;
    let slice = source
        .get(*offset..end)
        .ok_or_else(|| SbxError::InvalidFormat("insufficient entropy".to_string()))?;
    let mut out = [0u8; N];
    out.copy_from_slice(slice);
    *offset = end;
    Ok(out)
}

fn expected_chunk_count(original_size: u64, chunk_size: usize) -> Result<u64> {
    if original_size == 0 {
        return Ok(0);
    }
    let chunk_size = u64::try_from(chunk_size)
        .map_err(|_| SbxError::InvalidFormat("chunk size conversion failed".to_string()))?;
    let adjusted = original_size
        .checked_add(chunk_size - 1)
        .ok_or_else(|| SbxError::InvalidFormat("original size overflow".to_string()))?;
    Ok(adjusted / chunk_size)
}

fn validate_memory_file_name(name: &str) -> Result<()> {
    if name.is_empty()
        || name == "."
        || name == ".."
        || name.contains('/')
        || name.contains('\\')
        || name.contains('\0')
        || name.chars().any(|ch| ch.is_control())
        || name.chars().any(|ch| matches!(ch, '<' | '>' | ':' | '"' | '|' | '?' | '*'))
        || name.ends_with(' ')
        || name.ends_with('.')
        || is_windows_reserved_name(name)
        || name.chars().count() > 255
    {
        return Err(SbxError::UnsafeFileName);
    }
    Ok(())
}

fn validate_visible_sbx_name(name: &str) -> Result<()> {
    if name.is_empty()
        || name.contains('/')
        || name.contains('\\')
        || name.contains('\0')
        || name.chars().any(|ch| ch.is_control())
        || name.chars().count() > 160
    {
        return Err(SbxError::InvalidFormat("unsafe visible SBX name".to_string()));
    }
    Ok(())
}

fn validate_created_utc(value: &str) -> Result<()> {
    if value.is_empty()
        || value.len() > 64
        || value.contains('\0')
        || value.chars().any(|ch| ch == '\r' || ch == '\n')
    {
        return Err(SbxError::InvalidFormat("invalid created_utc".to_string()));
    }
    Ok(())
}

fn is_windows_reserved_name(file_name: &str) -> bool {
    let stem = file_name
        .split('.')
        .next()
        .unwrap_or(file_name)
        .trim_end_matches(&[' ', '.'][..])
        .to_ascii_uppercase();
    matches!(stem.as_str(), "CON" | "PRN" | "AUX" | "NUL")
        || (stem.len() == 4
            && (stem.starts_with("COM") || stem.starts_with("LPT"))
            && stem.as_bytes()[3].is_ascii_digit()
            && stem.as_bytes()[3] != b'0')
}

#[cfg(test)]
mod tests {
    use super::*;

    fn deterministic_entropy() -> [u8; WEB_ENTROPY_LEN] {
        let mut out = [0u8; WEB_ENTROPY_LEN];
        for (index, byte) in out.iter_mut().enumerate() {
            *byte = ((index * 29 + 17) % 251) as u8;
        }
        out
    }

    #[test]
    fn memory_roundtrip_uses_canonical_sbx_format() {
        let input = b"SafeBox WebAssembly canonical compatibility fixture";
        let mut options = MemoryCreateOptions::new(
            "fixture.txt",
            "fixture.sbx",
            "correct horse battery staple",
            "2026-08-30T20:00:00Z",
            deterministic_entropy(),
        );
        options.chunk_size = crate::validation::MIN_CREATE_CHUNK_SIZE;
        options.public_metadata = Some(PublicMetadata {
            sender_label: Some("Web".to_string()),
            access_profile: Some("Compatibility".to_string()),
            public_note: Some("R68".to_string()),
        });

        let created = create_sbx_bytes(input, options).unwrap();
        assert_eq!(&created.sbx_bytes[..4], crate::format::MAGIC);
        let unlocked = unlock_sbx_bytes(&created.sbx_bytes, "correct horse battery staple").unwrap();
        assert_eq!(unlocked.restored_bytes, input);
        assert_eq!(unlocked.original_file_name, "fixture.txt");
        assert_eq!(unlocked.public_metadata.unwrap().public_note.as_deref(), Some("R68"));
    }

    #[test]
    fn memory_unlock_rejects_wrong_code_and_tamper() {
        let input = vec![0x42; crate::validation::MIN_CREATE_CHUNK_SIZE + 33];
        let mut options = MemoryCreateOptions::new(
            "fixture.bin",
            "fixture.sbx",
            "R68-passphrase",
            "2026-08-30T20:00:00Z",
            deterministic_entropy(),
        );
        options.chunk_size = crate::validation::MIN_CREATE_CHUNK_SIZE;
        let created = create_sbx_bytes(&input, options).unwrap();
        assert!(matches!(
            unlock_sbx_bytes(&created.sbx_bytes, "wrong"),
            Err(SbxError::AccessDenied)
        ));

        let mut tampered = created.sbx_bytes;
        let last = tampered.len() - 1;
        tampered[last] ^= 0x01;
        assert!(matches!(
            unlock_sbx_bytes(&tampered, "R68-passphrase"),
            Err(SbxError::IntegrityFailed(_))
        ));
    }
}
