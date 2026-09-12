#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 7A — Public Sender Metadata
#
# Adds public metadata visible before unlock:
# - Sender label
# - Access profile
# - Optional public note
#
# Stored in the SBX public header.
# The true file name, true extension and content remain encrypted.
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint7a_public_sender_metadata_patch.sh

ROOT="$(pwd)"

if [ ! -d "$ROOT/safebox-desktop" ] || [ ! -d "$ROOT/safebox-core" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT"

echo "==> Backup SafeBox core and desktop files"
cp safebox-core/src/format.rs "safebox-core/src/format.rs.backup-sprint7a.$(date +%Y%m%d%H%M%S)"
cp safebox-core/src/create.rs "safebox-core/src/create.rs.backup-sprint7a.$(date +%Y%m%d%H%M%S)"
cp safebox-core/src/lib.rs "safebox-core/src/lib.rs.backup-sprint7a.$(date +%Y%m%d%H%M%S)"
cp safebox-desktop/src-tauri/src/lib.rs "safebox-desktop/src-tauri/src/lib.rs.backup-sprint7a.$(date +%Y%m%d%H%M%S)"
cp safebox-desktop/src/main.ts "safebox-desktop/src/main.ts.backup-sprint7a.$(date +%Y%m%d%H%M%S)"
cp safebox-desktop/src/style.css "safebox-desktop/src/style.css.backup-sprint7a.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

echo "==> Patch safebox-core format.rs"
python3 - <<'PY'
from pathlib import Path

p = Path("safebox-core/src/format.rs")
text = p.read_text()

# Imports: add File/BufReader/Path
text = text.replace(
    "use std::io::{Read, Write};",
    "use std::fs::File;\nuse std::io::{BufReader, Read, Write};\nuse std::path::Path;"
)

# Add PublicMetadata struct before SbxHeader
if "pub struct PublicMetadata" not in text:
    marker = "#[derive(Debug, Clone, Serialize, Deserialize)]\npub struct SbxHeader"
    public_struct = '''#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PublicMetadata {
    pub sender_label: Option<String>,
    pub access_profile: Option<String>,
    pub public_note: Option<String>,
}

'''
    if marker not in text:
        raise SystemExit("Could not find SbxHeader marker in format.rs")
    text = text.replace(marker, public_struct + marker)

# Add public field to SbxHeader
if "pub public: Option<PublicMetadata>," not in text:
    text = text.replace(
        "    pub chunk_size: usize,\n}",
        "    pub chunk_size: usize,\n    pub public: Option<PublicMetadata>,\n}"
    )

# Add reader helper after read_header
if "pub fn read_public_metadata_from_file" not in text:
    marker = "pub fn write_chunk<W: Write>(writer: &mut W, ciphertext: &[u8]) -> Result<()> {"
    helper = r'''
pub fn read_public_metadata_from_file(path: impl AsRef<Path>) -> Result<Option<PublicMetadata>> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    let header = read_header(&mut reader)?;
    Ok(header.public)
}

'''
    if marker not in text:
        raise SystemExit("Could not find write_chunk marker in format.rs")
    text = text.replace(marker, helper + marker)

p.write_text(text)
print("format.rs patched")
PY

echo "==> Patch safebox-core create.rs"
python3 - <<'PY'
from pathlib import Path

p = Path("safebox-core/src/create.rs")
text = p.read_text()

text = text.replace(
    "use crate::format::{write_chunk, write_header, KdfParams, Metadata, SbxHeader, DEFAULT_CHUNK_SIZE};",
    "use crate::format::{write_chunk, write_header, KdfParams, Metadata, PublicMetadata, SbxHeader, DEFAULT_CHUNK_SIZE};"
)

if "pub public_metadata: Option<PublicMetadata>," not in text:
    text = text.replace(
        "    pub kdf_profile: KdfProfile,\n}",
        "    pub kdf_profile: KdfProfile,\n    pub public_metadata: Option<PublicMetadata>,\n}"
    )

if "public_metadata: None," not in text:
    text = text.replace(
        "            kdf_profile: KdfProfile::default(),\n        }",
        "            kdf_profile: KdfProfile::default(),\n            public_metadata: None,\n        }"
    )

if "public: options.public_metadata.clone()," not in text:
    text = text.replace(
        "        chunk_size: options.chunk_size,\n    };",
        "        chunk_size: options.chunk_size,\n        public: options.public_metadata.clone(),\n    };"
    )

p.write_text(text)
print("create.rs patched")
PY

echo "==> Patch safebox-core lib.rs exports"
python3 - <<'PY'
from pathlib import Path

p = Path("safebox-core/src/lib.rs")
text = p.read_text()

text = text.replace(
    "pub use format::{Metadata, SbxHeader, DEFAULT_CHUNK_SIZE, VERSION};",
    "pub use format::{read_public_metadata_from_file, Metadata, PublicMetadata, SbxHeader, DEFAULT_CHUNK_SIZE, VERSION};"
)

p.write_text(text)
print("lib.rs patched")
PY

echo "==> Patch desktop Rust lib.rs"
python3 - <<'PY'
from pathlib import Path

p = Path("safebox-desktop/src-tauri/src/lib.rs")
text = p.read_text()

# Use imports
text = text.replace(
    "use safebox_core::{create_sbx, unlock_sbx, CreateOptions, UnlockOptions};",
    "use safebox_core::{create_sbx, read_public_metadata_from_file, unlock_sbx, CreateOptions, PublicMetadata, UnlockOptions};"
)

# Add PublicUiInfo struct after UnlockUiReport
if "struct PublicUiInfo" not in text:
    marker = '''struct UnlockUiReport {
    sbx_path: String,
    restored_path: String,
    original_file_name: String,
    original_size: u64,
    decrypted_chunks: u64,
    sbx_deleted: bool,
    mission: String,
}

'''
    insert = marker + r'''#[derive(Debug, Serialize)]
struct PublicUiInfo {
    visible_file_name: String,
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
}

'''
    if marker not in text:
        raise SystemExit("Could not find UnlockUiReport block in desktop lib.rs")
    text = text.replace(marker, insert)

# Add command before get_initial_sbx_path
if "fn read_sbx_public_info(" not in text:
    marker = "#[tauri::command]\nfn get_initial_sbx_path"
    command = r'''
#[tauri::command]
fn read_sbx_public_info(sbx_path: String) -> Result<PublicUiInfo, String> {
    let path = PathBuf::from(clean_path(&sbx_path));

    let visible_file_name = path
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("document.sbx")
        .to_string();

    let public = read_public_metadata_from_file(&path).map_err(|err| err.to_string())?;

    Ok(PublicUiInfo {
        visible_file_name,
        sender_label: public.as_ref().and_then(|value| clean_public_optional(value.sender_label.as_deref())),
        access_profile: public.as_ref().and_then(|value| clean_public_optional(value.access_profile.as_deref())),
        public_note: public.as_ref().and_then(|value| clean_public_optional(value.public_note.as_deref())),
    })
}

'''
    if marker not in text:
        raise SystemExit("Could not find get_initial_sbx_path marker in desktop lib.rs")
    text = text.replace(marker, command + marker)

# Patch create_sbx_file signature
old_sig = '''fn create_sbx_file(
    input_path: String,
    code: String,
    visible_name: String,
    output_dir: Option<String>,
    keep_after_unlock: bool,
) -> Result<CreateUiReport, String> {'''
new_sig = '''fn create_sbx_file(
    input_path: String,
    code: String,
    visible_name: String,
    output_dir: Option<String>,
    keep_after_unlock: bool,
    sender_label: Option<String>,
    access_profile: Option<String>,
    public_note: Option<String>,
) -> Result<CreateUiReport, String> {'''
if old_sig in text:
    text = text.replace(old_sig, new_sig)
elif "sender_label: Option<String>" not in text:
    raise SystemExit("Could not patch create_sbx_file signature")

# Set public metadata after options creation.
old = '''    let mut options = CreateOptions::new(input.clone(), output_path.clone(), code);
    options.burn_after_unlock = !keep_after_unlock;'''
new = '''    let mut options = CreateOptions::new(input.clone(), output_path.clone(), code);
    options.burn_after_unlock = !keep_after_unlock;
    options.public_metadata = build_public_metadata(sender_label, access_profile, public_note);'''
if old in text and "options.public_metadata = build_public_metadata" not in text:
    text = text.replace(old, new)

# Add helper functions after clean_path
if "fn build_public_metadata(" not in text:
    marker = '''fn clean_path(value: &str) -> String {
    let trimmed = value.trim().trim_matches('"');

    // Tauri/macOS may deliver file URLs for Finder open events.
    if let Some(rest) = trimmed.strip_prefix("file://") {
        // Simple URL cleanup for normal local file paths.
        // RunEvent::Opened path conversion is handled separately with Url::to_file_path().
        return rest.replace("%20", " ");
    }

    trimmed.to_string()
}

'''
    # We support older/later clean_path without comments too.
    if marker not in text:
        start = text.find("fn clean_path(value: &str) -> String {")
        if start == -1:
            raise SystemExit("Could not find clean_path function")
        end = text.find("\n}\n", start) + 3
        marker = text[start:end]
    helpers = marker + r'''
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

'''
    text = text.replace(marker, helpers, 1)

# Add command to generate_handler
if "read_sbx_public_info" not in text.split("tauri::generate_handler!", 1)[1]:
    text = text.replace(
        "get_initial_sbx_path,",
        "get_initial_sbx_path,\n            read_sbx_public_info,"
    )
    # in case handler has no comma version
    text = text.replace(
        "get_initial_sbx_path\n        ])",
        "get_initial_sbx_path,\n            read_sbx_public_info\n        ])"
    )

p.write_text(text)
print("desktop lib.rs patched")
PY

echo "==> Patch frontend main.ts"
python3 - <<'PY'
from pathlib import Path

p = Path("safebox-desktop/src/main.ts")
text = p.read_text()

# Add PublicInfo type
if "type PublicInfo" not in text:
    marker = '''type SbxOpenPayload = string;

'''
    insert = marker + '''type PublicInfo = {
  visible_file_name: string;
  sender_label?: string | null;
  access_profile?: string | null;
  public_note?: string | null;
};

'''
    if marker not in text:
        raise SystemExit("Could not find SbxOpenPayload marker")
    text = text.replace(marker, insert)

# Extend settings type
text = text.replace(
'''type SafeBoxSettings = {
  defaultVisibleName: string;
  useGlobalCode: boolean;
};''',
'''type SafeBoxSettings = {
  defaultVisibleName: string;
  useGlobalCode: boolean;
  globalSenderLabel: string;
  defaultAccessProfile: string;
};'''
)

# readSettings defaults
text = text.replace(
'''return { defaultVisibleName: "document", useGlobalCode: false };''',
'''return { defaultVisibleName: "document", useGlobalCode: false, globalSenderLabel: "", defaultAccessProfile: "" };'''
)
text = text.replace(
'''      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || "document"),
      useGlobalCode: Boolean(parsed.useGlobalCode ?? parsed.useSessionCode)
    };''',
'''      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || "document"),
      useGlobalCode: Boolean(parsed.useGlobalCode ?? parsed.useSessionCode),
      globalSenderLabel: cleanPublicInput((parsed as any).globalSenderLabel || ""),
      defaultAccessProfile: cleanPublicInput((parsed as any).defaultAccessProfile || "")
    };'''
)
text = text.replace(
'''return { defaultVisibleName: "document", useGlobalCode: false };''',
'''return { defaultVisibleName: "document", useGlobalCode: false, globalSenderLabel: "", defaultAccessProfile: "" };'''
)

# writeSettings
text = text.replace(
'''    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || "document"),
    useGlobalCode: Boolean(settings.useGlobalCode)
  }));''',
'''    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || "document"),
    useGlobalCode: Boolean(settings.useGlobalCode),
    globalSenderLabel: cleanPublicInput(settings.globalSenderLabel || ""),
    defaultAccessProfile: cleanPublicInput(settings.defaultAccessProfile || "")
  }));'''
)

# Add cleanPublicInput after sanitizeVisibleName
if "function cleanPublicInput(" not in text:
    marker = '''function sanitizeVisibleName(value: string): string {
  const cleaned = (value || "document")
    .trim()
    .replace(/\\.sbx$/i, "")
    .replace(/[^a-zA-Z0-9 _-]/g, "")
    .trim();

  return cleaned || "document";
}

'''
    insert = marker + r'''function cleanPublicInput(value: string): string {
  return (value || "")
    .trim()
    .replace(/[\r\n\0]/g, " ")
    .replace(/\s+/g, " ")
    .slice(0, 120);
}

function cleanPublicNote(value: string): string {
  return cleanPublicInput(value).slice(0, 180);
}

'''
    if marker not in text:
        raise SystemExit("Could not find sanitizeVisibleName block")
    text = text.replace(marker, insert)

# Add create panel fields after visible/code grid
old = '''          <div class="grid-2">
            <label>
              Visible SBX name
              <input id="visibleName" value="document" autocomplete="off" />
            </label>
            <label>
              Code
              <input id="createCode" type="password" placeholder="Enter sender code" autocomplete="new-password" />
            </label>
          </div>

          <button id="createBtn" class="primary-btn" type="button">Create SBX</button>'''
new = '''          <div class="grid-2">
            <label>
              Visible SBX name
              <input id="visibleName" value="document" autocomplete="off" />
            </label>
            <label>
              Code
              <input id="createCode" type="password" placeholder="Enter sender code" autocomplete="new-password" />
            </label>
          </div>

          <div class="grid-2">
            <label>
              Sender label
              <input id="senderLabel" placeholder="visible before unlock" autocomplete="off" />
            </label>
            <label>
              Access profile
              <input id="accessProfile" placeholder="Family / Work / Private" autocomplete="off" />
            </label>
          </div>

          <label>
            Public note optional
            <input id="publicNote" placeholder="visible before unlock, leave empty for privacy" autocomplete="off" />
          </label>

          <button id="createBtn" class="primary-btn" type="button">Create SBX</button>'''
if old in text:
    text = text.replace(old, new)
elif 'id="senderLabel"' not in text:
    raise SystemExit("Could not patch Create panel public fields")

# Add Settings fields after default name
old = '''        <label>
          Default SBX name
          <input id="settingsDefaultName" autocomplete="off" />
        </label>

        <label class="checkline settings-check">'''
new = '''        <label>
          Default SBX name
          <input id="settingsDefaultName" autocomplete="off" />
        </label>

        <label>
          Global sender label
          <input id="settingsGlobalSenderLabel" placeholder="Martina / Noureddine / Team" autocomplete="off" />
        </label>

        <label>
          Default access profile
          <input id="settingsDefaultAccessProfile" placeholder="Family / Work / Private" autocomplete="off" />
        </label>

        <label class="checkline settings-check">'''
if old in text:
    text = text.replace(old, new)
elif 'settingsGlobalSenderLabel' not in text:
    raise SystemExit("Could not patch Settings fields")

# applySettingsToUi
old = '''  if (settings.useGlobalCode) {
    const code = getGlobalCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}'''
new = '''  setInput("#senderLabel", settings.globalSenderLabel || "");
  setInput("#accessProfile", settings.defaultAccessProfile || "");

  if (settings.useGlobalCode) {
    const code = getGlobalCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}'''
if old in text:
    text = text.replace(old, new, 1)

# openSettings
text = text.replace(
'''  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  $<HTMLInputElement>("#settingsUseGlobalCode").checked = settings.useGlobalCode;''',
'''  setInput("#settingsDefaultName", settings.defaultVisibleName || "document");
  setInput("#settingsGlobalSenderLabel", settings.globalSenderLabel || "");
  setInput("#settingsDefaultAccessProfile", settings.defaultAccessProfile || "");
  $<HTMLInputElement>("#settingsUseGlobalCode").checked = settings.useGlobalCode;'''
)

# save settings nextSettings
text = text.replace(
'''    defaultVisibleName: sanitizeVisibleName(inputValue("#settingsDefaultName")),
    useGlobalCode: checked("#settingsUseGlobalCode")
  };''',
'''    defaultVisibleName: sanitizeVisibleName(inputValue("#settingsDefaultName")),
    useGlobalCode: checked("#settingsUseGlobalCode"),
    globalSenderLabel: cleanPublicInput(inputValue("#settingsGlobalSenderLabel")),
    defaultAccessProfile: cleanPublicInput(inputValue("#settingsDefaultAccessProfile"))
  };'''
)

# show result settings saved details
text = text.replace(
'''      <span>Default name</span><code>${esc(nextSettings.defaultVisibleName)}.sbx</code>
      <span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>''',
'''      <span>Default name</span><code>${esc(nextSettings.defaultVisibleName)}.sbx</code>
      <span>Sender</span><code>${esc(nextSettings.globalSenderLabel || "not set")}</code>
      <span>Access</span><code>${esc(nextSettings.defaultAccessProfile || "not set")}</code>
      <span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>'''
)

# create invoke add params
old = '''      keepAfterUnlock: checked("#keepAfterUnlock")
    });'''
new = '''      keepAfterUnlock: checked("#keepAfterUnlock"),
      senderLabel: cleanPublicInput(inputValue("#senderLabel")) || null,
      accessProfile: cleanPublicInput(inputValue("#accessProfile")) || null,
      publicNote: cleanPublicNote(inputValue("#publicNote")) || null
    });'''
if old in text and "senderLabel:" not in text[text.find(old)-300:text.find(old)+len(old)+300]:
    text = text.replace(old, new, 1)

# Add public metadata loader before showHardReceiverOverlay
if "async function loadReceiverPublicInfo" not in text:
    marker = "function showHardReceiverOverlay(sbxPath: string) {"
    helper = r'''
async function loadReceiverPublicInfo(sbxPath: string) {
  try {
    const info = await invoke<PublicInfo>("read_sbx_public_info", { sbxPath });

    const name = info.visible_file_name || fileNameFromPath(sbxPath) || "document.sbx";
    const sender = cleanPublicInput(info.sender_label || "");
    const access = cleanPublicInput(info.access_profile || "");
    const note = cleanPublicNote(info.public_note || "");

    const identity = [sender, access].filter(Boolean).join(" · ");

    const fileTargets = [
      document.querySelector<HTMLElement>("#hardReceiverFile"),
      document.querySelector<HTMLElement>("#receiverFileName"),
      document.querySelector<HTMLElement>("#fileInfoName")
    ];
    fileTargets.forEach(target => {
      if (target) target.textContent = name;
    });

    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");
    if (identityTarget) {
      identityTarget.textContent = identity;
      identityTarget.classList.toggle("hidden", !identity);
    }

    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");
    if (noteTarget) {
      noteTarget.textContent = note;
      noteTarget.classList.toggle("hidden", !note);
    }

    const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
    const infoAccess = document.querySelector<HTMLElement>("#hardInfoAccess");
    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");

    if (infoSender) {
      infoSender.textContent = sender || "not set";
    }
    if (infoAccess) {
      infoAccess.textContent = access || "not set";
    }
    if (infoNote) {
      infoNote.textContent = note || "empty";
    }
  } catch {
    // Old SBX files may not have public metadata. Keep minimal receiver view.
  }
}

'''
    if marker not in text:
        raise SystemExit("Could not find showHardReceiverOverlay marker")
    text = text.replace(marker, helper + marker)

# Modify hard receiver overlay HTML: file div id and identity/note + info rows
text = text.replace(
    '<div class="hard-receiver-file">${esc(name)}</div>',
    '<div id="hardReceiverFile" class="hard-receiver-file">${esc(name)}</div>\n\n      <div id="hardReceiverIdentity" class="hard-receiver-identity hidden"></div>\n      <div id="hardReceiverNote" class="hard-receiver-note hidden"></div>'
)

text = text.replace(
'''        <div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>''',
'''        <div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>
        <div><span>From</span><code id="hardInfoSender">not set</code></div>
        <div><span>Access</span><code id="hardInfoAccess">not set</code></div>
        <div><span>Note</span><code id="hardInfoNote">empty</code></div>'''
)

# Call loader in showHardReceiverOverlay near focus timeout
if "loadReceiverPublicInfo(sbxPath);" not in text:
    text = text.replace(
'''  setTimeout(() => {
    codeInput?.focus();
  }, 80);''',
'''  loadReceiverPublicInfo(sbxPath);

  setTimeout(() => {
    codeInput?.focus();
  }, 80);''',
1)

p.write_text(text)
print("frontend main.ts patched")
PY

echo "==> Append Sprint 7A CSS"
cat >> safebox-desktop/src/style.css <<'CSS'

/* Sprint 7A — Public sender metadata */
.hard-receiver-identity {
  margin-top: -6px;
  color: #F8FBFF;
  font-weight: 950;
  letter-spacing: -0.01em;
}

.hard-receiver-note {
  margin-top: -8px;
  color: #8EA7C2;
  font-weight: 750;
  line-height: 1.4;
  word-break: break-word;
}

.hard-receiver-info > div {
  grid-template-columns: 74px minmax(0, 1fr);
}

#publicNote {
  width: 100%;
}
CSS

echo "==> Sprint 7A patch applied."
echo ""
echo "Run:"
echo "  cd \"$ROOT/safebox-desktop\""
echo "  npm run tauri dev"
echo ""
echo "Test:"
echo "  Settings → Global sender label + Default access profile → Save"
echo "  Create SBX with optional Public note"
echo "  Drag/open SBX → receiver sees sender/access/note before code"
