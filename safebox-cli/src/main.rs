use clap::{Parser, Subcommand};
use safebox_core::{create_sbx, unlock_sbx, CreateOptions, SbxError, UnlockOptions};
use std::io::{self, Write};
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(name = "safebox")]
#[command(about = "SafeBox SBX developer CLI")]
#[command(version)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Create a secure .sbx capsule from any file.
    Create {
        /// Original file to protect.
        input: PathBuf,

        /// Visible SBX name without extension. Default: document -> document.sbx.
        #[arg(long)]
        name: Option<String>,

        /// Explicit output path. Overrides --name.
        #[arg(long)]
        out: Option<PathBuf>,

        /// Do not mark the SBX for deletion after successful unlock.
        #[arg(long)]
        keep_after_unlock: bool,
    },

    /// Unlock a .sbx capsule and restore the original file.
    Unlock {
        /// SBX file to unlock.
        sbx: PathBuf,

        /// Output directory for the restored original file.
        #[arg(long)]
        out_dir: Option<PathBuf>,

        /// Keep the local .sbx after successful unlock. Useful for development tests.
        #[arg(long)]
        keep_sbx: bool,

        /// Overwrite existing restored file if present.
        #[arg(long)]
        overwrite: bool,
    },
}

fn main() {
    if let Err(err) = run() {
        eprintln!("SafeBox error [{}]: {err}", err.stable_code());
        std::process::exit(1);
    }
}

fn run() -> safebox_core::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Create {
            input,
            name,
            out,
            keep_after_unlock,
        } => {
            let code = read_secret("SafeBox code: ")?;
            let output_path = out.unwrap_or_else(|| {
                let visible_name = normalize_sbx_name(name.as_deref().unwrap_or("document"));
                PathBuf::from(visible_name)
            });

            let mut options = CreateOptions::new(input, output_path, code);
            options.burn_after_unlock = !keep_after_unlock;

            let report = create_sbx(options)?;
            println!("SafeBox created");
            println!("  input:  {}", report.input_path.display());
            println!("  output: {}", report.output_path.display());
            println!("  visible: {}", report.visible_sbx_name);
            println!("  original hidden: yes");
            println!("  chunks: {}", report.encrypted_chunks);
        }
        Commands::Unlock {
            sbx,
            out_dir,
            keep_sbx,
            overwrite,
        } => {
            let code = read_secret("SafeBox code: ")?;
            let mut options = UnlockOptions::new(sbx, code);
            options.output_dir = out_dir;
            options.burn_after_unlock = !keep_sbx;
            options.overwrite = overwrite;

            let report = unlock_sbx(options)?;
            println!("SafeBox unlocked");
            println!("  restored: {}", report.restored_path.display());
            println!("  original file: {}", report.original_file_name);
            println!("  bytes: {}", report.original_size);
            println!("  chunks: {}", report.decrypted_chunks);
            println!("  sbx deleted locally: {}", report.sbx_deleted);
            if let Some(warning) = report.burn_warning {
                eprintln!("  warning: {warning}");
            }
        }
    }

    Ok(())
}

fn read_secret(prompt: &str) -> safebox_core::Result<String> {
    #[cfg(windows)]
    {
        if let Some(secret) = read_secret_windows(prompt) {
            return validate_secret(secret);
        }

        eprint!("{prompt}");
        io::stderr().flush()?;
        let mut secret = String::new();
        io::stdin().read_line(&mut secret)?;
        return validate_secret(secret);
    }

    #[cfg(unix)]
    {
        let _guard = UnixEchoGuard::disable();
        eprint!("{prompt}");
        io::stderr().flush()?;
        let mut secret = String::new();
        io::stdin().read_line(&mut secret)?;
        eprintln!();
        return validate_secret(secret);
    }

    #[cfg(not(any(unix, windows)))]
    {
        eprint!("{prompt}");
        io::stderr().flush()?;
        let mut secret = String::new();
        io::stdin().read_line(&mut secret)?;
        validate_secret(secret)
    }
}

fn validate_secret(secret: String) -> safebox_core::Result<String> {
    let secret = secret.trim_end_matches(&['\r', '\n'][..]).to_string();
    if secret.is_empty() {
        Err(SbxError::EmptyCode)
    } else {
        Ok(secret)
    }
}

#[cfg(unix)]
struct UnixEchoGuard {
    disabled: bool,
}

#[cfg(unix)]
impl UnixEchoGuard {
    fn disable() -> Self {
        let disabled = std::process::Command::new("stty")
            .arg("-echo")
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .map(|status| status.success())
            .unwrap_or(false);
        Self { disabled }
    }
}

#[cfg(unix)]
impl Drop for UnixEchoGuard {
    fn drop(&mut self) {
        if self.disabled {
            let _ = std::process::Command::new("stty")
                .arg("echo")
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .status();
        }
    }
}

#[cfg(windows)]
fn read_secret_windows(prompt: &str) -> Option<String> {
    let escaped_prompt = prompt.replace('\'', "''");
    let script = format!(
        "$p=Read-Host -Prompt '{}' -AsSecureString; \
         $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); \
         try {{ [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }} \
         finally {{ [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }}",
        escaped_prompt
    );

    let output = std::process::Command::new("powershell.exe")
        .args(["-NoProfile", "-Command", &script])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    String::from_utf8(output.stdout).ok()
}

fn normalize_sbx_name(input: &str) -> String {
    let trimmed = input.trim().trim_end_matches(".sbx");
    let cleaned: String = trimmed
        .chars()
        .filter(|ch| {
            !ch.is_control() && !matches!(*ch, '/' | '\\' | '<' | '>' | ':' | '"' | '|' | '?' | '*')
        })
        .take(120)
        .collect();

    let base = if cleaned.trim().is_empty() {
        "document".to_string()
    } else {
        cleaned.trim().to_string()
    };

    format!("{base}.sbx")
}
