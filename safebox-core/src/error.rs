use thiserror::Error;

pub type Result<T> = std::result::Result<T, SbxError>;

#[derive(Debug, Error)]
pub enum SbxError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("invalid SBX file: {0}")]
    InvalidFormat(String),

    #[error("unsupported SBX version: {0}")]
    UnsupportedVersion(u16),

    #[error("SafeBox KDF parameters rejected: {0}")]
    KdfRejected(String),

    #[error("invalid code or damaged SafeBox key envelope")]
    AccessDenied,

    #[error("SafeBox integrity check failed: {0}")]
    IntegrityFailed(String),

    #[error("crypto error")]
    Crypto,

    #[error("Argon2 error: {0}")]
    Argon2(String),

    #[error("output file already exists: {0}")]
    OutputExists(String),

    #[error("unsafe or empty file name in metadata")]
    UnsafeFileName,

    #[error("code cannot be empty")]
    EmptyCode,
}

impl SbxError {
    pub fn stable_code(&self) -> &'static str {
        match self {
            SbxError::Io(_) => "IO_ERROR",
            SbxError::Json(_) | SbxError::InvalidFormat(_) => "INVALID_FORMAT",
            SbxError::UnsupportedVersion(_) => "UNSUPPORTED_VERSION",
            SbxError::KdfRejected(_) => "KDF_REJECTED",
            SbxError::AccessDenied => "ACCESS_DENIED",
            SbxError::IntegrityFailed(_) => "INTEGRITY_FAILED",
            SbxError::Crypto => "CRYPTO_ERROR",
            SbxError::Argon2(_) => "KDF_ERROR",
            SbxError::OutputExists(_) => "OUTPUT_EXISTS",
            SbxError::UnsafeFileName => "UNSAFE_FILE_NAME",
            SbxError::EmptyCode => "EMPTY_CODE",
        }
    }
}

impl From<chacha20poly1305::aead::Error> for SbxError {
    fn from(_: chacha20poly1305::aead::Error) -> Self {
        SbxError::Crypto
    }
}

impl From<argon2::Error> for SbxError {
    fn from(value: argon2::Error) -> Self {
        SbxError::Argon2(value.to_string())
    }
}
