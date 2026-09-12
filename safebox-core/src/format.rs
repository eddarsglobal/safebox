use crate::crypto::{CHUNK_NONCE_PREFIX_LEN, KEY_LEN, SALT_LEN, XNONCE_LEN};
use crate::error::{Result, SbxError};
use crate::validation::{
    max_ciphertext_chunk_len, validate_kdf_params, validate_public_metadata,
    validate_read_chunk_size, AEAD_TAG_LEN, MAX_METADATA_CIPHERTEXT_LEN,
};
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::{BufReader, Read, Write};
use std::path::Path;

pub const MAGIC: &[u8; 4] = b"SBX1";
pub const VERSION: u16 = 1;
pub const DEFAULT_CHUNK_SIZE: usize = 1024 * 1024;
pub const MAX_HEADER_LEN: usize = 1024 * 1024;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KdfParams {
    pub name: String,
    pub memory_kib: u32,
    pub time_cost: u32,
    pub parallelism: u32,
    pub output_len: usize,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PublicMetadata {
    pub sender_label: Option<String>,
    pub access_profile: Option<String>,
    pub public_note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SbxHeader {
    pub format: String,
    pub version: u16,
    pub kdf: KdfParams,
    pub salt_hex: String,
    pub wrapped_key_nonce_hex: String,
    pub wrapped_file_key_hex: String,
    pub metadata_nonce_hex: String,
    pub encrypted_metadata_hex: String,
    pub chunk_nonce_prefix_hex: String,
    pub chunk_size: usize,
    pub public: Option<PublicMetadata>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metadata {
    pub original_file_name: String,
    pub original_extension: String,
    pub original_size: u64,
    pub created_utc: String,
    pub visible_sbx_name: String,
    pub burn_after_unlock: bool,
}

pub fn write_header<W: Write>(writer: &mut W, header: &SbxHeader) -> Result<()> {
    validate_header_safety(header)?;

    let json = serde_json::to_vec(header)?;
    if json.len() > MAX_HEADER_LEN {
        return Err(SbxError::InvalidFormat("header too large".to_string()));
    }

    writer.write_all(MAGIC)?;
    writer.write_all(&VERSION.to_le_bytes())?;
    writer.write_all(&(json.len() as u32).to_le_bytes())?;
    writer.write_all(&json)?;
    Ok(())
}

pub fn read_header<R: Read>(reader: &mut R) -> Result<SbxHeader> {
    let mut magic = [0u8; 4];
    reader.read_exact(&mut magic)?;
    if &magic != MAGIC {
        return Err(SbxError::InvalidFormat("bad magic".to_string()));
    }

    let mut version_bytes = [0u8; 2];
    reader.read_exact(&mut version_bytes)?;
    let version = u16::from_le_bytes(version_bytes);
    if version != VERSION {
        return Err(SbxError::UnsupportedVersion(version));
    }

    let mut len_bytes = [0u8; 4];
    reader.read_exact(&mut len_bytes)?;
    let len = u32::from_le_bytes(len_bytes) as usize;
    if len == 0 || len > MAX_HEADER_LEN {
        return Err(SbxError::InvalidFormat("invalid header length".to_string()));
    }

    let mut json = vec![0u8; len];
    reader.read_exact(&mut json)?;
    let header: SbxHeader = serde_json::from_slice(&json)?;

    if header.format != "SBX" {
        return Err(SbxError::InvalidFormat("invalid SBX header".to_string()));
    }
    if header.version != VERSION {
        return Err(SbxError::UnsupportedVersion(header.version));
    }

    validate_header_safety(&header)?;
    Ok(header)
}

pub fn read_public_metadata<R: Read>(reader: &mut R) -> Result<Option<PublicMetadata>> {
    let header = read_header(reader)?;
    Ok(header.public)
}

pub fn read_public_metadata_from_file(path: impl AsRef<Path>) -> Result<Option<PublicMetadata>> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    read_public_metadata(&mut reader)
}

pub fn write_chunk<W: Write>(
    writer: &mut W,
    ciphertext: &[u8],
    declared_chunk_size: usize,
) -> Result<()> {
    let max_len = max_ciphertext_chunk_len(declared_chunk_size)?;
    if ciphertext.len() <= AEAD_TAG_LEN || ciphertext.len() > max_len {
        return Err(SbxError::InvalidFormat(
            "chunk size outside format limits".to_string(),
        ));
    }
    if ciphertext.len() > u32::MAX as usize {
        return Err(SbxError::InvalidFormat("chunk too large".to_string()));
    }
    writer.write_all(&(ciphertext.len() as u32).to_le_bytes())?;
    writer.write_all(ciphertext)?;
    Ok(())
}

pub fn read_next_chunk<R: Read>(
    reader: &mut R,
    declared_chunk_size: usize,
) -> Result<Option<Vec<u8>>> {
    let mut len_bytes = [0u8; 4];
    let mut read = 0usize;

    while read < len_bytes.len() {
        match reader.read(&mut len_bytes[read..])? {
            0 if read == 0 => return Ok(None),
            0 => {
                return Err(SbxError::InvalidFormat(
                    "truncated chunk length".to_string(),
                ))
            }
            n => read += n,
        }
    }

    let len = u32::from_le_bytes(len_bytes) as usize;
    let max_len = max_ciphertext_chunk_len(declared_chunk_size)?;
    if len <= AEAD_TAG_LEN || len > max_len {
        return Err(SbxError::InvalidFormat(format!(
            "encrypted chunk length outside SafeBox limits: {len}"
        )));
    }

    let mut ciphertext = vec![0u8; len];
    reader.read_exact(&mut ciphertext)?;
    Ok(Some(ciphertext))
}

fn validate_header_safety(header: &SbxHeader) -> Result<()> {
    validate_kdf_params(&header.kdf, KEY_LEN)?;
    validate_read_chunk_size(header.chunk_size)?;
    validate_public_metadata(&header.public)?;

    validate_exact_hex_len(&header.salt_hex, SALT_LEN, "salt_hex")?;
    validate_exact_hex_len(
        &header.wrapped_key_nonce_hex,
        XNONCE_LEN,
        "wrapped_key_nonce_hex",
    )?;
    validate_exact_hex_len(
        &header.wrapped_file_key_hex,
        KEY_LEN + AEAD_TAG_LEN,
        "wrapped_file_key_hex",
    )?;
    validate_exact_hex_len(&header.metadata_nonce_hex, XNONCE_LEN, "metadata_nonce_hex")?;
    validate_exact_hex_len(
        &header.chunk_nonce_prefix_hex,
        CHUNK_NONCE_PREFIX_LEN,
        "chunk_nonce_prefix_hex",
    )?;

    if header.encrypted_metadata_hex.len() % 2 != 0
        || header.encrypted_metadata_hex.len() <= AEAD_TAG_LEN * 2
        || header.encrypted_metadata_hex.len() > MAX_METADATA_CIPHERTEXT_LEN * 2
        || !header
            .encrypted_metadata_hex
            .bytes()
            .all(|b| b.is_ascii_hexdigit())
    {
        return Err(SbxError::InvalidFormat(
            "invalid encrypted metadata field".to_string(),
        ));
    }

    Ok(())
}

fn validate_exact_hex_len(value: &str, expected_bytes: usize, field: &str) -> Result<()> {
    let expected_chars = expected_bytes
        .checked_mul(2)
        .ok_or_else(|| SbxError::InvalidFormat("hex length overflow".to_string()))?;
    if value.len() != expected_chars || !value.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(SbxError::InvalidFormat(format!(
            "invalid encoded length for field: {field}"
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    fn valid_header() -> SbxHeader {
        SbxHeader {
            format: "SBX".to_string(),
            version: VERSION,
            kdf: KdfParams {
                name: "argon2id".to_string(),
                memory_kib: 32 * 1024,
                time_cost: 3,
                parallelism: 1,
                output_len: KEY_LEN,
            },
            salt_hex: "00".repeat(SALT_LEN),
            wrapped_key_nonce_hex: "00".repeat(XNONCE_LEN),
            wrapped_file_key_hex: "00".repeat(KEY_LEN + AEAD_TAG_LEN),
            metadata_nonce_hex: "00".repeat(XNONCE_LEN),
            encrypted_metadata_hex: "00".repeat(AEAD_TAG_LEN + 1),
            chunk_nonce_prefix_hex: "00".repeat(CHUNK_NONCE_PREFIX_LEN),
            chunk_size: DEFAULT_CHUNK_SIZE,
            public: None,
        }
    }

    #[test]
    fn rejects_hostile_kdf_before_use() {
        let mut header = valid_header();
        header.kdf.memory_kib = u32::MAX;
        assert!(matches!(
            validate_header_safety(&header),
            Err(SbxError::KdfRejected(_))
        ));
    }

    #[test]
    fn rejects_oversized_encrypted_chunk_before_allocation() {
        let declared = 1024usize;
        let hostile_len = (declared + AEAD_TAG_LEN + 1) as u32;
        let mut bytes = hostile_len.to_le_bytes().to_vec();
        bytes.extend_from_slice(&[0u8; 8]);
        let mut cursor = Cursor::new(bytes);
        assert!(read_next_chunk(&mut cursor, declared).is_err());
    }

    #[test]
    fn rejects_unsupported_version() {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(MAGIC);
        bytes.extend_from_slice(&(VERSION + 1).to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        let mut cursor = Cursor::new(bytes);
        assert!(matches!(
            read_header(&mut cursor),
            Err(SbxError::UnsupportedVersion(_))
        ));
    }
}
