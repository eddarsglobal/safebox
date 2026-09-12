use safebox_core::{
    create_sbx_bytes, read_public_metadata_from_bytes, unlock_sbx_bytes, KdfProfile, MemoryCreateOptions, PublicMetadata,
    SbxError, DEFAULT_CHUNK_SIZE, WEB_ENTROPY_LEN,
};
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::slice;

const ABI_VERSION: u32 = 1;
const MAX_CONFIG_JSON: usize = 16 * 1024;
const MAX_CODE_BYTES: usize = 4096;

thread_local! {
    static LAST_DATA: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
    static LAST_META: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
    static LAST_ERROR: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
}

#[derive(Debug, Deserialize)]
struct CreateConfig {
    original_file_name: String,
    visible_sbx_name: String,
    burn_after_unlock: bool,
    #[serde(default = "default_chunk_size")]
    chunk_size: usize,
    #[serde(default)]
    kdf_memory_kib: Option<u32>,
    #[serde(default)]
    kdf_time_cost: Option<u32>,
    #[serde(default)]
    kdf_parallelism: Option<u32>,
    #[serde(default)]
    sender_label: Option<String>,
    #[serde(default)]
    access_profile: Option<String>,
    #[serde(default)]
    public_note: Option<String>,
    created_utc: String,
}

#[derive(Debug, Serialize)]
struct CreateMeta<'a> {
    visible_sbx_name: &'a str,
    original_size: u64,
    encrypted_chunks: u64,
}

#[derive(Debug, Serialize)]
struct UnlockMeta<'a> {
    original_file_name: &'a str,
    original_size: u64,
    visible_sbx_name: &'a str,
    decrypted_chunks: u64,
    burn_after_unlock: bool,
    public_metadata: &'a Option<PublicMetadata>,
}


#[derive(Debug, Serialize)]
struct PublicInfoMeta<'a> {
    format: &'a str,
    public_metadata: &'a Option<PublicMetadata>,
}

#[derive(Debug, Serialize)]
struct ErrorEnvelope<'a> {
    code: &'a str,
    message: String,
}

fn default_chunk_size() -> usize {
    DEFAULT_CHUNK_SIZE
}

#[no_mangle]
pub extern "C" fn sbx_abi_version() -> u32 {
    ABI_VERSION
}

#[no_mangle]
pub extern "C" fn sbx_entropy_len() -> u32 {
    WEB_ENTROPY_LEN as u32
}

#[no_mangle]
pub extern "C" fn sbx_alloc(len: usize) -> *mut u8 {
    if len == 0 || len > isize::MAX as usize {
        return std::ptr::null_mut();
    }
    let mut boxed = vec![0u8; len].into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    ptr
}

#[no_mangle]
pub unsafe extern "C" fn sbx_dealloc(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    let raw = std::ptr::slice_from_raw_parts_mut(ptr, len);
    drop(Box::from_raw(raw));
}

#[no_mangle]
pub unsafe extern "C" fn sbx_protect(
    input_ptr: *const u8,
    input_len: usize,
    config_ptr: *const u8,
    config_len: usize,
    code_ptr: *const u8,
    code_len: usize,
    entropy_ptr: *const u8,
    entropy_len: usize,
) -> i32 {
    clear_results();
    match protect_impl(
        input_ptr, input_len, config_ptr, config_len, code_ptr, code_len, entropy_ptr, entropy_len,
    ) {
        Ok(()) => 0,
        Err(error) => {
            set_error(&error);
            error_status(&error)
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn sbx_public_info(
    sbx_ptr: *const u8,
    sbx_len: usize,
) -> i32 {
    clear_results();
    let result = (|| -> Result<(), SbxError> {
        let sbx = checked_slice(sbx_ptr, sbx_len)?;
        let (format, public_metadata) = read_public_metadata_from_bytes(sbx)?;
        let meta = serde_json::to_vec(&PublicInfoMeta {
            format: &format,
            public_metadata: &public_metadata,
        })?;
        set_success(Vec::new(), meta);
        Ok(())
    })();
    match result {
        Ok(()) => 0,
        Err(error) => {
            set_error(&error);
            error_status(&error)
        }
    }
}

#[no_mangle]
pub unsafe extern "C" fn sbx_unlock(
    sbx_ptr: *const u8,
    sbx_len: usize,
    code_ptr: *const u8,
    code_len: usize,
) -> i32 {
    clear_results();
    match unlock_impl(sbx_ptr, sbx_len, code_ptr, code_len) {
        Ok(()) => 0,
        Err(error) => {
            set_error(&error);
            error_status(&error)
        }
    }
}

#[no_mangle]
pub extern "C" fn sbx_result_data_ptr() -> *const u8 {
    LAST_DATA.with(|value| value.borrow().as_ptr())
}

#[no_mangle]
pub extern "C" fn sbx_result_data_len() -> usize {
    LAST_DATA.with(|value| value.borrow().len())
}

#[no_mangle]
pub extern "C" fn sbx_result_meta_ptr() -> *const u8 {
    LAST_META.with(|value| value.borrow().as_ptr())
}

#[no_mangle]
pub extern "C" fn sbx_result_meta_len() -> usize {
    LAST_META.with(|value| value.borrow().len())
}

#[no_mangle]
pub extern "C" fn sbx_error_ptr() -> *const u8 {
    LAST_ERROR.with(|value| value.borrow().as_ptr())
}

#[no_mangle]
pub extern "C" fn sbx_error_len() -> usize {
    LAST_ERROR.with(|value| value.borrow().len())
}

#[no_mangle]
pub extern "C" fn sbx_clear_result() {
    clear_results();
}

unsafe fn protect_impl(
    input_ptr: *const u8,
    input_len: usize,
    config_ptr: *const u8,
    config_len: usize,
    code_ptr: *const u8,
    code_len: usize,
    entropy_ptr: *const u8,
    entropy_len: usize,
) -> Result<(), SbxError> {
    if config_len == 0 || config_len > MAX_CONFIG_JSON {
        return Err(SbxError::InvalidFormat("invalid web config length".to_string()));
    }
    validate_code_len(code_len)?;
    if entropy_len != WEB_ENTROPY_LEN {
        return Err(SbxError::InvalidFormat("invalid browser entropy length".to_string()));
    }

    let input = checked_slice(input_ptr, input_len)?;
    let config_bytes = checked_slice(config_ptr, config_len)?;
    let code_bytes = checked_slice(code_ptr, code_len)?;
    let entropy_bytes = checked_slice(entropy_ptr, entropy_len)?;
    let config: CreateConfig = serde_json::from_slice(config_bytes)?;
    let code = std::str::from_utf8(code_bytes)
        .map_err(|_| SbxError::InvalidFormat("code is not valid UTF-8".to_string()))?;
    let entropy: [u8; WEB_ENTROPY_LEN] = entropy_bytes
        .try_into()
        .map_err(|_| SbxError::InvalidFormat("invalid browser entropy".to_string()))?;

    let mut options = MemoryCreateOptions::new(
        config.original_file_name,
        config.visible_sbx_name,
        code,
        config.created_utc,
        entropy,
    );
    options.burn_after_unlock = config.burn_after_unlock;
    options.chunk_size = config.chunk_size;
    let mut kdf = KdfProfile::default();
    if let Some(value) = config.kdf_memory_kib { kdf.memory_kib = value; }
    if let Some(value) = config.kdf_time_cost { kdf.time_cost = value; }
    if let Some(value) = config.kdf_parallelism { kdf.parallelism = value; }
    options.kdf_profile = kdf;
    options.public_metadata = Some(PublicMetadata {
        sender_label: config.sender_label.filter(|value| !value.is_empty()),
        access_profile: config.access_profile.filter(|value| !value.is_empty()),
        public_note: config.public_note.filter(|value| !value.is_empty()),
    });
    if options.public_metadata.as_ref().is_some_and(|public| {
        public.sender_label.is_none() && public.access_profile.is_none() && public.public_note.is_none()
    }) {
        options.public_metadata = None;
    }

    let report = create_sbx_bytes(input, options)?;
    let meta = serde_json::to_vec(&CreateMeta {
        visible_sbx_name: &report.visible_sbx_name,
        original_size: report.original_size,
        encrypted_chunks: report.encrypted_chunks,
    })?;
    set_success(report.sbx_bytes, meta);
    Ok(())
}

unsafe fn unlock_impl(
    sbx_ptr: *const u8,
    sbx_len: usize,
    code_ptr: *const u8,
    code_len: usize,
) -> Result<(), SbxError> {
    validate_code_len(code_len)?;
    let sbx = checked_slice(sbx_ptr, sbx_len)?;
    let code_bytes = checked_slice(code_ptr, code_len)?;
    let code = std::str::from_utf8(code_bytes)
        .map_err(|_| SbxError::InvalidFormat("code is not valid UTF-8".to_string()))?;
    let report = unlock_sbx_bytes(sbx, code)?;
    let meta = serde_json::to_vec(&UnlockMeta {
        original_file_name: &report.original_file_name,
        original_size: report.original_size,
        visible_sbx_name: &report.visible_sbx_name,
        decrypted_chunks: report.decrypted_chunks,
        burn_after_unlock: report.burn_after_unlock,
        public_metadata: &report.public_metadata,
    })?;
    set_success(report.restored_bytes, meta);
    Ok(())
}

unsafe fn checked_slice<'a>(ptr: *const u8, len: usize) -> Result<&'a [u8], SbxError> {
    if len == 0 {
        return Ok(&[]);
    }
    if ptr.is_null() || len > isize::MAX as usize {
        return Err(SbxError::InvalidFormat("invalid WebAssembly memory range".to_string()));
    }
    Ok(slice::from_raw_parts(ptr, len))
}

fn validate_code_len(len: usize) -> Result<(), SbxError> {
    if len == 0 {
        return Err(SbxError::EmptyCode);
    }
    if len > MAX_CODE_BYTES {
        return Err(SbxError::InvalidFormat("code exceeds browser limit".to_string()));
    }
    Ok(())
}

fn set_success(data: Vec<u8>, meta: Vec<u8>) {
    LAST_DATA.with(|value| *value.borrow_mut() = data);
    LAST_META.with(|value| *value.borrow_mut() = meta);
}

fn set_error(error: &SbxError) {
    let envelope = ErrorEnvelope {
        code: error.stable_code(),
        message: error.to_string(),
    };
    let bytes = serde_json::to_vec(&envelope)
        .unwrap_or_else(|_| b"{\"code\":\"CRYPTO_ERROR\",\"message\":\"SafeBox WebAssembly error\"}".to_vec());
    LAST_ERROR.with(|value| *value.borrow_mut() = bytes);
}

fn error_status(error: &SbxError) -> i32 {
    match error.stable_code() {
        "EMPTY_CODE" => 2,
        "ACCESS_DENIED" => 3,
        "INTEGRITY_FAILED" => 4,
        "KDF_REJECTED" => 5,
        "UNSUPPORTED_VERSION" => 6,
        "INVALID_FORMAT" | "UNSAFE_FILE_NAME" => 7,
        _ => 1,
    }
}

fn clear_results() {
    LAST_DATA.with(clear_cell);
    LAST_META.with(clear_cell);
    LAST_ERROR.with(clear_cell);
}

fn clear_cell(value: &RefCell<Vec<u8>>) {
    let mut value = value.borrow_mut();
    value.fill(0);
    value.clear();
    value.shrink_to(0);
}
