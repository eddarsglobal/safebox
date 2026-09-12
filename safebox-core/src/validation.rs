use crate::error::{Result, SbxError};
use crate::format::{KdfParams, PublicMetadata};

pub const AEAD_TAG_LEN: usize = 16;
pub const MIN_CREATE_CHUNK_SIZE: usize = 64 * 1024;
pub const MAX_CHUNK_SIZE: usize = 16 * 1024 * 1024;
pub const MIN_KDF_MEMORY_KIB: u32 = 19 * 1024;
pub const MAX_KDF_MEMORY_KIB: u32 = 256 * 1024;
pub const MIN_KDF_TIME_COST: u32 = 2;
pub const MAX_KDF_TIME_COST: u32 = 10;
pub const MIN_KDF_PARALLELISM: u32 = 1;
pub const MAX_KDF_PARALLELISM: u32 = 4;
pub const MAX_PUBLIC_LABEL_CHARS: usize = 120;
pub const MAX_PUBLIC_NOTE_CHARS: usize = 180;
pub const MAX_METADATA_CIPHERTEXT_LEN: usize = 64 * 1024;

pub fn validate_kdf_params(kdf: &KdfParams, expected_output_len: usize) -> Result<()> {
    if kdf.name != "argon2id" || kdf.output_len != expected_output_len {
        return Err(SbxError::KdfRejected(
            "unsupported KDF algorithm or output length".to_string(),
        ));
    }

    if !(MIN_KDF_MEMORY_KIB..=MAX_KDF_MEMORY_KIB).contains(&kdf.memory_kib) {
        return Err(SbxError::KdfRejected(format!(
            "Argon2 memory cost outside SafeBox limits: {} KiB",
            kdf.memory_kib
        )));
    }

    if !(MIN_KDF_TIME_COST..=MAX_KDF_TIME_COST).contains(&kdf.time_cost) {
        return Err(SbxError::KdfRejected(format!(
            "Argon2 time cost outside SafeBox limits: {}",
            kdf.time_cost
        )));
    }

    if !(MIN_KDF_PARALLELISM..=MAX_KDF_PARALLELISM).contains(&kdf.parallelism) {
        return Err(SbxError::KdfRejected(format!(
            "Argon2 parallelism outside SafeBox limits: {}",
            kdf.parallelism
        )));
    }

    Ok(())
}

pub fn validate_create_chunk_size(chunk_size: usize) -> Result<()> {
    if !(MIN_CREATE_CHUNK_SIZE..=MAX_CHUNK_SIZE).contains(&chunk_size) {
        return Err(SbxError::InvalidFormat(format!(
            "chunk size must be between {} KiB and {} MiB",
            MIN_CREATE_CHUNK_SIZE / 1024,
            MAX_CHUNK_SIZE / (1024 * 1024)
        )));
    }
    Ok(())
}

pub fn validate_read_chunk_size(chunk_size: usize) -> Result<()> {
    if chunk_size == 0 || chunk_size > MAX_CHUNK_SIZE {
        return Err(SbxError::InvalidFormat(format!(
            "unsafe chunk size: {chunk_size}"
        )));
    }
    Ok(())
}

pub fn max_ciphertext_chunk_len(chunk_size: usize) -> Result<usize> {
    validate_read_chunk_size(chunk_size)?;
    chunk_size
        .checked_add(AEAD_TAG_LEN)
        .ok_or_else(|| SbxError::InvalidFormat("chunk size overflow".to_string()))
}

pub fn validate_public_metadata(public: &Option<PublicMetadata>) -> Result<()> {
    let Some(public) = public else {
        return Ok(());
    };

    validate_optional_char_limit(
        public.sender_label.as_deref(),
        MAX_PUBLIC_LABEL_CHARS,
        "sender_label",
    )?;
    validate_optional_char_limit(
        public.access_profile.as_deref(),
        MAX_PUBLIC_LABEL_CHARS,
        "access_profile",
    )?;
    validate_optional_char_limit(
        public.public_note.as_deref(),
        MAX_PUBLIC_NOTE_CHARS,
        "public_note",
    )?;

    Ok(())
}

fn validate_optional_char_limit(value: Option<&str>, max_chars: usize, field: &str) -> Result<()> {
    if let Some(value) = value {
        if value.chars().count() > max_chars {
            return Err(SbxError::InvalidFormat(format!(
                "public metadata field too long: {field}"
            )));
        }
        if value
            .chars()
            .any(|ch| ch == '\0' || ch == '\r' || ch == '\n')
        {
            return Err(SbxError::InvalidFormat(format!(
                "invalid characters in public metadata field: {field}"
            )));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn good_kdf() -> KdfParams {
        KdfParams {
            name: "argon2id".to_string(),
            memory_kib: 32 * 1024,
            time_cost: 3,
            parallelism: 1,
            output_len: 32,
        }
    }

    #[test]
    fn accepts_default_kdf() {
        validate_kdf_params(&good_kdf(), 32).unwrap();
    }

    #[test]
    fn rejects_hostile_argon2_memory() {
        let mut kdf = good_kdf();
        kdf.memory_kib = u32::MAX;
        assert!(matches!(
            validate_kdf_params(&kdf, 32),
            Err(SbxError::KdfRejected(_))
        ));
    }

    #[test]
    fn rejects_hostile_argon2_time_cost() {
        let mut kdf = good_kdf();
        kdf.time_cost = u32::MAX;
        assert!(matches!(
            validate_kdf_params(&kdf, 32),
            Err(SbxError::KdfRejected(_))
        ));
    }

    #[test]
    fn rejects_oversized_chunk_configuration() {
        assert!(validate_read_chunk_size(MAX_CHUNK_SIZE + 1).is_err());
    }
}
