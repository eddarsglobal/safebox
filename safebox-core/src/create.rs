use crate::crypto::{
    chunk_aad, chunk_nonce, derive_code_key, encrypt_aead, random_array, AAD_FILE_KEY,
    AAD_METADATA, CHUNK_NONCE_PREFIX_LEN, KEY_LEN, SALT_LEN, XNONCE_LEN,
};
use crate::error::{Result, SbxError};
use crate::format::{
    write_chunk, write_header, KdfParams, Metadata, PublicMetadata, SbxHeader, DEFAULT_CHUNK_SIZE,
};
use crate::validation::{validate_create_chunk_size, validate_kdf_params};
use chrono::Utc;
use std::fs::{self, File, OpenOptions};
use std::io::{BufReader, BufWriter, ErrorKind, Read, Write};
use std::path::{Path, PathBuf};
use zeroize::Zeroizing;

use crate::profile::KdfProfile;

#[derive(Debug, Clone)]
pub struct CreateOptions {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub code: String,
    pub burn_after_unlock: bool,
    pub chunk_size: usize,
    pub kdf_profile: KdfProfile,
    pub public_metadata: Option<PublicMetadata>,
}

impl CreateOptions {
    pub fn new(
        input_path: impl Into<PathBuf>,
        output_path: impl Into<PathBuf>,
        code: impl Into<String>,
    ) -> Self {
        Self {
            input_path: input_path.into(),
            output_path: output_path.into(),
            code: code.into(),
            burn_after_unlock: false,
            chunk_size: DEFAULT_CHUNK_SIZE,
            kdf_profile: KdfProfile::default(),
            public_metadata: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct CreateReport {
    pub input_path: PathBuf,
    pub output_path: PathBuf,
    pub original_file_name: String,
    pub original_size: u64,
    pub visible_sbx_name: String,
    pub encrypted_chunks: u64,
}

pub fn create_sbx(options: CreateOptions) -> Result<CreateReport> {
    let CreateOptions {
        input_path,
        output_path,
        code,
        burn_after_unlock,
        chunk_size,
        kdf_profile,
        public_metadata,
    } = options;

    let code = Zeroizing::new(code);
    if code.is_empty() {
        return Err(SbxError::EmptyCode);
    }

    validate_create_chunk_size(chunk_size)?;

    let input_metadata = fs::symlink_metadata(&input_path)?;
    if input_metadata.file_type().is_symlink() || !input_metadata.is_file() {
        return Err(SbxError::InvalidFormat(
            "input path must be a regular non-symlink file".to_string(),
        ));
    }

    let input_file = File::open(&input_path)?;
    let metadata_fs = input_file.metadata()?;
    if !metadata_fs.is_file() {
        return Err(SbxError::InvalidFormat(
            "input path must be a regular file".to_string(),
        ));
    }

    let original_file_name = input_path
        .file_name()
        .and_then(|v| v.to_str())
        .ok_or(SbxError::UnsafeFileName)?
        .to_string();

    let original_extension = input_path
        .extension()
        .and_then(|v| v.to_str())
        .unwrap_or("")
        .to_string();

    let visible_sbx_name = output_path
        .file_name()
        .and_then(|v| v.to_str())
        .ok_or_else(|| SbxError::InvalidFormat("output path has no filename".to_string()))?
        .to_string();

    let salt = random_array::<SALT_LEN>();
    let wrapped_key_nonce = random_array::<XNONCE_LEN>();
    let metadata_nonce = random_array::<XNONCE_LEN>();
    let chunk_nonce_prefix = random_array::<CHUNK_NONCE_PREFIX_LEN>();

    let kdf = KdfParams {
        name: "argon2id".to_string(),
        memory_kib: kdf_profile.memory_kib,
        time_cost: kdf_profile.time_cost,
        parallelism: kdf_profile.parallelism,
        output_len: KEY_LEN,
    };
    validate_kdf_params(&kdf, KEY_LEN)?;

    let code_key = Zeroizing::new(derive_code_key(code.as_str(), &salt, &kdf)?);
    let file_key = Zeroizing::new(random_array::<KEY_LEN>());

    let wrapped_file_key = encrypt_aead(&*code_key, &wrapped_key_nonce, &*file_key, AAD_FILE_KEY)?;

    let encrypted_metadata = {
        let metadata = Metadata {
            original_file_name: original_file_name.clone(),
            original_extension,
            original_size: metadata_fs.len(),
            created_utc: Utc::now().to_rfc3339(),
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

    let result = (|| -> Result<CreateReport> {
        let output_file = create_private_new_file(&output_path)?;
        let mut reader = BufReader::new(input_file);
        let mut writer = BufWriter::new(output_file);

        write_header(&mut writer, &header)?;

        let mut buffer = Zeroizing::new(vec![0u8; chunk_size]);
        let mut counter = 0u64;

        loop {
            let n = reader.read(&mut buffer[..])?;
            if n == 0 {
                break;
            }

            let nonce = chunk_nonce(&chunk_nonce_prefix, counter);
            let aad = chunk_aad(counter);
            let ciphertext = encrypt_aead(&*file_key, &nonce, &buffer[..n], &aad)?;
            write_chunk(&mut writer, &ciphertext, chunk_size)?;
            counter = counter
                .checked_add(1)
                .ok_or_else(|| SbxError::InvalidFormat("chunk counter overflow".to_string()))?;
        }

        writer.flush()?;
        writer.get_ref().sync_all()?;
        drop(writer);
        sync_parent_dir(&output_path)?;

        Ok(CreateReport {
            input_path: input_path.clone(),
            output_path: output_path.clone(),
            original_file_name,
            original_size: metadata_fs.len(),
            visible_sbx_name,
            encrypted_chunks: counter,
        })
    })();

    if result.is_err() {
        let _ = fs::remove_file(&output_path);
    }

    result
}

fn create_private_new_file(path: &Path) -> Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);

    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }

    match options.open(path) {
        Ok(file) => Ok(file),
        Err(err) if err.kind() == ErrorKind::AlreadyExists => {
            Err(SbxError::OutputExists(path.display().to_string()))
        }
        Err(err) => Err(err.into()),
    }
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
