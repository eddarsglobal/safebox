use crate::crypto::{
    chunk_aad, chunk_nonce, decode_hex_fixed, decrypt_aead, derive_code_key, random_array,
    AAD_FILE_KEY, AAD_METADATA, CHUNK_NONCE_PREFIX_LEN, KEY_LEN, SALT_LEN, XNONCE_LEN,
};
use crate::error::{Result, SbxError};
use crate::format::{read_header, read_next_chunk, Metadata};
#[cfg(test)]
use crate::validation::AEAD_TAG_LEN;
use std::fs::{self, File, OpenOptions};
use std::io::{BufReader, BufWriter, ErrorKind, Write};
use std::path::{Path, PathBuf};
use zeroize::Zeroizing;

#[derive(Debug, Clone)]
pub struct UnlockOptions {
    pub sbx_path: PathBuf,
    pub output_dir: Option<PathBuf>,
    pub code: String,
    pub burn_after_unlock: bool,
    pub overwrite: bool,
}

impl UnlockOptions {
    pub fn new(sbx_path: impl Into<PathBuf>, code: impl Into<String>) -> Self {
        Self {
            sbx_path: sbx_path.into(),
            output_dir: None,
            code: code.into(),
            burn_after_unlock: false,
            overwrite: false,
        }
    }
}

#[derive(Debug, Clone)]
pub struct UnlockReport {
    pub sbx_path: PathBuf,
    pub restored_path: PathBuf,
    pub original_file_name: String,
    pub original_size: u64,
    pub decrypted_chunks: u64,
    pub sbx_deleted: bool,
    pub burn_warning: Option<String>,
}

pub fn unlock_sbx(options: UnlockOptions) -> Result<UnlockReport> {
    let UnlockOptions {
        sbx_path,
        output_dir,
        code,
        burn_after_unlock,
        overwrite,
    } = options;

    let code = Zeroizing::new(code);
    if code.is_empty() {
        return Err(SbxError::EmptyCode);
    }

    let sbx_metadata = fs::symlink_metadata(&sbx_path)?;
    if sbx_metadata.file_type().is_symlink() || !sbx_metadata.is_file() {
        return Err(SbxError::InvalidFormat(
            "SBX input must be a regular non-symlink file".to_string(),
        ));
    }

    let sbx_file = File::open(&sbx_path)?;
    let mut reader = BufReader::new(sbx_file);
    let header = read_header(&mut reader)?;

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

    let code_key = Zeroizing::new(derive_code_key(code.as_str(), &salt, &header.kdf)?);
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

    let safe_name = safe_output_file_name(&metadata.original_file_name)?;
    let output_dir = output_dir.unwrap_or_else(|| {
        sbx_path
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .to_path_buf()
    });
    fs::create_dir_all(&output_dir)?;

    let mut restored_path = output_dir.join(&safe_name);
    if restored_path.exists() && !overwrite {
        restored_path = next_available_path(&restored_path);
    }
    if restored_path.exists() && !overwrite {
        return Err(SbxError::OutputExists(restored_path.display().to_string()));
    }

    let (temp_path, temp_file) = create_secure_temp_file(&restored_path)?;

    let result = (|| -> Result<UnlockReport> {
        let mut writer = BufWriter::new(temp_file);
        let mut counter = 0u64;
        let mut restored_size = 0u64;
        let expected_chunks = expected_chunk_count(metadata.original_size, header.chunk_size)?;

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
                    SbxError::IntegrityFailed(format!(
                        "chunk authentication failed at index {counter}"
                    ))
                })?,
            );

            if plaintext.is_empty() || plaintext.len() > header.chunk_size {
                return Err(SbxError::IntegrityFailed(
                    "decrypted chunk size outside declared limits".to_string(),
                ));
            }

            let new_size = restored_size
                .checked_add(plaintext.len() as u64)
                .ok_or_else(|| SbxError::IntegrityFailed("restored size overflow".to_string()))?;
            if new_size > metadata.original_size {
                return Err(SbxError::IntegrityFailed(
                    "decrypted content exceeds declared original size".to_string(),
                ));
            }

            writer.write_all(plaintext.as_slice())?;
            restored_size = new_size;
            counter = counter
                .checked_add(1)
                .ok_or_else(|| SbxError::IntegrityFailed("chunk counter overflow".to_string()))?;
        }

        if counter != expected_chunks {
            return Err(SbxError::IntegrityFailed(format!(
                "missing encrypted chunks: expected {expected_chunks}, got {counter}"
            )));
        }

        if restored_size != metadata.original_size {
            return Err(SbxError::IntegrityFailed(format!(
                "restored size mismatch: expected {}, got {}",
                metadata.original_size, restored_size
            )));
        }

        writer.flush()?;
        writer.get_ref().sync_all()?;
        drop(writer);
        drop(reader);

        commit_restored_file(&temp_path, &restored_path, overwrite)?;

        let mut sbx_deleted = false;
        let mut burn_warning = None;
        if burn_after_unlock && metadata.burn_after_unlock {
            match fs::remove_file(&sbx_path) {
                Ok(()) => {
                    sbx_deleted = true;
                    if let Err(err) = sync_parent_dir(&sbx_path) {
                        burn_warning = Some(format!(
                            "SBX deleted, but directory durability sync failed: {err}"
                        ));
                    }
                }
                Err(err) => {
                    burn_warning = Some(format!(
                        "Original restored, but local SBX could not be removed: {err}"
                    ));
                }
            }
        }

        Ok(UnlockReport {
            sbx_path: sbx_path.clone(),
            restored_path: restored_path.clone(),
            original_file_name: metadata.original_file_name.clone(),
            original_size: metadata.original_size,
            decrypted_chunks: counter,
            sbx_deleted,
            burn_warning,
        })
    })();

    if result.is_err() {
        let _ = fs::remove_file(&temp_path);
    }

    result
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

fn safe_output_file_name(name: &str) -> Result<String> {
    let file_name = Path::new(name)
        .file_name()
        .and_then(|v| v.to_str())
        .ok_or(SbxError::UnsafeFileName)?;

    if file_name.is_empty()
        || file_name == "."
        || file_name == ".."
        || file_name.contains('/')
        || file_name.contains('\\')
        || file_name.contains('\0')
        || file_name.chars().any(|ch| ch.is_control())
        || file_name
            .chars()
            .any(|ch| matches!(ch, '<' | '>' | ':' | '"' | '|' | '?' | '*'))
        || file_name.ends_with(' ')
        || file_name.ends_with('.')
        || is_windows_reserved_name(file_name)
    {
        return Err(SbxError::UnsafeFileName);
    }

    Ok(file_name.to_string())
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

fn create_secure_temp_file(restored_path: &Path) -> Result<(PathBuf, File)> {
    for _ in 0..32 {
        let suffix = hex::encode(random_array::<16>());
        let file_name = restored_path
            .file_name()
            .and_then(|v| v.to_str())
            .unwrap_or("restored_file");
        let candidate =
            restored_path.with_file_name(format!(".{file_name}.sbx-restoring-{suffix}"));

        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }

        match options.open(&candidate) {
            Ok(file) => return Ok((candidate, file)),
            Err(err) if err.kind() == ErrorKind::AlreadyExists => continue,
            Err(err) => return Err(err.into()),
        }
    }

    Err(SbxError::Io(std::io::Error::new(
        ErrorKind::AlreadyExists,
        "could not allocate a unique restore temp file",
    )))
}

fn commit_restored_file(temp_path: &Path, restored_path: &Path, overwrite: bool) -> Result<()> {
    if !restored_path.exists() {
        fs::rename(temp_path, restored_path)?;
        sync_parent_dir(restored_path)?;
        return Ok(());
    }

    if !overwrite {
        return Err(SbxError::OutputExists(restored_path.display().to_string()));
    }

    let backup_path = unique_backup_path(restored_path);
    fs::rename(restored_path, &backup_path)?;

    if let Err(commit_err) = fs::rename(temp_path, restored_path) {
        let _ = fs::rename(&backup_path, restored_path);
        return Err(commit_err.into());
    }

    if let Err(sync_err) = sync_parent_dir(restored_path) {
        let _ = fs::remove_file(restored_path);
        let _ = fs::rename(&backup_path, restored_path);
        return Err(sync_err);
    }

    let _ = fs::remove_file(&backup_path);
    let _ = sync_parent_dir(restored_path);
    Ok(())
}

fn unique_backup_path(restored_path: &Path) -> PathBuf {
    let suffix = hex::encode(random_array::<16>());
    let file_name = restored_path
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or("restored_file");
    restored_path.with_file_name(format!(".{file_name}.sbx-backup-{suffix}"))
}

fn next_available_path(path: &Path) -> PathBuf {
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    let stem = path.file_stem().and_then(|v| v.to_str()).unwrap_or("file");
    let ext = path.extension().and_then(|v| v.to_str()).unwrap_or("");

    for i in 1..10_000u32 {
        let candidate_name = if ext.is_empty() {
            format!("{stem} ({i})")
        } else {
            format!("{stem} ({i}).{ext}")
        };
        let candidate = parent.join(candidate_name);
        if !candidate.exists() {
            return candidate;
        }
    }

    path.to_path_buf()
}

#[cfg(unix)]
fn sync_parent_dir(path: &Path) -> Result<()> {
    if let Some(parent) = path.parent() {
        let parent = if parent.as_os_str().is_empty() {
            Path::new(".")
        } else {
            parent
        };
        File::open(parent)?.sync_all()?;
    }
    Ok(())
}

#[cfg(not(unix))]
fn sync_parent_dir(_path: &Path) -> Result<()> {
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_windows_reserved_names_cross_platform() {
        for value in ["CON", "con.txt", "AUX.pdf", "LPT1.log", "COM9.bin"] {
            assert!(safe_output_file_name(value).is_err(), "{value}");
        }
    }

    #[test]
    fn accepts_unicode_file_names() {
        assert_eq!(
            safe_output_file_name("čuvaj_ملف.pdf").unwrap(),
            "čuvaj_ملف.pdf"
        );
    }

    #[test]
    fn expected_chunk_count_is_bounded_by_size() {
        assert_eq!(expected_chunk_count(0, 1024).unwrap(), 0);
        assert_eq!(expected_chunk_count(1, 1024).unwrap(), 1);
        assert_eq!(expected_chunk_count(1024, 1024).unwrap(), 1);
        assert_eq!(expected_chunk_count(1025, 1024).unwrap(), 2);
    }

    #[test]
    fn aead_tag_constant_matches_sbx_assumption() {
        assert_eq!(AEAD_TAG_LEN, 16);
    }
}
