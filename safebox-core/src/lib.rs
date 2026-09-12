//! SafeBox Core
//!
//! Creates and unlocks `.sbx` secure file capsules.
//! The cryptographic core is local-only and independent from UI, ads and network code.

#[cfg(not(target_arch = "wasm32"))]
mod create;
mod crypto;
mod error;
mod format;
mod memory;
mod profile;
#[cfg(not(target_arch = "wasm32"))]
mod unlock;
mod validation;

#[cfg(not(target_arch = "wasm32"))]
pub use create::{create_sbx, CreateOptions, CreateReport};
pub use profile::KdfProfile;
pub use error::{Result, SbxError};
pub use format::{
    read_public_metadata, read_public_metadata_from_file, Metadata, PublicMetadata, SbxHeader,
    DEFAULT_CHUNK_SIZE, VERSION,
};
#[cfg(not(target_arch = "wasm32"))]
pub use unlock::{unlock_sbx, UnlockOptions, UnlockReport};
pub use validation::{
    MAX_CHUNK_SIZE, MAX_KDF_MEMORY_KIB, MAX_KDF_PARALLELISM, MAX_KDF_TIME_COST,
    MIN_CREATE_CHUNK_SIZE, MIN_KDF_MEMORY_KIB, MIN_KDF_PARALLELISM, MIN_KDF_TIME_COST,
};

pub use memory::{create_sbx_bytes, read_public_metadata_from_bytes, unlock_sbx_bytes, MemoryCreateOptions, MemoryCreateReport, MemoryUnlockReport, WEB_ENTROPY_LEN};
