use safebox_core::{
    create_sbx, read_public_metadata, read_public_metadata_from_file, unlock_sbx, CreateOptions,
    PublicMetadata, SbxError, UnlockOptions,
};
use serde::Serialize;
use std::{
    collections::HashSet,
    fs::{self, File, OpenOptions as StdOpenOptions},
    io::{self, Read, Write},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    },
    time::{SystemTime, UNIX_EPOCH},
};
use tauri::{AppHandle, Emitter, Manager, State};
use tauri_plugin_fs::{FilePath, FsExt, OpenOptions as FsOpenOptions};

#[derive(Default)]
struct OpenFileState {
    initial_opened_paths: Mutex<Vec<String>>,
}

#[derive(Default)]
struct GeneratedFileState {
    paths: Mutex<HashSet<PathBuf>>,
}

static MOBILE_WORK_COUNTER: AtomicU64 = AtomicU64::new(0);

struct PreparedLocalInput {
    path: PathBuf,
    external_document: bool,
    cleanup_on_drop: bool,
}

impl Drop for PreparedLocalInput {
    fn drop(&mut self) {
        if self.cleanup_on_drop {
            let parent = self.path.parent().map(Path::to_path_buf);
            let _ = fs::remove_file(&self.path);
            if let Some(parent) = parent {
                let _ = fs::remove_dir(parent);
            }
        }
    }
}

struct SecurityScopedAccessGuard {
    app: AppHandle,
    path: FilePath,
}

impl SecurityScopedAccessGuard {
    fn new(app: &AppHandle, path: FilePath) -> Self {
        Self {
            app: app.clone(),
            path,
        }
    }
}

impl Drop for SecurityScopedAccessGuard {
    fn drop(&mut self) {
        #[cfg(target_os = "ios")]
        {
            let _ = self
                .app
                .fs()
                .stop_accessing_security_scoped_resource(self.path.clone());
        }
    }
}

#[derive(Debug, Serialize)]
struct CreateUiReport {
    input_path: String,
    output_path: String,
    visible_sbx_name: String,
    encrypted_chunks: u64,
    mobile_save_required: bool,
    mission: String,
}

#[derive(Debug, Serialize)]
struct UnlockUiReport {
    sbx_path: String,
    restored_path: String,
    original_file_name: String,
    original_size: u64,
    decrypted_chunks: u64,
    sbx_deleted: bool,
    burn_warning: Option<String>,
    mobile_save_required: bool,
    mission: String,
}

#[derive(Debug, Serialize)]
struct SaveUiReport {
    destination: String,
    bytes: u64,
    verified: bool,
}

#[derive(Debug, Serialize)]
struct UiCommandError {
    code: String,
    message: String,
}

impl From<SbxError> for UiCommandError {
    fn from(value: SbxError) -> Self {
        Self {
            code: value.stable_code().to_string(),
            message: value.to_string(),
        }
    }
}

fn background_task_error(error: impl std::fmt::Display) -> UiCommandError {
    UiCommandError {
        code: "BACKGROUND_TASK_FAILED".to_string(),
        message: format!("SafeBox background task failed: {error}"),
    }
}

#[derive(Debug, Serialize)]
struct PublicUiInfo {
    visible_file_name: String,
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
}

#[derive(Debug, Serialize)]
struct PlatformCapabilities {
    platform: &'static str,
    mobile: bool,
    supports_folder_picker: bool,
    supports_reveal_in_file_manager: bool,
    supports_desktop_open: bool,
    supports_mobile_save: bool,
    uses_content_uri: bool,
    uses_security_scoped_file_uri: bool,
}

#[derive(Debug, Serialize)]
struct IosAdsStatus {
    available: bool,
    test_mode: bool,
    can_request_ads: bool,
    privacy_options_required: bool,
    sdk_ready: bool,
}

#[cfg(target_os = "ios")]
#[derive(Clone, Copy)]
struct IosAdsNativeApi {
    bootstrap: unsafe extern "C" fn(),
    set_visible: unsafe extern "C" fn(u8),
    show_privacy_options: unsafe extern "C" fn(),
    can_request: unsafe extern "C" fn() -> u8,
    privacy_required: unsafe extern "C" fn() -> u8,
    sdk_ready: unsafe extern "C" fn() -> u8,
}

#[cfg(target_os = "ios")]
static IOS_ADS_NATIVE_API: std::sync::OnceLock<IosAdsNativeApi> = std::sync::OnceLock::new();

#[cfg(target_os = "ios")]
static IOS_SHARE_INBOX_PENDING: std::sync::OnceLock<Mutex<Vec<String>>> = std::sync::OnceLock::new();
#[cfg(target_os = "ios")]
static IOS_SHARE_APP_HANDLE: std::sync::OnceLock<AppHandle> = std::sync::OnceLock::new();
#[cfg(target_os = "ios")]
static IOS_SHARE_NATIVE_DRAIN: std::sync::OnceLock<unsafe extern "C" fn()> = std::sync::OnceLock::new();
#[cfg(target_os = "ios")]
static IOS_COLD_OPEN_PENDING: std::sync::OnceLock<Mutex<Vec<String>>> = std::sync::OnceLock::new();

#[cfg(target_os = "ios")]
fn ios_share_pending() -> &'static Mutex<Vec<String>> {
    IOS_SHARE_INBOX_PENDING.get_or_init(|| Mutex::new(Vec::new()))
}

#[cfg(target_os = "ios")]
#[no_mangle]
pub unsafe extern "C" fn safebox_ios_share_register(drain: unsafe extern "C" fn()) {
    let _ = IOS_SHARE_NATIVE_DRAIN.set(drain);
    eprintln!("SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_RUST_PASS");
}

#[cfg(target_os = "ios")]
fn drain_ios_share_inbox(trigger: &str) {
    let Some(drain) = IOS_SHARE_NATIVE_DRAIN.get().copied() else {
        eprintln!("SAFEBOX_IOS_SHARE_INBOX_DRAIN_API_UNAVAILABLE: trigger={trigger}");
        return;
    };
    eprintln!("SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger={trigger}");
    unsafe { drain() };
}

#[cfg(not(target_os = "ios"))]
fn drain_ios_share_inbox(_trigger: &str) {}

#[cfg(target_os = "ios")]
#[no_mangle]
pub unsafe extern "C" fn safebox_ios_share_foreground() {
    // R52: UIKit/scene activation is the authoritative foreground source for
    // Share Extension handoff. This callback stays native -> Rust, and Rust
    // still invokes the registered native drain only through the resolved API.
    eprintln!("SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_RUST_PASS");
    drain_ios_share_inbox("native-foreground");
}

#[cfg(target_os = "ios")]
#[no_mangle]
pub unsafe extern "C" fn safebox_ios_share_inbox_accept(
    path_utf8: *const std::os::raw::c_char,
) -> u8 {
    if path_utf8.is_null() {
        eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK: reason=null");
        return 0;
    }
    let Ok(raw) = std::ffi::CStr::from_ptr(path_utf8).to_str() else {
        eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK: reason=encoding");
        return 0;
    };
    let value = raw.trim();
    if value.is_empty() {
        eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK: reason=empty");
        return 0;
    }
    let route = if value.to_ascii_lowercase().ends_with(".sbx") {
        "unlock"
    } else {
        "protect"
    };
    eprintln!("SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route={route}");

    if let Some(app) = IOS_SHARE_APP_HANDLE.get() {
        emit_opened_files(app, vec![value.to_string()]);
        eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live");
        return 1;
    }
    if let Ok(mut pending) = ios_share_pending().lock() {
        if pending.iter().any(|item| item == value) {
            eprintln!("SAFEBOX_IOS_SHARE_HARDENING_DEDUP_PASS");
            eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=dedup");
            return 1;
        }
        if pending.len() >= 8 {
            eprintln!("SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=pending-capacity");
            eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK: reason=pending-capacity");
            return 0;
        }
        pending.push(value.to_string());
        eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=pending");
        return 1;
    }
    eprintln!("SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK: reason=pending-lock");
    0
}

#[cfg(target_os = "ios")]
fn take_ios_share_pending() -> Vec<String> {
    ios_share_pending()
        .lock()
        .map(|mut pending| std::mem::take(&mut *pending))
        .unwrap_or_default()
}


#[cfg(target_os = "ios")]
fn ios_cold_open_pending() -> &'static Mutex<Vec<String>> {
    IOS_COLD_OPEN_PENDING.get_or_init(|| Mutex::new(Vec::new()))
}

#[cfg(target_os = "ios")]
#[no_mangle]
pub unsafe extern "C" fn safebox_ios_cold_open_accept(path_utf8: *const std::os::raw::c_char) {
    if path_utf8.is_null() {
        eprintln!("SAFEBOX_IOS_COLD_OPEN_REJECT: reason=null");
        return;
    }
    let Ok(raw) = std::ffi::CStr::from_ptr(path_utf8).to_str() else {
        eprintln!("SAFEBOX_IOS_COLD_OPEN_REJECT: reason=encoding");
        return;
    };
    let value = raw.trim();
    if value.is_empty() || !value.to_ascii_lowercase().ends_with(".sbx") {
        eprintln!("SAFEBOX_IOS_COLD_OPEN_REJECT: reason=route");
        return;
    }

    // Route-only diagnostics. Never print the provider URL or private path.
    eprintln!("SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock");
    if let Some(app) = IOS_SHARE_APP_HANDLE.get() {
        emit_opened_files(app, vec![value.to_string()]);
        eprintln!("SAFEBOX_IOS_COLD_OPEN_DELIVERY_PASS: mode=live");
        return;
    }

    if let Ok(mut pending) = ios_cold_open_pending().lock() {
        if pending.len() < 2 && !pending.iter().any(|item| item == value) {
            pending.push(value.to_string());
        }
    }
    eprintln!("SAFEBOX_IOS_COLD_OPEN_DELIVERY_PASS: mode=pending");
}

#[cfg(target_os = "ios")]
fn take_ios_cold_open_pending() -> Vec<String> {
    ios_cold_open_pending()
        .lock()
        .map(|mut pending| std::mem::take(&mut *pending))
        .unwrap_or_default()
}

// Native iOS registers its function table into Rust at process startup.
// Direction matters: Rust does not hard-link unresolved Ads/UMP symbols, so the
// normal Tauri mobile `cargo build --lib` path can build every manifest crate
// type without asking Cargo to resolve Objective-C symbols. Xcode remains the
// only final linker for the native Ads/UMP implementation.
#[cfg(target_os = "ios")]
#[no_mangle]
pub unsafe extern "C" fn safebox_ios_ads_register(
    bootstrap: unsafe extern "C" fn(),
    set_visible: unsafe extern "C" fn(u8),
    show_privacy_options: unsafe extern "C" fn(),
    can_request: unsafe extern "C" fn() -> u8,
    privacy_required: unsafe extern "C" fn() -> u8,
    sdk_ready: unsafe extern "C" fn() -> u8,
) {
    let _ = IOS_ADS_NATIVE_API.set(IosAdsNativeApi {
        bootstrap,
        set_visible,
        show_privacy_options,
        can_request,
        privacy_required,
        sdk_ready,
    });
}

#[cfg(target_os = "ios")]
fn ios_ads_native_api() -> Option<IosAdsNativeApi> {
    IOS_ADS_NATIVE_API.get().copied()
}

#[cfg(target_os = "ios")]
fn bootstrap_ios_ads() {
    if let Some(api) = ios_ads_native_api() {
        unsafe { (api.bootstrap)() };
    }
}

#[cfg(not(target_os = "ios"))]
fn bootstrap_ios_ads() {}

#[tauri::command]
fn ios_ads_set_visible(visible: bool) -> Result<(), String> {
    #[cfg(target_os = "ios")]
    if let Some(api) = ios_ads_native_api() {
        unsafe { (api.set_visible)(u8::from(visible)) };
    }
    #[cfg(not(target_os = "ios"))]
    let _ = visible;
    Ok(())
}

#[tauri::command]
fn ios_ads_show_privacy_options() -> Result<(), String> {
    #[cfg(target_os = "ios")]
    if let Some(api) = ios_ads_native_api() {
        unsafe { (api.show_privacy_options)() };
    }
    Ok(())
}

#[tauri::command]
fn ios_ads_status() -> IosAdsStatus {
    #[cfg(target_os = "ios")]
    {
        if let Some(api) = ios_ads_native_api() {
            unsafe {
                return IosAdsStatus {
                    available: true,
                    test_mode: true,
                    can_request_ads: (api.can_request)() != 0,
                    privacy_options_required: (api.privacy_required)() != 0,
                    sdk_ready: (api.sdk_ready)() != 0,
                };
            }
        }
        return IosAdsStatus {
            available: false,
            test_mode: true,
            can_request_ads: false,
            privacy_options_required: false,
            sdk_ready: false,
        };
    }

    #[cfg(not(target_os = "ios"))]
    IosAdsStatus {
        available: false,
        test_mode: false,
        can_request_ads: false,
        privacy_options_required: false,
        sdk_ready: false,
    }
}

#[tauri::command]
fn get_platform_capabilities() -> PlatformCapabilities {
    let platform = if cfg!(target_os = "android") {
        "android"
    } else if cfg!(target_os = "ios") {
        "ios"
    } else if cfg!(target_os = "macos") {
        "macos"
    } else if cfg!(target_os = "windows") {
        "windows"
    } else if cfg!(target_os = "linux") {
        "linux"
    } else {
        "unknown"
    };

    let mobile = cfg!(any(target_os = "android", target_os = "ios"));

    PlatformCapabilities {
        platform,
        mobile,
        supports_folder_picker: !mobile,
        supports_reveal_in_file_manager: !mobile,
        supports_desktop_open: !mobile,
        supports_mobile_save: mobile,
        uses_content_uri: cfg!(target_os = "android"),
        uses_security_scoped_file_uri: cfg!(target_os = "ios"),
    }
}

#[tauri::command]
fn get_document_display_name(app: AppHandle, value: String) -> Option<String> {
    let trimmed = value.trim().trim_matches('"');
    app.path().file_name(trimmed).or_else(|| {
        local_path_from_input(trimmed)
            .ok()
            .and_then(|path| path.file_name()?.to_str().map(str::to_string))
    })
}

#[tauri::command]
fn open_original_file(path: String) -> Result<(), String> {
    let file_path = PathBuf::from(clean_path(&path));

    if !file_path.exists() {
        return Err(format!("File not found: {}", file_path.display()));
    }

    #[cfg(target_os = "macos")]
    {
        return run_system_command("open", &[file_path.display().to_string()]);
    }

    #[cfg(target_os = "windows")]
    {
        // Direct process invocation: no cmd.exe / shell interpretation of file names.
        return run_system_command("explorer.exe", &[file_path.display().to_string()]);
    }

    #[cfg(target_os = "linux")]
    {
        return run_system_command("xdg-open", &[file_path.display().to_string()]);
    }

    #[cfg(any(target_os = "ios", target_os = "android"))]
    {
        Err("Use the mobile Open/Share adapter for restored files".to_string())
    }
}

#[tauri::command]
fn reveal_in_file_manager(path: String) -> Result<(), String> {
    let file_path = PathBuf::from(clean_path(&path));

    if !file_path.exists() {
        return Err(format!("File not found: {}", file_path.display()));
    }

    #[cfg(target_os = "macos")]
    {
        return run_system_command("open", &["-R".to_string(), file_path.display().to_string()]);
    }

    #[cfg(target_os = "windows")]
    {
        return run_system_command(
            "explorer.exe",
            &[format!("/select,{}", file_path.display())],
        );
    }

    #[cfg(target_os = "linux")]
    {
        let dir = file_path
            .parent()
            .map(Path::to_path_buf)
            .unwrap_or_else(|| PathBuf::from("."));

        return run_system_command("xdg-open", &[dir.display().to_string()]);
    }

    #[cfg(any(target_os = "ios", target_os = "android"))]
    {
        Err("Reveal in file manager is a desktop-only action".to_string())
    }
}

#[cfg(any(target_os = "macos", target_os = "windows", target_os = "linux"))]
fn run_system_command(program: &str, args: &[String]) -> Result<(), String> {
    let status = std::process::Command::new(program)
        .args(args)
        .status()
        .map_err(|err| format!("Failed to run {program}: {err}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("{program} exited with status: {status}"))
    }
}

#[tauri::command]
async fn read_sbx_public_info(
    app: AppHandle,
    sbx_path: String,
) -> Result<PublicUiInfo, UiCommandError> {
    tauri::async_runtime::spawn_blocking(move || read_sbx_public_info_blocking(app, sbx_path))
        .await
        .map_err(background_task_error)?
}

fn read_sbx_public_info_blocking(
    app: AppHandle,
    sbx_path: String,
) -> Result<PublicUiInfo, UiCommandError> {
    let trimmed = sbx_path.trim().trim_matches('"');
    let display_name = app
        .path()
        .file_name(trimmed)
        .or_else(|| {
            local_path_from_input(trimmed)
                .ok()
                .and_then(|path| path.file_name()?.to_str().map(str::to_string))
        })
        .unwrap_or_else(|| "SafeBox file".to_string());

    let public = if is_mobile_external_document_uri(trimmed) {
        let url = tauri::Url::parse(trimmed).map_err(|err| UiCommandError {
            code: "INVALID_DOCUMENT_URI".to_string(),
            message: format!("Invalid mobile document URI: {err}"),
        })?;
        let mut read_options = FsOpenOptions::new();
        read_options.read(true);
        let file_path = FilePath::Url(url);
        let mut file = app
            .fs()
            .open(file_path.clone(), read_options)
            .map_err(|err| UiCommandError {
                code: "MOBILE_DOCUMENT_OPEN_FAILED".to_string(),
                message: format!("Could not open SafeBox document: {err}"),
            })?;
        let _scope_guard = SecurityScopedAccessGuard::new(&app, file_path);
        read_public_metadata(&mut file).map_err(UiCommandError::from)?
    } else {
        let path = local_path_from_input(trimmed)?;
        read_public_metadata_from_file(&path).map_err(UiCommandError::from)?
    };

    Ok(PublicUiInfo {
        visible_file_name: display_name,
        sender_label: public
            .as_ref()
            .and_then(|value| clean_public_optional(value.sender_label.as_deref())),
        access_profile: public
            .as_ref()
            .and_then(|value| clean_public_optional(value.access_profile.as_deref())),
        public_note: public
            .as_ref()
            .and_then(|value| clean_public_optional(value.public_note.as_deref())),
    })
}

#[tauri::command]
fn get_initial_sbx_path(state: State<'_, OpenFileState>) -> Option<String> {
    state.initial_opened_paths.lock().ok().and_then(|paths| {
        paths
            .iter()
            .find(|path| path.to_ascii_lowercase().ends_with(".sbx"))
            .cloned()
    })
}

#[tauri::command]
fn take_initial_opened_paths(state: State<'_, OpenFileState>) -> Vec<String> {
    state
        .initial_opened_paths
        .lock()
        .map(|mut paths| std::mem::take(&mut *paths))
        .unwrap_or_default()
}

#[tauri::command]
async fn create_sbx_file(
    app: AppHandle,
    input_path: String,
    code: String,
    visible_name: String,
    output_dir: Option<String>,
    keep_after_unlock: bool,
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
) -> Result<CreateUiReport, UiCommandError> {
    tauri::async_runtime::spawn_blocking(move || {
        create_sbx_file_blocking(
            app,
            input_path,
            code,
            visible_name,
            output_dir,
            keep_after_unlock,
            sender_label,
            access_profile,
            public_note,
        )
    })
    .await
    .map_err(background_task_error)?
}

fn create_sbx_file_blocking(
    app: AppHandle,
    input_path: String,
    code: String,
    visible_name: String,
    output_dir: Option<String>,
    keep_after_unlock: bool,
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
) -> Result<CreateUiReport, UiCommandError> {
    let prepared = prepare_local_input(&app, &input_path)?;
    let input = prepared.path.clone();
    let visible_sbx_name =
        normalize_sbx_name(&visible_name, &input).map_err(|message| UiCommandError {
            code: "INVALID_NAME".to_string(),
            message,
        })?;
    let output_path = resolve_create_output_path(&input, output_dir.as_deref(), &visible_sbx_name)
        .map_err(|message| UiCommandError {
            code: "INVALID_PATH".to_string(),
            message,
        })?;

    let mut options = CreateOptions::new(input.clone(), output_path.clone(), code);
    options.burn_after_unlock = !keep_after_unlock;
    options.public_metadata = build_public_metadata(sender_label, access_profile, public_note);

    let report = create_sbx(options).map_err(UiCommandError::from)?;
    let mobile_save_required = cfg!(any(target_os = "android", target_os = "ios"));

    if mobile_save_required {
        register_generated_file(&app, &report.output_path)?;
    }

    Ok(CreateUiReport {
        input_path,
        output_path: report.output_path.display().to_string(),
        visible_sbx_name: report.visible_sbx_name,
        encrypted_chunks: report.encrypted_chunks,
        mobile_save_required,
        mission: if prepared.external_document {
            "SBX created locally; choose Save to export it".to_string()
        } else {
            "SBX capsule ready for sending".to_string()
        },
    })
}

#[tauri::command]
async fn unlock_sbx_file(
    app: AppHandle,
    sbx_path: String,
    code: String,
    output_dir: Option<String>,
    keep_sbx: bool,
    overwrite: bool,
) -> Result<UnlockUiReport, UiCommandError> {
    tauri::async_runtime::spawn_blocking(move || {
        unlock_sbx_file_blocking(app, sbx_path, code, output_dir, keep_sbx, overwrite)
    })
    .await
    .map_err(background_task_error)?
}

fn unlock_sbx_file_blocking(
    app: AppHandle,
    sbx_path: String,
    code: String,
    output_dir: Option<String>,
    keep_sbx: bool,
    overwrite: bool,
) -> Result<UnlockUiReport, UiCommandError> {
    let prepared = prepare_local_input(&app, &sbx_path)?;
    let sbx = prepared.path.clone();
    let mut options = UnlockOptions::new(sbx.clone(), code);
    options.output_dir = match output_dir
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        Some(value) => Some(local_path_from_input(value)?),
        None => None,
    };

    let requested_source_delete = !keep_sbx;
    options.burn_after_unlock = requested_source_delete && !prepared.external_document;
    options.overwrite = overwrite;

    let report = unlock_sbx(options).map_err(UiCommandError::from)?;
    let mobile_save_required = cfg!(any(target_os = "android", target_os = "ios"));

    if mobile_save_required {
        register_generated_file(&app, &report.restored_path)?;
    }

    let mut burn_warning = report.burn_warning.clone();
    if prepared.external_document && requested_source_delete {
        append_warning(
            &mut burn_warning,
            "The external mobile document was not deleted; SafeBox only removed its private working copy.",
        );
    }

    Ok(UnlockUiReport {
        sbx_path,
        restored_path: report.restored_path.display().to_string(),
        original_file_name: report.original_file_name,
        original_size: report.original_size,
        decrypted_chunks: report.decrypted_chunks,
        sbx_deleted: report.sbx_deleted,
        burn_warning,
        mobile_save_required,
        mission: if report.sbx_deleted {
            "SBX mission completed and local capsule removed".to_string()
        } else if mobile_save_required {
            "Original restored locally; choose Save to export it".to_string()
        } else {
            "Original restored; SBX kept".to_string()
        },
    })
}

fn is_mobile_external_document_uri(value: &str) -> bool {
    let trimmed = value.trim().trim_matches('"');
    (cfg!(target_os = "android") && trimmed.starts_with("content://"))
        || (cfg!(target_os = "ios") && trimmed.starts_with("file://"))
}

fn mobile_document_error_code(suffix: &str) -> String {
    let prefix = if cfg!(target_os = "ios") {
        "IOS"
    } else {
        "ANDROID"
    };
    format!("{prefix}_{suffix}")
}

fn prepare_local_input(app: &AppHandle, value: &str) -> Result<PreparedLocalInput, UiCommandError> {
    let trimmed = value.trim().trim_matches('"');

    if is_mobile_external_document_uri(trimmed) {
        let url = tauri::Url::parse(trimmed).map_err(|err| UiCommandError {
            code: "INVALID_DOCUMENT_URI".to_string(),
            message: format!("Invalid mobile document URI: {err}"),
        })?;
        let display_name = app
            .path()
            .file_name(trimmed)
            .or_else(|| {
                url.to_file_path()
                    .ok()
                    .and_then(|path| path.file_name()?.to_str().map(str::to_string))
            })
            .and_then(|name| safe_stage_file_name(&name))
            .ok_or_else(|| UiCommandError {
                code: mobile_document_error_code("FILE_NAME_UNAVAILABLE"),
                message: "The mobile document picker did not provide a usable filename"
                    .to_string(),
            })?;

        let work_dir = create_mobile_work_dir(app)?;
        let staged_path = work_dir.join(&display_name);
        let mut read_options = FsOpenOptions::new();
        read_options.read(true);
        let file_path = FilePath::Url(url);
        let mut source = app
            .fs()
            .open(file_path.clone(), read_options)
            .map_err(|err| UiCommandError {
                code: mobile_document_error_code("DOCUMENT_OPEN_FAILED"),
                message: format!("Could not open mobile document: {err}"),
            })?;
        let _scope_guard = SecurityScopedAccessGuard::new(app, file_path);
        let mut staged = create_private_new_file(&staged_path)?;

        io::copy(&mut source, &mut staged).map_err(|err| UiCommandError {
            code: mobile_document_error_code("DOCUMENT_COPY_FAILED"),
            message: format!("Could not stage mobile document: {err}"),
        })?;
        staged.flush().map_err(io_command_error)?;
        staged.sync_all().map_err(io_command_error)?;

        return Ok(PreparedLocalInput {
            path: staged_path,
            external_document: true,
            cleanup_on_drop: true,
        });
    }

    let path = local_path_from_input(trimmed)?;
    Ok(PreparedLocalInput {
        path,
        external_document: false,
        cleanup_on_drop: false,
    })
}

fn local_path_from_input(value: &str) -> Result<PathBuf, UiCommandError> {
    let trimmed = value.trim().trim_matches('"');

    if trimmed.starts_with("content://") {
        return Err(UiCommandError {
            code: "ANDROID_DOCUMENT_URI".to_string(),
            message: "Android document URI must be handled by the SafeBox document adapter"
                .to_string(),
        });
    }

    if trimmed.starts_with("file://") {
        let url = tauri::Url::parse(trimmed).map_err(|err| UiCommandError {
            code: "INVALID_PATH".to_string(),
            message: format!("Invalid file URL: {err}"),
        })?;
        return url.to_file_path().map_err(|_| UiCommandError {
            code: "INVALID_PATH".to_string(),
            message: "File URL could not be converted to a local path".to_string(),
        });
    }

    if trimmed.contains("://") {
        return Err(UiCommandError {
            code: "UNSUPPORTED_URI".to_string(),
            message: "Unsupported document URI".to_string(),
        });
    }

    Ok(PathBuf::from(trimmed))
}

fn create_mobile_work_dir(app: &AppHandle) -> Result<PathBuf, UiCommandError> {
    let base = app
        .path()
        .app_cache_dir()
        .map_err(|err| UiCommandError {
            code: "MOBILE_WORKSPACE_FAILED".to_string(),
            message: format!("Could not resolve SafeBox mobile cache directory: {err}"),
        })?
        .join("mobile-work");

    fs::create_dir_all(&base).map_err(io_command_error)?;

    for _ in 0..64 {
        let counter = MOBILE_WORK_COUNTER.fetch_add(1, Ordering::Relaxed);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let candidate = base.join(format!("op-{nanos:x}-{counter:x}"));

        match fs::create_dir(&candidate) {
            Ok(()) => {
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ = fs::set_permissions(&candidate, fs::Permissions::from_mode(0o700));
                }
                return Ok(candidate);
            }
            Err(err) if err.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(err) => return Err(io_command_error(err)),
        }
    }

    Err(UiCommandError {
        code: "MOBILE_WORKSPACE_FAILED".to_string(),
        message: "Could not allocate a private SafeBox mobile workspace".to_string(),
    })
}

fn safe_stage_file_name(value: &str) -> Option<String> {
    let name = Path::new(value).file_name()?.to_str()?.trim();
    let cleaned: String = name
        .chars()
        .filter(|ch| {
            !ch.is_control() && !matches!(*ch, '/' | '\\' | '<' | '>' | ':' | '"' | '|' | '?' | '*')
        })
        .take(180)
        .collect();

    let cleaned = cleaned.trim().trim_end_matches(&[' ', '.'][..]).to_string();
    if cleaned.is_empty() || cleaned == "." || cleaned == ".." {
        None
    } else {
        Some(cleaned)
    }
}

fn create_private_new_file(path: &Path) -> Result<File, UiCommandError> {
    let mut options = StdOpenOptions::new();
    options.write(true).create_new(true);

    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }

    options.open(path).map_err(io_command_error)
}

fn io_command_error(err: io::Error) -> UiCommandError {
    UiCommandError {
        code: "IO_ERROR".to_string(),
        message: err.to_string(),
    }
}

fn append_warning(target: &mut Option<String>, message: &str) {
    match target {
        Some(existing) if !existing.is_empty() => {
            existing.push_str(" ");
            existing.push_str(message);
        }
        _ => *target = Some(message.to_string()),
    }
}

fn register_generated_file(app: &AppHandle, path: &Path) -> Result<(), UiCommandError> {
    let canonical = path.canonicalize().map_err(io_command_error)?;
    let state = app.state::<GeneratedFileState>();
    let mut paths = state.paths.lock().map_err(|_| UiCommandError {
        code: "GENERATED_FILE_STATE_FAILED".to_string(),
        message: "SafeBox generated-file state is unavailable".to_string(),
    })?;
    paths.insert(canonical);
    Ok(())
}

#[tauri::command]
async fn save_generated_file(
    app: AppHandle,
    source_path: String,
    destination: String,
) -> Result<SaveUiReport, UiCommandError> {
    tauri::async_runtime::spawn_blocking(move || {
        save_generated_file_blocking(app, source_path, destination)
    })
    .await
    .map_err(background_task_error)?
}

fn save_generated_file_blocking(
    app: AppHandle,
    source_path: String,
    destination: String,
) -> Result<SaveUiReport, UiCommandError> {
    let source = local_path_from_input(&source_path)?;
    let source = source.canonicalize().map_err(io_command_error)?;

    {
        let state = app.state::<GeneratedFileState>();
        let paths = state.paths.lock().map_err(|_| UiCommandError {
            code: "GENERATED_FILE_STATE_FAILED".to_string(),
            message: "SafeBox generated-file state is unavailable".to_string(),
        })?;
        if !paths.contains(&source) {
            return Err(UiCommandError {
                code: "UNTRUSTED_EXPORT_SOURCE".to_string(),
                message: "Only files generated by the current SafeBox session can be exported"
                    .to_string(),
            });
        }
    }

    let source_meta = fs::metadata(&source).map_err(io_command_error)?;
    if !source_meta.is_file() {
        return Err(UiCommandError {
            code: "INVALID_EXPORT_SOURCE".to_string(),
            message: "SafeBox export source is not a regular file".to_string(),
        });
    }

    if !is_mobile_external_document_uri(&destination) {
        if let Ok(destination_path) = local_path_from_input(&destination) {
            if destination_path.exists() {
                if let (Ok(source_canon), Ok(dest_canon)) =
                    (source.canonicalize(), destination_path.canonicalize())
                {
                    if source_canon == dest_canon {
                        return Err(UiCommandError {
                            code: "INVALID_EXPORT_DESTINATION".to_string(),
                            message: "Export destination cannot be the SafeBox working file"
                                .to_string(),
                        });
                    }
                }
            }
        }
    }

    let destination_path = external_file_path(&destination)?;
    let mut source_file = File::open(&source).map_err(io_command_error)?;
    let mut write_options = FsOpenOptions::new();
    write_options.write(true).create(true).truncate(true);
    let mut destination_file = app
        .fs()
        .open(destination_path.clone(), write_options)
        .map_err(|err| UiCommandError {
            code: "MOBILE_SAVE_FAILED".to_string(),
            message: format!("Could not open export destination: {err}"),
        })?;
    let destination_scope_guard =
        SecurityScopedAccessGuard::new(&app, destination_path.clone());

    let bytes =
        io::copy(&mut source_file, &mut destination_file).map_err(|err| UiCommandError {
            code: "MOBILE_SAVE_FAILED".to_string(),
            message: format!("Could not write exported file: {err}"),
        })?;
    destination_file.flush().map_err(|err| UiCommandError {
        code: "MOBILE_SAVE_FAILED".to_string(),
        message: format!("Could not flush exported file: {err}"),
    })?;
    let _ = destination_file.sync_all();
    drop(destination_file);
    drop(destination_scope_guard);

    verify_export_bytes(&app, &source, destination_path)?;

    Ok(SaveUiReport {
        destination,
        bytes,
        verified: true,
    })
}

fn external_file_path(value: &str) -> Result<FilePath, UiCommandError> {
    let trimmed = value.trim().trim_matches('"');

    if trimmed.contains("://") {
        let url = tauri::Url::parse(trimmed).map_err(|err| UiCommandError {
            code: "INVALID_EXPORT_DESTINATION".to_string(),
            message: format!("Invalid export destination: {err}"),
        })?;
        if !matches!(url.scheme(), "content" | "file") {
            return Err(UiCommandError {
                code: "INVALID_EXPORT_DESTINATION".to_string(),
                message: "Unsupported export destination URI".to_string(),
            });
        }
        return Ok(FilePath::Url(url));
    }

    Ok(FilePath::Path(PathBuf::from(trimmed)))
}

fn verify_export_bytes(
    app: &AppHandle,
    source: &Path,
    destination: FilePath,
) -> Result<(), UiCommandError> {
    let mut expected = File::open(source).map_err(io_command_error)?;
    let mut read_options = FsOpenOptions::new();
    read_options.read(true);
    let mut actual = app
        .fs()
        .open(destination.clone(), read_options)
        .map_err(|err| UiCommandError {
            code: "MOBILE_SAVE_VERIFY_FAILED".to_string(),
            message: format!("Could not reopen exported file for verification: {err}"),
        })?;
    let _destination_scope_guard = SecurityScopedAccessGuard::new(app, destination);

    let mut expected_buf = [0u8; 64 * 1024];
    let mut actual_buf = [0u8; 64 * 1024];

    loop {
        let expected_len = expected.read(&mut expected_buf).map_err(io_command_error)?;
        let actual_len = actual.read(&mut actual_buf).map_err(|err| UiCommandError {
            code: "MOBILE_SAVE_VERIFY_FAILED".to_string(),
            message: format!("Could not verify exported file: {err}"),
        })?;

        if expected_len != actual_len || expected_buf[..expected_len] != actual_buf[..actual_len] {
            return Err(UiCommandError {
                code: "MOBILE_SAVE_VERIFY_FAILED".to_string(),
                message: "Export verification failed; destination bytes do not match".to_string(),
            });
        }

        if expected_len == 0 {
            return Ok(());
        }
    }
}

fn clean_path(value: &str) -> String {
    let trimmed = value.trim().trim_matches('"');

    if let Some(rest) = trimmed.strip_prefix("file://") {
        return rest.replace("%20", " ");
    }

    trimmed.to_string()
}

fn clean_public_optional(value: Option<&str>) -> Option<String> {
    let cleaned = value
        .unwrap_or("")
        .trim()
        .chars()
        .filter(|ch| *ch != '\0' && *ch != '\r' && *ch != '\n')
        .collect::<String>();

    let trimmed = cleaned.trim();

    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.chars().take(120).collect())
    }
}

fn clean_public_note(value: Option<&str>) -> Option<String> {
    let cleaned = value
        .unwrap_or("")
        .trim()
        .chars()
        .filter(|ch| *ch != '\0' && *ch != '\r' && *ch != '\n')
        .collect::<String>();

    let trimmed = cleaned.trim();

    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.chars().take(180).collect())
    }
}

fn build_public_metadata(
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
) -> Option<PublicMetadata> {
    let public = PublicMetadata {
        sender_label: clean_public_optional(sender_label.as_deref()),
        access_profile: clean_public_optional(access_profile.as_deref()),
        public_note: clean_public_note(public_note.as_deref()),
    };

    if public.sender_label.is_none()
        && public.access_profile.is_none()
        && public.public_note.is_none()
    {
        None
    } else {
        Some(public)
    }
}

fn resolve_create_output_path(
    input: &Path,
    output_dir: Option<&str>,
    visible_sbx_name: &str,
) -> Result<PathBuf, String> {
    let base_dir = output_dir
        .map(clean_path)
        .filter(|v| !v.trim().is_empty())
        .map(PathBuf::from)
        .or_else(|| input.parent().map(Path::to_path_buf))
        .unwrap_or_else(|| PathBuf::from("."));

    Ok(base_dir.join(visible_sbx_name))
}

fn normalize_sbx_name(input: &str, source_path: &Path) -> Result<String, String> {
    let trimmed = input.trim().trim_end_matches(".sbx");
    let cleaned: String = trimmed
        .chars()
        .filter(|ch| {
            !ch.is_control() && !matches!(*ch, '/' | '\\' | '<' | '>' | ':' | '"' | '|' | '?' | '*')
        })
        .take(120)
        .collect();

    let requested = cleaned.trim();
    let base = if !requested.is_empty() {
        requested.to_string()
    } else {
        source_path
            .file_stem()
            .and_then(|value| value.to_str())
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .ok_or_else(|| "Could not derive a SafeBox name from the original file".to_string())?
            .chars()
            .filter(|ch| {
                !ch.is_control()
                    && !matches!(*ch, '/' | '\\' | '<' | '>' | ':' | '"' | '|' | '?' | '*')
            })
            .take(120)
            .collect::<String>()
            .trim()
            .to_string()
    };

    if base.is_empty() {
        return Err("SafeBox name cannot be empty".to_string());
    }

    Ok(format!("{base}.sbx"))
}

fn find_sbx_arg<I>(args: I, cwd: Option<&Path>) -> Option<String>
where
    I: IntoIterator<Item = String>,
{
    for raw in args {
        let cleaned = clean_path(&raw);
        if !cleaned.to_ascii_lowercase().ends_with(".sbx") {
            continue;
        }

        let path = PathBuf::from(&cleaned);
        let absolute = if path.is_absolute() {
            path
        } else if let Some(cwd) = cwd {
            cwd.join(path)
        } else {
            path
        };

        return Some(absolute.display().to_string());
    }

    None
}

fn ios_opened_path_from_url(url: &tauri::Url) -> Option<String> {
    if url.scheme() != "file" {
        return None;
    }

    // Preserve the security-scoped file URL exactly as delivered by iOS.
    // Both ordinary source documents and .sbx capsules are staged later through
    // the same private mobile-document adapter; never downgrade to a bare path here.
    Some(url.to_string())
}

fn opened_paths_from_urls(urls: &[tauri::Url]) -> Vec<String> {
    let mut opened = Vec::new();

    for url in urls.iter().take(8) {
        #[cfg(target_os = "android")]
        {
            if matches!(url.scheme(), "content" | "file") {
                opened.push(if url.scheme() == "file" {
                    url.to_file_path()
                        .map(|path| path.display().to_string())
                        .unwrap_or_else(|_| url.to_string())
                } else {
                    url.to_string()
                });
                continue;
            }
        }

        #[cfg(target_os = "ios")]
        if let Some(value) = ios_opened_path_from_url(url) {
            let route = if url.path().to_ascii_lowercase().ends_with(".sbx") {
                "unlock"
            } else {
                "protect"
            };
            // Route-only marker: never print the external filename or URL.
            eprintln!("SAFEBOX_IOS_OPEN_IN_ACCEPT: route={route}");
            opened.push(value);
            continue;
        }

        #[cfg(target_os = "macos")]
        if url.scheme() == "file" {
            if let Ok(path) = url.to_file_path() {
                let value = path.display().to_string();
                if value.to_ascii_lowercase().ends_with(".sbx") {
                    opened.push(value);
                }
            }
        }
    }

    opened.dedup();
    opened
}

#[cfg(test)]
mod ios_open_intake_tests {
    use super::ios_opened_path_from_url;

    #[test]
    fn ios_open_intake_preserves_security_scoped_file_urls_for_sbx_and_regular_files() {
        for raw in [
            "file:///private/provider/document.sbx",
            "file:///private/provider/report%20final.pdf",
            "file:///private/provider/photo.jpg",
        ] {
            let url = tauri::Url::parse(raw).expect("valid test URL");
            assert_eq!(ios_opened_path_from_url(&url).as_deref(), Some(raw));
        }
    }

    #[test]
    fn ios_open_intake_rejects_non_file_schemes() {
        for raw in [
            "https://example.invalid/file.pdf",
            "safebox://open/document.sbx",
            "content://provider/document.pdf",
        ] {
            let url = tauri::Url::parse(raw).expect("valid test URL");
            assert!(ios_opened_path_from_url(&url).is_none());
        }
    }
}

fn store_initial_opened_paths(app: &tauri::AppHandle, paths: &[String]) {
    if paths.is_empty() {
        return;
    }
    let state = app.state::<OpenFileState>();
    if let Ok(mut slot) = state.initial_opened_paths.lock() {
        slot.clear();
        slot.extend(paths.iter().cloned());
    };
}

fn store_initial_opened_paths_from_app(app: &tauri::App, paths: &[String]) {
    if paths.is_empty() {
        return;
    }
    let state = app.state::<OpenFileState>();
    if let Ok(mut slot) = state.initial_opened_paths.lock() {
        slot.clear();
        slot.extend(paths.iter().cloned());
    };
}

#[cfg(desktop)]
fn focus_main_window(app: &tauri::AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.show();
        let _ = window.unminimize();
        let _ = window.set_focus();
    }
}

#[cfg(mobile)]
fn focus_main_window(_app: &tauri::AppHandle) {
    // Android/iOS are foregrounded by the OS. Avoid desktop window mutations.
}

fn emit_opened_files(app: &tauri::AppHandle, paths: Vec<String>) {
    if paths.is_empty() {
        return;
    }
    store_initial_opened_paths(app, &paths);
    focus_main_window(app);
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.emit("safebox-open-files", paths);
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default()
        .manage(OpenFileState::default())
        .manage(GeneratedFileState::default());

    #[cfg(desktop)]
    let builder = builder.plugin(tauri_plugin_single_instance::init(|app, args, cwd| {
        let cwd_path = PathBuf::from(cwd);

        if let Some(sbx_path) = find_sbx_arg(args, Some(&cwd_path)) {
            emit_opened_files(app, vec![sbx_path]);
        } else {
            focus_main_window(app);
        }
    }));

    let app = builder
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .setup(|app| {
            let cwd = std::env::current_dir().ok();
            if let Some(sbx_path) = find_sbx_arg(std::env::args(), cwd.as_deref()) {
                store_initial_opened_paths_from_app(app, &[sbx_path]);
            }

            #[cfg(target_os = "ios")]
            {
                let _ = IOS_SHARE_APP_HANDLE.set(app.handle().clone());
                let shared = take_ios_share_pending();
                if !shared.is_empty() {
                    store_initial_opened_paths_from_app(app, &shared);
                }
                let cold_open = take_ios_cold_open_pending();
                if !cold_open.is_empty() {
                    store_initial_opened_paths_from_app(app, &cold_open);
                    eprintln!("SAFEBOX_IOS_COLD_OPEN_PENDING_DRAIN_PASS count={}", cold_open.len());
                }
                // R49: native bridge is registered before start_app(), but the
                // first drain waits until the Tauri AppHandle exists.
                drain_ios_share_inbox("setup");
            }

            // Best-effort ads/privacy surface. Crypto/file operations never depend on it.
            bootstrap_ios_ads();

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_sbx_file,
            unlock_sbx_file,
            get_initial_sbx_path,
            take_initial_opened_paths,
            read_sbx_public_info,
            open_original_file,
            reveal_in_file_manager,
            get_platform_capabilities,
            get_document_display_name,
            save_generated_file,
            ios_ads_set_visible,
            ios_ads_show_privacy_options,
            ios_ads_status
        ])
        .build(tauri::generate_context!())
        .expect("error while building SafeBox desktop app");

    app.run(|app_handle, event| {
        #[cfg(target_os = "ios")]
        if matches!(&event, tauri::RunEvent::Resumed) {
            // R52 fallback only. The validated foreground source is UIKit/scene
            // activation in SafeBoxShareInboxBridge.mm because the reference
            // simulator did not emit Tauri Resumed after Share Extension return.
            drain_ios_share_inbox("resumed");
        }

        #[cfg(any(target_os = "macos", target_os = "ios", target_os = "android"))]
        if let tauri::RunEvent::Opened { urls } = event {
            let opened = opened_paths_from_urls(&urls);
            if !opened.is_empty() {
                emit_opened_files(app_handle, opened);
            }
        }
    });
}
