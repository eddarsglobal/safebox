import { invoke } from "@tauri-apps/api/core";
import { listen, TauriEvent } from "@tauri-apps/api/event";
import { open, save } from "@tauri-apps/plugin-dialog";
import "./style.css";
import { downloadWebBytes, protectWebFile, readWebPublicInfo, unlockWebFile, WebSbxError } from "./web-sbx-engine";
import { installWebBrowserE2E } from "./web-e2e";

const SAFEBOX_TAURI_RUNTIME = typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
const SAFEBOX_LOGO_URL = `${import.meta.env.BASE_URL}safebox-logo.png`;

type CreateReport = {
  input_path: string;
  output_path: string;
  visible_sbx_name: string;
  encrypted_chunks: number;
  mobile_save_required: boolean;
  mission: string;
};

type UnlockReport = {
  sbx_path: string;
  restored_path: string;
  original_file_name: string;
  original_size: number;
  decrypted_chunks: number;
  sbx_deleted: boolean;
  burn_warning?: string | null;
  mobile_save_required: boolean;
  mission: string;
};

type SaveReport = {
  destination: string;
  bytes: number;
  verified: boolean;
};


type CommandError = {
  code?: string;
  message?: string;
};

function normalizeCommandError(error: unknown): CommandError {
  if (typeof error === "object" && error !== null) {
    const value = error as Record<string, unknown>;
    return {
      code: typeof value.code === "string" ? value.code : undefined,
      message: typeof value.message === "string" ? value.message : undefined
    };
  }
  return { message: String(error) };
}

function commandErrorText(error: unknown): string {
  const parsed = normalizeCommandError(error);
  return parsed.message || parsed.code || "Unknown SafeBox error";
}

function receiverErrorHtml(error: unknown): string {
  const parsed = normalizeCommandError(error);
  switch (parsed.code) {
    case "ACCESS_DENIED":
      return "<strong>Wrong code or damaged SafeBox.</strong>";
    case "INTEGRITY_FAILED":
      return "<strong>SafeBox damaged or modified.</strong>";
    case "UNSUPPORTED_VERSION":
      return "<strong>This SafeBox version is not supported.</strong>";
    case "KDF_REJECTED":
      return "<strong>Unsafe or unsupported SafeBox security parameters.</strong>";
    case "IO_ERROR":
      return "<strong>Could not read or restore this file.</strong>";
    default:
      return `<strong>Unlock failed.</strong><br/><code>${esc(commandErrorText(error))}</code>`;
  }
}

function burnWarningHtml(report: UnlockReport): string {
  if (!report.burn_warning) return "";
  return `<div class="burn-warning"><strong>Warning:</strong> ${esc(report.burn_warning)}</div>`;
}

type TauriDropPayload = {
  paths?: string[];
  position?: { x: number; y: number };
};

type SystemOpenPayload = string[];

type PublicInfo = {
  visible_file_name: string;
  sender_label?: string | null;
  access_profile?: string | null;
  public_note?: string | null;
};

type PlatformCapabilities = {
  platform: string;
  mobile: boolean;
  supports_folder_picker: boolean;
  supports_reveal_in_file_manager: boolean;
  supports_desktop_open: boolean;
  supports_mobile_save: boolean;
  uses_content_uri: boolean;
  uses_security_scoped_file_uri: boolean;
};


type IosAdsStatus = {
  available: boolean;
  test_mode: boolean;
  can_request_ads: boolean;
  privacy_options_required: boolean;
  sdk_ready: boolean;
};

const likelyMobileRuntime = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);

let platformCapabilities: PlatformCapabilities = SAFEBOX_TAURI_RUNTIME
  ? {
      platform: likelyMobileRuntime ? "mobile" : "unknown",
      mobile: likelyMobileRuntime,
      supports_folder_picker: !likelyMobileRuntime,
      supports_reveal_in_file_manager: !likelyMobileRuntime,
      supports_desktop_open: !likelyMobileRuntime,
      supports_mobile_save: likelyMobileRuntime,
      uses_content_uri: /Android/i.test(navigator.userAgent),
      uses_security_scoped_file_uri: /iPhone|iPad|iPod/i.test(navigator.userAgent)
    }
  : {
      platform: "web",
      mobile: false,
      supports_folder_picker: false,
      supports_reveal_in_file_manager: false,
      supports_desktop_open: false,
      supports_mobile_save: false,
      uses_content_uri: false,
      uses_security_scoped_file_uri: false
    };

const browserSelectedFiles = new Map<string, File>();
let browserSelectionSequence = 0;

function registerBrowserFile(file: File): string {
  browserSelectionSequence += 1;
  const token = `webfile://${browserSelectionSequence}/${encodeURIComponent(file.name)}`;
  browserSelectedFiles.set(token, file);
  return token;
}

function browserFileName(token: string): string {
  const file = browserSelectedFiles.get(token);
  return file?.name || fileNameFromPath(token);
}

function browserSelectedFile(token: string): File | null {
  return browserSelectedFiles.get(token) || null;
}

function webVisibleSbxName(value: string, fallbackFileName: string): string {
  const requested = sanitizeEditableVisibleName(value);
  const fallback = visibleNameFromOriginalPath(fallbackFileName);
  const base = requested || fallback;
  return `${base || "SafeBox"}.sbx`;
}

function webCommandError(error: unknown): CommandError {
  if (error instanceof WebSbxError) {
    return { code: error.code, message: error.message };
  }
  return normalizeCommandError(error);
}


function scheduleDesktopMaintenance(task: () => void, intervalMs: number) {
  if (likelyMobileRuntime) return;

  window.setInterval(() => {
    if (platformCapabilities.mobile) return;
    task();
  }, intervalMs);
}

type SafeBoxSettings = {
  defaultVisibleName: string;
  useGlobalCode: boolean;
  globalSenderLabel: string;
  defaultAccessProfile: string;
};

type AccessProfile = {
  id: string;
  profileName: string;
  senderLabel: string;
  accessLabel: string;
};

const ACCESS_PROFILES_KEY = "safebox.accessProfiles.v1";
const SIMPLE_PROFILES_MIGRATION_KEY = "safebox.simpleProfiles.v1";

const profileCodeMemory = new Map<string, string>();
let globalCodeMemory = "";


const SETTINGS_KEY = "safebox.settings.v1";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) throw new Error("#app not found");


function makeProfileId(): string {
  return `profile_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

function defaultAccessProfiles(): AccessProfile[] {
  return [];
}

function normalizeProfile(profile: Partial<AccessProfile>, fallbackIndex = 0): AccessProfile {
  const profileName = cleanPublicInput(profile.profileName || `Profile ${fallbackIndex + 1}`) || `Profile ${fallbackIndex + 1}`;
  const accessLabel = cleanPublicInput(profile.accessLabel || profileName) || profileName;

  return {
    id: cleanPublicInput(profile.id || "") || makeProfileId(),
    profileName,
    senderLabel: cleanPublicInput(profile.senderLabel || ""),
    accessLabel
  };
}

function readAccessProfiles(): AccessProfile[] {
  const demoCleanupKey = "safebox.accessProfiles.demoCleanup.10a2";

  try {
    const raw = localStorage.getItem(ACCESS_PROFILES_KEY);

    if (!raw) {
      return [];
    }

    const parsed = JSON.parse(raw);

    if (!Array.isArray(parsed)) {
      return [];
    }

    const profiles = parsed
      .map((item) => normalizeProfile(item))
      .filter((profile) => profile.profileName.trim() || profile.accessLabel.trim() || profile.senderLabel.trim());

    const demoNames = new Set(["private", "family", "work"]);

    const isOldDemoOnly =
      profiles.length > 0 &&
      profiles.length <= 3 &&
      profiles.every((profile) => {
        const profileName = profile.profileName.trim().toLowerCase();
        const accessLabel = profile.accessLabel.trim().toLowerCase();
        const senderLabel = profile.senderLabel.trim().toLowerCase();

        return (
          demoNames.has(profileName) &&
          (accessLabel === "" || demoNames.has(accessLabel) || accessLabel === "profile") &&
          (senderLabel === "" || demoNames.has(senderLabel))
        );
      });

    if (isOldDemoOnly && localStorage.getItem(demoCleanupKey) !== "1") {
      localStorage.setItem(ACCESS_PROFILES_KEY, "[]");
      localStorage.setItem(demoCleanupKey, "1");

      try {
        settings = {
          ...readSettings(),
          defaultAccessProfile: ""
        };
        writeSettings(settings);
      } catch {}

      return [];
    }

    return profiles;
  } catch {
    return [];
  }
}

function writeAccessProfiles(profiles: AccessProfile[]) {
  localStorage.setItem(
    ACCESS_PROFILES_KEY,
    JSON.stringify(profiles.map((profile, index) => normalizeProfile(profile, index)))
  );
}

function getProfileCode(profileId: string): string {
  return profileCodeMemory.get(profileId) || "";
}

function setProfileCode(profileId: string, code: string) {
  const cleaned = code.trim();
  if (cleaned) {
    profileCodeMemory.set(profileId, cleaned);
  } else {
    profileCodeMemory.delete(profileId);
  }
}

function profileOptionLabel(profile: AccessProfile): string {
  return `${profile.profileName}${profile.accessLabel && profile.accessLabel !== profile.profileName ? ` · ${profile.accessLabel}` : ""}`;
}

function readSettings(): SafeBoxSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) {
      return {
        defaultVisibleName: "",
        useGlobalCode: false,
        globalSenderLabel: "",
        defaultAccessProfile: ""
      };
    }

    const parsed = JSON.parse(raw) as Partial<SafeBoxSettings> & { useSessionCode?: boolean };

    return {
      defaultVisibleName: sanitizeVisibleName(parsed.defaultVisibleName || ""),
      useGlobalCode: Boolean(parsed.useGlobalCode ?? parsed.useSessionCode),
      globalSenderLabel: cleanPublicInput((parsed as any).globalSenderLabel || ""),
      defaultAccessProfile: cleanPublicInput((parsed as any).defaultAccessProfile || "")
    };
  } catch {
    return {
      defaultVisibleName: "",
      useGlobalCode: false,
      globalSenderLabel: "",
      defaultAccessProfile: ""
    };
  }
}

function writeSettings(settings: SafeBoxSettings) {
  localStorage.setItem(SETTINGS_KEY, JSON.stringify({
    defaultVisibleName: sanitizeVisibleName(settings.defaultVisibleName || ""),
    useGlobalCode: Boolean(settings.useGlobalCode),
    globalSenderLabel: cleanPublicInput(settings.globalSenderLabel || ""),
    defaultAccessProfile: cleanPublicInput(settings.defaultAccessProfile || "")
  }));
}

function getGlobalCode(): string {
  return globalCodeMemory;
}

function setGlobalCode(code: string) {
  globalCodeMemory = code.trim();
}

let settings = readSettings();

app.innerHTML = `
  <main class="shell">
    <section id="heroCard" class="hero-card">
      <div class="topbar">
        <div class="brand">
          <img src="${SAFEBOX_LOGO_URL}" alt="SafeBox" class="logo" />
          <div>
            <h1>SafeBox</h1>
            <p id="brandSubtitle">Universal secure file format</p>
          </div>
        </div>

        <div class="top-actions" aria-hidden="true"></div>
      </div>

      <div class="security-workspace-banner" aria-label="SafeBox secure local workspace">
        <span class="security-workspace-mark" aria-hidden="true"></span>
        <div><strong>Secure local workspace</strong><small>Files and codes stay on this device unless you explicitly save or share an output.</small></div>
        <code>LOCAL · AEAD · SBX1</code>
      </div>

      <div id="normalMode">
        <section id="createPanel" class="panel active-panel sender-panel">
          <div class="sender-head">
            <h2>Create SBX</h2>
            <p>Any file becomes a SafeBox file.</p>
            <div class="trust-strip" aria-label="SafeBox security properties">
              <span>Encrypted locally</span>
              <span>Offline-capable</span>
            </div>
          </div>

          <div id="createDrop" class="dropzone primary-drop">
            Drop any file here
          </div>

          <label>
            Original file
            <div class="field-action">
              <input id="createInput" placeholder="Select a file" autocomplete="off" />
              <button id="chooseOriginalBtn" class="mini-btn" type="button">Choose</button>
            </div>
          </label>

          <div class="grid-2">
            <label class="visible-name-field">
              Visible SBX name
              <input id="visibleName" value="" placeholder="Select a file first" autocomplete="off" />
            </label>
            <label>
              Code
              <div class="password-field">
                <input id="createCode" type="password" placeholder="Enter sender code" autocomplete="new-password" />
                <button class="password-eye-btn" type="button" data-password-target="createCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
              </div>
            </label>
          </div>

          <label>
            Access profile
            <select id="createProfileSelect"></select>
          </label>

          <div class="grid-2">
            <label>
              Sender label
              <input id="senderLabel" placeholder="visible in File info" autocomplete="off" />
            </label>
            <label>
              Access label
              <input id="accessProfile" placeholder="Family / Work / Private" autocomplete="off" />
            </label>
          </div>

          <label>
            Public note optional
            <input id="publicNote" placeholder="visible before unlock, leave empty for privacy" autocomplete="off" />
          </label>

          <button id="createBtn" class="primary-btn" type="button">Create SBX</button>

          <button id="advancedCreateToggle" class="soft-toggle" type="button">Advanced</button>

          <div id="advancedCreateBox" class="advanced-box hidden">
            <label id="createOutputDirField">
              Output directory
              <div class="field-action">
                <input id="createOutDir" placeholder="leave empty = same folder as original" autocomplete="off" />
                <button id="chooseCreateDirBtn" class="mini-btn" type="button">Folder</button>
              </div>
            </label>

            <label class="checkline">
              <input id="keepAfterUnlock" type="checkbox" checked />
              Keep SBX after unlock
            </label>
          </div>

          <button id="switchUnlockBtn" class="secondary-link" type="button">Open existing SBX</button>
        </section>

        <section id="unlockPanel" class="panel sender-panel">
          <div class="sender-head">
            <h2>Unlock SBX</h2>
            <p>Open a SafeBox file locally.</p>
            <div class="trust-strip" aria-label="SafeBox security properties">
              <span>Local decryption</span>
              <span>Offline-capable</span>
            </div>
          </div>

          <div id="unlockDrop" class="dropzone primary-drop">
            Drop a SafeBox file here
          </div>

          <label>
            SBX file
            <div class="field-action">
              <input id="unlockInput" placeholder="Select a .sbx file" autocomplete="off" />
              <button id="chooseSbxBtn" class="mini-btn" type="button">Choose</button>
            </div>
          </label>

          <label>
            Code
            <div class="password-field">
              <input id="unlockCode" type="password" placeholder="Enter receiver code" autocomplete="current-password" />
              <button class="password-eye-btn" type="button" data-password-target="unlockCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
            </div>
          </label>

          <button id="unlockBtn" class="primary-btn" type="button">Unlock</button>

          <button id="advancedUnlockToggle" class="soft-toggle" type="button">Advanced</button>

          <div id="advancedUnlockBox" class="advanced-box hidden">
            <label id="unlockOutputDirField">
              Output directory
              <div class="field-action">
                <input id="unlockOutDir" placeholder="leave empty = same folder as SBX" autocomplete="off" />
                <button id="chooseUnlockDirBtn" class="mini-btn" type="button">Folder</button>
              </div>
            </label>

            <div class="grid-2 checks">
              <label class="checkline">
                <input id="keepSbx" type="checkbox" checked />
                Keep SBX after unlock
              </label>
              <label class="checkline overwrite-checkline">
                <input id="overwrite" type="checkbox" />
                <span class="check-copy">
                  <strong>Replace existing file</strong>
                  <small>Off: keep both files. On: replace the existing file with the restored one.</small>
                </span>
              </label>
            </div>
          </div>

          <button id="switchCreateBtn" class="secondary-link" type="button">Create new SBX</button>
        </section>
      </div>

      <section id="receiverMode" class="receiver-panel">
        <div class="receiver-center">
          <div id="receiverFileName" class="receiver-file-name">SafeBox file</div>

          <label class="receiver-code-label">
            Enter code
            <div class="password-field receiver-password-field">
              <input id="receiverCode" class="receiver-code-input" type="password" autocomplete="current-password" autofocus />
              <button class="password-eye-btn" type="button" data-password-target="receiverCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
            </div>
          </label>

          <button id="receiverUnlockBtn" class="primary-btn receiver-unlock-btn" type="button">Unlock</button>

          <button id="fileInfoBtn" class="file-info-link" type="button">File info</button>

          <div id="fileInfoBox" class="file-info-box hidden">
            <div><span>Name</span><code id="fileInfoName">—</code></div>
            <div><span>Type</span><code>SafeBox File</code></div>
          </div>
        </div>
      </section>

      <section id="result" class="result hidden" aria-live="polite"></section>
    </section>

    <footer class="app-footer" aria-label="SafeBox controls">
      <button id="settingsBtn" class="footer-settings-btn" type="button" aria-label="Settings" title="Settings">
        <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path d="M12 8.7a3.3 3.3 0 1 0 0 6.6 3.3 3.3 0 0 0 0-6.6Z"/>
          <path d="M19.4 13.2c.04-.39.06-.79.06-1.2s-.02-.81-.07-1.2l2.03-1.58-1.92-3.32-2.4.97a7.7 7.7 0 0 0-2.08-1.2L14.66 3h-3.84l-.36 2.67c-.75.3-1.45.7-2.08 1.2l-2.4-.97-1.92 3.32 2.03 1.58A9.9 9.9 0 0 0 6.02 12c0 .41.02.81.07 1.2l-2.03 1.58 1.92 3.32 2.4-.97c.63.5 1.33.9 2.08 1.2l.36 2.67h3.84l.36-2.67c.75-.3 1.45-.7 2.08-1.2l2.4.97 1.92-3.32-2.02-1.58Z"/>
        </svg>
      </button>
    </footer>

    <div id="settingsModal" class="modal-backdrop hidden" role="dialog" aria-modal="true">
      <section class="settings-modal">
        <div class="modal-head">
          <div>
            <h2>Settings</h2>
            <p>Sender defaults</p>
          </div>
          <button id="closeSettingsBtn" class="icon-btn" type="button">×</button>
        </div>

        <div id="settingsFileNamingInfo" class="settings-file-naming-info">
          <strong>File naming</strong>
          <span>New SafeBox files use the original filename by default. The name can be changed before creation.</span>
        </div>

        <label class="settings-global-sender-field">
          Global sender label
          <input id="settingsGlobalSenderLabel" placeholder="Martina / Noureddine / Team" autocomplete="off" />
        </label>

        <label>
          Default access profile
          <input id="settingsDefaultAccessProfile" placeholder="Family / Work / Private" autocomplete="off" />
        </label>

        <label class="checkline settings-check">
          <input id="settingsUseGlobalCode" type="checkbox" />
          Use global code by default
        </label>

        <label id="settingsGlobalCodeBox">
          Global code
          <div class="password-action-row password-field">
            <input id="settingsGlobalCode" type="password" placeholder="Enter global code" autocomplete="new-password" />
            <button id="toggleGlobalCodeBtn" class="password-eye-btn" type="button" data-password-target="settingsGlobalCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
          </div>
        </label>

        <button id="clearGlobalCodeBtn" class="secondary-link danger-link" type="button">Clear global code</button>


        <div class="settings-section-divider"></div>

        <section class="profiles-section">
          <div class="profiles-header">
            <div>
              <h3>Access Profiles</h3>
              <p>Each profile block contains code, sender label and access label.</p>
            </div>
            <button id="addProfileBtn" class="mini-btn" type="button">+ Add profile</button>
          </div>

          <div id="settingsProfilesList" class="profiles-list"></div>

          <p class="settings-note">
            Profile codes are kept only for this app session. Profile names and labels are saved.
          </p>
        </section>

        <section id="iosPrivacySection" class="ios-privacy-section platform-hidden" aria-label="Advertising privacy">
          <div>
            <strong>Advertising privacy</strong>
            <span>Consent is handled by Google UMP. SafeBox never sends file names, codes or file contents to ads.</span>
          </div>
          <button id="iosPrivacyChoicesBtn" class="mini-btn" type="button">Privacy choices</button>
          <code id="iosAdsMode">test ads</code>
        </section>

        <div class="modal-actions">
          <button id="saveSettingsBtn" class="primary-btn" type="button">Save</button>
          <button id="cancelSettingsBtn" class="mini-btn" type="button">Cancel</button>
        </div>
      </section>
    </div>
  </main>
`;

const $ = <T extends HTMLElement>(selector: string): T => {
  const el = document.querySelector<T>(selector);
  if (!el) throw new Error(`${selector} not found`);
  return el;
};

const heroCard = $("#heroCard");
const normalMode = $("#normalMode");
const receiverModePanel = $("#receiverMode");
const createPanel = $("#createPanel");
const unlockPanel = $("#unlockPanel");
const result = $("#result");
const themeToggle = document.querySelector<HTMLElement>("#themeToggle");
const createDrop = $("#createDrop");
const unlockDrop = $("#unlockDrop");
const brandSubtitle = $("#brandSubtitle");
const settingsModal = $("#settingsModal");

function sbxPasswordEyeSvg(visible: boolean): string {
  return visible
    ? `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M3 3l18 18"/><path d="M10.6 10.7a2 2 0 0 0 2.7 2.7"/><path d="M9.9 4.3A10.8 10.8 0 0 1 12 4c5.5 0 9.5 5.1 10.5 6.6.2.3.2.7 0 1-.5.8-1.8 2.5-3.8 4"/><path d="M6.6 6.6C4 8 2.3 10.3 1.5 11.5c-.2.3-.2.7 0 1C2.5 14 6.5 19 12 19c1.3 0 2.5-.3 3.6-.7"/></svg>`
    : `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M2 12s3.7-7 10-7 10 7 10 7-3.7 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>`;
}

function sbxSyncPasswordEye(button: HTMLButtonElement, input: HTMLInputElement) {
  const visible = input.type === "text";
  const label = visible ? "Hide password" : "Show password";
  button.classList.add("password-eye-btn");
  button.innerHTML = sbxPasswordEyeSvg(visible);
  button.setAttribute("aria-label", label);
  button.setAttribute("title", label);
  button.setAttribute("aria-pressed", visible ? "true" : "false");
  button.dataset.passwordVisible = visible ? "true" : "false";
}

function sbxSyncAllPasswordEyes(root: ParentNode = document) {
  root.querySelectorAll<HTMLButtonElement>(".password-eye-btn[data-password-target]").forEach((button) => {
    const targetId = button.dataset.passwordTarget || "";
    const input = document.getElementById(targetId) as HTMLInputElement | null;
    if (input) sbxSyncPasswordEye(button, input);
  });
}

document.addEventListener("click", (event) => {
  const target = event.target as Element | null;
  const button = target?.closest<HTMLButtonElement>(".password-eye-btn[data-password-target]");
  if (!button) return;

  const targetId = button.dataset.passwordTarget || "";
  const input = document.getElementById(targetId) as HTMLInputElement | null;
  if (!input) return;

  event.preventDefault();
  const cursorStart = input.selectionStart;
  const cursorEnd = input.selectionEnd;
  input.type = input.type === "password" ? "text" : "password";
  sbxSyncPasswordEye(button, input);
  input.focus({ preventScroll: true });
  if (cursorStart !== null && cursorEnd !== null) {
    try { input.setSelectionRange(cursorStart, cursorEnd); } catch {}
  }
});

setTimeout(() => sbxSyncAllPasswordEyes(), 0);

let activeMode: "create" | "unlock" = "create";
let receiverMode = false;
let receiverSbxPath = "";

function sanitizeVisibleName(value: string): string {
  const cleaned = (value || "")
    .trim()
    .replace(/\.sbx$/i, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/[\/\\<>:\"|?*]/g, " ")
    .replace(/\s+/g, " ")
    .replace(/[. ]+$/g, "")
    .trim()
    .slice(0, 120);

  return cleaned;
}

function cleanPublicInput(value: string): string {
  return (value || "")
    .trim()
    .replace(/[\r\n\0]/g, " ")
    .replace(/\s+/g, " ")
    .slice(0, 120);
}

function cleanPublicNote(value: string): string {
  return cleanPublicInput(value).slice(0, 180);
}

function setTab(mode: "create" | "unlock") {
  activeMode = mode;
  const create = mode === "create";
  createPanel.classList.toggle("active-panel", create);
  unlockPanel.classList.toggle("active-panel", !create);
  clearResult();
}

function enterNormalMode(mode: "create" | "unlock" = "create") {
  hideHardReceiverOverlay();

  receiverMode = false;
  heroCard.classList.remove("receiver-only");

  normalMode.classList.remove("hidden");
  normalMode.style.display = "block";

  receiverModePanel.classList.remove("active-receiver-panel");
  receiverModePanel.style.display = "none";

  brandSubtitle.textContent = "Universal secure file format";
  setTab(mode);
}

function enterReceiverMode(sbxPath: string) {
  showHardReceiverOverlay(sbxPath);

  receiverMode = true;
  receiverSbxPath = sbxPath;

  heroCard.classList.add("receiver-only");

  normalMode.classList.add("hidden");
  normalMode.style.display = "none";

  receiverModePanel.classList.add("active-receiver-panel");
  receiverModePanel.style.display = "block";

  brandSubtitle.textContent = "";

  const name = fileNameFromPath(sbxPath) || "SafeBox file";
  $("#receiverFileName").textContent = name;
  $("#fileInfoName").textContent = name;
  setInput("#unlockInput", sbxPath);
  setInput("#receiverCode", "");
  $("#fileInfoBox").classList.add("hidden");

  clearResult();

  setTimeout(() => {
    $<HTMLInputElement>("#receiverCode").focus();
  }, 100);
}

function applySettingsToUi() {
  settings = readSettings();
  renderCreateProfileSelect();

  if (settings.useGlobalCode) {
    const code = getGlobalCode();
    if (code) {
      setInput("#createCode", code);
    }
  }
}

$("#switchUnlockBtn").addEventListener("click", () => enterNormalMode("unlock"));
$("#switchCreateBtn").addEventListener("click", () => enterNormalMode("create"));

type SafeBoxThemeMode = "system" | "light" | "dark";

const SAFEBOX_THEME_MODE_KEY = "safebox-theme-mode.v1";
const SAFEBOX_LEGACY_THEME_KEY = "safebox-theme";
const SAFEBOX_SYSTEM_DARK = window.matchMedia("(prefers-color-scheme: dark)");

function readThemeMode(): SafeBoxThemeMode {
  const stored = localStorage.getItem(SAFEBOX_THEME_MODE_KEY);
  if (stored === "system" || stored === "light" || stored === "dark") return stored;

  const legacy = localStorage.getItem(SAFEBOX_LEGACY_THEME_KEY);
  if (legacy === "light" || legacy === "dark") return legacy;
  return "system";
}

function resolveTheme(mode: SafeBoxThemeMode): "dark" | "light" {
  if (mode === "system") return SAFEBOX_SYSTEM_DARK.matches ? "dark" : "light";
  return mode;
}

function applyThemeMode(mode: SafeBoxThemeMode, persist = true) {
  const resolved = resolveTheme(mode);
  document.documentElement.dataset.themeMode = mode;
  document.documentElement.dataset.theme = resolved;

  if (persist) {
    localStorage.setItem(SAFEBOX_THEME_MODE_KEY, mode);
    localStorage.setItem(SAFEBOX_LEGACY_THEME_KEY, resolved);
  }

  if (themeToggle) themeToggle.textContent = resolved === "dark" ? "Light" : "Dark";

  document.querySelectorAll<HTMLButtonElement>("[data-theme-mode]").forEach((button) => {
    const active = button.dataset.themeMode === mode;
    button.classList.toggle("active", active);
    button.setAttribute("aria-pressed", active ? "true" : "false");
  });
}

applyThemeMode(readThemeMode(), false);

SAFEBOX_SYSTEM_DARK.addEventListener("change", () => {
  if (readThemeMode() === "system") applyThemeMode("system", false);
});

themeToggle?.addEventListener("click", () => {
  applyThemeMode(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
});

function showResult(kind: "ok" | "error", html: string) {
  result.classList.remove("hidden", "ok", "error");
  result.classList.add(kind);
  result.innerHTML = html;
  window.setTimeout(() => { try { sbxFullApplyAppLanguage(); } catch {} }, 0);
}

function clearResult() {
  result.classList.add("hidden");
  result.innerHTML = "";
}

function esc(value: string): string {
  return value.replace(/[&<>'"]/g, ch => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#039;",
    '"': "&quot;"
  }[ch] ?? ch));
}

function fileNameFromPath(path: string): string {
  const clean = path.replace(/\\/g, "/");
  return clean.split("/").pop() || path;
}

function inputValue(id: string): string {
  return ($<HTMLInputElement>(id).value || "").trim();
}

function checked(id: string): boolean {
  return $<HTMLInputElement>(id).checked;
}

function setInput(id: string, value: string) {
  $<HTMLInputElement>(id).value = value;
}

function selectedPath(selected: string | string[] | null): string | null {
  if (Array.isArray(selected)) return selected[0] ?? null;
  return selected;
}

async function setIosAdVisible(visible: boolean) {
  if (platformCapabilities.platform !== "ios") return;
  document.documentElement.dataset.iosAdVisible = visible ? "true" : "false";
  try {
    await invoke("ios_ads_set_visible", { visible });
  } catch (error) {
    console.warn("SafeBox iOS ad visibility unavailable", error);
  }
}

async function refreshIosAdsUi() {
  if (platformCapabilities.platform !== "ios") return;
  document.querySelector<HTMLElement>("#iosPrivacySection")?.classList.remove("platform-hidden");
  try {
    const status = await invoke<IosAdsStatus>("ios_ads_status");
    const mode = document.querySelector<HTMLElement>("#iosAdsMode");
    if (mode) {
      mode.textContent = status.test_mode
        ? (status.sdk_ready ? "test ads · ready" : "test ads · consent pending")
        : "ads";
    }
  } catch (error) {
    console.warn("SafeBox iOS ads status unavailable", error);
  }
}

async function showIosPrivacyChoices() {
  if (platformCapabilities.platform !== "ios") return;
  try {
    await invoke("ios_ads_show_privacy_options");
    window.setTimeout(() => void refreshIosAdsUi(), 300);
  } catch (error) {
    console.warn("SafeBox iOS privacy options unavailable", error);
  }
}

async function setupPlatformCapabilities() {
  if (!SAFEBOX_TAURI_RUNTIME) {
    document.documentElement.dataset.platform = "web";
    document.documentElement.dataset.mobile = "false";
    document.documentElement.dataset.runtime = "browser";
    document.querySelector<HTMLElement>("#createOutputDirField")?.classList.add("platform-hidden");
    document.querySelector<HTMLElement>("#unlockOutputDirField")?.classList.add("platform-hidden");
    return;
  }

  try {
    platformCapabilities = await invoke<PlatformCapabilities>("get_platform_capabilities");
    document.documentElement.dataset.platform = platformCapabilities.platform;
    document.documentElement.dataset.mobile = platformCapabilities.mobile ? "true" : "false";

    if (platformCapabilities.platform === "ios") {
      await refreshIosAdsUi();
      await setIosAdVisible(true);
    }

    if (!platformCapabilities.supports_folder_picker) {
      document.querySelector<HTMLElement>("#createOutputDirField")?.classList.add("platform-hidden");
      document.querySelector<HTMLElement>("#unlockOutputDirField")?.classList.add("platform-hidden");
    }
  } catch (error) {
    console.warn("SafeBox platform capabilities unavailable", error);
  }
}

type SafeBoxDocumentDialogOptions = {
  multiple: false;
  directory: false;
  pickerMode?: "document";
  fileAccessMode?: "scoped";
  filters?: Array<{ name: string; extensions: string[] }>;
};

function waitForUiTurn(ms: number): Promise<void> {
  return new Promise(resolve => window.setTimeout(resolve, ms));
}

async function openSafeBoxDocumentDialog(
  options: SafeBoxDocumentDialogOptions
): Promise<string | string[] | null> {
  const androidDialogRuntime =
    platformCapabilities.platform === "android" || /Android/i.test(navigator.userAgent);

  const firstAttempt = open(options);
  if (!androidDialogRuntime) return await firstAttempt;

  // Tauri Android can occasionally leave the first Activity callback pending without
  // launching the picker. If the WebView stayed foregrounded, a guarded second open
  // re-arms the callback path. If Android actually opened the picker, focus/visibility
  // changes prevent the recovery kick from firing.
  let leftForeground = false;
  const markBackground = () => {
    leftForeground = true;
  };
  const markVisibility = () => {
    if (document.visibilityState !== "visible") leftForeground = true;
  };

  window.addEventListener("blur", markBackground, { once: true });
  document.addEventListener("visibilitychange", markVisibility);

  await waitForUiTurn(450);

  try {
    if (!leftForeground && document.visibilityState === "visible") {
      console.warn("SAFEBOX_ANDROID_DIALOG_FIRST_CALLBACK_RECOVERY");
      const recoveryAttempt = open(options);
      return await Promise.race([firstAttempt, recoveryAttempt]);
    }

    return await firstAttempt;
  } finally {
    window.removeEventListener("blur", markBackground);
    document.removeEventListener("visibilitychange", markVisibility);
  }
}

async function chooseFile(targetInput: string, sbxOnly = false) {
  if (!SAFEBOX_TAURI_RUNTIME) {
    const picker = document.createElement("input");
    picker.type = "file";
    if (sbxOnly) picker.accept = ".sbx,application/x-safebox";
    picker.style.display = "none";
    document.body.appendChild(picker);

    const file = await new Promise<File | null>((resolve) => {
      picker.addEventListener("change", () => resolve(picker.files?.[0] || null), { once: true });
      picker.addEventListener("cancel", () => resolve(null), { once: true });
      picker.click();
    });
    picker.remove();
    if (!file) return;
    if (sbxOnly && !file.name.toLowerCase().endsWith(".sbx")) {
      showResult("error", "<strong>Select a .sbx SafeBox file.</strong>");
      return;
    }

    const token = registerBrowserFile(file);
    setInput(targetInput, token);
    if (targetInput === "#createInput") {
      syncVisibleNameFromOriginal(file.name);
      enterNormalMode("create");
    } else if (sbxOnly) {
      enterReceiverMode(token);
    }
    showResult("ok", `<strong>Browser file selected.</strong><br/><code>${esc(file.name)}</code>`);
    return;
  }

  const iosScoped = platformCapabilities.platform === "ios";
  const androidDialogRuntime =
    platformCapabilities.platform === "android" || /Android/i.test(navigator.userAgent);

  if (androidDialogRuntime) {
    showResult("ok", "<strong>Opening Android file picker…</strong>");
  }

  try {
    const selected = await openSafeBoxDocumentDialog({
      multiple: false,
      directory: false,
      pickerMode: iosScoped ? "document" : undefined,
      fileAccessMode: iosScoped ? "scoped" : undefined,
      // Android document providers do not reliably honor custom-extension filters.
      // Select any document there, then let SafeBox validate the actual SBX payload.
      filters: sbxOnly && !iosScoped && !androidDialogRuntime
        ? [{ name: "SafeBox File", extensions: ["sbx"] }]
        : undefined
    });
    const path = selectedPath(selected);
    if (!path) {
      clearResult();
      return;
    }

    let sourceName = path;
    try {
      sourceName = (await invoke<string | null>("get_document_display_name", { value: path })) || path;
    } catch {}

    if (sbxOnly && !androidDialogRuntime && !sourceName.toLowerCase().endsWith(".sbx")) {
      showResult("error", "<strong>Select a .sbx SafeBox file.</strong>");
      return;
    }

    setInput(targetInput, path);
    if (targetInput === "#createInput") {
      syncVisibleNameFromOriginal(sourceName);
      enterNormalMode("create");
      showResult("ok", `<strong>File ready.</strong><br/><code>${esc(sourceName)}</code>`);
    } else if (sbxOnly) {
      enterReceiverMode(path);
    }
  } catch (error) {
    const parsed = webCommandError(error);
    console.error("SAFEBOX_FILE_PICKER_FAILED", error);
    showResult(
      "error",
      `<strong>Could not open the file picker.</strong><br/><code>${esc(parsed.message || parsed.code || "Unknown Android file-picker error")}</code>`
    );
  }
}

async function chooseDirectory(targetInput: string) {
  if (!SAFEBOX_TAURI_RUNTIME) {
    showResult("ok", "<strong>Browser mode saves through the browser download flow.</strong>");
    return;
  }
  const selected = await open({
    multiple: false,
    directory: true
  });
  const path = selectedPath(selected);
  if (path) setInput(targetInput, path);
}

$("#chooseOriginalBtn").addEventListener("click", () => chooseFile("#createInput", false));
$("#chooseSbxBtn").addEventListener("click", () => chooseFile("#unlockInput", true));
$("#chooseCreateDirBtn").addEventListener("click", () => chooseDirectory("#createOutDir"));
$("#chooseUnlockDirBtn").addEventListener("click", () => chooseDirectory("#unlockOutDir"));

setupPlatformCapabilities();

$("#advancedCreateToggle").addEventListener("click", () => {
  $("#advancedCreateBox").classList.toggle("hidden");
});

$("#advancedUnlockToggle").addEventListener("click", () => {
  $("#advancedUnlockBox").classList.toggle("hidden");
});


function renderCreateProfileSelect() {
  const select = document.querySelector<HTMLSelectElement>("#createProfileSelect");
  if (!select) return;

  const profiles = readAccessProfiles();
  const wrapper =
    select.closest<HTMLElement>("label") ||
    select.closest<HTMLElement>(".field") ||
    select.closest<HTMLElement>(".form-row") ||
    select.closest<HTMLElement>(".input-group") ||
    select.parentElement;

  if (!profiles.length) {
    select.innerHTML = "";
    select.disabled = true;

    if (wrapper) {
      wrapper.dataset.sbxHiddenEmptyProfiles = "1";
      wrapper.classList.add("hidden", "sbx-hide-main-access-profile");
      wrapper.style.display = "none";
    }

    applySelectedProfileToCreate();
    return;
  }

  select.disabled = false;

  if (wrapper && wrapper.dataset.sbxHiddenEmptyProfiles === "1") {
    delete wrapper.dataset.sbxHiddenEmptyProfiles;
    wrapper.classList.remove("hidden", "sbx-hide-main-access-profile");
    wrapper.style.display = "";
  }

  const currentSettings = readSettings();
  const selectedId = currentSettings.defaultAccessProfile || profiles[0]?.id || "";

  select.innerHTML = profiles
    .map((profile) => {
      const label = `${profile.profileName}${profile.accessLabel ? ` · ${profile.accessLabel}` : ""}`;
      return `<option value="${esc(profile.id)}">${esc(label)}</option>`;
    })
    .join("");

  if (selectedId && profiles.some((profile) => profile.id === selectedId)) {
    select.value = selectedId;
  } else if (profiles[0]) {
    select.value = profiles[0].id;
  }

  applySelectedProfileToCreate();
}

function applySelectedProfileToCreate() {
  const select = document.querySelector<HTMLSelectElement>("#createProfileSelect");
  if (!select) return;

  const profiles = readAccessProfiles();

  if (!profiles.length) {
    setInput("#senderLabel", settings.globalSenderLabel || "");
    setInput("#accessProfile", "");

    if (settings.useGlobalCode) {
      const globalCode = getGlobalCode();
      if (globalCode) setInput("#createCode", globalCode);
    }

    return;
  }

  const selected = profiles.find((profile) => profile.id === select.value) || profiles[0];

  if (!selected) return;

  setInput("#senderLabel", selected.senderLabel || settings.globalSenderLabel || "");
  setInput("#accessProfile", selected.accessLabel || selected.profileName || "");

  const profileCode = getProfileCode(selected.id);
  if (profileCode) {
    setInput("#createCode", profileCode);
  } else if (settings.useGlobalCode) {
    const globalCode = getGlobalCode();
    if (globalCode) setInput("#createCode", globalCode);
  }
}

function renderAccessProfilesSettings() {
  const container = document.querySelector<HTMLElement>("#settingsProfilesList");
  if (!container) return;

  const profiles = readAccessProfiles();
  const currentSettings = readSettings();
  const defaultId = currentSettings.defaultAccessProfile || profiles[0]?.id || "";

  if (!profiles.length) {
    container.innerHTML = `
      <div class="profiles-empty-state compact-profiles-empty">
        <strong>No access profiles yet.</strong>
        <p>Keep SafeBox simple: add a profile only when you need separate access.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = `
    <div class="compact-profiles-list">
      ${profiles.map((profile, index) => {
        const isDefault = profile.id === defaultId || (!defaultId && index === 0);
        const accessLabel = profile.accessLabel || profile.profileName;

        return `
          <article class="compact-profile-row" data-profile-id="${esc(profile.id)}">
            <div class="compact-profile-main">
              <strong>${esc(profile.profileName)}</strong>
              <span>${esc(accessLabel)}</span>
            </div>

            <div class="compact-profile-actions">
              ${isDefault ? `<span class="compact-profile-badge">Default</span>` : `<button class="mini-btn compact-profile-set-default" type="button">Set default</button>`}
              <button class="mini-btn compact-profile-edit" type="button">Edit</button>
              <button class="mini-btn danger-link compact-profile-delete" type="button">Delete</button>
            </div>
          </article>
        `;
      }).join("")}
    </div>
  `;
}

function collectAccessProfilesFromSettings(): AccessProfile[] {
  const cards = Array.from(document.querySelectorAll<HTMLElement>(".profile-card"));

  if (!cards.length) {
    return readAccessProfiles();
  }

  return cards.map((card, index) => {
    const id = card.dataset.profileId || makeProfileId();
    const profileName = cleanPublicInput(card.querySelector<HTMLInputElement>(".profile-name-input")?.value || `Profile ${index + 1}`) || `Profile ${index + 1}`;
    const senderLabel = cleanPublicInput(card.querySelector<HTMLInputElement>(".profile-sender-input")?.value || "");
    const accessLabel = cleanPublicInput(card.querySelector<HTMLInputElement>(".profile-access-input")?.value || profileName) || profileName;
    const code = card.querySelector<HTMLInputElement>(".profile-code-input")?.value || "";

    setProfileCode(id, code);

    return { id, profileName, senderLabel, accessLabel };
  });
}

function addAccessProfileCard() {
  openAccessProfileEditor();
}


function getSettingsFieldWrapper(selector: string): HTMLElement | null {
  const element = document.querySelector<HTMLElement>(selector);
  if (!element) return null;

  return (
    element.closest<HTMLElement>("label") ||
    element.closest<HTMLElement>(".field") ||
    element.closest<HTMLElement>(".setting-row") ||
    element.parentElement
  );
}

function moveSettingsNode(node: HTMLElement | null, panel: HTMLElement) {
  if (!node || node.dataset.settingsTabsMoved === "1") return;
  node.dataset.settingsTabsMoved = "1";
  panel.appendChild(node);
}

function activateSettingsTab(tabName: string) {
  document.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tabName);
  });

  document.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.dataset.panel === tabName);
  });
}

function enhanceSettingsTabs() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const actions = modal.querySelector<HTMLElement>(".settings-actions");
  const profilesSection = modal.querySelector<HTMLElement>(".profiles-section");

  if (!actions || !profilesSection) return;

  if (!modal.querySelector("#settingsTabsRoot")) {
    const tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root";

    tabsRoot.innerHTML = `
      <div class="settings-tabs-nav" role="tablist">
        <button class="settings-tab-button active" type="button" data-tab="general">General</button>
        <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
        <button class="settings-tab-button" type="button" data-tab="security">Security</button>
      </div>

      <div class="settings-tab-panels">
        <div class="settings-tab-panel active" data-panel="general"></div>
        <div class="settings-tab-panel" data-panel="profiles"></div>
        <div class="settings-tab-panel" data-panel="security"></div>
      </div>
    `;

    actions.parentElement?.insertBefore(tabsRoot, actions);

    tabsRoot.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
      button.addEventListener("click", () => activateSettingsTab(button.dataset.tab || "general"));
    });
  }

  const generalPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  const profilesPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="profiles"]');
  const securityPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="security"]');

  if (!generalPanel || !profilesPanel || !securityPanel) return;

  moveSettingsNode(document.querySelector<HTMLElement>("#settingsFileNamingInfo"), generalPanel);
  moveSettingsNode(getSettingsFieldWrapper("#settingsGlobalSenderLabel"), generalPanel);

  const oldDefaultAccessWrapper = getSettingsFieldWrapper("#settingsDefaultAccessProfile");
  if (oldDefaultAccessWrapper) {
    oldDefaultAccessWrapper.classList.add("hidden", "legacy-default-access-field");
    oldDefaultAccessWrapper.style.display = "none";
  }

  moveSettingsNode(profilesSection, profilesPanel);

  moveSettingsNode(getSettingsFieldWrapper("#settingsUseGlobalCode"), securityPanel);
  moveSettingsNode(getSettingsFieldWrapper("#settingsGlobalCode"), securityPanel);

  const clearButton = document.querySelector<HTMLElement>("#clearGlobalCodeBtn");
  if (clearButton && clearButton.dataset.settingsTabsMoved !== "1") {
    const wrapper = clearButton.closest<HTMLElement>(".password-action-row") || clearButton.parentElement;
    if (wrapper && wrapper !== getSettingsFieldWrapper("#settingsGlobalCode")) {
      moveSettingsNode(wrapper, securityPanel);
    } else {
      clearButton.dataset.settingsTabsMoved = "1";
      securityPanel.appendChild(clearButton);
    }
  }

  modal.classList.add("settings-tabs-enabled");
  activateSettingsTab(
    modal.querySelector<HTMLElement>(".settings-tab-button.active")?.dataset.tab || "general"
  );
}

function openSettings() {
  settings = readSettings();
  setInput("#settingsGlobalSenderLabel", settings.globalSenderLabel || "");
  setInput("#settingsDefaultAccessProfile", settings.defaultAccessProfile || "");
  $<HTMLInputElement>("#settingsUseGlobalCode").checked = settings.useGlobalCode;
  setInput("#settingsGlobalCode", getGlobalCode());
  $<HTMLInputElement>("#settingsGlobalCode").type = "password";
  sbxSyncPasswordEye($("#toggleGlobalCodeBtn") as HTMLButtonElement, $<HTMLInputElement>("#settingsGlobalCode"));
  renderAccessProfilesSettings();
  enhanceSettingsTabs();
  settingsModal.classList.remove("hidden");
  settingsModal.style.display = "grid";
  void setIosAdVisible(false);
  void refreshIosAdsUi();
  setTimeout(() => $<HTMLInputElement>("#settingsGlobalSenderLabel").focus(), 80);
}

function closeSettings() {
  settingsModal.classList.add("hidden");
  settingsModal.style.display = "none";
  void setIosAdVisible(true);
}

$("#settingsBtn").addEventListener("click", openSettings);
$("#closeSettingsBtn").addEventListener("click", closeSettings);
$("#cancelSettingsBtn").addEventListener("click", closeSettings);
$("#iosPrivacyChoicesBtn").addEventListener("click", () => void showIosPrivacyChoices());

$("#addProfileBtn").addEventListener("click", addAccessProfileCard);

$("#settingsProfilesList").addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  const card = target.closest<HTMLElement>(".profile-card");
  if (!card) return;

  if (target.closest(".profile-toggle-code")) {
    const input = card.querySelector<HTMLInputElement>(".profile-code-input");
    const button = target.closest<HTMLButtonElement>(".profile-toggle-code");
    if (!input || !button) return;

    input.type = input.type === "password" ? "text" : "password";
    sbxSyncPasswordEye(button, input);
    return;
  }

  if (target.closest(".profile-set-default")) {
    const profiles = collectAccessProfilesFromSettings();
    writeAccessProfiles(profiles);

    settings = {
      ...readSettings(),
      defaultAccessProfile: card.dataset.profileId || profiles[0]?.id || ""
    };

    writeSettings(settings);
    renderAccessProfilesSettings();
    renderCreateProfileSelect();
    return;
  }

  if (target.closest(".profile-delete")) {
    const id = card.dataset.profileId || "";
    const profiles = collectAccessProfilesFromSettings().filter((profile) => profile.id !== id);

    if (!profiles.length) {
      showResult("error", "<strong>Keep at least one profile.</strong>");
      return;
    }

    setProfileCode(id, "");
    writeAccessProfiles(profiles);

    if (settings.defaultAccessProfile === id) {
      settings = {
        ...readSettings(),
        defaultAccessProfile: profiles[0].id
      };
      writeSettings(settings);
    }

    renderAccessProfilesSettings();
    renderCreateProfileSelect();
  }
});

$("#createProfileSelect").addEventListener("change", applySelectedProfileToCreate);


$("#clearGlobalCodeBtn").addEventListener("click", () => {
  setInput("#settingsGlobalCode", "");
  setGlobalCode("");
  setInput("#createCode", "");
  showResult("ok", "<strong>Global code cleared.</strong>");
});

$("#saveSettingsBtn").addEventListener("click", () => {
  const nextProfiles = collectAccessProfilesFromSettings();
  writeAccessProfiles(nextProfiles);
  const currentDefault = settings.defaultAccessProfile || nextProfiles[0]?.id || "";
  const nextSettings: SafeBoxSettings = {
    // Legacy field kept in storage for backwards compatibility; naming is now per-file.
    defaultVisibleName: "",
    useGlobalCode: checked("#settingsUseGlobalCode"),
    globalSenderLabel: cleanPublicInput(inputValue("#settingsGlobalSenderLabel")),
    defaultAccessProfile: currentDefault || nextProfiles[0]?.id || ""
  };

  writeSettings(nextSettings);

  if (nextSettings.useGlobalCode) {
    setGlobalCode(inputValue("#settingsGlobalCode"));
  } else {
    setGlobalCode("");
  }

  closeSettings();
  applySettingsToUi();

  showResult("ok", `
    <strong>Settings saved.</strong>
    <div class="result-grid compact">
      <span>Naming</span><code>original filename by default</code>
      <span>Sender</span><code>${esc(nextSettings.globalSenderLabel || "not set")}</code>
      <span>Access</span><code>${esc(nextSettings.defaultAccessProfile || "not set")}</code>
      <span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>
      <span>Profiles</span><code>${nextProfiles.length}</code>
    </div>
  `);
});

settingsModal.addEventListener("click", event => {
  if (event.target === settingsModal) closeSettings();
});

function setDropVisual(on: boolean) {
  createDrop.classList.toggle("dragging", on && activeMode === "create" && !receiverMode);
  unlockDrop.classList.toggle("dragging", on && activeMode === "unlock" && !receiverMode);
  document.body.classList.toggle("dragging-file", on);
}

function applyDroppedPath(path: string) {
  const isSbx = path.toLowerCase().endsWith(".sbx");

  if (isSbx) {
    enterReceiverMode(path);
    return;
  }

  enterNormalMode("create");
  setInput("#createInput", path);
  syncVisibleNameFromOriginal(path);
  showResult("ok", `<strong>File selected.</strong><br/><code>${esc(path)}</code>`);
}

async function setupNativeFileDrop() {
  if (!SAFEBOX_TAURI_RUNTIME) {
    const prevent = (event: DragEvent) => {
      event.preventDefault();
      setDropVisual(true);
    };
    window.addEventListener("dragenter", prevent);
    window.addEventListener("dragover", prevent);
    window.addEventListener("dragleave", (event) => {
      event.preventDefault();
      setDropVisual(false);
    });
    window.addEventListener("drop", (event) => {
      event.preventDefault();
      setDropVisual(false);
      const file = event.dataTransfer?.files?.[0];
      if (!file) return;
      const token = registerBrowserFile(file);
      if (file.name.toLowerCase().endsWith(".sbx")) {
        setInput("#unlockInput", token);
        enterReceiverMode(token);
      } else {
        enterNormalMode("create");
        setInput("#createInput", token);
        syncVisibleNameFromOriginal(file.name);
      }
      showResult("ok", `<strong>Browser file selected.</strong><br/><code>${esc(file.name)}</code>`);
    });
    return;
  }

  await listen<TauriDropPayload>(TauriEvent.DRAG_ENTER, () => {
    setDropVisual(true);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_OVER, () => {
    setDropVisual(true);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_LEAVE, () => {
    setDropVisual(false);
  });

  await listen<TauriDropPayload>(TauriEvent.DRAG_DROP, event => {
    setDropVisual(false);
    const path = event.payload.paths?.[0];

    if (!path) {
      showResult("error", "<strong>Drop failed.</strong><br/>Use the Choose button.");
      return;
    }

    applyDroppedPath(path);
  });
}

setupNativeFileDrop().catch(error => {
  showResult("error", `<strong>Drag/drop init failed.</strong><br/><code>${esc(commandErrorText(error))}</code>`);
});

async function handleSystemOpenedPath(path: string) {
  const cleaned = (path || "").trim();
  if (!cleaned) return;

  let displayName = cleaned;
  try {
    displayName = (await invoke<string | null>("get_document_display_name", { value: cleaned })) || cleaned;
  } catch {}

  const isSbx = displayName.toLowerCase().endsWith(".sbx") || cleaned.toLowerCase().endsWith(".sbx");
  if (isSbx) {
    enterReceiverMode(cleaned);
    return;
  }

  enterNormalMode("create");
  setInput("#createInput", cleaned);
  syncVisibleNameFromOriginal(displayName);
  showResult("ok", `<strong>Shared file ready.</strong><br/><code>${esc(displayName)}</code>`);
}

async function handleSystemOpenedPaths(paths: string[]) {
  const opened = (paths || []).filter(Boolean);
  if (!opened.length) return;
  await handleSystemOpenedPath(opened[0]);
  if (opened.length > 1) {
    showResult("ok", `<strong>First shared file loaded.</strong><br/>SafeBox processes one file at a time. ${opened.length - 1} additional file(s) were not opened.`);
  }
}

async function setupSystemOpenHandler() {
  if (!SAFEBOX_TAURI_RUNTIME) return;
  await listen<SystemOpenPayload>("safebox-open-files", event => {
    void handleSystemOpenedPaths(event.payload);
  });
  const initial = await invoke<string[]>("take_initial_opened_paths");
  await handleSystemOpenedPaths(initial);
}

setupSystemOpenHandler().catch(error => {
  showResult("error", `<strong>System open handler failed.</strong><br/><code>${esc(commandErrorText(error))}</code>`);
});

$("#fileInfoBtn").addEventListener("click", () => {
  $("#fileInfoBox").classList.toggle("hidden");
});

$("#receiverCode").addEventListener("keydown", event => {
  if (event.key === "Enter") {
    $("#receiverUnlockBtn").click();
  }
});


function mobileSaveActionHtml(path: string, suggestedName: string, label: string): string {
  if (!platformCapabilities.supports_mobile_save) return "";

  return `
    <div class="mobile-save-actions"
         data-generated-path="${esc(path)}"
         data-suggested-name="${esc(suggestedName)}">
      <button type="button" data-mobile-save="true">${esc(label)}</button>
      <span class="mobile-save-status" aria-live="polite"></span>
    </div>
  `;
}

function restoredActionsHtml(path: string, originalFileName = ""): string {
  const openButton = platformCapabilities.supports_desktop_open
    ? '<button type="button" data-restore-action="open">Open original</button>'
    : "";
  const revealButton = platformCapabilities.supports_reveal_in_file_manager
    ? `<button type="button" data-restore-action="show">${platformCapabilities.platform === "macos" ? "Show in Finder" : "Show in folder"}</button>`
    : "";

  const desktopActions = openButton || revealButton
    ? `
      <div class="restore-actions" data-restored-path="${esc(path)}">
        ${openButton}
        ${revealButton}
      </div>
    `
    : "";

  return desktopActions + mobileSaveActionHtml(
    path,
    originalFileName || fileNameFromPath(path),
    "Save original"
  );
}

async function openOriginalPath(path: string) {
  if (!path) return;

  try {
    await invoke("open_original_file", { path });
  } catch (error) {
    showResult("error", `<strong>Open failed.</strong><br/><code>${esc(commandErrorText(error))}</code>`);
  }
}

async function revealOriginalPath(path: string) {
  if (!path) return;

  try {
    await invoke("reveal_in_file_manager", { path });
  } catch (error) {
    showResult("error", `<strong>Show in Finder failed.</strong><br/><code>${esc(commandErrorText(error))}</code>`);
  }
}

type SafeBoxSaveDialogFilter = { name: string; extensions: string[] };

const SAFEBOX_ANDROID_MIME_BY_EXTENSION: Record<string, string> = {
  sbx: "application/x-safebox",
  png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp",
  gif: "image/gif", bmp: "image/bmp", svg: "image/svg+xml", heic: "image/heic",
  avif: "image/avif", tif: "image/tiff", tiff: "image/tiff",
  pdf: "application/pdf", txt: "text/plain", csv: "text/csv", html: "text/html",
  json: "application/json", xml: "application/xml", zip: "application/zip",
  mp3: "audio/mpeg", wav: "audio/wav", flac: "audio/flac", ogg: "audio/ogg",
  mp4: "video/mp4", webm: "video/webm", mov: "video/quicktime"
};

function fileExtensionForSave(name: string): string {
  const clean = (name || "").trim().replace(/\s+\(\d+\)$/u, "");
  const match = clean.match(/\.([A-Za-z0-9]{1,16})$/u);
  return match ? match[1].toLowerCase() : "";
}

function saveDialogFiltersForName(name: string): SafeBoxSaveDialogFilter[] | undefined {
  const ext = fileExtensionForSave(name);
  if (!ext) return undefined;

  if (platformCapabilities.platform === "android" || /Android/i.test(navigator.userAgent)) {
    const mime = SAFEBOX_ANDROID_MIME_BY_EXTENSION[ext] || "application/octet-stream";
    return [{ name: ext === "sbx" ? "SafeBox File" : `${ext.toUpperCase()} file`, extensions: [mime] }];
  }

  return [{ name: ext === "sbx" ? "SafeBox File" : `${ext.toUpperCase()} file`, extensions: [ext] }];
}

function androidCollisionSafeSuggestedName(name: string): string {
  const android = platformCapabilities.platform === "android" || /Android/i.test(navigator.userAgent);
  if (!android) return name;

  const ext = fileExtensionForSave(name);
  if (!ext || ext === "sbx") return name;

  const suffix = `.${ext}`;
  const base = name.slice(0, -suffix.length).replace(/\s+\(\d+\)$/u, "");
  if (/-restored$/iu.test(base)) return `${base}${suffix}`;
  return `${base}-restored${suffix}`;
}

async function saveGeneratedMobileFile(
  sourcePath: string,
  suggestedName: string,
  status?: HTMLElement | null
) {
  if (!sourcePath) return;

  try {
    const cleanSuggestedName = (suggestedName || fileNameFromPath(sourcePath)).trim();
    const destinationName = androidCollisionSafeSuggestedName(cleanSuggestedName);
    const destination = await save({
      defaultPath: destinationName,
      filters: saveDialogFiltersForName(destinationName)
    });
    if (!destination) return;

    if (status) status.textContent = "Saving…";
    const report = await invoke<SaveReport>("save_generated_file", {
      sourcePath,
      destination
    });

    if (status) {
      status.textContent = report.verified
        ? `Saved and verified (${report.bytes.toLocaleString()} bytes)`
        : "Saved";
    }
  } catch (error) {
    if (status) status.textContent = `Save failed: ${commandErrorText(error)}`;
  }
}

document.addEventListener("click", event => {
  const target = event.target as HTMLElement | null;

  const restoreButton = target?.closest<HTMLButtonElement>("[data-restore-action]");
  if (restoreButton) {
    const wrapper = restoreButton.closest<HTMLElement>(".restore-actions");
    const path = wrapper?.dataset.restoredPath || "";
    const action = restoreButton.dataset.restoreAction;

    if (action === "open") {
      openOriginalPath(path);
    } else if (action === "show") {
      revealOriginalPath(path);
    }
    return;
  }

  const saveButton = target?.closest<HTMLButtonElement>("[data-mobile-save]");
  if (!saveButton) return;

  const wrapper = saveButton.closest<HTMLElement>(".mobile-save-actions");
  const path = wrapper?.dataset.generatedPath || "";
  const suggestedName = wrapper?.dataset.suggestedName || fileNameFromPath(path);
  const status = wrapper?.querySelector<HTMLElement>(".mobile-save-status");
  saveGeneratedMobileFile(path, suggestedName, status);
});



async function loadReceiverPublicInfo(sbxPath: string) {
  if (!SAFEBOX_TAURI_RUNTIME) {
    const file = browserSelectedFile(sbxPath);
    const name = file?.name || browserFileName(sbxPath) || "SafeBox file";
    [
      document.querySelector<HTMLElement>("#hardReceiverFile"),
      document.querySelector<HTMLElement>("#receiverFileName"),
      document.querySelector<HTMLElement>("#fileInfoName")
    ].forEach((target) => { if (target) target.textContent = name; });
    if (!file) return;

    try {
      const info = await readWebPublicInfo(file);
      const publicInfo = info.public_metadata || {};
      const sender = cleanPublicInput(publicInfo.sender_label || "");
      const access = cleanPublicInput(publicInfo.access_profile || "");
      const note = cleanPublicNote(publicInfo.public_note || "");
      const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
      const infoAccess = document.querySelector<HTMLElement>("#hardInfoAccess");
      const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");
      const noteRow = document.querySelector<HTMLElement>("#hardInfoNoteRow") || infoNote?.closest<HTMLElement>("div");
      if (infoSender) infoSender.textContent = sender || "not set";
      if (infoAccess) infoAccess.textContent = access || "not set";
      if (infoNote) infoNote.textContent = note;
      if (noteRow) {
        noteRow.classList.toggle("hidden", !note);
        noteRow.style.display = note ? "" : "none";
      }
    } catch (error) {
      console.warn("SafeBox Web public metadata not available:", error);
    }
    return;
  }

  try {
    const info = await invoke<PublicInfo>("read_sbx_public_info", { sbxPath });

    const name = info.visible_file_name || fileNameFromPath(sbxPath) || "SafeBox file";
    const sender = cleanPublicInput(info.sender_label || "");
    const access = cleanPublicInput(info.access_profile || "");
    const note = cleanPublicNote(info.public_note || "");

    [
      document.querySelector<HTMLElement>("#hardReceiverFile"),
      document.querySelector<HTMLElement>("#receiverFileName"),
      document.querySelector<HTMLElement>("#fileInfoName")
    ].forEach((target) => {
      if (target) target.textContent = name;
    });

    // Main receiver screen stays minimal.
    // Sender / access / note are ONLY shown inside File info.
    const identityTarget = document.querySelector<HTMLElement>("#hardReceiverIdentity");
    if (identityTarget) {
      identityTarget.textContent = "";
      identityTarget.classList.add("hidden");
      identityTarget.style.display = "none";
    }

    const noteTarget = document.querySelector<HTMLElement>("#hardReceiverNote");
    if (noteTarget) {
      noteTarget.textContent = "";
      noteTarget.classList.add("hidden");
      noteTarget.style.display = "none";
    }

    const infoSender = document.querySelector<HTMLElement>("#hardInfoSender");
    const infoAccess = document.querySelector<HTMLElement>("#hardInfoAccess");
    const infoNote = document.querySelector<HTMLElement>("#hardInfoNote");
    const noteRow =
      document.querySelector<HTMLElement>("#hardInfoNoteRow") ||
      infoNote?.closest<HTMLElement>("div");

    if (infoSender) infoSender.textContent = sender || "not set";
    if (infoAccess) infoAccess.textContent = access || "not set";

    if (infoNote) {
      infoNote.textContent = note;
    }

    if (noteRow) {
      noteRow.classList.toggle("hidden", !note);
      noteRow.style.display = note ? "" : "none";
    }
  } catch (error) {
    console.warn("SafeBox public metadata not available:", error);
  }
}


function showHardReceiverOverlay(sbxPath: string) {
  receiverMode = true;
  receiverSbxPath = sbxPath;

  document.body.dataset.safeboxMode = "receiver";

  let overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "hardReceiverOverlay";
    overlay.className = "hard-receiver-overlay";
    document.body.appendChild(overlay);
  }

  const name = fileNameFromPath(sbxPath) || "SafeBox file";

  overlay.innerHTML = `
    <div class="hard-receiver-card">
      <div class="hard-receiver-brand">
        <img src="${SAFEBOX_LOGO_URL}" alt="SafeBox" />
        <h1>SafeBox</h1>
      </div>

      <div id="hardReceiverFile" class="hard-receiver-file">${esc(name)}</div>

      <label class="hard-receiver-label">
        Enter code
        <div class="password-field hard-receiver-password-field">
          <input id="hardReceiverCode" type="password" autocomplete="current-password" />
          <button class="password-eye-btn" type="button" data-password-target="hardReceiverCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
        </div>
      </label>

      <button id="hardReceiverUnlock" type="button">Unlock</button>

      <button id="hardReceiverInfoBtn" type="button" class="hard-receiver-info-btn">File info</button>

      <div id="hardReceiverInfo" class="hard-receiver-info hidden">
        <div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>
        <div id="hardInfoSenderRow"><span>From</span><code id="hardInfoSender">not set</code></div>
        <div id="hardInfoAccessRow"><span>Access</span><code id="hardInfoAccess">not set</code></div>
        <div id="hardInfoNoteRow" class="hidden"><span>Note</span><code id="hardInfoNote"></code></div>
      </div>

      <div id="hardReceiverResult" class="hard-receiver-result hidden"></div>
    </div>
  `;

  overlay.style.display = "grid";
  sbxSyncAllPasswordEyes(overlay);

  const codeInput = overlay.querySelector<HTMLInputElement>("#hardReceiverCode");
  const unlockBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverUnlock");
  const infoBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverInfoBtn");
  const infoBox = overlay.querySelector<HTMLDivElement>("#hardReceiverInfo");
  const overlayResult = overlay.querySelector<HTMLDivElement>("#hardReceiverResult");

  const showOverlayResult = (kind: "ok" | "error", html: string) => {
    if (!overlayResult) return;
    overlayResult.className = `hard-receiver-result ${kind}`;
    overlayResult.innerHTML = html;
  };

  const doUnlock = async () => {
    const code = (codeInput?.value || "").trim();

    if (!code) {
      showOverlayResult("error", "<strong>Wrong code</strong>");
      codeInput?.focus();
      return;
    }

    try {
      if (!SAFEBOX_TAURI_RUNTIME) {
        const file = browserSelectedFile(sbxPath);
        if (!file) throw new WebSbxError("IO_ERROR", "Browser SafeBox selection expired");
        const report = await unlockWebFile(file, code);
        downloadWebBytes(report.bytes, report.original_file_name);
        report.bytes.fill(0);
        showOverlayResult("ok", `
          <div class="boom-title">BOOOOM</div>
          <strong>Original restored.</strong><br/>
          <span>Downloaded by your browser.</span>
          <div class="result-grid compact">
            <span>Original</span><code>${esc(report.original_file_name)}</code>
            <span>Size</span><code>${report.original_size} bytes</code>
          </div>
        `);
      } else {
        const report = await invoke<UnlockReport>("unlock_sbx_file", {
          sbxPath,
          code,
          outputDir: null,
          keepSbx: true,
          overwrite: false
        });

        showOverlayResult("ok", `
          <div class="boom-title">BOOOOM</div>
          <strong>Original restored.</strong><br/>
          <span>SBX completed.</span>
          <div class="result-grid compact">
            <span>Original</span><code>${esc(report.original_file_name)}</code>
            <span>Saved</span><code>${esc(report.restored_path)}</code>
          </div>
          ${burnWarningHtml(report)}
          ${restoredActionsHtml(report.restored_path, report.original_file_name)}
        `);
      }
    } catch (error) {
      showOverlayResult("error", receiverErrorHtml(webCommandError(error)));
      codeInput?.select();
      codeInput?.focus();
    }
  };

  unlockBtn?.addEventListener("click", doUnlock);
  codeInput?.addEventListener("keydown", event => {
    if (event.key === "Enter") doUnlock();
  });

  infoBtn?.addEventListener("click", () => {
    infoBox?.classList.toggle("hidden");
  });

  loadReceiverPublicInfo(sbxPath);
  enforceReceiverMinimalUi();

  setTimeout(() => {
    codeInput?.focus();
  }, 80);
}

function hideHardReceiverOverlay() {
  delete document.body.dataset.safeboxMode;
  const overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (overlay) {
    overlay.style.display = "none";
  }
}

$("#createBtn").addEventListener("click", async () => {
  clearResult();
  const inputPath = inputValue("#createInput");
  const code = inputValue("#createCode");
  const visibleName = sanitizeEditableVisibleName(inputValue("#visibleName"));
  const outputDir = inputValue("#createOutDir");

  if (!inputPath || !code) {
    showResult("error", "<strong>Missing information.</strong><br/>File and code are required.");
    return;
  }

  try {
    if (!SAFEBOX_TAURI_RUNTIME) {
      const file = browserSelectedFile(inputPath);
      if (!file) throw new WebSbxError("IO_ERROR", "Browser file selection expired");
      const safeName = webVisibleSbxName(visibleName, file.name);
      const report = await protectWebFile(file, code, {
        visibleSbxName: safeName,
        keepAfterUnlock: checked("#keepAfterUnlock"),
        senderLabel: cleanPublicInput(inputValue("#senderLabel")) || null,
        accessProfile: cleanPublicInput(inputValue("#accessProfile")) || null,
        publicNote: cleanPublicNote(inputValue("#publicNote")) || null
      });
      downloadWebBytes(report.bytes, report.visible_sbx_name, "application/x-safebox");
      report.bytes.fill(0);
      showResult("ok", `
        <strong>SafeBox created in your browser.</strong>
        <div class="result-grid">
          <span>Download</span><code>${esc(report.visible_sbx_name)}</code>
          <span>Original hidden</span><code>yes</code>
          <span>Engine</span><code>Rust/WASM · canonical SBX1</code>
        </div>
      `);
      return;
    }

    const report = await invoke<CreateReport>("create_sbx_file", {
      inputPath,
      code,
      visibleName,
      outputDir: outputDir || null,
      keepAfterUnlock: checked("#keepAfterUnlock"),
      senderLabel: cleanPublicInput(inputValue("#senderLabel")) || null,
      accessProfile: cleanPublicInput(inputValue("#accessProfile")) || null,
      publicNote: cleanPublicNote(inputValue("#publicNote")) || null
    });

    showResult("ok", `
      <strong>SafeBox created.</strong>
      <div class="result-grid">
        <span>Output</span><code>${esc(report.output_path)}</code>
        <span>Visible name</span><code>${esc(report.visible_sbx_name)}</code>
        <span>Original hidden</span><code>yes</code>
      </div>
      ${report.mobile_save_required
        ? mobileSaveActionHtml(report.output_path, report.visible_sbx_name, "Save SafeBox")
        : ""}
    `);
  } catch (error) {
    const parsed = webCommandError(error);
    showResult("error", `<strong>Create failed.</strong><br/><code>${esc(parsed.message || parsed.code || "Unknown SafeBox error")}</code>`);
  }
});

async function unlockNow(sbxPath: string, code: string, receiver: boolean) {
  clearResult();

  if (!sbxPath || !code) {
    showResult("error", receiver ? "<strong>Wrong code</strong>" : "<strong>Missing information.</strong><br/>SBX file and code are required.");
    return;
  }

  try {
    if (!SAFEBOX_TAURI_RUNTIME) {
      const file = browserSelectedFile(sbxPath);
      if (!file) throw new WebSbxError("IO_ERROR", "Browser SafeBox selection expired");
      const report = await unlockWebFile(file, code);
      downloadWebBytes(report.bytes, report.original_file_name);
      report.bytes.fill(0);
      showResult("ok", `
        <strong>BOOOOM. Original restored in your browser.</strong>
        <div class="result-grid">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Size</span><code>${report.original_size} bytes</code>
          <span>SBX source</span><code>unchanged by browser</code>
          <span>Engine</span><code>Rust/WASM · canonical SBX1</code>
        </div>
      `);
      return;
    }

    const report = await invoke<UnlockReport>("unlock_sbx_file", {
      sbxPath,
      code,
      outputDir: receiver ? null : (inputValue("#unlockOutDir") || null),
      keepSbx: receiver ? true : checked("#keepSbx"),
      overwrite: receiver ? false : checked("#overwrite")
    });

    showResult("ok", `
      <strong>BOOOOM. Original restored.</strong>
      <div class="result-grid">
        <span>Original</span><code>${esc(report.original_file_name)}</code>
        <span>Saved</span><code>${esc(report.restored_path)}</code>
        <span>SBX deleted locally</span><code>${report.sbx_deleted ? "yes" : "no"}</code>
      </div>
      ${burnWarningHtml(report)}
      ${restoredActionsHtml(report.restored_path, report.original_file_name)}
    `);
  } catch (_error) {
    const parsed = webCommandError(_error);
    if (receiver) {
      showResult("error", receiverErrorHtml(parsed));
      $<HTMLInputElement>("#receiverCode").select();
    } else {
      showResult("error", `<strong>Unlock failed.</strong><br/><code>${esc(parsed.message || parsed.code || "Unknown SafeBox error")}</code>`);
    }
  }
}

$("#unlockBtn").addEventListener("click", async () => {
  await unlockNow(inputValue("#unlockInput"), inputValue("#unlockCode"), false);
});

$("#receiverUnlockBtn").addEventListener("click", async () => {
  await unlockNow(receiverSbxPath, inputValue("#receiverCode"), true);
});


/**
 * Receiver metadata UI guard
 *
 * Product rule:
 * - Main receiver screen shows only: SafeBox, file name, code field, Unlock, File info.
 * - Sender/access/note are visible only inside File info.
 * - Empty note row is hidden.
 *
 * This guard removes old visible metadata blocks even if older overlay code still creates them.
 */
function enforceReceiverMinimalUi() {
  const overlay = document.querySelector<HTMLElement>("#hardReceiverOverlay");
  if (!overlay) return;

  overlay
    .querySelectorAll<HTMLElement>(
      "#hardReceiverIdentity, #hardReceiverNote, .hard-receiver-identity, .hard-receiver-note"
    )
    .forEach((element) => {
      element.textContent = "";
      element.remove();
    });

  const noteValue = overlay.querySelector<HTMLElement>("#hardInfoNote");
  const noteRow =
    overlay.querySelector<HTMLElement>("#hardInfoNoteRow") ||
    noteValue?.closest<HTMLElement>("div");

  if (noteValue && noteRow) {
    const value = (noteValue.textContent || "").trim().toLowerCase();
    const hasRealNote = value.length > 0 && value !== "empty" && value !== "not set";

    if (!hasRealNote) {
      noteValue.textContent = "";
      noteRow.classList.add("hidden");
      noteRow.style.display = "none";
    } else {
      noteRow.classList.remove("hidden");
      noteRow.style.display = "";
    }
  }
}

const receiverMinimalUiObserver = 
// Sprint 9A hotfix:
// Removed global MutationObserver to avoid recursive DOM/i18n loops.
// i18n is applied on startup, Settings open, Help open, and language change.



console.debug("i18n-no-global-dom-observer");


type SafeBoxLocaleChoice = "auto" | "en" | "fr" | "de" | "hr" | "ar" | "es" | "it" | "pt";
type SafeBoxResolvedLocale = Exclude<SafeBoxLocaleChoice, "auto">;

const SAFEBOX_LANGUAGE_KEY = "safebox.language.v1";
const SAFEBOX_LEGACY_LANDING_LANGUAGE_KEY = "safebox.lang";

function sbxMigrateSharedLanguagePreference() {
  const canonical = localStorage.getItem(SAFEBOX_LANGUAGE_KEY);
  if (canonical) return;
  const legacy = localStorage.getItem(SAFEBOX_LEGACY_LANDING_LANGUAGE_KEY);
  if (legacy && ["en","fr","de","hr","ar","es","it","pt"].includes(legacy)) {
    localStorage.setItem(SAFEBOX_LANGUAGE_KEY, legacy);
  }
}

function sbxPersistSharedLanguage(choice: string) {
  localStorage.setItem(SAFEBOX_LANGUAGE_KEY, choice);
  if (choice === "auto") localStorage.removeItem(SAFEBOX_LEGACY_LANDING_LANGUAGE_KEY);
  else localStorage.setItem(SAFEBOX_LEGACY_LANDING_LANGUAGE_KEY, choice);
}

sbxMigrateSharedLanguagePreference();
const SAFEBOX_SUPPORTED_LOCALES: SafeBoxLocaleChoice[] = ["auto", "en", "fr", "de", "hr", "ar", "es", "it", "pt"];

const SAFEBOX_I18N: Record<string, Record<string, string>> = {
  en: {
    help: "Help",
    howToUse: "How to Use SafeBox",
    close: "Close",
    language: "Language",
    autoSystem: "Auto – System language",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "General",
    accessProfiles: "Access Profiles",
    security: "Security",
    helpIntro: "SafeBox creates encrypted .sbx files. The receiver only needs SafeBox and the correct code.",
    helpWhatIsSbxTitle: "What is an .sbx file?",
    helpWhatIsSbxText: "An .sbx file is an encrypted SafeBox file. The original filename, extension and content stay hidden until unlock.",
    helpCodeTitle: "What is the code?",
    helpCodeText: "The code is the secret shared between sender and receiver. Without it, the .sbx file cannot be opened.",
    helpProfilesTitle: "What are Access Profiles?",
    helpProfilesText: "Access Profiles are optional. They help you use different codes and labels for family, work, clients or private files.",
    helpNameTitle: "Name in SafeBox vs Shown in File info",
    helpNameText: "Name in SafeBox is only for you. Shown in File info is what the receiver can see after clicking File info.",
    helpBurnTitle: "What happens after unlock?",
    helpBurnText: "After a correct unlock, SafeBox restores the original file and removes the local .sbx copy.",
    helpMoreLater: "More detailed help and examples will be added in the next Help sprint."
  },
  fr: {
    help: "Aide",
    howToUse: "Comment utiliser SafeBox",
    close: "Fermer",
    language: "Langue",
    autoSystem: "Auto – langue du système",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "Général",
    accessProfiles: "Profils d’accès",
    security: "Sécurité",
    helpIntro: "SafeBox crée des fichiers .sbx chiffrés. Le receveur a seulement besoin de SafeBox et du bon code.",
    helpWhatIsSbxTitle: "Qu’est-ce qu’un fichier .sbx ?",
    helpWhatIsSbxText: "Un fichier .sbx est un fichier SafeBox chiffré. Le nom original, l’extension et le contenu restent cachés jusqu’au déverrouillage.",
    helpCodeTitle: "Qu’est-ce que le code ?",
    helpCodeText: "Le code est le secret partagé entre l’expéditeur et le receveur. Sans lui, le fichier .sbx ne peut pas être ouvert.",
    helpProfilesTitle: "Que sont les profils d’accès ?",
    helpProfilesText: "Les profils d’accès sont optionnels. Ils servent à utiliser différents codes et labels pour famille, travail, clients ou fichiers privés.",
    helpNameTitle: "Nom dans SafeBox et nom affiché dans les informations du fichier",
    helpNameText: "Le nom dans SafeBox est uniquement pour vous. Le nom affiché dans les informations du fichier est ce que le destinataire peut voir en ouvrant ces informations.",
    helpBurnTitle: "Que se passe-t-il après le déverrouillage ?",
    helpBurnText: "Après un déverrouillage correct, SafeBox restaure le fichier original et supprime la copie locale .sbx.",
    helpMoreLater: "Cette aide contient les informations essentielles pour utiliser SafeBox de manière sûre."
  },
  de: {
    help: "Hilfe",
    howToUse: "SafeBox verwenden",
    close: "Schließen",
    language: "Sprache",
    autoSystem: "Auto – Systemsprache",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "Allgemein",
    accessProfiles: "Zugriffsprofile",
    security: "Sicherheit",
    helpIntro: "SafeBox erstellt verschlüsselte .sbx-Dateien. Der Empfänger braucht nur SafeBox und den richtigen Code.",
    helpWhatIsSbxTitle: "Was ist eine .sbx-Datei?",
    helpWhatIsSbxText: "Eine .sbx-Datei ist eine verschlüsselte SafeBox-Datei. Originalname, Erweiterung und Inhalt bleiben bis zum Entsperren verborgen.",
    helpCodeTitle: "Was ist der Code?",
    helpCodeText: "Der Code ist das gemeinsame Geheimnis zwischen Sender und Empfänger. Ohne ihn kann die .sbx-Datei nicht geöffnet werden.",
    helpProfilesTitle: "Was sind Zugriffsprofile?",
    helpProfilesText: "Zugriffsprofile sind optional. Sie helfen, verschiedene Codes und Labels für Familie, Arbeit, Kunden oder private Dateien zu nutzen.",
    helpNameTitle: "Name in SafeBox und Anzeige in den Dateiinformationen",
    helpNameText: "Der Name in SafeBox ist nur für dich. Die Anzeige in den Dateiinformationen ist das, was der Empfänger sehen kann.",
    helpBurnTitle: "Was passiert nach dem Entsperren?",
    helpBurnText: "Nach dem richtigen Entsperren stellt SafeBox die Originaldatei wieder her und entfernt die lokale .sbx-Kopie.",
    helpMoreLater: "Diese Hilfe enthält die wichtigsten Informationen für die sichere Verwendung von SafeBox."
  },
  hr: {
    help: "Pomoć",
    howToUse: "Kako koristiti SafeBox",
    close: "Zatvori",
    language: "Jezik",
    autoSystem: "Auto – jezik sistema",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "Opšte",
    accessProfiles: "Pristupni profili",
    security: "Sigurnost",
    helpIntro: "SafeBox stvara šifrirane .sbx fajlove. Primaocu treba samo SafeBox i tačan kod.",
    helpWhatIsSbxTitle: "Šta je .sbx fajl?",
    helpWhatIsSbxText: ".sbx je šifrirani SafeBox fajl. Originalno ime, ekstenzija i sadržaj ostaju skriveni dok se fajl ne otključa.",
    helpCodeTitle: "Šta je kod?",
    helpCodeText: "Kod je tajna koju dijele pošiljalac i primalac. Bez njega .sbx fajl ne može da se otvori.",
    helpProfilesTitle: "Šta su pristupni profili?",
    helpProfilesText: "Pristupni profili su opcionalni. Koriste se za različite kodove i labele za porodicu, posao, klijente ili privatne fajlove.",
    helpNameTitle: "Naziv u SafeBoxu i naziv prikazan u informacijama datoteke",
    helpNameText: "Naziv u SafeBoxu je samo za vas. Naziv prikazan u informacijama datoteke je ono što primatelj može vidjeti.",
    helpBurnTitle: "Šta se dešava nakon otključavanja?",
    helpBurnText: "Nakon tačnog koda SafeBox vraća originalni fajl i uklanja lokalnu .sbx kopiju.",
    helpMoreLater: "Ova pomoć sadrži ključne informacije za sigurno korištenje SafeBoxa."
  },
  ar: {
    help: "مساعدة",
    howToUse: "كيفية استخدام SafeBox",
    close: "إغلاق",
    language: "اللغة",
    autoSystem: "تلقائي – لغة النظام",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "عام",
    accessProfiles: "ملفات الوصول",
    security: "الأمان",
    helpIntro: "SafeBox ينشئ ملفات .sbx مشفرة. يحتاج المستقبل فقط إلى SafeBox والرمز الصحيح.",
    helpWhatIsSbxTitle: "ما هو ملف .sbx؟",
    helpWhatIsSbxText: "ملف .sbx هو ملف SafeBox مشفر. يبقى اسم الملف الأصلي والامتداد والمحتوى مخفيًا حتى فتحه.",
    helpCodeTitle: "ما هو الرمز؟",
    helpCodeText: "الرمز هو السر المشترك بين المرسل والمستقبل. بدونه لا يمكن فتح ملف .sbx.",
    helpProfilesTitle: "ما هي ملفات الوصول؟",
    helpProfilesText: "ملفات الوصول اختيارية. تساعدك على استخدام رموز وتسميات مختلفة للعائلة أو العمل أو العملاء أو الملفات الخاصة.",
    helpNameTitle: "الاسم داخل SafeBox والاسم الظاهر في معلومات الملف",
    helpNameText: "الاسم داخل SafeBox مخصص لك فقط. الاسم الظاهر في معلومات الملف هو ما يمكن للمستلم رؤيته.",
    helpBurnTitle: "ماذا يحدث بعد الفتح؟",
    helpBurnText: "بعد إدخال الرمز الصحيح، يسترجع SafeBox الملف الأصلي ويحذف نسخة .sbx المحلية.",
    helpMoreLater: "تتضمن هذه المساعدة المعلومات الأساسية لاستخدام SafeBox بأمان."
  },
  es: {
    help: "Ayuda",
    howToUse: "Cómo usar SafeBox",
    close: "Cerrar",
    language: "Idioma",
    autoSystem: "Auto – idioma del sistema",
    english: "English",
    french: "Français",
    german: "Deutsch",
    croatian: "Hrvatski / BCS",
    arabic: "العربية",
    spanish: "Español",
    italian: "Italiano",
    portuguese: "Português",
    general: "General",
    accessProfiles: "Perfiles de acceso",
    security: "Seguridad",
    helpIntro: "SafeBox crea archivos .sbx cifrados. El receptor solo necesita SafeBox y el código correcto.",
    helpWhatIsSbxTitle: "¿Qué es un archivo .sbx?",
    helpWhatIsSbxText: "Un archivo .sbx es un archivo SafeBox cifrado. El nombre original, la extensión y el contenido quedan ocultos hasta desbloquearlo.",
    helpCodeTitle: "¿Qué es el código?",
    helpCodeText: "El código es el secreto compartido entre remitente y receptor. Sin él, el archivo .sbx no se puede abrir.",
    helpProfilesTitle: "¿Qué son los perfiles de acceso?",
    helpProfilesText: "Los perfiles de acceso son opcionales. Ayudan a usar diferentes códigos y etiquetas para familia, trabajo, clientes o archivos privados.",
    helpNameTitle: "Nombre en SafeBox y nombre mostrado en la información del archivo",
    helpNameText: "El nombre en SafeBox es solo para ti. El nombre mostrado en la información del archivo es lo que puede ver el receptor.",
    helpBurnTitle: "¿Qué ocurre después de desbloquear?",
    helpBurnText: "Después de un desbloqueo correcto, SafeBox restaura el archivo original y elimina la copia local .sbx.",
    helpMoreLater: "Esta ayuda contiene la información esencial para usar SafeBox de forma segura."
  }
  ,it: {
    help: "Aiuto", howToUse: "Come usare SafeBox", close: "Chiudi", language: "Lingua", autoSystem: "Auto – lingua di sistema",
    english: "English", french: "Français", german: "Deutsch", croatian: "Hrvatski / BCS", arabic: "العربية", spanish: "Español", italian: "Italiano", portuguese: "Português",
    general: "Generale", accessProfiles: "Profili di accesso", security: "Sicurezza",
    helpIntro: "SafeBox crea file .sbx cifrati. Il destinatario ha bisogno solo di SafeBox e del codice corretto.",
    helpWhatIsSbxTitle: "Che cos’è un file .sbx?", helpWhatIsSbxText: "Un file .sbx è un file SafeBox cifrato. Nome originale, estensione e contenuto restano nascosti fino allo sblocco.",
    helpCodeTitle: "Che cos’è il codice?", helpCodeText: "Il codice è il segreto condiviso tra mittente e destinatario. Senza di esso il file .sbx non può essere aperto.",
    helpProfilesTitle: "Che cosa sono i profili di accesso?", helpProfilesText: "I profili di accesso sono facoltativi e permettono di usare codici ed etichette diversi per famiglia, lavoro, clienti o file privati.",
    helpNameTitle: "Nome in SafeBox e nome mostrato nelle informazioni file", helpNameText: "Il nome in SafeBox è solo per te. Il nome mostrato nelle informazioni file è ciò che il destinatario può vedere aprendo le informazioni.",
    helpBurnTitle: "Che cosa succede dopo lo sblocco?", helpBurnText: "Dopo uno sblocco corretto, SafeBox ripristina il file originale e gestisce la copia locale .sbx secondo le impostazioni selezionate.",
    helpMoreLater: "La guida include le informazioni essenziali per usare SafeBox in modo sicuro."
  },
  pt: {
    help: "Ajuda", howToUse: "Como usar o SafeBox", close: "Fechar", language: "Idioma", autoSystem: "Auto – idioma do sistema",
    english: "English", french: "Français", german: "Deutsch", croatian: "Hrvatski / BCS", arabic: "العربية", spanish: "Español", italian: "Italiano", portuguese: "Português",
    general: "Geral", accessProfiles: "Perfis de acesso", security: "Segurança",
    helpIntro: "O SafeBox cria ficheiros .sbx cifrados. O destinatário precisa apenas do SafeBox e do código correto.",
    helpWhatIsSbxTitle: "O que é um ficheiro .sbx?", helpWhatIsSbxText: "Um ficheiro .sbx é um ficheiro SafeBox cifrado. O nome original, a extensão e o conteúdo permanecem ocultos até ao desbloqueio.",
    helpCodeTitle: "O que é o código?", helpCodeText: "O código é o segredo partilhado entre remetente e destinatário. Sem ele, o ficheiro .sbx não pode ser aberto.",
    helpProfilesTitle: "O que são perfis de acesso?", helpProfilesText: "Os perfis de acesso são opcionais e permitem usar códigos e etiquetas diferentes para família, trabalho, clientes ou ficheiros privados.",
    helpNameTitle: "Nome no SafeBox e nome mostrado nas informações do ficheiro", helpNameText: "O nome no SafeBox é apenas para si. O nome mostrado nas informações do ficheiro é o que o destinatário pode ver ao abrir as informações.",
    helpBurnTitle: "O que acontece após o desbloqueio?", helpBurnText: "Após um desbloqueio correto, o SafeBox restaura o ficheiro original e gere a cópia local .sbx de acordo com as opções selecionadas.",
    helpMoreLater: "A ajuda inclui as informações essenciais para usar o SafeBox com segurança."
  }
};

function sbxHtmlEscape(value: string): string {
  return value.replace(/[&<>'"]/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#039;",
    '"': "&quot;"
  }[char] ?? char));
}

function sbxStoredLanguageChoice(): SafeBoxLocaleChoice {
  const stored = localStorage.getItem(SAFEBOX_LANGUAGE_KEY) as SafeBoxLocaleChoice | null;
  return stored && SAFEBOX_SUPPORTED_LOCALES.includes(stored) ? stored : "auto";
}

function sbxDetectSystemLanguage(): SafeBoxResolvedLocale {
  const languages = navigator.languages?.length ? navigator.languages : [navigator.language || "en"];
  const first = (languages[0] || "en").toLowerCase();

  if (first.startsWith("fr")) return "fr";
  if (first.startsWith("de")) return "de";
  if (first.startsWith("hr") || first.startsWith("bs") || first.startsWith("sr") || first.startsWith("sh")) return "hr";
  if (first.startsWith("ar")) return "ar";
  if (first.startsWith("es")) return "es";
  if (first.startsWith("it")) return "it";
  if (first.startsWith("pt")) return "pt";

  return "en";
}

function sbxResolvedLanguage(): SafeBoxResolvedLocale {
  const choice = sbxStoredLanguageChoice();
  return choice === "auto" ? sbxDetectSystemLanguage() : choice;
}

function sbxT(key: string): string {
  const locale = sbxResolvedLanguage();
  return SAFEBOX_I18N[locale]?.[key] || SAFEBOX_I18N.en[key] || key;
}

function sbxSetText(selector: string, value: string) {
  const element = document.querySelector<HTMLElement>(selector);
  if (element) element.textContent = value;
}

function sbxEnsureHelpButton() {
  if (document.querySelector("#helpBtn")) return;

  const settingsButton = document.querySelector<HTMLElement>("#settingsBtn");
  const parent = settingsButton?.parentElement || document.querySelector<HTMLElement>(".top-actions");

  if (!parent) return;

  const helpButton = document.createElement("button");
  helpButton.id = "helpBtn";
  helpButton.className = settingsButton?.className || "ghost-btn";
  helpButton.type = "button";
  helpButton.textContent = sbxT("help");

  if (settingsButton) {
    parent.insertBefore(helpButton, settingsButton.nextSibling);
  } else {
    parent.appendChild(helpButton);
  }

  helpButton.addEventListener("click", () => {
    sbxEnsureHelpModal();
    sbxRenderHelpModal();
    document.querySelector<HTMLElement>("#howToUseModal")?.classList.remove("hidden");
    void setIosAdVisible(false);
  });
}

function sbxEnsureLanguageSelector() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const existing = modal.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  const generalPanel =
    modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]') ||
    modal.querySelector<HTMLElement>("#settingsTabsRoot") ||
    modal.querySelector<HTMLElement>(".settings-content") ||
    modal.querySelector<HTMLElement>(".modal-content") ||
    modal;

  if (!generalPanel) return;

  if (!existing) {
    const wrapper = document.createElement("label");
    wrapper.id = "settingsLanguageField";
    wrapper.className = "settings-language-field";
    wrapper.innerHTML = `
      <span class="settings-language-title"></span>
      <select id="settingsLanguageSelect">
        <option value="auto"></option>
        <option value="en"></option>
        <option value="fr"></option>
        <option value="de"></option>
        <option value="hr"></option>
        <option value="ar"></option>
        <option value="es"></option>
        <option value="it"></option>
        <option value="pt"></option>
      </select>
    `;

    const firstChild = generalPanel.firstElementChild;
    if (firstChild) {
      generalPanel.insertBefore(wrapper, firstChild);
    } else {
      generalPanel.appendChild(wrapper);
    }

    const select = wrapper.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
    select?.addEventListener("change", () => {
      sbxPersistSharedLanguage(select.value);
      sbxApplyI18n();
    });
  }

  const select = modal.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (select) {
    select.value = sbxStoredLanguageChoice();

    const labels: Record<SafeBoxLocaleChoice, string> = {
      auto: sbxT("autoSystem"),
      en: sbxT("english"),
      fr: sbxT("french"),
      de: sbxT("german"),
      hr: sbxT("croatian"),
      ar: sbxT("arabic"),
      es: sbxT("spanish"),
      it: sbxT("italian"),
      pt: sbxT("portuguese")
    };

    Array.from(select.options).forEach((option) => {
      option.textContent = labels[option.value as SafeBoxLocaleChoice] || option.value;
    });
  }

  const title = modal.querySelector<HTMLElement>(".settings-language-title");
  if (title) title.textContent = sbxT("language");
}

function sbxEnsureHelpModal() {
  if (document.querySelector("#howToUseModal")) return;

  const modal = document.createElement("div");
  modal.id = "howToUseModal";
  modal.className = "modal-backdrop hidden";
  modal.innerHTML = `
    <section class="settings-modal help-modal-card" role="dialog" aria-modal="true">
      <div class="modal-head">
        <div>
          <h2 id="howToUseTitle"></h2>
          <p id="howToUseIntro"></p>
        </div>
        <button id="closeHelpBtn" class="icon-btn" type="button">×</button>
      </div>

      <div id="howToUseContent" class="help-content"></div>

      <div class="settings-actions">
        <button id="closeHelpFooterBtn" class="primary-btn" type="button"></button>
      </div>
    </section>
  `;

  document.body.appendChild(modal);

  document.querySelector("#closeHelpBtn")?.addEventListener("click", () => {
    document.querySelector("#howToUseModal")?.classList.add("hidden");
    void setIosAdVisible(true);
  });

  document.querySelector("#closeHelpFooterBtn")?.addEventListener("click", () => {
    document.querySelector("#howToUseModal")?.classList.add("hidden");
    void setIosAdVisible(true);
  });

  modal.addEventListener("click", (event) => {
    if (event.target === modal) {
      modal.classList.add("hidden");
      void setIosAdVisible(true);
    }
  });
}

function sbxRenderHelpModal() {
  sbxEnsureHelpModal();

  sbxSetText("#howToUseTitle", sbxT("howToUse"));
  sbxSetText("#howToUseIntro", sbxT("helpIntro"));
  sbxSetText("#closeHelpFooterBtn", sbxT("close"));

  const content = document.querySelector<HTMLElement>("#howToUseContent");
  if (!content) return;

  const sections = [
    ["helpWhatIsSbxTitle", "helpWhatIsSbxText"],
    ["helpCodeTitle", "helpCodeText"],
    ["helpProfilesTitle", "helpProfilesText"],
    ["helpNameTitle", "helpNameText"],
    ["helpBurnTitle", "helpBurnText"]
  ];

  content.innerHTML = sections.map(([titleKey, textKey]) => `
    <article class="help-section">
      <h3>${sbxHtmlEscape(sbxT(titleKey))}</h3>
      <p>${sbxHtmlEscape(sbxT(textKey))}</p>
    </article>
  `).join("") + `
    <p class="settings-note">${sbxHtmlEscape(sbxT("helpMoreLater"))}</p>
  `;
}

function sbxTranslateSettingsTabs() {
  document.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
    const tab = button.dataset.tab;
    if (tab === "general") button.textContent = sbxT("general");
    if (tab === "profiles") button.textContent = sbxT("accessProfiles");
    if (tab === "security") button.textContent = sbxT("security");
  });
}

function sbxApplyI18n() {
  const locale = sbxResolvedLanguage();

  document.documentElement.lang = locale;
  document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";

  sbxEnsureHelpButton();
  sbxEnsureLanguageSelector();
  sbxEnsureHelpModal();
  sbxTranslateSettingsTabs();
  sbxRenderHelpModal();

  sbxSetText("#helpBtn", sbxT("help"));
}

function SAFEBOX_I18N_SPRINT9A_MARKER() {
  return "i18n-language-selector-help-foundation";
}

console.debug(SAFEBOX_I18N_SPRINT9A_MARKER());

setTimeout(sbxApplyI18n, 0);
setTimeout(sbxApplyI18n, 250);

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxApplyI18n, 80);
  setTimeout(sbxApplyI18n, 250);
});


// Sprint 9A hotfix:
// Global DOM MutationObserver removed to prevent Settings/Help freeze.
// i18n applies on startup, Settings open, Help open, and language change.
console.debug("i18n-no-global-dom-observer");



function sbxFinalSettingsRepair() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild instanceof HTMLElement ? modal.firstElementChild : null);

  if (!card) return;

  const head = card.querySelector<HTMLElement>(".modal-head");
  const actions =
    card.querySelector<HTMLElement>(".settings-actions") ||
    card.querySelector<HTMLElement>(".modal-actions");

  if (!head || !actions) return;

  // Remove language selectors floating outside the card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  // Remove tabs created in wrong places.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsTabsRoot")).forEach((root) => {
    if (!card.contains(root) || root.parentElement !== card) root.remove();
  });

  let tabsRoot = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!tabsRoot) {
    tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root sbx-final-settings-tabs";
    tabsRoot.innerHTML = `
      <div class="settings-tabs-nav" role="tablist">
        <button class="settings-tab-button active" type="button" data-tab="general">General</button>
        <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
        <button class="settings-tab-button" type="button" data-tab="security">Security</button>
      </div>

      <div class="settings-tab-panels">
        <div class="settings-tab-panel active" data-panel="general"></div>
        <div class="settings-tab-panel" data-panel="profiles"></div>
        <div class="settings-tab-panel" data-panel="security"></div>
      </div>
    `;
    card.insertBefore(tabsRoot, actions);
  }

  const generalPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  const profilesPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="profiles"]');
  const securityPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="security"]');

  if (!generalPanel || !profilesPanel || !securityPanel) return;

  const wrapperFor = (selector: string): HTMLElement | null => {
    const element =
      card.querySelector<HTMLElement>(selector) ||
      document.querySelector<HTMLElement>(selector);

    if (!element) return null;

    return (
      element.closest<HTMLElement>("label") ||
      element.closest<HTMLElement>(".field") ||
      element.closest<HTMLElement>(".setting-row") ||
      element.parentElement
    );
  };

  const moveInto = (node: HTMLElement | null, panel: HTMLElement) => {
    if (!node) return;
    panel.appendChild(node);
    node.classList.remove("hidden");
    node.style.display = "";
  };

  // Language field inside General.
  let languageField = card.querySelector<HTMLElement>("#settingsLanguageField");

  if (!languageField) {
    languageField = document.createElement("label");
    languageField.id = "settingsLanguageField";
    languageField.className = "settings-language-field";
    languageField.innerHTML = `
      <span class="settings-language-title">Language</span>
      <select id="settingsLanguageSelect">
        <option value="auto">Auto - System language</option>
        <option value="en">English</option>
        <option value="fr">Français</option>
        <option value="de">Deutsch</option>
        <option value="hr">Hrvatski / BCS</option>
        <option value="ar">العربية</option>
        <option value="es">Español</option>
        <option value="it">Italiano</option>
        <option value="pt">Português</option>
      </select>
    `;

    const select = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
    select?.addEventListener("change", () => {
      sbxPersistSharedLanguage(select.value);
      const apply = (window as any).sbxApplyI18n;
      if (typeof apply === "function") apply();
    });
  }

  moveInto(languageField, generalPanel);

  const select = card.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (select) select.value = localStorage.getItem("safebox.language.v1") || "auto";

  moveInto(card.querySelector<HTMLElement>("#settingsFileNamingInfo"), generalPanel);
  moveInto(wrapperFor("#settingsGlobalSenderLabel"), generalPanel);

  // Hide legacy access profile input forever.
  const legacy = wrapperFor("#settingsDefaultAccessProfile");
  if (legacy) {
    legacy.classList.add("hidden", "legacy-default-access-field");
    legacy.style.display = "none";
  }

  const profilesSection = card.querySelector<HTMLElement>(".profiles-section");
  moveInto(profilesSection, profilesPanel);

  moveInto(wrapperFor("#settingsUseGlobalCode"), securityPanel);
  moveInto(wrapperFor("#settingsGlobalCode"), securityPanel);

  const clearBtn = card.querySelector<HTMLElement>("#clearGlobalCodeBtn") || document.querySelector<HTMLElement>("#clearGlobalCodeBtn");
  if (clearBtn) {
    const clearWrapper = clearBtn.closest<HTMLElement>(".password-action-row") || clearBtn.parentElement;
    if (clearWrapper && !securityPanel.contains(clearWrapper)) {
      moveInto(clearWrapper, securityPanel);
    } else if (!securityPanel.contains(clearBtn)) {
      securityPanel.appendChild(clearBtn);
    }
  }

  // Move global-code note into Security tab.
  Array.from(card.querySelectorAll<HTMLElement>(".settings-note")).forEach((note) => {
    const txt = (note.textContent || "").toLowerCase();
    if (txt.includes("global code") || txt.includes("keychain") || txt.includes("credential")) {
      securityPanel.appendChild(note);
    }
  });

  // Remove dividers and floating empty leftovers from direct card children.
  Array.from(card.children).forEach((child) => {
    if (!(child instanceof HTMLElement)) return;
    if (child === head || child === tabsRoot || child === actions) return;

    if (child.classList.contains("settings-section-divider")) {
      child.remove();
      return;
    }

    if (child.id === "settingsLanguageField") {
      generalPanel.appendChild(child);
      return;
    }
  });

  // Bind tab clicks once.
  tabsRoot.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    if (button.dataset.sbxFinalTabsBound === "1") return;
    button.dataset.sbxFinalTabsBound = "1";

    button.addEventListener("click", () => {
      const tab = button.dataset.tab || "general";

      tabsRoot?.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((btn) => {
        btn.classList.toggle("active", btn.dataset.tab === tab);
      });

      tabsRoot?.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
        panel.classList.toggle("active", panel.dataset.panel === tab);
      });
    });
  });

  modal.classList.add("settings-tabs-enabled", "sbx-final-settings-repaired");
}

function SAFEBOX_FINAL_SETTINGS_REPAIR_MARKER() {
  return "final-settings-repair-tabs-language-scroll";
}

console.debug(SAFEBOX_FINAL_SETTINGS_REPAIR_MARKER());

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxFinalSettingsRepair, 20);
  setTimeout(sbxFinalSettingsRepair, 100);
  setTimeout(sbxFinalSettingsRepair, 250);
});

setTimeout(sbxFinalSettingsRepair, 300);


function sbxHardSettingsModalFix() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild instanceof HTMLElement ? modal.firstElementChild : null);

  if (!card) return;

  const head = card.querySelector<HTMLElement>(".modal-head");
  const actions =
    card.querySelector<HTMLElement>(".settings-actions") ||
    card.querySelector<HTMLElement>(".modal-actions");

  if (!head || !actions) return;

  // This modal must not make the background page scroll.
  modal.classList.add("sbx-hard-settings-fixed");
  document.body.classList.add("sbx-settings-open");

  // Remove all language fields outside the Settings card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  // Remove old/broken tab roots, then build one clean tab root.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsTabsRoot")).forEach((root) => {
    root.remove();
  });

  const tabsRoot = document.createElement("section");
  tabsRoot.id = "settingsTabsRoot";
  tabsRoot.className = "settings-tabs-root sbx-hard-tabs-root";

  tabsRoot.innerHTML = `
    <div class="settings-tabs-nav" role="tablist">
      <button class="settings-tab-button active" type="button" data-tab="general">General</button>
      <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
      <button class="settings-tab-button" type="button" data-tab="security">Security</button>
    </div>

    <div class="settings-tab-panels">
      <div class="settings-tab-panel active" data-panel="general"></div>
      <div class="settings-tab-panel" data-panel="profiles"></div>
      <div class="settings-tab-panel" data-panel="security"></div>
    </div>
  `;

  card.insertBefore(tabsRoot, actions);

  const generalPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  const profilesPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="profiles"]');
  const securityPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="security"]');

  if (!generalPanel || !profilesPanel || !securityPanel) return;

  const wrapperFor = (selector: string): HTMLElement | null => {
    const element =
      card.querySelector<HTMLElement>(selector) ||
      document.querySelector<HTMLElement>(selector);

    if (!element) return null;

    return (
      element.closest<HTMLElement>("label") ||
      element.closest<HTMLElement>(".field") ||
      element.closest<HTMLElement>(".setting-row") ||
      element.parentElement
    );
  };

  const moveInto = (node: HTMLElement | null, panel: HTMLElement) => {
    if (!node) return;
    panel.appendChild(node);
    node.classList.remove("hidden");
    node.style.display = "";
  };

  // Language field inside General.
  let languageField = card.querySelector<HTMLElement>("#settingsLanguageField");

  if (!languageField) {
    languageField = document.createElement("label");
    languageField.id = "settingsLanguageField";
    languageField.className = "settings-language-field";
    languageField.innerHTML = `
      <span class="settings-language-title">Language</span>
      <select id="settingsLanguageSelect">
        <option value="auto">Auto - System language</option>
        <option value="en">English</option>
        <option value="fr">Français</option>
        <option value="de">Deutsch</option>
        <option value="hr">Hrvatski / BCS</option>
        <option value="ar">العربية</option>
        <option value="es">Español</option>
        <option value="it">Italiano</option>
        <option value="pt">Português</option>
      </select>
    `;

    const select = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
    select?.addEventListener("change", () => {
      sbxPersistSharedLanguage(select.value);
      const apply = (window as any).sbxApplyI18n;
      if (typeof apply === "function") apply();
    });
  }

  moveInto(languageField, generalPanel);

  const languageSelect = card.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) languageSelect.value = localStorage.getItem("safebox.language.v1") || "auto";

  moveInto(card.querySelector<HTMLElement>("#settingsFileNamingInfo"), generalPanel);
  moveInto(wrapperFor("#settingsGlobalSenderLabel"), generalPanel);

  const legacyDefaultAccess = wrapperFor("#settingsDefaultAccessProfile");
  if (legacyDefaultAccess) {
    legacyDefaultAccess.classList.add("hidden", "legacy-default-access-field");
    legacyDefaultAccess.style.display = "none";
  }

  const profilesSection = card.querySelector<HTMLElement>(".profiles-section");
  moveInto(profilesSection, profilesPanel);

  moveInto(wrapperFor("#settingsUseGlobalCode"), securityPanel);
  const globalCodeWrapper = wrapperFor("#settingsGlobalCode");
  moveInto(globalCodeWrapper, securityPanel);

  const clearBtn =
    card.querySelector<HTMLElement>("#clearGlobalCodeBtn") ||
    document.querySelector<HTMLElement>("#clearGlobalCodeBtn");

  if (clearBtn) {
    const clearWrapper = clearBtn.closest<HTMLElement>(".password-action-row") || clearBtn.parentElement;
    if (clearWrapper && clearWrapper !== globalCodeWrapper) {
      moveInto(clearWrapper, securityPanel);
    } else if (!securityPanel.contains(clearBtn)) {
      securityPanel.appendChild(clearBtn);
    }
  }

  Array.from(card.querySelectorAll<HTMLElement>(".settings-note")).forEach((note) => {
    const txt = (note.textContent || "").toLowerCase();
    if (txt.includes("global code") || txt.includes("keychain") || txt.includes("credential")) {
      securityPanel.appendChild(note);
    }
  });

  Array.from(card.children).forEach((child) => {
    if (!(child instanceof HTMLElement)) return;
    if (child === head || child === tabsRoot || child === actions) return;

    if (child.classList.contains("settings-section-divider")) {
      child.remove();
    }
  });

  const activateTab = (tab: string) => {
    tabsRoot.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
      button.classList.toggle("active", button.dataset.tab === tab);
    });

    tabsRoot.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
      panel.classList.toggle("active", panel.dataset.panel === tab);
    });
  };

  tabsRoot.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>(".settings-tab-button");
    if (!button) return;
    activateTab(button.dataset.tab || "general");
  });

  activateTab("general");
}

function sbxHardSettingsModalCloseCleanup() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal || modal.classList.contains("hidden") || modal.style.display === "none") {
    document.body.classList.remove("sbx-settings-open");
  }
}

function SAFEBOX_HARD_SETTINGS_MODAL_FIX_MARKER() {
  return "hard-settings-modal-fixed-tabs-click-scroll";
}

console.debug(SAFEBOX_HARD_SETTINGS_MODAL_FIX_MARKER());

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalFix, 20);
  setTimeout(sbxHardSettingsModalFix, 100);
  setTimeout(sbxHardSettingsModalFix, 260);
});

document.querySelector("#closeSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});

document.querySelector("#cancelSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});

document.querySelector("#saveSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});

// HARD FIX — Settings tabs click handler
// Marker: hard-settings-tabs-click-handler-v1
function sbxForceSettingsTab(tabName: string) {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const root = modal.querySelector<HTMLElement>("#settingsTabsRoot");
  if (!root) return;

  root.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tabName);
  });

  root.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
    const isActive = panel.dataset.panel === tabName;
    panel.classList.toggle("active", isActive);
    panel.style.display = isActive ? "block" : "none";
  });
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;
    const button = target?.closest<HTMLButtonElement>("#settingsModal .settings-tab-button");

    if (!button) return;

    event.preventDefault();
    event.stopPropagation();

    sbxForceSettingsTab(button.dataset.tab || "general");
  },
  true
);

setTimeout(() => sbxForceSettingsTab("general"), 300);

console.debug("hard-settings-tabs-click-handler-v1");

// HARD RESTORE — Settings content inside tabs
// Marker: settings-content-restore-general-profiles-security-v1
function sbxSettingsContentRestore() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild instanceof HTMLElement ? modal.firstElementChild : null);

  if (!card) return;

  const actions =
    card.querySelector<HTMLElement>(".settings-actions") ||
    card.querySelector<HTMLElement>(".modal-actions");

  const head = card.querySelector<HTMLElement>(".modal-head");

  if (!actions || !head) return;

  modal.classList.add("sbx-hard-settings-fixed", "sbx-settings-content-restored");
  document.body.classList.add("sbx-settings-open");

  // Remove floating language fields outside the Settings card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  let tabsRoot = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!tabsRoot) {
    tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root sbx-hard-tabs-root";
    tabsRoot.innerHTML = `
      <div class="settings-tabs-nav" role="tablist">
        <button class="settings-tab-button active" type="button" data-tab="general">General</button>
        <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
        <button class="settings-tab-button" type="button" data-tab="security">Security</button>
      </div>

      <div class="settings-tab-panels">
        <div class="settings-tab-panel active" data-panel="general"></div>
        <div class="settings-tab-panel" data-panel="profiles"></div>
        <div class="settings-tab-panel" data-panel="security"></div>
      </div>
    `;
    card.insertBefore(tabsRoot, actions);
  }

  const nav = tabsRoot.querySelector<HTMLElement>(".settings-tabs-nav");
  const panels = tabsRoot.querySelector<HTMLElement>(".settings-tab-panels");

  if (!nav || !panels) return;

  const ensurePanel = (name: string) => {
    let panel = tabsRoot!.querySelector<HTMLElement>(`.settings-tab-panel[data-panel="${name}"]`);
    if (!panel) {
      panel = document.createElement("div");
      panel.className = `settings-tab-panel ${name === "general" ? "active" : ""}`;
      panel.dataset.panel = name;
      panels.appendChild(panel);
    }
    return panel;
  };

  const generalPanel = ensurePanel("general");
  const profilesPanel = ensurePanel("profiles");
  const securityPanel = ensurePanel("security");

  const ensureButton = (name: string, label: string) => {
    let button = tabsRoot!.querySelector<HTMLButtonElement>(`.settings-tab-button[data-tab="${name}"]`);
    if (!button) {
      button = document.createElement("button");
      button.className = `settings-tab-button ${name === "general" ? "active" : ""}`;
      button.type = "button";
      button.dataset.tab = name;
      button.textContent = label;
      nav.appendChild(button);
    }
    return button;
  };

  ensureButton("general", "General");
  ensureButton("profiles", "Access Profiles");
  ensureButton("security", "Security");

  const activate = (tab: string) => {
    tabsRoot!.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
      button.classList.toggle("active", button.dataset.tab === tab);
    });

    tabsRoot!.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
      const active = panel.dataset.panel === tab;
      panel.classList.toggle("active", active);
      panel.style.display = active ? "block" : "none";
    });
  };

  tabsRoot.onclick = (event) => {
    const target = event.target as HTMLElement | null;
    const button = target?.closest<HTMLButtonElement>(".settings-tab-button");
    if (!button) return;
    event.preventDefault();
    event.stopPropagation();
    activate(button.dataset.tab || "general");
  };

  const settingsNow = readSettings();

  const moveOrCreateLabelInput = (
    id: string,
    labelText: string,
    value: string,
    panel: HTMLElement,
    inputType = "text"
  ) => {
    let input = document.querySelector<HTMLInputElement>(`#${id}`);
    let wrapper: HTMLElement | null = input?.closest<HTMLElement>("label") || null;

    if (!input || !wrapper) {
      wrapper = document.createElement("label");
      input = document.createElement("input");
      input.id = id;
      input.type = inputType;
      input.autocomplete = "off";
      wrapper.textContent = labelText;
      wrapper.appendChild(input);
    } else {
      const firstTextNode = Array.from(wrapper.childNodes).find((node) => node.nodeType === Node.TEXT_NODE);
      if (firstTextNode) firstTextNode.textContent = labelText;
      else wrapper.prepend(document.createTextNode(labelText));
    }

    input.value = value || "";
    wrapper.classList.remove("hidden");
    wrapper.style.display = "";
    panel.appendChild(wrapper);

    return input;
  };

  // Language field.
  let languageField = card.querySelector<HTMLElement>("#settingsLanguageField");

  if (!languageField) {
    languageField = document.createElement("label");
    languageField.id = "settingsLanguageField";
    languageField.className = "settings-language-field";
    languageField.innerHTML = `
      <span class="settings-language-title">Language</span>
      <select id="settingsLanguageSelect">
        <option value="auto">Auto - System language</option>
        <option value="en">English</option>
        <option value="fr">Français</option>
        <option value="de">Deutsch</option>
        <option value="hr">Hrvatski / BCS</option>
        <option value="ar">العربية</option>
        <option value="es">Español</option>
        <option value="it">Italiano</option>
        <option value="pt">Português</option>
      </select>
    `;
  }

  generalPanel.appendChild(languageField);

  const languageSelect = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) {
    languageSelect.value = localStorage.getItem("safebox.language.v1") || "auto";
    languageSelect.onchange = () => {
      sbxPersistSharedLanguage(languageSelect.value);
      const apply = (window as any).sbxApplyI18n;
      if (typeof apply === "function") apply();
    };
  }

  let namingInfo = card.querySelector<HTMLElement>("#settingsFileNamingInfo");
  if (!namingInfo) {
    namingInfo = document.createElement("div");
    namingInfo.id = "settingsFileNamingInfo";
    namingInfo.className = "settings-file-naming-info";
  }
  namingInfo.innerHTML = `
    <strong>File naming</strong>
    <span>New SafeBox files use the original filename by default. The name can be changed before creation.</span>
  `;
  generalPanel.appendChild(namingInfo);

  document.querySelector("#settingsDefaultName")?.closest("label")?.remove();

  const globalSenderInput = moveOrCreateLabelInput(
    "settingsGlobalSenderLabel",
    "Global sender label",
    settingsNow.globalSenderLabel || "",
    generalPanel
  );
  globalSenderInput.closest<HTMLElement>("label")?.classList.add("settings-global-sender-field");

  // Keep legacy default access profile input for old save code, but hidden.
  let legacyInput = document.querySelector<HTMLInputElement>("#settingsDefaultAccessProfile");
  if (!legacyInput) {
    const legacyWrapper = document.createElement("label");
    legacyWrapper.className = "legacy-default-access-field hidden";
    legacyInput = document.createElement("input");
    legacyInput.id = "settingsDefaultAccessProfile";
    legacyWrapper.appendChild(legacyInput);
    card.appendChild(legacyWrapper);
  }
  legacyInput.value = settingsNow.defaultAccessProfile || "";
  const legacyWrapper = legacyInput.closest<HTMLElement>("label") || legacyInput.parentElement;
  if (legacyWrapper) {
    legacyWrapper.classList.add("hidden", "legacy-default-access-field");
    legacyWrapper.style.display = "none";
  }

  // Access Profiles section.
  let profilesSection = card.querySelector<HTMLElement>(".profiles-section");

  if (!profilesSection) {
    profilesSection = document.createElement("section");
    profilesSection.className = "profiles-section";
    profilesSection.innerHTML = `
      <div class="profiles-header">
        <div>
          <h3>Access Profiles</h3>
          <p>Keep SafeBox simple: add a profile only when you need separate access.</p>
        </div>
        <button id="addProfileBtn" class="mini-btn" type="button">+ Add profile</button>
      </div>
      <div id="settingsProfilesList" class="profiles-list"></div>
      <p class="settings-note">Profile codes are kept only for this app session. Profile names and labels are saved.</p>
    `;
  } else {
    let list = profilesSection.querySelector("#settingsProfilesList");
    if (!list) {
      list = document.createElement("div");
      list.id = "settingsProfilesList";
      list.className = "profiles-list";
      profilesSection.appendChild(list);
    }

    if (!profilesSection.querySelector("#addProfileBtn")) {
      const button = document.createElement("button");
      button.id = "addProfileBtn";
      button.className = "mini-btn";
      button.type = "button";
      button.textContent = "+ Add profile";
      profilesSection.querySelector(".profiles-header")?.appendChild(button);
    }
  }

  profilesPanel.appendChild(profilesSection);

  try {
    renderAccessProfilesSettings();
  } catch (error) {
    console.warn("renderAccessProfilesSettings failed", error);
  }

  // Security content.
  let useGlobalWrapper = document.querySelector<HTMLInputElement>("#settingsUseGlobalCode")?.closest<HTMLElement>("label") || null;

  if (!useGlobalWrapper) {
    useGlobalWrapper = document.createElement("label");
    useGlobalWrapper.className = "settings-check checkline";
    useGlobalWrapper.innerHTML = `
      <input id="settingsUseGlobalCode" type="checkbox" />
      <span>Use global code by default</span>
    `;
  }

  const useGlobal = useGlobalWrapper.querySelector<HTMLInputElement>("#settingsUseGlobalCode");
  if (useGlobal) useGlobal.checked = settingsNow.useGlobalCode;

  securityPanel.appendChild(useGlobalWrapper);

  let globalCodeInput = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
  let globalCodeWrapper = globalCodeInput?.closest<HTMLElement>("label") || null;

  if (!globalCodeInput || !globalCodeWrapper) {
    globalCodeWrapper = document.createElement("label");
    globalCodeWrapper.innerHTML = `
      Global code
      <div class="password-action-row password-field">
        <input id="settingsGlobalCode" type="password" placeholder="Enter global code" autocomplete="new-password" />
        <button id="toggleGlobalCodeBtn" class="password-eye-btn" type="button" data-password-target="settingsGlobalCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
      </div>
    `;
  }

  globalCodeInput = globalCodeWrapper.querySelector<HTMLInputElement>("#settingsGlobalCode");
  if (globalCodeInput) {
    try {
      globalCodeInput.value = getGlobalCode();
    } catch {
      globalCodeInput.value = "";
    }
    globalCodeInput.type = "password";
  }

  const restoredPasswordRow = globalCodeWrapper.querySelector<HTMLElement>(".password-action-row");
  restoredPasswordRow?.classList.add("password-field");
  const restoredToggle = globalCodeWrapper.querySelector<HTMLButtonElement>("#toggleGlobalCodeBtn");
  if (restoredToggle && globalCodeInput) {
    restoredToggle.className = "password-eye-btn";
    restoredToggle.dataset.passwordTarget = "settingsGlobalCode";
    sbxSyncPasswordEye(restoredToggle, globalCodeInput);
  }

  securityPanel.appendChild(globalCodeWrapper);

  let clearBtn = document.querySelector<HTMLButtonElement>("#clearGlobalCodeBtn");

  if (!clearBtn) {
    clearBtn = document.createElement("button");
    clearBtn.id = "clearGlobalCodeBtn";
    clearBtn.className = "mini-btn danger-link";
    clearBtn.type = "button";
    clearBtn.textContent = "Clear global code";
  }

  securityPanel.appendChild(clearBtn);

  Array.from(card.querySelectorAll<HTMLElement>(".settings-note"))
    .filter((note) => (note.textContent || "").toLowerCase().includes("global code"))
    .forEach((note) => note.remove());

  // Delegated actions for restored/new buttons.
  modal.onclick = (event) => {
    const target = event.target as HTMLElement | null;

    const tabButton = target?.closest<HTMLButtonElement>(".settings-tab-button");
    if (tabButton) {
      event.preventDefault();
      event.stopPropagation();
      activate(tabButton.dataset.tab || "general");
      return;
    }

    if (target?.closest("#addProfileBtn")) {
      event.preventDefault();
      event.stopPropagation();
      try {
        addAccessProfileCard();
      } catch (error) {
        console.error("addAccessProfileCard failed", error);
      }
      return;
    }

    if (target?.closest("#toggleGlobalCodeBtn")) {
      event.preventDefault();
      event.stopPropagation();

      const input = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      const button = document.querySelector<HTMLButtonElement>("#toggleGlobalCodeBtn");

      if (input && button) {
        input.type = input.type === "password" ? "text" : "password";
        sbxSyncPasswordEye(button, input);
      }
      return;
    }

    if (target?.closest("#clearGlobalCodeBtn")) {
      const input = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      if (input) input.value = "";
      return;
    }
  };

  // Make sure the initial visible tab shows real content.
  activate("general");
}

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxSettingsContentRestore, 20);
  setTimeout(sbxSettingsContentRestore, 100);
  setTimeout(sbxSettingsContentRestore, 280);
});

setTimeout(sbxSettingsContentRestore, 400);

console.debug("settings-content-restore-general-profiles-security-v1");


function ensureAccessProfileEditorModal() {
  if (document.querySelector("#accessProfileEditorModal")) return;

  const modal = document.createElement("div");
  modal.id = "accessProfileEditorModal";
  modal.className = "modal-backdrop hidden access-profile-editor-modal";
  modal.innerHTML = `
    <section class="settings-modal access-profile-editor-card" role="dialog" aria-modal="true">
      <div class="modal-head">
        <div>
          <h2 id="profileEditorTitle">Access Profile</h2>
          <p>Use profiles only when you need separate access.</p>
        </div>
        <button id="closeProfileEditorBtn" class="icon-btn" type="button">×</button>
      </div>

      <div class="access-profile-editor-body">
        <input id="profileEditorId" type="hidden" />

        <label>
          Name in SafeBox
          <input id="profileEditorName" placeholder="Private / Work / Family" autocomplete="off" />
        </label>

        <label>
          Shown in File info
          <input id="profileEditorAccess" placeholder="Private / Work / Family" autocomplete="off" />
        </label>

        <label>
          Sender label
          <input id="profileEditorSender" placeholder="optional, uses global sender if empty" autocomplete="off" />
        </label>

        <label>
          Code
          <div class="password-action-row password-field">
            <input id="profileEditorCode" type="password" placeholder="Enter profile code" autocomplete="new-password" />
            <button id="toggleProfileEditorCodeBtn" class="password-eye-btn" type="button" data-password-target="profileEditorCode" aria-label="Show password" title="Show password" aria-pressed="false"></button>
          </div>
        </label>

        <p class="settings-note">Profile codes are kept only for this app session. Profile names and labels are saved.</p>
      </div>

      <div class="settings-actions profile-editor-actions">
        <button id="saveProfileEditorBtn" class="primary-btn" type="button">Save profile</button>
        <button id="cancelProfileEditorBtn" class="mini-btn" type="button">Cancel</button>
      </div>
    </section>
  `;

  document.body.appendChild(modal);
  sbxSyncAllPasswordEyes(modal);

  const close = () => modal.classList.add("hidden");

  modal.querySelector("#closeProfileEditorBtn")?.addEventListener("click", close);
  modal.querySelector("#cancelProfileEditorBtn")?.addEventListener("click", close);

  modal.addEventListener("click", (event) => {
    if (event.target === modal) close();
  });

  modal.querySelector("#saveProfileEditorBtn")?.addEventListener("click", () => {
    saveAccessProfileEditor();
  });
}

function openAccessProfileEditor(profileId?: string) {
  ensureAccessProfileEditorModal();

  const modal = document.querySelector<HTMLElement>("#accessProfileEditorModal");
  if (!modal) return;

  const profiles = readAccessProfiles();
  const existing = profileId ? profiles.find((profile) => profile.id === profileId) : null;
  const suggestedName = profiles.length ? `Profile ${profiles.length + 1}` : "Private";
  const id = existing?.id || makeProfileId();
  const profileName = existing?.profileName || suggestedName;
  const accessLabel = existing?.accessLabel || profileName;
  const senderLabel = existing?.senderLabel || settings.globalSenderLabel || "";
  const code = existing ? getProfileCode(existing.id) : "";

  const setValue = (selector: string, value: string) => {
    const input = modal.querySelector<HTMLInputElement>(selector);
    if (input) input.value = value;
  };

  const title = modal.querySelector<HTMLElement>("#profileEditorTitle");
  if (title) title.textContent = existing ? "Edit Access Profile" : "New Access Profile";

  setValue("#profileEditorId", id);
  setValue("#profileEditorName", profileName);
  setValue("#profileEditorAccess", accessLabel);
  setValue("#profileEditorSender", senderLabel);
  setValue("#profileEditorCode", code);

  const codeInput = modal.querySelector<HTMLInputElement>("#profileEditorCode");
  const toggleButton = modal.querySelector<HTMLButtonElement>("#toggleProfileEditorCodeBtn");
  if (codeInput) codeInput.type = "password";
  if (toggleButton && codeInput) sbxSyncPasswordEye(toggleButton, codeInput);

  modal.classList.remove("hidden");

  setTimeout(() => {
    modal.querySelector<HTMLInputElement>("#profileEditorName")?.focus();
  }, 80);
}

function saveAccessProfileEditor() {
  const modal = document.querySelector<HTMLElement>("#accessProfileEditorModal");
  if (!modal) return;

  const value = (selector: string) => modal.querySelector<HTMLInputElement>(selector)?.value || "";

  const id = cleanPublicInput(value("#profileEditorId")) || makeProfileId();
  const profileName = cleanPublicInput(value("#profileEditorName")) || "Profile";
  const accessLabel = cleanPublicInput(value("#profileEditorAccess")) || profileName;
  const senderLabel = cleanPublicInput(value("#profileEditorSender"));
  const code = value("#profileEditorCode").trim();

  const profiles = readAccessProfiles();
  const index = profiles.findIndex((profile) => profile.id === id);

  const nextProfile: AccessProfile = {
    id,
    profileName,
    senderLabel,
    accessLabel
  };

  if (index >= 0) {
    profiles[index] = nextProfile;
  } else {
    profiles.push(nextProfile);
  }

  writeAccessProfiles(profiles);
  setProfileCode(id, code);

  const currentSettings = readSettings();

  if (!currentSettings.defaultAccessProfile || !profiles.some((profile) => profile.id === currentSettings.defaultAccessProfile)) {
    settings = {
      ...currentSettings,
      defaultAccessProfile: id
    };
    writeSettings(settings);
  } else {
    settings = currentSettings;
  }

  renderAccessProfilesSettings();
  renderCreateProfileSelect();

  modal.classList.add("hidden");
}

function deleteCompactAccessProfile(profileId: string) {
  const profiles = readAccessProfiles().filter((profile) => profile.id !== profileId);

  setProfileCode(profileId, "");
  writeAccessProfiles(profiles);

  const currentSettings = readSettings();

  if (currentSettings.defaultAccessProfile === profileId) {
    settings = {
      ...currentSettings,
      defaultAccessProfile: profiles[0]?.id || ""
    };
    writeSettings(settings);
  } else {
    settings = currentSettings;
  }

  renderAccessProfilesSettings();
  renderCreateProfileSelect();
}

function setCompactAccessProfileDefault(profileId: string) {
  const profiles = readAccessProfiles();

  if (!profiles.some((profile) => profile.id === profileId)) return;

  settings = {
    ...readSettings(),
    defaultAccessProfile: profileId
  };

  writeSettings(settings);
  renderAccessProfilesSettings();
  renderCreateProfileSelect();
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    const addButton = target?.closest<HTMLButtonElement>("#addProfileBtn");
    if (addButton) {
      event.preventDefault();
      event.stopPropagation();
      openAccessProfileEditor();
      return;
    }

    const compactRow = target?.closest<HTMLElement>(".compact-profile-row");
    if (!compactRow) return;

    const profileId = compactRow.dataset.profileId || "";

    if (target?.closest(".compact-profile-edit")) {
      event.preventDefault();
      event.stopPropagation();
      openAccessProfileEditor(profileId);
      return;
    }

    if (target?.closest(".compact-profile-set-default")) {
      event.preventDefault();
      event.stopPropagation();
      setCompactAccessProfileDefault(profileId);
      return;
    }

    if (target?.closest(".compact-profile-delete")) {
      event.preventDefault();
      event.stopPropagation();
      deleteCompactAccessProfile(profileId);
    }
  },
  true
);

function SAFEBOX_COMPACT_ACCESS_PROFILES_MARKER() {
  return "compact-access-profiles-edit-modal";
}

console.debug(SAFEBOX_COMPACT_ACCESS_PROFILES_MARKER());

// UX FIX — Hide main Create "Access profile" when no Access Profiles exist
// Marker: hide-main-access-profile-when-empty-v1
function sbxHideMainAccessProfileWhenEmpty() {
  let profiles: AccessProfile[] = [];

  try {
    profiles = readAccessProfiles();
  } catch {
    profiles = [];
  }

  const hasProfiles = profiles.length > 0;

  const hideNode = (node: HTMLElement) => {
    node.dataset.sbxHiddenEmptyProfiles = "1";
    node.classList.add("hidden", "sbx-hide-main-access-profile");
    node.style.display = "none";
  };

  const showNode = (node: HTMLElement) => {
    if (node.dataset.sbxHiddenEmptyProfiles !== "1") return;

    delete node.dataset.sbxHiddenEmptyProfiles;
    node.classList.remove("hidden", "sbx-hide-main-access-profile");
    node.style.display = "";
  };

  document.querySelectorAll<HTMLSelectElement>("#createProfileSelect").forEach((select) => {
    const wrapper =
      select.closest<HTMLElement>("label") ||
      select.closest<HTMLElement>(".field") ||
      select.closest<HTMLElement>(".form-row") ||
      select.closest<HTMLElement>(".input-group") ||
      select.parentElement;

    select.disabled = !hasProfiles;

    if (!wrapper) return;

    if (!hasProfiles) {
      select.innerHTML = "";
      hideNode(wrapper);
    } else {
      showNode(wrapper);
    }
  });

  document
    .querySelectorAll<HTMLElement>("label, .field, .form-row, .input-group, .create-field")
    .forEach((node) => {
      if (
        node.closest("#settingsModal") ||
        node.closest("#accessProfileEditorModal") ||
        node.closest("#hardReceiverOverlay")
      ) {
        return;
      }

      const nodeText = (node.textContent || "").trim().toLowerCase();
      const hasSelect = !!node.querySelector("select");

      if (hasSelect && nodeText.includes("access profile")) {
        if (!hasProfiles) {
          hideNode(node);
        } else {
          showNode(node);
        }
      }
    });
}

document.addEventListener(
  "click",
  () => {
    setTimeout(sbxHideMainAccessProfileWhenEmpty, 50);
    setTimeout(sbxHideMainAccessProfileWhenEmpty, 250);
  },
  true
);

setTimeout(sbxHideMainAccessProfileWhenEmpty, 100);
setTimeout(sbxHideMainAccessProfileWhenEmpty, 500);
scheduleDesktopMaintenance(sbxHideMainAccessProfileWhenEmpty, 1000);

console.debug("hide-main-access-profile-when-empty-v1");


// HARD UX FIX — Access Profiles must be empty by default
// Marker: force-empty-access-profiles-v1
function sbxForceEmptyAccessProfilesOnce() {
  const resetKey = "safebox.accessProfiles.emptyDefault.v1";
  const profilesKey = "safebox.accessProfiles.v1";

  if (localStorage.getItem(resetKey) === "1") return;

  localStorage.setItem(profilesKey, "[]");
  localStorage.setItem(resetKey, "1");

  profileCodeMemory.clear();

  try {
    settings = {
      ...readSettings(),
      defaultAccessProfile: ""
    };
    writeSettings(settings);
  } catch {}

  try {
    renderAccessProfilesSettings();
    renderCreateProfileSelect();
    sbxHideMainAccessProfileWhenEmpty();
  } catch {}
}

setTimeout(sbxForceEmptyAccessProfilesOnce, 50);
setTimeout(sbxForceEmptyAccessProfilesOnce, 300);
console.debug("force-empty-access-profiles-v1");

// SafeBox Sprint 9B — Professional How To Use modal
// Marker: sprint9b-how-to-use-safebox-v1
type SbxHowToLang = "en" | "fr" | "de" | "hr" | "es" | "ar";
type SbxHowToBlock = { title: string; items: string[] };
type SbxHowToContent = { help: string; title: string; subtitle: string; close: string; blocks: SbxHowToBlock[] };

const SBX_HOWTO: Record<SbxHowToLang, SbxHowToContent> = {
  en: { help: "Help", title: "How to Use SafeBox", subtitle: "Create, send and unlock encrypted .sbx files safely.", close: "Close", blocks: [
    { title: "What is SafeBox?", items: ["SafeBox creates an encrypted file with the .sbx extension.", "The receiver only sees the .sbx file until the correct code is entered.", "The original filename, extension and content stay hidden before unlock."] },
    { title: "Create a SafeBox file", items: ["Choose a file, enter a code, then create the SafeBox file.", "By default, the SafeBox name follows the original file name. You can change it before creation.", "Use a strong code and send it through a different channel than the .sbx file."] },
    { title: "Send a .sbx file", items: ["Send it like any normal file: email, USB, AirDrop, cloud drive or messenger.", "The receiver does not need an online account to unlock it.", "Do not send the unlock code in the same message as the .sbx file."] },
    { title: "Unlock a received .sbx file", items: ["Open the .sbx file with SafeBox, enter the code, then press Unlock.", "After a successful unlock, the original file is restored.", "By default, SafeBox keeps the .sbx after unlock. You can change this in Advanced."] },
    { title: "File info", items: ["Before unlock, the receiver screen stays minimal.", "Optional public information appears only inside File info.", "File info is public metadata, not secret encrypted content."] },
    { title: "Access Profiles", items: ["Access Profiles are optional.", "Keep them empty for a simple workflow.", "Add a profile only when you need separate access for family, work, clients or private files."] },
    { title: "Security notes", items: ["SafeBox protects file content with encryption and a code.", "Security depends on the strength and secrecy of the code.", "Share the code separately and avoid obvious words, names or dates."] },
    { title: "macOS .sbx files", items: ["SafeBox registers .sbx as a macOS file type.", "Double-clicking a .sbx should open SafeBox in receiver mode.", "Finder may cache icons and file associations after updates."] },
    { title: "Storage & burn notes", items: ["Global code and profile codes are kept in memory for the current app session.", "Keep SBX after unlock is enabled by default.", "If you disable it, SafeBox removes the local .sbx only after a successful restore."] }
  ]},
  fr: { help: "Aide", title: "Comment utiliser SafeBox", subtitle: "Créer, envoyer et ouvrir des fichiers chiffrés .sbx.", close: "Fermer", blocks: [
    { title: "Qu’est-ce que SafeBox ?", items: ["SafeBox crée un fichier chiffré avec l’extension .sbx.", "Le destinataire voit seulement le fichier .sbx tant que le bon code n’est pas entré.", "Le nom original, l’extension et le contenu restent cachés avant le déverrouillage."] },
    { title: "Créer un fichier SafeBox", items: ["Choisissez un fichier, entrez un code, puis créez le fichier SafeBox.", "Par défaut, le nom SafeBox reprend le nom du fichier original. Vous pouvez le modifier avant la création.", "Utilisez un code fort et envoyez-le par un autre canal que le fichier .sbx."] },
    { title: "Envoyer un fichier .sbx", items: ["Envoyez le .sbx comme un fichier normal : email, USB, AirDrop, cloud ou messagerie.", "Le destinataire n’a pas besoin d’un compte en ligne pour l’ouvrir.", "N’envoyez pas le code dans le même message que le fichier .sbx."] },
    { title: "Ouvrir un .sbx reçu", items: ["Ouvrez le .sbx avec SafeBox, entrez le code, puis cliquez sur Unlock.", "Après un déverrouillage réussi, le fichier original est restauré.", "Par défaut, SafeBox conserve le .sbx après le déverrouillage. Vous pouvez modifier ce choix dans Advanced."] },
    { title: "File info", items: ["Avant le code, l’écran destinataire reste minimal.", "Les informations publiques optionnelles apparaissent seulement dans File info.", "File info est une métadonnée publique, pas un contenu secret chiffré."] },
    { title: "Access Profiles", items: ["Les Access Profiles sont optionnels.", "Laissez-les vides pour un flux simple.", "Ajoutez un profil seulement pour un accès séparé : famille, travail, clients ou fichiers privés."] },
    { title: "Notes de sécurité", items: ["SafeBox protège le contenu avec chiffrement et code.", "La sécurité dépend de la force et du secret du code.", "Envoyez le code séparément et évitez les mots, noms ou dates évidents."] },
    { title: "Fichiers .sbx sur macOS", items: ["SafeBox enregistre .sbx comme type de fichier macOS.", "Un double-clic sur un .sbx doit ouvrir SafeBox en mode destinataire.", "Finder peut garder d’anciens caches d’icône ou d’association après update."] },
    { title: "Stockage et suppression", items: ["Le code global et les codes de profils restent en mémoire pendant la session actuelle.", "Keep SBX after unlock est activé par défaut.", "Si vous le désactivez, SafeBox supprime le .sbx local seulement après une restauration réussie."] }
  ]},
  de: { help: "Hilfe", title: "SafeBox verwenden", subtitle: "Verschlüsselte .sbx-Dateien erstellen, senden und öffnen.", close: "Schliessen", blocks: [
    { title: "Was ist SafeBox?", items: ["SafeBox erstellt eine verschlüsselte Datei mit der Endung .sbx.", "Der Empfänger sieht nur die .sbx-Datei bis der richtige Code eingegeben wird.", "Originalname, Endung und Inhalt bleiben vor dem Entsperren verborgen."] },
    { title: "Datei erstellen", items: ["Datei wählen, Code eingeben und SafeBox-Datei erstellen.", "Standardmässig übernimmt SafeBox den Namen der Originaldatei. Du kannst ihn vor der Erstellung ändern.", "Sende den Code getrennt von der .sbx-Datei."] },
    { title: "Senden", items: ["Sende die .sbx wie eine normale Datei: E-Mail, USB, AirDrop, Cloud oder Messenger.", "Der Empfänger braucht kein Online-Konto.", "Sende den Code nicht in derselben Nachricht."] },
    { title: "Öffnen", items: ["Öffne die .sbx mit SafeBox, gib den Code ein und klicke Unlock.", "Danach wird die Originaldatei wiederhergestellt.", "Standardmäßig behält SafeBox die .sbx nach dem Entsperren. Dies kann unter Advanced geändert werden."] },
    { title: "File info", items: ["Vor dem Code bleibt der Empfängerbildschirm minimal.", "Optionale öffentliche Infos erscheinen nur in File info.", "File info ist öffentliche Metadaten."] },
    { title: "Access Profiles", items: ["Access Profiles sind optional.", "Leer lassen für einfache Nutzung.", "Nur hinzufügen, wenn getrennte Zugänge nötig sind."] },
    { title: "Sicherheit", items: ["SafeBox schützt den Inhalt mit Verschlüsselung und Code.", "Sicherheit hängt von Stärke und Geheimhaltung des Codes ab.", "Code getrennt senden und offensichtliche Daten vermeiden."] },
    { title: "macOS .sbx", items: ["SafeBox registriert .sbx als macOS-Dateityp.", "Doppelklick soll SafeBox im Empfängermodus öffnen.", "Finder kann Icons und Zuordnungen cachen."] },
    { title: "Speicher- und Löschhinweise", items: ["Global- und Profilcodes bleiben für die aktuelle Sitzung im Speicher.", "Keep SBX after unlock ist standardmäßig aktiviert.", "Wenn es deaktiviert wird, löscht SafeBox die lokale .sbx erst nach erfolgreicher Wiederherstellung."] }
  ]},
  hr: { help: "Pomoć", title: "Kako koristiti SafeBox", subtitle: "Kreiranje, slanje i otvaranje šifriranih .sbx datoteka.", close: "Zatvori", blocks: [
    { title: "Što je SafeBox?", items: ["SafeBox stvara šifriranu datoteku s nastavkom .sbx.", "Primatelj vidi samo .sbx dok ne unese točan kod.", "Originalni naziv, ekstenzija i sadržaj ostaju skriveni prije otključavanja."] },
    { title: "Kreiranje", items: ["Odaberi datoteku, unesi kod i kreiraj SafeBox.", "SafeBox prema zadanim postavkama preuzima naziv izvorne datoteke. Možeš ga promijeniti prije kreiranja.", "Kod pošalji drugim kanalom od .sbx datoteke."] },
    { title: "Slanje", items: ["Pošalji .sbx kao normalnu datoteku: email, USB, AirDrop, cloud ili messenger.", "Primatelju ne treba online račun.", "Nemoj slati kod u istoj poruci."] },
    { title: "Otvaranje", items: ["Otvori .sbx sa SafeBoxom, unesi kod i klikni Unlock.", "Originalna datoteka se vraća nakon uspješnog otključavanja.", "SafeBox po zadanim postavkama zadržava .sbx nakon otključavanja. To se može promijeniti u Advanced."] },
    { title: "File info", items: ["Prije koda ekran primatelja ostaje minimalan.", "Javne informacije vide se samo u File info.", "File info nije tajni šifrirani sadržaj."] },
    { title: "Access Profiles", items: ["Access Profiles su opcionalni.", "Ostavi ih prazne za jednostavan rad.", "Dodaj profil samo za odvojeni pristup."] },
    { title: "Sigurnost", items: ["SafeBox štiti sadržaj šifriranjem i kodom.", "Sigurnost ovisi o jačini i tajnosti koda.", "Kod šalji odvojeno i izbjegavaj očite riječi ili datume."] },
    { title: "macOS .sbx", items: ["SafeBox registrira .sbx kao macOS tip datoteke.", "Dvoklik na .sbx treba otvoriti receiver mode.", "Finder može zadržati cache nakon updatea."] },
    { title: "Pohrana i brisanje", items: ["Globalni i profilni kodovi ostaju u memoriji tijekom trenutne sesije.", "Keep SBX after unlock je uključeno po zadanim postavkama.", "Ako ga isključiš, SafeBox briše lokalni .sbx tek nakon uspješne obnove."] }
  ]},
  es: { help: "Ayuda", title: "Cómo usar SafeBox", subtitle: "Crear, enviar y abrir archivos cifrados .sbx.", close: "Cerrar", blocks: [
    { title: "¿Qué es SafeBox?", items: ["SafeBox crea un archivo cifrado .sbx.", "El receptor solo ve el .sbx hasta introducir el código correcto.", "Nombre original, extensión y contenido quedan ocultos antes de abrir."] },
    { title: "Crear", items: ["Elige archivo, introduce código y crea SafeBox.", "Por defecto, SafeBox usa el nombre del archivo original. Puedes cambiarlo antes de crear el archivo.", "Envía el código por otro canal."] },
    { title: "Enviar", items: ["Envía .sbx como archivo normal: email, USB, AirDrop, nube o messenger.", "El receptor no necesita cuenta online.", "No envíes el código junto al archivo."] },
    { title: "Abrir", items: ["Abre .sbx con SafeBox, introduce código y pulsa Unlock.", "Se restaura el archivo original.", "Por defecto, SafeBox conserva el .sbx después de desbloquearlo. Esto se puede cambiar en Advanced."] },
    { title: "File info", items: ["La pantalla del receptor queda mínima.", "Información pública aparece solo en File info.", "No es contenido secreto cifrado."] },
    { title: "Access Profiles", items: ["Son opcionales.", "Déjalos vacíos para uso simple.", "Añade perfiles solo para accesos separados."] },
    { title: "Seguridad", items: ["SafeBox protege con cifrado y código.", "La seguridad depende del código.", "Comparte el código por separado."] },
    { title: "macOS .sbx", items: ["SafeBox registra .sbx en macOS.", "Doble clic abre receiver mode.", "Finder puede guardar caché."] },
    { title: "Almacenamiento y borrado", items: ["El código global y los códigos de perfil permanecen en memoria durante la sesión actual.", "Keep SBX after unlock está activado por defecto.", "Si se desactiva, SafeBox elimina el .sbx local solo después de una restauración correcta."] }
  ]},
  ar: { help: "مساعدة", title: "طريقة استخدام SafeBox", subtitle: "إنشاء وإرسال وفتح ملفات .sbx مشفرة.", close: "إغلاق", blocks: [
    { title: "ما هو SafeBox؟", items: ["SafeBox ينشئ ملفاً مشفراً بامتداد .sbx.", "المستلم يرى ملف .sbx فقط حتى إدخال الكود الصحيح.", "الاسم والامتداد والمحتوى الأصلي تبقى مخفية قبل الفتح."] },
    { title: "إنشاء ملف", items: ["اختر ملفاً، أدخل الكود، ثم أنشئ SafeBox.", "يستخدم SafeBox اسم الملف الأصلي افتراضياً، ويمكنك تغييره قبل الإنشاء.", "أرسل الكود عبر قناة مختلفة."] },
    { title: "إرسال .sbx", items: ["أرسل .sbx كأي ملف عادي: بريد، USB، AirDrop، cloud أو messenger.", "لا يحتاج المستلم إلى حساب أونلاين.", "لا ترسل الكود مع نفس الرسالة."] },
    { title: "فتح ملف", items: ["افتح .sbx مع SafeBox، أدخل الكود واضغط Unlock.", "يتم استرجاع الملف الأصلي بعد النجاح.", "بشكل افتراضي يحتفظ SafeBox بملف .sbx بعد فتحه. يمكن تغيير ذلك من Advanced."] },
    { title: "File info", items: ["قبل الكود تبقى شاشة المستلم بسيطة.", "المعلومات العامة تظهر فقط داخل File info.", "ليست محتوى سرياً مشفراً."] },
    { title: "Access Profiles", items: ["اختياري.", "اتركه فارغاً للاستعمال البسيط.", "أضف بروفايل فقط عند الحاجة لوصول منفصل."] },
    { title: "الأمان", items: ["SafeBox يحمي المحتوى بالتشفير والكود.", "الأمان يعتمد على قوة وسرية الكود.", "أرسل الكود بشكل منفصل."] },
    { title: "macOS .sbx", items: ["SafeBox يسجل .sbx كنوع ملف macOS.", "النقر مرتين يفتح وضع المستلم.", "Finder قد يحتفظ بالكاش."] },
    { title: "ملاحظات التخزين والحذف", items: ["يبقى الكود العام وأكواد الملفات في الذاكرة خلال جلسة التطبيق الحالية.", "خيار Keep SBX after unlock مفعّل افتراضياً.", "عند تعطيله يحذف SafeBox ملف .sbx المحلي فقط بعد استعادة ناجحة."] }
  ]}
};

function sbxHowToLang(): SbxHowToLang {
  const stored = localStorage.getItem("safebox.language.v1") || "auto";
  const raw = stored === "auto" ? navigator.language : stored;
  const l = raw.toLowerCase();
  if (l.startsWith("fr")) return "fr";
  if (l.startsWith("de")) return "de";
  if (l.startsWith("hr") || l.startsWith("sr") || l.startsWith("bs")) return "hr";
  if (l.startsWith("es")) return "es";
  if (l.startsWith("ar")) return "ar";
  return "en";
}

function sbxHowToEsc(v: string) {
  return v.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function sbxHowToContent() {
  return SBX_HOWTO[sbxHowToLang()] || SBX_HOWTO.en;
}

function ensureHowToUseButton() {
  let b = document.querySelector<HTMLButtonElement>("#howToUseBtn");
  if (!b) {
    b = document.createElement("button");
    b.id = "howToUseBtn";
    b.className = "mini-btn how-to-use-btn";
    b.type = "button";
    const target =
      document.querySelector<HTMLElement>("#settingsUtilities") ||
      document.querySelector<HTMLElement>('#settingsModal .settings-tab-panel[data-panel="general"]') ||
      document.querySelector<HTMLElement>("#settingsModal .settings-modal");
    if (!target) return b;
    target.appendChild(b);
  }
  b.textContent = sbxHowToContent().help;
  return b;
}

function ensureHowToUseModal() {
  let m = document.querySelector<HTMLElement>("#howToUseModal");
  if (!m) {
    m = document.createElement("div");
    m.id = "howToUseModal";
    m.className = "modal-backdrop hidden how-to-use-modal";
    document.body.appendChild(m);
    m.addEventListener("click", (event) => { if (event.target === m) m?.classList.add("hidden"); });
  }
  return m;
}

function renderHowToUseModal() {
  const m = ensureHowToUseModal();
  const c = sbxHowToContent();
  const rtl = sbxHowToLang() === "ar";
  m.dir = rtl ? "rtl" : "ltr";
  m.innerHTML = `
    <section class="settings-modal how-to-use-card" role="dialog" aria-modal="true" aria-labelledby="howToUseTitle">
      <div class="modal-head how-to-use-head">
        <div><h2 id="howToUseTitle">${sbxHowToEsc(c.title)}</h2><p>${sbxHowToEsc(c.subtitle)}</p></div>
        <button id="closeHowToUseBtn" class="icon-btn" type="button">×</button>
      </div>
      <div class="how-to-use-body">
        ${c.blocks.map((block, index) => `
          <article class="how-to-section">
            <div class="how-to-section-number">${String(index + 1).padStart(2, "0")}</div>
            <div><h3>${sbxHowToEsc(block.title)}</h3><ul>${block.items.map(item => `<li>${sbxHowToEsc(item)}</li>`).join("")}</ul></div>
          </article>`).join("")}
      </div>
      <div class="settings-actions how-to-use-actions"><button id="closeHowToUseFooterBtn" class="primary-btn" type="button">${sbxHowToEsc(c.close)}</button></div>
    </section>`;
  m.querySelector("#closeHowToUseBtn")?.addEventListener("click", () => m.classList.add("hidden"));
  m.querySelector("#closeHowToUseFooterBtn")?.addEventListener("click", () => m.classList.add("hidden"));
}

function openHowToUseModal() {
  renderHowToUseModal();
  ensureHowToUseModal().classList.remove("hidden");
}

function initHowToUseSafeBox() {
  const b = ensureHowToUseButton();
  if (b.dataset.sbxHowToBound !== "1") {
    b.dataset.sbxHowToBound = "1";
    b.addEventListener("click", (event) => { event.preventDefault(); event.stopPropagation(); openHowToUseModal(); });
  }
  renderHowToUseModal();
}

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") document.querySelector<HTMLElement>("#howToUseModal")?.classList.add("hidden");
});

document.addEventListener("change", (event) => {
  if ((event.target as HTMLElement | null)?.id === "settingsLanguageSelect") {
    setTimeout(initHowToUseSafeBox, 50);
    setTimeout(initHowToUseSafeBox, 250);
  }
});

document.querySelector("#settingsBtn")?.addEventListener("click", () => setTimeout(initHowToUseSafeBox, 120));
setTimeout(initHowToUseSafeBox, 100);
setTimeout(initHowToUseSafeBox, 500);
scheduleDesktopMaintenance(() => {
  const b = document.querySelector<HTMLButtonElement>("#howToUseBtn");
  if (!b) initHowToUseSafeBox();
  else b.textContent = sbxHowToContent().help;
}, 1200);

console.debug("sprint9b-how-to-use-safebox-v1");




// UX FIX — Main page scrollbar must always be available when window is reduced
// Marker: main-page-scrollbar-always-v1
function sbxIsVisibleModal(selector: string) {
  const element = document.querySelector<HTMLElement>(selector);
  if (!element) return false;

  const style = window.getComputedStyle(element);

  return (
    !element.classList.contains("hidden") &&
    style.display !== "none" &&
    style.visibility !== "hidden" &&
    style.opacity !== "0"
  );
}

function sbxMainPageScrollbarGuard() {
  const anyModalOpen =
    sbxIsVisibleModal("#settingsModal") ||
    sbxIsVisibleModal("#howToUseModal") ||
    sbxIsVisibleModal("#accessProfileEditorModal") ||
    sbxIsVisibleModal("#hardReceiverOverlay");

  document.documentElement.classList.add("sbx-main-scroll-root");
  document.body.classList.add("sbx-main-scroll-ready");

  if (anyModalOpen) {
    document.body.classList.add("sbx-settings-open");
    document.documentElement.style.overflowY = "hidden";
    document.body.style.overflowY = "hidden";
    return;
  }

  document.body.classList.remove("sbx-settings-open");

  document.documentElement.style.overflowY = "scroll";
  document.documentElement.style.overflowX = "hidden";
  document.body.style.overflowY = "scroll";
  document.body.style.overflowX = "hidden";
}

window.addEventListener("resize", sbxMainPageScrollbarGuard);
window.addEventListener("orientationchange", sbxMainPageScrollbarGuard);

document.addEventListener(
  "click",
  () => {
    setTimeout(sbxMainPageScrollbarGuard, 20);
    setTimeout(sbxMainPageScrollbarGuard, 120);
    setTimeout(sbxMainPageScrollbarGuard, 350);
  },
  true
);

setTimeout(sbxMainPageScrollbarGuard, 50);
setTimeout(sbxMainPageScrollbarGuard, 300);
setTimeout(sbxMainPageScrollbarGuard, 1000);
scheduleDesktopMaintenance(sbxMainPageScrollbarGuard, 1000);

console.debug("main-page-scrollbar-always-v1");


// SafeBox Sprint 9C — Full App i18n
// Marker: sprint9c-full-app-i18n-v1

type SbxFullLocale = "en" | "fr" | "de" | "hr" | "es" | "ar" | "it" | "pt";

const SBX_FULL_I18N: Record<string, Record<string, string>> = {
  en: {
    settings: "Settings",
    help: "Help",
    theme: "Theme",
    light: "Light",
    dark: "Dark",
    create: "Create",
    createSbx: "Create SBX",
    open: "Open",
    openSbx: "Open SBX",
    openExistingSbx: "Open existing SBX",
    chooseFile: "Choose file",
    selectFile: "Select file",
    noFileSelected: "No file selected",
    code: "Code",
    enterCode: "Enter code",
    unlock: "Unlock",
    fileInfo: "File info",
    file: "File",
    from: "From",
    access: "Access",
    note: "Note",
    save: "Save",
    cancel: "Cancel",
    close: "Close",
    show: "Show",
    hide: "Hide",
    delete: "Delete",
    edit: "Edit",
    setDefault: "Set default",
    default: "Default",
    general: "General",
    accessProfiles: "Access Profiles",
    security: "Security",
    language: "Language",
    autoSystem: "Auto - System language",
    senderDefaults: "Sender defaults",
    defaultSbxName: "Default SBX name",
    globalSenderLabel: "Global sender label",
    useGlobalCode: "Use global code by default",
    globalCode: "Global code",
    clearGlobalCode: "Clear global code",
    accessProfile: "Access profile",
    noAccessProfilesYet: "No access profiles yet.",
    keepSafeBoxSimple: "Keep SafeBox simple: add a profile only when you need separate access.",
    keepSafeBoxSimpleLong: "Keep SafeBox simple: add a profile only when you need separate access for family, work, clients or private files.",
    addProfile: "+ Add profile",
    newAccessProfile: "New Access Profile",
    editAccessProfile: "Edit Access Profile",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "Shown in File info",
    senderLabel: "Sender label",
    saveProfile: "Save profile",
    profileCodesSession: "Profile codes are kept only for this app session. Profile names and labels are saved.",
    globalCodeSession: "The global code is kept in memory for the current app session.",
    keptOnlySession: "kept only for this app session",
    optionalGlobalSender: "optional, uses global sender if empty",
    howToUseSafeBox: "How to Use SafeBox",
    howToSubtitle: "Create, send and unlock encrypted .sbx files safely."
  },

  fr: {
    settings: "Paramètres",
    help: "Aide",
    theme: "Thème",
    light: "Clair",
    dark: "Sombre",
    create: "Créer",
    createSbx: "Créer SBX",
    open: "Ouvrir",
    openSbx: "Ouvrir SBX",
    openExistingSbx: "Ouvrir un SBX existant",
    chooseFile: "Choisir un fichier",
    selectFile: "Sélectionner un fichier",
    noFileSelected: "Aucun fichier sélectionné",
    code: "Code",
    enterCode: "Entrer le code",
    unlock: "Déverrouiller",
    fileInfo: "Infos fichier",
    file: "Fichier",
    from: "De",
    access: "Accès",
    note: "Note",
    save: "Enregistrer",
    cancel: "Annuler",
    close: "Fermer",
    show: "Afficher",
    hide: "Masquer",
    delete: "Supprimer",
    edit: "Modifier",
    setDefault: "Définir par défaut",
    default: "Par défaut",
    general: "Général",
    accessProfiles: "Profils d’accès",
    security: "Sécurité",
    language: "Langue",
    autoSystem: "Auto - langue du système",
    senderDefaults: "Valeurs expéditeur",
    defaultSbxName: "Nom SBX par défaut",
    globalSenderLabel: "Label expéditeur global",
    useGlobalCode: "Utiliser le code global par défaut",
    globalCode: "Code global",
    clearGlobalCode: "Effacer le code global",
    accessProfile: "Profil d’accès",
    noAccessProfilesYet: "Aucun profil d’accès pour le moment.",
    keepSafeBoxSimple: "Gardez SafeBox simple : ajoutez un profil seulement si vous avez besoin d’un accès séparé.",
    keepSafeBoxSimpleLong: "Gardez SafeBox simple : ajoutez un profil seulement si vous avez besoin d’un accès séparé pour famille, travail, clients ou fichiers privés.",
    addProfile: "+ Ajouter un profil",
    newAccessProfile: "Nouveau profil d’accès",
    editAccessProfile: "Modifier le profil d’accès",
    nameInSafeBox: "Nom dans SafeBox",
    shownInFileInfo: "Affiché dans File info",
    senderLabel: "Label expéditeur",
    saveProfile: "Enregistrer le profil",
    profileCodesSession: "Les codes de profils sont gardés seulement pour cette session. Les noms et labels sont enregistrés.",
    globalCodeSession: "Le code global reste en mémoire pendant la session actuelle.",
    keptOnlySession: "gardé seulement pour cette session",
    optionalGlobalSender: "optionnel, utilise l’expéditeur global si vide",
    howToUseSafeBox: "Comment utiliser SafeBox",
    howToSubtitle: "Créer, envoyer et ouvrir des fichiers chiffrés .sbx."
  },

  de: {
    settings: "Einstellungen",
    help: "Hilfe",
    theme: "Design",
    light: "Hell",
    dark: "Dunkel",
    create: "Erstellen",
    createSbx: "SBX erstellen",
    open: "Öffnen",
    openSbx: "SBX öffnen",
    openExistingSbx: "Bestehende SBX öffnen",
    chooseFile: "Datei wählen",
    selectFile: "Datei auswählen",
    noFileSelected: "Keine Datei ausgewählt",
    code: "Code",
    enterCode: "Code eingeben",
    unlock: "Entsperren",
    fileInfo: "Dateiinfo",
    file: "Datei",
    from: "Von",
    access: "Zugriff",
    note: "Notiz",
    save: "Speichern",
    cancel: "Abbrechen",
    close: "Schliessen",
    show: "Anzeigen",
    hide: "Verbergen",
    delete: "Löschen",
    edit: "Bearbeiten",
    setDefault: "Als Standard setzen",
    default: "Standard",
    general: "Allgemein",
    accessProfiles: "Zugriffsprofile",
    security: "Sicherheit",
    language: "Sprache",
    autoSystem: "Auto - Systemsprache",
    senderDefaults: "Absender-Standardwerte",
    defaultSbxName: "Standard-SBX-Name",
    globalSenderLabel: "Globales Absenderlabel",
    useGlobalCode: "Globalen Code standardmässig verwenden",
    globalCode: "Globaler Code",
    clearGlobalCode: "Globalen Code löschen",
    accessProfile: "Zugriffsprofil",
    noAccessProfilesYet: "Noch keine Zugriffsprofile.",
    keepSafeBoxSimple: "Halte SafeBox einfach: Füge ein Profil nur hinzu, wenn du getrennten Zugriff brauchst.",
    keepSafeBoxSimpleLong: "Halte SafeBox einfach: Füge ein Profil nur hinzu, wenn du getrennten Zugriff für Familie, Arbeit, Kunden oder private Dateien brauchst.",
    addProfile: "+ Profil hinzufügen",
    newAccessProfile: "Neues Zugriffsprofil",
    editAccessProfile: "Zugriffsprofil bearbeiten",
    nameInSafeBox: "Name in SafeBox",
    shownInFileInfo: "In File info angezeigt",
    senderLabel: "Absenderlabel",
    saveProfile: "Profil speichern",
    profileCodesSession: "Profilcodes werden nur für diese App-Sitzung gespeichert. Profilnamen und Labels werden gespeichert.",
    globalCodeSession: "Der globale Code bleibt für die aktuelle App-Sitzung im Speicher.",
    keptOnlySession: "nur für diese App-Sitzung gespeichert",
    optionalGlobalSender: "optional, nutzt globalen Absender wenn leer",
    howToUseSafeBox: "SafeBox verwenden",
    howToSubtitle: "Verschlüsselte .sbx-Dateien erstellen, senden und öffnen."
  },

  hr: {
    settings: "Postavke",
    help: "Pomoć",
    theme: "Tema",
    light: "Svijetlo",
    dark: "Tamno",
    create: "Kreiraj",
    createSbx: "Kreiraj SBX",
    open: "Otvori",
    openSbx: "Otvori SBX",
    openExistingSbx: "Otvori postojeći SBX",
    chooseFile: "Odaberi datoteku",
    selectFile: "Izaberi datoteku",
    noFileSelected: "Nijedna datoteka nije odabrana",
    code: "Kod",
    enterCode: "Unesi kod",
    unlock: "Otključaj",
    fileInfo: "Info o datoteci",
    file: "Datoteka",
    from: "Od",
    access: "Pristup",
    note: "Bilješka",
    save: "Spremi",
    cancel: "Odustani",
    close: "Zatvori",
    show: "Prikaži",
    hide: "Sakrij",
    delete: "Obriši",
    edit: "Uredi",
    setDefault: "Postavi kao zadano",
    default: "Zadano",
    general: "Općenito",
    accessProfiles: "Profili pristupa",
    security: "Sigurnost",
    language: "Jezik",
    autoSystem: "Auto - jezik sustava",
    senderDefaults: "Zadane vrijednosti pošiljatelja",
    defaultSbxName: "Zadani SBX naziv",
    globalSenderLabel: "Globalni label pošiljatelja",
    useGlobalCode: "Koristi globalni kod kao zadani",
    globalCode: "Globalni kod",
    clearGlobalCode: "Obriši globalni kod",
    accessProfile: "Profil pristupa",
    noAccessProfilesYet: "Još nema profila pristupa.",
    keepSafeBoxSimple: "Neka SafeBox ostane jednostavan: dodaj profil samo kad trebaš odvojeni pristup.",
    keepSafeBoxSimpleLong: "Neka SafeBox ostane jednostavan: dodaj profil samo kad trebaš odvojeni pristup za obitelj, posao, klijente ili privatne datoteke.",
    addProfile: "+ Dodaj profil",
    newAccessProfile: "Novi profil pristupa",
    editAccessProfile: "Uredi profil pristupa",
    nameInSafeBox: "Naziv u SafeBoxu",
    shownInFileInfo: "Prikazano u File info",
    senderLabel: "Label pošiljatelja",
    saveProfile: "Spremi profil",
    profileCodesSession: "Kodovi profila čuvaju se samo za ovu sesiju. Nazivi i labeli profila se spremaju.",
    globalCodeSession: "Globalni kod ostaje u memoriji tijekom trenutne sesije.",
    keptOnlySession: "čuva se samo za ovu sesiju",
    optionalGlobalSender: "opcionalno, koristi globalnog pošiljatelja ako je prazno",
    howToUseSafeBox: "Kako koristiti SafeBox",
    howToSubtitle: "Kreiranje, slanje i otvaranje šifriranih .sbx datoteka."
  },

  es: {
    settings: "Ajustes",
    help: "Ayuda",
    theme: "Tema",
    light: "Claro",
    dark: "Oscuro",
    create: "Crear",
    createSbx: "Crear SBX",
    open: "Abrir",
    openSbx: "Abrir SBX",
    openExistingSbx: "Abrir SBX existente",
    chooseFile: "Elegir archivo",
    selectFile: "Seleccionar archivo",
    noFileSelected: "Ningún archivo seleccionado",
    code: "Código",
    enterCode: "Introducir código",
    unlock: "Desbloquear",
    fileInfo: "Info del archivo",
    file: "Archivo",
    from: "De",
    access: "Acceso",
    note: "Nota",
    save: "Guardar",
    cancel: "Cancelar",
    close: "Cerrar",
    show: "Mostrar",
    hide: "Ocultar",
    delete: "Eliminar",
    edit: "Editar",
    setDefault: "Definir por defecto",
    default: "Por defecto",
    general: "General",
    accessProfiles: "Perfiles de acceso",
    security: "Seguridad",
    language: "Idioma",
    autoSystem: "Auto - idioma del sistema",
    senderDefaults: "Valores del remitente",
    defaultSbxName: "Nombre SBX por defecto",
    globalSenderLabel: "Etiqueta global del remitente",
    useGlobalCode: "Usar código global por defecto",
    globalCode: "Código global",
    clearGlobalCode: "Borrar código global",
    accessProfile: "Perfil de acceso",
    noAccessProfilesYet: "Aún no hay perfiles de acceso.",
    keepSafeBoxSimple: "Mantén SafeBox simple: añade un perfil solo cuando necesites acceso separado.",
    keepSafeBoxSimpleLong: "Mantén SafeBox simple: añade un perfil solo cuando necesites acceso separado para familia, trabajo, clientes o archivos privados.",
    addProfile: "+ Añadir perfil",
    newAccessProfile: "Nuevo perfil de acceso",
    editAccessProfile: "Editar perfil de acceso",
    nameInSafeBox: "Nombre en SafeBox",
    shownInFileInfo: "Mostrado en File info",
    senderLabel: "Etiqueta del remitente",
    saveProfile: "Guardar perfil",
    profileCodesSession: "Los códigos de perfil se guardan solo para esta sesión. Los nombres y etiquetas se guardan.",
    globalCodeSession: "El código global permanece en memoria durante la sesión actual.",
    keptOnlySession: "guardado solo para esta sesión",
    optionalGlobalSender: "opcional, usa el remitente global si está vacío",
    howToUseSafeBox: "Cómo usar SafeBox",
    howToSubtitle: "Crear, enviar y abrir archivos cifrados .sbx."
  },

  ar: {
    settings: "الإعدادات",
    help: "مساعدة",
    theme: "المظهر",
    light: "فاتح",
    dark: "داكن",
    create: "إنشاء",
    createSbx: "إنشاء SBX",
    open: "فتح",
    openSbx: "فتح SBX",
    openExistingSbx: "فتح SBX موجود",
    chooseFile: "اختيار ملف",
    selectFile: "تحديد ملف",
    noFileSelected: "لم يتم اختيار ملف",
    code: "الكود",
    enterCode: "أدخل الكود",
    unlock: "فتح",
    fileInfo: "معلومات الملف",
    file: "الملف",
    from: "من",
    access: "الوصول",
    note: "ملاحظة",
    save: "حفظ",
    cancel: "إلغاء",
    close: "إغلاق",
    show: "إظهار",
    hide: "إخفاء",
    delete: "حذف",
    edit: "تعديل",
    setDefault: "تعيين كافتراضي",
    default: "افتراضي",
    general: "عام",
    accessProfiles: "ملفات الوصول",
    security: "الأمان",
    language: "اللغة",
    autoSystem: "تلقائي - لغة النظام",
    senderDefaults: "إعدادات المرسل",
    defaultSbxName: "اسم SBX الافتراضي",
    globalSenderLabel: "تسمية المرسل العامة",
    useGlobalCode: "استخدام الكود العام افتراضياً",
    globalCode: "الكود العام",
    clearGlobalCode: "مسح الكود العام",
    accessProfile: "ملف الوصول",
    noAccessProfilesYet: "لا توجد ملفات وصول بعد.",
    keepSafeBoxSimple: "اجعل SafeBox بسيطاً: أضف ملف وصول فقط عندما تحتاج إلى وصول منفصل.",
    keepSafeBoxSimpleLong: "اجعل SafeBox بسيطاً: أضف ملف وصول فقط عندما تحتاج إلى وصول منفصل للعائلة أو العمل أو العملاء أو الملفات الخاصة.",
    addProfile: "+ إضافة ملف وصول",
    newAccessProfile: "ملف وصول جديد",
    editAccessProfile: "تعديل ملف الوصول",
    nameInSafeBox: "الاسم في SafeBox",
    shownInFileInfo: "يظهر في File info",
    senderLabel: "تسمية المرسل",
    saveProfile: "حفظ الملف",
    profileCodesSession: "أكواد الملفات محفوظة فقط خلال هذه الجلسة. الأسماء والتسميات يتم حفظها.",
    globalCodeSession: "يبقى الكود العام في الذاكرة خلال جلسة التطبيق الحالية.",
    keptOnlySession: "محفوظ فقط خلال هذه الجلسة",
    optionalGlobalSender: "اختياري، يستخدم المرسل العام إذا كان فارغاً",
    howToUseSafeBox: "طريقة استخدام SafeBox",
    howToSubtitle: "إنشاء وإرسال وفتح ملفات .sbx مشفرة."
  }
};

// SafeBox R86 RC8 — translation closure + IT/PT + shared language contract.
const SBX_RC8_I18N: Record<string, Record<string, string>> = {
  en: {
    "brandSubtitle": "Universal secure file format",
    "createIntro": "Any file becomes a SafeBox file.",
    "encryptedLocally": "Encrypted locally",
    "offlineCapable": "Offline-capable",
    "dropAny": "Drop any file here",
    "originalFile": "Original file",
    "choose": "Choose",
    "visibleSbxName": "Visible SBX name",
    "selectFileFirst": "Select a file first",
    "enterSenderCode": "Enter sender code",
    "accessLabel": "Access label",
    "publicNoteOptional": "Public note optional",
    "publicNoteHint": "visible before unlock, leave empty for privacy",
    "advanced": "Advanced",
    "outputDirectory": "Output directory",
    "sameFolderOriginal": "leave empty = same folder as original",
    "folder": "Folder",
    "keepSbxAfterUnlock": "Keep SBX after unlock",
    "unlockSbx": "Unlock SBX",
    "unlockIntro": "Open a SafeBox file locally.",
    "localDecryption": "Local decryption",
    "dropSbx": "Drop a SafeBox file here",
    "sbxFile": "SBX file",
    "selectSbx": "Select a .sbx file",
    "enterReceiverCode": "Enter receiver code",
    "sameFolderSbx": "leave empty = same folder as SBX",
    "replaceExisting": "Replace existing file",
    "replaceHint": "Off: keep both files. On: replace the existing file with the restored one.",
    "createNewSbx": "Create new SBX",
    "safeBoxFile": "SafeBox File",
    "type": "Type",
    "name": "Name",
    "notSet": "not set",
    "fileNaming": "File naming",
    "fileNamingText": "New SafeBox files use the original filename by default. The name can be changed before creation.",
    "defaultAccessProfile": "Default access profile",
    "enterGlobalCode": "Enter global code",
    "profileBlockText": "Each profile block contains code, sender label and access label.",
    "advertisingPrivacy": "Advertising privacy",
    "advertisingPrivacyText": "Consent is handled by Google UMP. SafeBox never sends file names, codes or file contents to ads.",
    "privacyChoices": "Privacy choices",
    "testAds": "test ads",
    "showPassword": "Show password",
    "hidePassword": "Hide password",
    "wrongCodeDamaged": "Wrong code or damaged SafeBox.",
    "damagedModified": "SafeBox damaged or modified.",
    "unsupportedVersion": "This SafeBox version is not supported.",
    "unsafeParameters": "Unsafe or unsupported SafeBox security parameters.",
    "readRestoreFailed": "Could not read or restore this file.",
    "unlockFailed": "Unlock failed.",
    "warning": "Warning:",
    "missingInformation": "Missing information.",
    "fileAndCodeRequired": "File and code are required.",
    "sbxAndCodeRequired": "SBX file and code are required.",
    "createdBrowser": "SafeBox created in your browser.",
    "created": "SafeBox created.",
    "download": "Download",
    "originalHidden": "Original hidden",
    "engine": "Engine",
    "yes": "yes",
    "output": "Output",
    "visibleName": "Visible name",
    "createFailed": "Create failed.",
    "restoredBrowser": "Original restored in your browser.",
    "restored": "Original restored.",
    "original": "Original",
    "size": "Size",
    "sbxSource": "SBX source",
    "unchangedBrowser": "unchanged by browser",
    "saved": "Saved",
    "sbxDeletedLocally": "SBX deleted locally",
    "no": "no",
    "openingPicker": "Opening Android file picker…",
    "fileReady": "File ready.",
    "saveOriginal": "Save original",
    "saving": "Saving…",
    "openOriginal": "Open original",
    "showFinder": "Show in Finder",
    "showFolder": "Show in folder",
    "senderDefaults": "Sender defaults",
    "settings": "Settings",
    "help": "Help",
    "appearance": "Appearance",
    "mode": "Mode",
    "system": "System",
    "light": "Light",
    "dark": "Dark",
    "securityWorkspace": "Secure local workspace",
    "securityWorkspaceHint": "Files and codes stay on this device unless you explicitly save or share an output."
  },
  fr: {
    "brandSubtitle": "Format de fichier sécurisé universel",
    "createIntro": "N’importe quel fichier devient un fichier SafeBox.",
    "encryptedLocally": "Chiffré localement",
    "offlineCapable": "Fonctionne hors ligne",
    "dropAny": "Déposez n’importe quel fichier ici",
    "originalFile": "Fichier original",
    "choose": "Choisir",
    "visibleSbxName": "Nom SBX visible",
    "selectFileFirst": "Sélectionnez d’abord un fichier",
    "enterSenderCode": "Entrez le code expéditeur",
    "accessLabel": "Label d’accès",
    "publicNoteOptional": "Note publique facultative",
    "publicNoteHint": "visible avant déverrouillage, laissez vide pour plus de confidentialité",
    "advanced": "Avancé",
    "outputDirectory": "Dossier de sortie",
    "sameFolderOriginal": "laisser vide = même dossier que l’original",
    "folder": "Dossier",
    "keepSbxAfterUnlock": "Conserver le SBX après déverrouillage",
    "unlockSbx": "Déverrouiller le SBX",
    "unlockIntro": "Ouvrez localement un fichier SafeBox.",
    "localDecryption": "Déchiffrement local",
    "dropSbx": "Déposez un fichier SafeBox ici",
    "sbxFile": "Fichier SBX",
    "selectSbx": "Sélectionnez un fichier .sbx",
    "enterReceiverCode": "Entrez le code du destinataire",
    "sameFolderSbx": "laisser vide = même dossier que le SBX",
    "replaceExisting": "Remplacer le fichier existant",
    "replaceHint": "Désactivé : conserver les deux fichiers. Activé : remplacer le fichier existant par le fichier restauré.",
    "createNewSbx": "Créer un nouveau SBX",
    "safeBoxFile": "Fichier SafeBox",
    "type": "Type",
    "name": "Nom",
    "notSet": "non défini",
    "fileNaming": "Nom des fichiers",
    "fileNamingText": "Les nouveaux fichiers SafeBox utilisent par défaut le nom du fichier original. Le nom peut être modifié avant la création.",
    "defaultAccessProfile": "Profil d’accès par défaut",
    "enterGlobalCode": "Entrez le code global",
    "profileBlockText": "Chaque profil contient un code, un label expéditeur et un label d’accès.",
    "advertisingPrivacy": "Confidentialité publicitaire",
    "advertisingPrivacyText": "Le consentement est géré par Google UMP. SafeBox n’envoie jamais aux annonces les noms de fichiers, codes ou contenus.",
    "privacyChoices": "Choix de confidentialité",
    "testAds": "annonces de test",
    "showPassword": "Afficher le mot de passe",
    "hidePassword": "Masquer le mot de passe",
    "wrongCodeDamaged": "Code incorrect ou SafeBox endommagé.",
    "damagedModified": "SafeBox endommagé ou modifié.",
    "unsupportedVersion": "Cette version de SafeBox n’est pas prise en charge.",
    "unsafeParameters": "Paramètres de sécurité SafeBox non sûrs ou non pris en charge.",
    "readRestoreFailed": "Impossible de lire ou restaurer ce fichier.",
    "unlockFailed": "Échec du déverrouillage.",
    "warning": "Avertissement :",
    "missingInformation": "Informations manquantes.",
    "fileAndCodeRequired": "Le fichier et le code sont requis.",
    "sbxAndCodeRequired": "Le fichier SBX et le code sont requis.",
    "createdBrowser": "SafeBox créé dans votre navigateur.",
    "created": "SafeBox créé.",
    "download": "Téléchargement",
    "originalHidden": "Original masqué",
    "engine": "Moteur",
    "yes": "oui",
    "output": "Sortie",
    "visibleName": "Nom visible",
    "createFailed": "Échec de la création.",
    "restoredBrowser": "Original restauré dans votre navigateur.",
    "restored": "Original restauré.",
    "original": "Original",
    "size": "Taille",
    "sbxSource": "Source SBX",
    "unchangedBrowser": "inchangée par le navigateur",
    "saved": "Enregistré",
    "sbxDeletedLocally": "SBX supprimé localement",
    "no": "non",
    "openingPicker": "Ouverture du sélecteur de fichiers Android…",
    "fileReady": "Fichier prêt.",
    "saveOriginal": "Enregistrer l’original",
    "saving": "Enregistrement…",
    "openOriginal": "Ouvrir l’original",
    "showFinder": "Afficher dans le Finder",
    "showFolder": "Afficher dans le dossier",
    "senderDefaults": "Valeurs par défaut de l’expéditeur",
    "settings": "Réglages",
    "help": "Aide",
    "appearance": "Apparence",
    "mode": "Mode",
    "system": "Système",
    "light": "Clair",
    "dark": "Sombre",
    "securityWorkspace": "Espace local sécurisé",
    "securityWorkspaceHint": "Les fichiers et les codes restent sur cet appareil, sauf si vous enregistrez ou partagez explicitement une sortie."
  },
  de: {
    "brandSubtitle": "Universelles sicheres Dateiformat",
    "createIntro": "Jede Datei wird zu einer SafeBox-Datei.",
    "encryptedLocally": "Lokal verschlüsselt",
    "offlineCapable": "Offline-fähig",
    "dropAny": "Beliebige Datei hier ablegen",
    "originalFile": "Originaldatei",
    "choose": "Auswählen",
    "visibleSbxName": "Sichtbarer SBX-Name",
    "selectFileFirst": "Zuerst eine Datei auswählen",
    "enterSenderCode": "Sendercode eingeben",
    "accessLabel": "Zugriffslabel",
    "publicNoteOptional": "Öffentliche Notiz optional",
    "publicNoteHint": "vor dem Entsperren sichtbar, für Privatsphäre leer lassen",
    "advanced": "Erweitert",
    "outputDirectory": "Ausgabeordner",
    "sameFolderOriginal": "leer lassen = gleicher Ordner wie Original",
    "folder": "Ordner",
    "keepSbxAfterUnlock": "SBX nach Entsperren behalten",
    "unlockSbx": "SBX entsperren",
    "unlockIntro": "SafeBox-Datei lokal öffnen.",
    "localDecryption": "Lokale Entschlüsselung",
    "dropSbx": "SafeBox-Datei hier ablegen",
    "sbxFile": "SBX-Datei",
    "selectSbx": ".sbx-Datei auswählen",
    "enterReceiverCode": "Empfängercode eingeben",
    "sameFolderSbx": "leer lassen = gleicher Ordner wie SBX",
    "replaceExisting": "Vorhandene Datei ersetzen",
    "replaceHint": "Aus: beide Dateien behalten. An: vorhandene Datei durch die wiederhergestellte ersetzen.",
    "createNewSbx": "Neue SBX erstellen",
    "safeBoxFile": "SafeBox-Datei",
    "type": "Typ",
    "name": "Name",
    "notSet": "nicht gesetzt",
    "fileNaming": "Dateibenennung",
    "fileNamingText": "Neue SafeBox-Dateien verwenden standardmäßig den Originaldateinamen. Der Name kann vor der Erstellung geändert werden.",
    "defaultAccessProfile": "Standard-Zugriffsprofil",
    "enterGlobalCode": "Globalen Code eingeben",
    "profileBlockText": "Jedes Profil enthält Code, Absenderlabel und Zugriffslabel.",
    "advertisingPrivacy": "Werbe-Datenschutz",
    "advertisingPrivacyText": "Die Einwilligung wird durch Google UMP verwaltet. SafeBox sendet niemals Dateinamen, Codes oder Dateiinhalte an Werbung.",
    "privacyChoices": "Datenschutzoptionen",
    "testAds": "Testanzeigen",
    "showPassword": "Passwort anzeigen",
    "hidePassword": "Passwort verbergen",
    "wrongCodeDamaged": "Falscher Code oder beschädigte SafeBox.",
    "damagedModified": "SafeBox beschädigt oder verändert.",
    "unsupportedVersion": "Diese SafeBox-Version wird nicht unterstützt.",
    "unsafeParameters": "Unsichere oder nicht unterstützte SafeBox-Sicherheitsparameter.",
    "readRestoreFailed": "Datei konnte nicht gelesen oder wiederhergestellt werden.",
    "unlockFailed": "Entsperren fehlgeschlagen.",
    "warning": "Warnung:",
    "missingInformation": "Angaben fehlen.",
    "fileAndCodeRequired": "Datei und Code sind erforderlich.",
    "sbxAndCodeRequired": "SBX-Datei und Code sind erforderlich.",
    "createdBrowser": "SafeBox im Browser erstellt.",
    "created": "SafeBox erstellt.",
    "download": "Download",
    "originalHidden": "Original verborgen",
    "engine": "Engine",
    "yes": "ja",
    "output": "Ausgabe",
    "visibleName": "Sichtbarer Name",
    "createFailed": "Erstellung fehlgeschlagen.",
    "restoredBrowser": "Original im Browser wiederhergestellt.",
    "restored": "Original wiederhergestellt.",
    "original": "Original",
    "size": "Größe",
    "sbxSource": "SBX-Quelle",
    "unchangedBrowser": "vom Browser unverändert",
    "saved": "Gespeichert",
    "sbxDeletedLocally": "SBX lokal gelöscht",
    "no": "nein",
    "openingPicker": "Android-Dateiauswahl wird geöffnet…",
    "fileReady": "Datei bereit.",
    "saveOriginal": "Original speichern",
    "saving": "Speichern…",
    "openOriginal": "Original öffnen",
    "showFinder": "Im Finder anzeigen",
    "showFolder": "Im Ordner anzeigen",
    "senderDefaults": "Absender-Standards",
    "settings": "Einstellungen",
    "help": "Hilfe",
    "appearance": "Darstellung",
    "mode": "Modus",
    "system": "System",
    "light": "Hell",
    "dark": "Dunkel",
    "securityWorkspace": "Sicherer lokaler Arbeitsbereich",
    "securityWorkspaceHint": "Dateien und Codes bleiben auf diesem Gerät, außer du speicherst oder teilst ausdrücklich eine Ausgabe."
  },
  hr: {
    "brandSubtitle": "Univerzalni sigurni format datoteke",
    "createIntro": "Bilo koja datoteka postaje SafeBox datoteka.",
    "encryptedLocally": "Lokalno šifrirano",
    "offlineCapable": "Radi bez interneta",
    "dropAny": "Ispusti bilo koju datoteku ovdje",
    "originalFile": "Originalna datoteka",
    "choose": "Odaberi",
    "visibleSbxName": "Vidljivi SBX naziv",
    "selectFileFirst": "Prvo odaberi datoteku",
    "enterSenderCode": "Unesi kod pošiljatelja",
    "accessLabel": "Oznaka pristupa",
    "publicNoteOptional": "Javna bilješka nije obavezna",
    "publicNoteHint": "vidljivo prije otključavanja, ostavi prazno radi privatnosti",
    "advanced": "Napredno",
    "outputDirectory": "Izlazna mapa",
    "sameFolderOriginal": "ostavi prazno = ista mapa kao original",
    "folder": "Mapa",
    "keepSbxAfterUnlock": "Zadrži SBX nakon otključavanja",
    "unlockSbx": "Otključaj SBX",
    "unlockIntro": "Otvori SafeBox datoteku lokalno.",
    "localDecryption": "Lokalno dešifriranje",
    "dropSbx": "Ispusti SafeBox datoteku ovdje",
    "sbxFile": "SBX datoteka",
    "selectSbx": "Odaberi .sbx datoteku",
    "enterReceiverCode": "Unesi kod primatelja",
    "sameFolderSbx": "ostavi prazno = ista mapa kao SBX",
    "replaceExisting": "Zamijeni postojeću datoteku",
    "replaceHint": "Isključeno: zadrži obje datoteke. Uključeno: zamijeni postojeću datoteku obnovljenom.",
    "createNewSbx": "Kreiraj novi SBX",
    "safeBoxFile": "SafeBox datoteka",
    "type": "Vrsta",
    "name": "Naziv",
    "notSet": "nije postavljeno",
    "fileNaming": "Nazivi datoteka",
    "fileNamingText": "Nove SafeBox datoteke prema zadanim postavkama koriste naziv originalne datoteke. Naziv se može promijeniti prije kreiranja.",
    "defaultAccessProfile": "Zadani profil pristupa",
    "enterGlobalCode": "Unesi globalni kod",
    "profileBlockText": "Svaki profil sadrži kod, oznaku pošiljatelja i oznaku pristupa.",
    "advertisingPrivacy": "Privatnost oglasa",
    "advertisingPrivacyText": "Privolu obrađuje Google UMP. SafeBox oglasima nikada ne šalje nazive datoteka, kodove ni sadržaj datoteka.",
    "privacyChoices": "Postavke privatnosti",
    "testAds": "testni oglasi",
    "showPassword": "Prikaži lozinku",
    "hidePassword": "Sakrij lozinku",
    "wrongCodeDamaged": "Pogrešan kod ili oštećen SafeBox.",
    "damagedModified": "SafeBox je oštećen ili izmijenjen.",
    "unsupportedVersion": "Ova verzija SafeBoxa nije podržana.",
    "unsafeParameters": "Nesigurni ili nepodržani sigurnosni parametri SafeBoxa.",
    "readRestoreFailed": "Datoteku nije moguće pročitati ili obnoviti.",
    "unlockFailed": "Otključavanje nije uspjelo.",
    "warning": "Upozorenje:",
    "missingInformation": "Nedostaju podaci.",
    "fileAndCodeRequired": "Datoteka i kod su obavezni.",
    "sbxAndCodeRequired": "SBX datoteka i kod su obavezni.",
    "createdBrowser": "SafeBox je kreiran u pregledniku.",
    "created": "SafeBox je kreiran.",
    "download": "Preuzimanje",
    "originalHidden": "Original skriven",
    "engine": "Mehanizam",
    "yes": "da",
    "output": "Izlaz",
    "visibleName": "Vidljivi naziv",
    "createFailed": "Kreiranje nije uspjelo.",
    "restoredBrowser": "Original je obnovljen u pregledniku.",
    "restored": "Original je obnovljen.",
    "original": "Original",
    "size": "Veličina",
    "sbxSource": "SBX izvor",
    "unchangedBrowser": "preglednik ga nije mijenjao",
    "saved": "Spremljeno",
    "sbxDeletedLocally": "SBX lokalno obrisan",
    "no": "ne",
    "openingPicker": "Otvaranje Android odabira datoteke…",
    "fileReady": "Datoteka je spremna.",
    "saveOriginal": "Spremi original",
    "saving": "Spremanje…",
    "openOriginal": "Otvori original",
    "showFinder": "Prikaži u Finderu",
    "showFolder": "Prikaži u mapi",
    "senderDefaults": "Zadane postavke pošiljatelja",
    "settings": "Postavke",
    "help": "Pomoć",
    "appearance": "Izgled",
    "mode": "Način",
    "system": "Sustav",
    "light": "Svijetlo",
    "dark": "Tamno",
    "securityWorkspace": "Sigurni lokalni radni prostor",
    "securityWorkspaceHint": "Datoteke i kodovi ostaju na ovom uređaju osim ako izričito spremiš ili podijeliš izlaz."
  },
  es: {
    "brandSubtitle": "Formato de archivo seguro universal",
    "createIntro": "Cualquier archivo se convierte en un archivo SafeBox.",
    "encryptedLocally": "Cifrado localmente",
    "offlineCapable": "Funciona sin conexión",
    "dropAny": "Suelta cualquier archivo aquí",
    "originalFile": "Archivo original",
    "choose": "Elegir",
    "visibleSbxName": "Nombre SBX visible",
    "selectFileFirst": "Selecciona primero un archivo",
    "enterSenderCode": "Introduce el código del remitente",
    "accessLabel": "Etiqueta de acceso",
    "publicNoteOptional": "Nota pública opcional",
    "publicNoteHint": "visible antes de desbloquear; déjalo vacío para mayor privacidad",
    "advanced": "Avanzado",
    "outputDirectory": "Carpeta de salida",
    "sameFolderOriginal": "dejar vacío = misma carpeta que el original",
    "folder": "Carpeta",
    "keepSbxAfterUnlock": "Conservar SBX después de desbloquear",
    "unlockSbx": "Desbloquear SBX",
    "unlockIntro": "Abre un archivo SafeBox localmente.",
    "localDecryption": "Descifrado local",
    "dropSbx": "Suelta un archivo SafeBox aquí",
    "sbxFile": "Archivo SBX",
    "selectSbx": "Selecciona un archivo .sbx",
    "enterReceiverCode": "Introduce el código del receptor",
    "sameFolderSbx": "dejar vacío = misma carpeta que el SBX",
    "replaceExisting": "Reemplazar archivo existente",
    "replaceHint": "Desactivado: conservar ambos archivos. Activado: reemplazar el archivo existente por el restaurado.",
    "createNewSbx": "Crear nuevo SBX",
    "safeBoxFile": "Archivo SafeBox",
    "type": "Tipo",
    "name": "Nombre",
    "notSet": "sin definir",
    "fileNaming": "Nombre de archivos",
    "fileNamingText": "Los nuevos archivos SafeBox usan por defecto el nombre del archivo original. El nombre puede cambiarse antes de la creación.",
    "defaultAccessProfile": "Perfil de acceso predeterminado",
    "enterGlobalCode": "Introduce el código global",
    "profileBlockText": "Cada perfil contiene código, etiqueta del remitente y etiqueta de acceso.",
    "advertisingPrivacy": "Privacidad publicitaria",
    "advertisingPrivacyText": "El consentimiento se gestiona con Google UMP. SafeBox nunca envía a los anuncios nombres de archivos, códigos ni contenido.",
    "privacyChoices": "Opciones de privacidad",
    "testAds": "anuncios de prueba",
    "showPassword": "Mostrar contraseña",
    "hidePassword": "Ocultar contraseña",
    "wrongCodeDamaged": "Código incorrecto o SafeBox dañado.",
    "damagedModified": "SafeBox dañado o modificado.",
    "unsupportedVersion": "Esta versión de SafeBox no es compatible.",
    "unsafeParameters": "Parámetros de seguridad SafeBox inseguros o no compatibles.",
    "readRestoreFailed": "No se pudo leer o restaurar este archivo.",
    "unlockFailed": "Error al desbloquear.",
    "warning": "Advertencia:",
    "missingInformation": "Falta información.",
    "fileAndCodeRequired": "El archivo y el código son obligatorios.",
    "sbxAndCodeRequired": "El archivo SBX y el código son obligatorios.",
    "createdBrowser": "SafeBox creado en el navegador.",
    "created": "SafeBox creado.",
    "download": "Descarga",
    "originalHidden": "Original oculto",
    "engine": "Motor",
    "yes": "sí",
    "output": "Salida",
    "visibleName": "Nombre visible",
    "createFailed": "Error al crear.",
    "restoredBrowser": "Original restaurado en el navegador.",
    "restored": "Original restaurado.",
    "original": "Original",
    "size": "Tamaño",
    "sbxSource": "Fuente SBX",
    "unchangedBrowser": "sin cambios por el navegador",
    "saved": "Guardado",
    "sbxDeletedLocally": "SBX eliminado localmente",
    "no": "no",
    "openingPicker": "Abriendo selector de archivos de Android…",
    "fileReady": "Archivo listo.",
    "saveOriginal": "Guardar original",
    "saving": "Guardando…",
    "openOriginal": "Abrir original",
    "showFinder": "Mostrar en Finder",
    "showFolder": "Mostrar en carpeta",
    "senderDefaults": "Valores predeterminados del remitente",
    "settings": "Ajustes",
    "help": "Ayuda",
    "appearance": "Apariencia",
    "mode": "Modo",
    "system": "Sistema",
    "light": "Claro",
    "dark": "Oscuro",
    "securityWorkspace": "Espacio local seguro",
    "securityWorkspaceHint": "Los archivos y códigos permanecen en este dispositivo salvo que guardes o compartas explícitamente una salida."
  },
  ar: {
    "brandSubtitle": "تنسيق ملفات آمن وعالمي",
    "createIntro": "أي ملف يمكن أن يصبح ملف SafeBox.",
    "encryptedLocally": "تشفير محلي",
    "offlineCapable": "يعمل دون اتصال",
    "dropAny": "أسقط أي ملف هنا",
    "originalFile": "الملف الأصلي",
    "choose": "اختيار",
    "visibleSbxName": "اسم SBX الظاهر",
    "selectFileFirst": "اختر ملفًا أولاً",
    "enterSenderCode": "أدخل رمز المرسل",
    "accessLabel": "تسمية الوصول",
    "publicNoteOptional": "ملاحظة عامة اختيارية",
    "publicNoteHint": "تظهر قبل الفتح، اتركها فارغة لمزيد من الخصوصية",
    "advanced": "متقدم",
    "outputDirectory": "مجلد الإخراج",
    "sameFolderOriginal": "اتركه فارغًا = نفس مجلد الأصل",
    "folder": "مجلد",
    "keepSbxAfterUnlock": "الاحتفاظ بـ SBX بعد الفتح",
    "unlockSbx": "فتح SBX",
    "unlockIntro": "افتح ملف SafeBox محليًا.",
    "localDecryption": "فك تشفير محلي",
    "dropSbx": "أسقط ملف SafeBox هنا",
    "sbxFile": "ملف SBX",
    "selectSbx": "اختر ملف .sbx",
    "enterReceiverCode": "أدخل رمز المستلم",
    "sameFolderSbx": "اتركه فارغًا = نفس مجلد SBX",
    "replaceExisting": "استبدال الملف الموجود",
    "replaceHint": "إيقاف: احتفظ بالملفين. تشغيل: استبدل الملف الموجود بالملف المستعاد.",
    "createNewSbx": "إنشاء SBX جديد",
    "safeBoxFile": "ملف SafeBox",
    "type": "النوع",
    "name": "الاسم",
    "notSet": "غير محدد",
    "fileNaming": "تسمية الملفات",
    "fileNamingText": "تستخدم ملفات SafeBox الجديدة اسم الملف الأصلي افتراضيًا، ويمكن تغيير الاسم قبل الإنشاء.",
    "defaultAccessProfile": "ملف الوصول الافتراضي",
    "enterGlobalCode": "أدخل الرمز العام",
    "profileBlockText": "يحتوي كل ملف وصول على رمز وتسمية مرسل وتسمية وصول.",
    "advertisingPrivacy": "خصوصية الإعلانات",
    "advertisingPrivacyText": "تُدار الموافقة عبر Google UMP. لا يرسل SafeBox أسماء الملفات أو الرموز أو محتوى الملفات إلى الإعلانات.",
    "privacyChoices": "خيارات الخصوصية",
    "testAds": "إعلانات اختبار",
    "showPassword": "إظهار كلمة المرور",
    "hidePassword": "إخفاء كلمة المرور",
    "wrongCodeDamaged": "رمز خاطئ أو SafeBox تالف.",
    "damagedModified": "SafeBox تالف أو تم تعديله.",
    "unsupportedVersion": "إصدار SafeBox هذا غير مدعوم.",
    "unsafeParameters": "معلمات أمان SafeBox غير آمنة أو غير مدعومة.",
    "readRestoreFailed": "تعذر قراءة هذا الملف أو استعادته.",
    "unlockFailed": "فشل الفتح.",
    "warning": "تحذير:",
    "missingInformation": "معلومات ناقصة.",
    "fileAndCodeRequired": "الملف والرمز مطلوبان.",
    "sbxAndCodeRequired": "ملف SBX والرمز مطلوبان.",
    "createdBrowser": "تم إنشاء SafeBox في المتصفح.",
    "created": "تم إنشاء SafeBox.",
    "download": "تنزيل",
    "originalHidden": "الأصل مخفي",
    "engine": "المحرك",
    "yes": "نعم",
    "output": "الإخراج",
    "visibleName": "الاسم الظاهر",
    "createFailed": "فشل الإنشاء.",
    "restoredBrowser": "تمت استعادة الأصل في المتصفح.",
    "restored": "تمت استعادة الأصل.",
    "original": "الأصل",
    "size": "الحجم",
    "sbxSource": "مصدر SBX",
    "unchangedBrowser": "لم يغيره المتصفح",
    "saved": "تم الحفظ",
    "sbxDeletedLocally": "تم حذف SBX محليًا",
    "no": "لا",
    "openingPicker": "جارٍ فتح منتقي ملفات Android…",
    "fileReady": "الملف جاهز.",
    "saveOriginal": "حفظ الأصل",
    "saving": "جارٍ الحفظ…",
    "openOriginal": "فتح الأصل",
    "showFinder": "إظهار في Finder",
    "showFolder": "إظهار في المجلد",
    "senderDefaults": "إعدادات المرسل الافتراضية",
    "settings": "الإعدادات",
    "help": "مساعدة",
    "appearance": "المظهر",
    "mode": "الوضع",
    "system": "النظام",
    "light": "فاتح",
    "dark": "داكن",
    "securityWorkspace": "مساحة عمل محلية آمنة",
    "securityWorkspaceHint": "تبقى الملفات والرموز على هذا الجهاز ما لم تحفظ أو تشارك ناتجًا بشكل صريح."
  },
  it: {
    "settings": "Impostazioni",
    "help": "Aiuto",
    "theme": "Tema",
    "light": "Chiaro",
    "dark": "Scuro",
    "create": "Crea",
    "createSbx": "Crea SBX",
    "open": "Apri",
    "openSbx": "Apri SBX",
    "openExistingSbx": "Apri SBX esistente",
    "chooseFile": "Scegli file",
    "selectFile": "Seleziona file",
    "noFileSelected": "Nessun file selezionato",
    "code": "Codice",
    "enterCode": "Inserisci codice",
    "unlock": "Sblocca",
    "fileInfo": "Informazioni file",
    "file": "File",
    "from": "Da",
    "access": "Accesso",
    "note": "Nota",
    "save": "Salva",
    "cancel": "Annulla",
    "close": "Chiudi",
    "show": "Mostra",
    "hide": "Nascondi",
    "delete": "Elimina",
    "edit": "Modifica",
    "setDefault": "Imposta predefinito",
    "default": "Predefinito",
    "general": "Generale",
    "accessProfiles": "Profili di accesso",
    "security": "Sicurezza",
    "language": "Lingua",
    "autoSystem": "Auto - lingua di sistema",
    "senderDefaults": "Impostazioni mittente",
    "defaultSbxName": "Nome SBX predefinito",
    "globalSenderLabel": "Etichetta mittente globale",
    "useGlobalCode": "Usa codice globale per impostazione predefinita",
    "globalCode": "Codice globale",
    "clearGlobalCode": "Cancella codice globale",
    "accessProfile": "Profilo di accesso",
    "noAccessProfilesYet": "Nessun profilo di accesso.",
    "keepSafeBoxSimple": "Mantieni SafeBox semplice: aggiungi un profilo solo quando serve un accesso separato.",
    "keepSafeBoxSimpleLong": "Mantieni SafeBox semplice: aggiungi un profilo solo quando serve un accesso separato per famiglia, lavoro, clienti o file privati.",
    "addProfile": "+ Aggiungi profilo",
    "newAccessProfile": "Nuovo profilo di accesso",
    "editAccessProfile": "Modifica profilo di accesso",
    "nameInSafeBox": "Nome in SafeBox",
    "shownInFileInfo": "Mostrato nelle informazioni file",
    "senderLabel": "Etichetta mittente",
    "saveProfile": "Salva profilo",
    "profileCodesSession": "I codici dei profili restano solo per questa sessione. Nomi ed etichette vengono salvati.",
    "globalCodeSession": "Il codice globale resta in memoria per la sessione corrente.",
    "keptOnlySession": "conservato solo per questa sessione",
    "optionalGlobalSender": "facoltativo, usa il mittente globale se vuoto",
    "howToUseSafeBox": "Come usare SafeBox",
    "howToSubtitle": "Crea, invia e sblocca file .sbx cifrati in sicurezza.",
    "brandSubtitle": "Formato file sicuro universale",
    "createIntro": "Qualsiasi file diventa un file SafeBox.",
    "encryptedLocally": "Cifrato localmente",
    "offlineCapable": "Funziona offline",
    "dropAny": "Trascina qui qualsiasi file",
    "originalFile": "File originale",
    "choose": "Scegli",
    "visibleSbxName": "Nome SBX visibile",
    "selectFileFirst": "Seleziona prima un file",
    "enterSenderCode": "Inserisci il codice del mittente",
    "accessLabel": "Etichetta di accesso",
    "publicNoteOptional": "Nota pubblica facoltativa",
    "publicNoteHint": "visibile prima dello sblocco, lascia vuoto per maggiore privacy",
    "advanced": "Avanzate",
    "outputDirectory": "Cartella di uscita",
    "sameFolderOriginal": "lascia vuoto = stessa cartella dell’originale",
    "folder": "Cartella",
    "keepSbxAfterUnlock": "Mantieni SBX dopo lo sblocco",
    "unlockSbx": "Sblocca SBX",
    "unlockIntro": "Apri localmente un file SafeBox.",
    "localDecryption": "Decrittazione locale",
    "dropSbx": "Trascina qui un file SafeBox",
    "sbxFile": "File SBX",
    "selectSbx": "Seleziona un file .sbx",
    "enterReceiverCode": "Inserisci il codice del destinatario",
    "sameFolderSbx": "lascia vuoto = stessa cartella del SBX",
    "replaceExisting": "Sostituisci file esistente",
    "replaceHint": "Disattivato: mantieni entrambi i file. Attivato: sostituisci il file esistente con quello ripristinato.",
    "createNewSbx": "Crea nuovo SBX",
    "safeBoxFile": "File SafeBox",
    "type": "Tipo",
    "name": "Nome",
    "notSet": "non impostato",
    "fileNaming": "Denominazione file",
    "fileNamingText": "I nuovi file SafeBox usano per impostazione predefinita il nome del file originale. Il nome può essere modificato prima della creazione.",
    "defaultAccessProfile": "Profilo di accesso predefinito",
    "enterGlobalCode": "Inserisci il codice globale",
    "profileBlockText": "Ogni profilo contiene codice, etichetta mittente ed etichetta di accesso.",
    "advertisingPrivacy": "Privacy pubblicitaria",
    "advertisingPrivacyText": "Il consenso è gestito da Google UMP. SafeBox non invia mai agli annunci nomi di file, codici o contenuti.",
    "privacyChoices": "Scelte privacy",
    "testAds": "annunci di test",
    "showPassword": "Mostra password",
    "hidePassword": "Nascondi password",
    "wrongCodeDamaged": "Codice errato o SafeBox danneggiato.",
    "damagedModified": "SafeBox danneggiato o modificato.",
    "unsupportedVersion": "Questa versione di SafeBox non è supportata.",
    "unsafeParameters": "Parametri di sicurezza SafeBox non sicuri o non supportati.",
    "readRestoreFailed": "Impossibile leggere o ripristinare questo file.",
    "unlockFailed": "Sblocco non riuscito.",
    "warning": "Avviso:",
    "missingInformation": "Informazioni mancanti.",
    "fileAndCodeRequired": "File e codice sono obbligatori.",
    "sbxAndCodeRequired": "File SBX e codice sono obbligatori.",
    "createdBrowser": "SafeBox creato nel browser.",
    "created": "SafeBox creato.",
    "download": "Download",
    "originalHidden": "Originale nascosto",
    "engine": "Motore",
    "yes": "sì",
    "output": "Uscita",
    "visibleName": "Nome visibile",
    "createFailed": "Creazione non riuscita.",
    "restoredBrowser": "Originale ripristinato nel browser.",
    "restored": "Originale ripristinato.",
    "original": "Originale",
    "size": "Dimensione",
    "sbxSource": "Origine SBX",
    "unchangedBrowser": "non modificato dal browser",
    "saved": "Salvato",
    "sbxDeletedLocally": "SBX eliminato localmente",
    "no": "no",
    "openingPicker": "Apertura selettore file Android…",
    "fileReady": "File pronto.",
    "saveOriginal": "Salva originale",
    "saving": "Salvataggio…",
    "openOriginal": "Apri originale",
    "showFinder": "Mostra nel Finder",
    "showFolder": "Mostra nella cartella",
    "appearance": "Aspetto",
    "mode": "Modalità",
    "system": "Sistema",
    "securityWorkspace": "Area di lavoro locale sicura",
    "securityWorkspaceHint": "File e codici restano su questo dispositivo salvo salvataggio o condivisione esplicita di un output."
  },
  pt: {
    "settings": "Definições",
    "help": "Ajuda",
    "theme": "Tema",
    "light": "Claro",
    "dark": "Escuro",
    "create": "Criar",
    "createSbx": "Criar SBX",
    "open": "Abrir",
    "openSbx": "Abrir SBX",
    "openExistingSbx": "Abrir SBX existente",
    "chooseFile": "Escolher ficheiro",
    "selectFile": "Selecionar ficheiro",
    "noFileSelected": "Nenhum ficheiro selecionado",
    "code": "Código",
    "enterCode": "Introduzir código",
    "unlock": "Desbloquear",
    "fileInfo": "Informações do ficheiro",
    "file": "Ficheiro",
    "from": "De",
    "access": "Acesso",
    "note": "Nota",
    "save": "Guardar",
    "cancel": "Cancelar",
    "close": "Fechar",
    "show": "Mostrar",
    "hide": "Ocultar",
    "delete": "Eliminar",
    "edit": "Editar",
    "setDefault": "Definir como padrão",
    "default": "Padrão",
    "general": "Geral",
    "accessProfiles": "Perfis de acesso",
    "security": "Segurança",
    "language": "Idioma",
    "autoSystem": "Auto - idioma do sistema",
    "senderDefaults": "Predefinições do remetente",
    "defaultSbxName": "Nome SBX padrão",
    "globalSenderLabel": "Etiqueta global do remetente",
    "useGlobalCode": "Usar código global por padrão",
    "globalCode": "Código global",
    "clearGlobalCode": "Limpar código global",
    "accessProfile": "Perfil de acesso",
    "noAccessProfilesYet": "Ainda não existem perfis de acesso.",
    "keepSafeBoxSimple": "Mantenha o SafeBox simples: adicione um perfil apenas quando precisar de acesso separado.",
    "keepSafeBoxSimpleLong": "Mantenha o SafeBox simples: adicione um perfil apenas quando precisar de acesso separado para família, trabalho, clientes ou ficheiros privados.",
    "addProfile": "+ Adicionar perfil",
    "newAccessProfile": "Novo perfil de acesso",
    "editAccessProfile": "Editar perfil de acesso",
    "nameInSafeBox": "Nome no SafeBox",
    "shownInFileInfo": "Mostrado nas informações do ficheiro",
    "senderLabel": "Etiqueta do remetente",
    "saveProfile": "Guardar perfil",
    "profileCodesSession": "Os códigos dos perfis são mantidos apenas nesta sessão. Os nomes e etiquetas são guardados.",
    "globalCodeSession": "O código global permanece na memória durante a sessão atual.",
    "keptOnlySession": "mantido apenas nesta sessão",
    "optionalGlobalSender": "opcional, usa o remetente global se estiver vazio",
    "howToUseSafeBox": "Como usar o SafeBox",
    "howToSubtitle": "Crie, envie e desbloqueie ficheiros .sbx cifrados com segurança.",
    "brandSubtitle": "Formato de ficheiro seguro universal",
    "createIntro": "Qualquer ficheiro torna-se um ficheiro SafeBox.",
    "encryptedLocally": "Cifrado localmente",
    "offlineCapable": "Funciona offline",
    "dropAny": "Arraste qualquer ficheiro para aqui",
    "originalFile": "Ficheiro original",
    "choose": "Escolher",
    "visibleSbxName": "Nome SBX visível",
    "selectFileFirst": "Selecione primeiro um ficheiro",
    "enterSenderCode": "Introduza o código do remetente",
    "accessLabel": "Etiqueta de acesso",
    "publicNoteOptional": "Nota pública opcional",
    "publicNoteHint": "visível antes do desbloqueio; deixe vazio para maior privacidade",
    "advanced": "Avançado",
    "outputDirectory": "Pasta de saída",
    "sameFolderOriginal": "deixe vazio = mesma pasta do original",
    "folder": "Pasta",
    "keepSbxAfterUnlock": "Manter SBX após desbloquear",
    "unlockSbx": "Desbloquear SBX",
    "unlockIntro": "Abra localmente um ficheiro SafeBox.",
    "localDecryption": "Desencriptação local",
    "dropSbx": "Arraste um ficheiro SafeBox para aqui",
    "sbxFile": "Ficheiro SBX",
    "selectSbx": "Selecione um ficheiro .sbx",
    "enterReceiverCode": "Introduza o código do destinatário",
    "sameFolderSbx": "deixe vazio = mesma pasta do SBX",
    "replaceExisting": "Substituir ficheiro existente",
    "replaceHint": "Desligado: manter ambos os ficheiros. Ligado: substituir o ficheiro existente pelo restaurado.",
    "createNewSbx": "Criar novo SBX",
    "safeBoxFile": "Ficheiro SafeBox",
    "type": "Tipo",
    "name": "Nome",
    "notSet": "não definido",
    "fileNaming": "Nomes de ficheiros",
    "fileNamingText": "Novos ficheiros SafeBox usam por padrão o nome do ficheiro original. O nome pode ser alterado antes da criação.",
    "defaultAccessProfile": "Perfil de acesso padrão",
    "enterGlobalCode": "Introduza o código global",
    "profileBlockText": "Cada perfil contém código, etiqueta do remetente e etiqueta de acesso.",
    "advertisingPrivacy": "Privacidade de publicidade",
    "advertisingPrivacyText": "O consentimento é gerido pelo Google UMP. O SafeBox nunca envia nomes de ficheiros, códigos ou conteúdos aos anúncios.",
    "privacyChoices": "Opções de privacidade",
    "testAds": "anúncios de teste",
    "showPassword": "Mostrar palavra-passe",
    "hidePassword": "Ocultar palavra-passe",
    "wrongCodeDamaged": "Código incorreto ou SafeBox danificado.",
    "damagedModified": "SafeBox danificado ou modificado.",
    "unsupportedVersion": "Esta versão do SafeBox não é suportada.",
    "unsafeParameters": "Parâmetros de segurança SafeBox inseguros ou não suportados.",
    "readRestoreFailed": "Não foi possível ler ou restaurar este ficheiro.",
    "unlockFailed": "Falha ao desbloquear.",
    "warning": "Aviso:",
    "missingInformation": "Faltam informações.",
    "fileAndCodeRequired": "O ficheiro e o código são obrigatórios.",
    "sbxAndCodeRequired": "O ficheiro SBX e o código são obrigatórios.",
    "createdBrowser": "SafeBox criado no navegador.",
    "created": "SafeBox criado.",
    "download": "Transferência",
    "originalHidden": "Original oculto",
    "engine": "Motor",
    "yes": "sim",
    "output": "Saída",
    "visibleName": "Nome visível",
    "createFailed": "Falha ao criar.",
    "restoredBrowser": "Original restaurado no navegador.",
    "restored": "Original restaurado.",
    "original": "Original",
    "size": "Tamanho",
    "sbxSource": "Origem SBX",
    "unchangedBrowser": "inalterado pelo navegador",
    "saved": "Guardado",
    "sbxDeletedLocally": "SBX eliminado localmente",
    "no": "não",
    "openingPicker": "A abrir seletor de ficheiros Android…",
    "fileReady": "Ficheiro pronto.",
    "saveOriginal": "Guardar original",
    "saving": "A guardar…",
    "openOriginal": "Abrir original",
    "showFinder": "Mostrar no Finder",
    "showFolder": "Mostrar na pasta",
    "appearance": "Aparência",
    "mode": "Modo",
    "system": "Sistema",
    "securityWorkspace": "Espaço local seguro",
    "securityWorkspaceHint": "Os ficheiros e códigos permanecem neste dispositivo, exceto se guardar ou partilhar explicitamente uma saída."
  },
};
Object.entries(SBX_RC8_I18N).forEach(([locale, dict]) => { SBX_FULL_I18N[locale] = { ...(SBX_FULL_I18N[locale] || SBX_FULL_I18N.en), ...dict }; });


// SafeBox R86 RC8 — urgent visible-text translation closure.
// This layer covers asynchronous status/result copy, placeholders and accessibility labels
// that historically sat outside the original Sprint 9C dictionaries.
const SBX_RC8_STATUS_I18N: Record<string, Record<string, string>> = {
  en: {
    visibleInFileInfo: "visible in File info", categoryExample: "Family / Work / Private",
    senderTeamExample: "Martina / Noureddine / Team", profileCategoryExample: "Private / Work / Family",
    enterProfileCode: "Enter profile code", secureWorkspaceAria: "SafeBox secure local workspace",
    securityPropertiesAria: "SafeBox security properties", controlsAria: "SafeBox controls",
    appearanceModeAria: "Appearance mode", selectSbxSafeBox: "Select a .sbx SafeBox file.",
    browserFileSelected: "Browser file selected.", pickerFailed: "Could not open the file picker.",
    browserDownloadFlow: "Browser mode saves through the browser download flow.", keepOneProfile: "Keep at least one profile.",
    globalCodeCleared: "Global code cleared.", settingsSaved: "Settings saved.", naming: "Naming",
    originalFilenameDefault: "original filename by default", sender: "Sender", profiles: "Profiles",
    fileSelected: "File selected.", dropFailed: "Drop failed.", dragDropInitFailed: "Drag/drop init failed.",
    sharedFileReady: "Shared file ready.", firstSharedFileLoaded: "First shared file loaded.",
    systemOpenFailed: "System open handler failed.", openFailed: "Open failed.", finderFailed: "Show in Finder failed.",
    wrongCode: "Wrong code", downloadedBrowser: "Downloaded by your browser.", sbxCompleted: "SBX completed.",
    restoredBrowserBoom: "BOOOOM. Original restored in your browser.", restoredBoom: "BOOOOM. Original restored.",
    accessProfileTitle: "Access Profile", profilesOnlyWhenNeeded: "Use profiles only when you need separate access.",
    saveSafeBox: "Save SafeBox", unknownSafeBoxError: "Unknown SafeBox error", unknownPickerError: "Unknown Android file-picker error"
  },
  fr: {
    visibleInFileInfo: "visible dans Infos fichier", categoryExample: "Famille / Travail / Privé",
    senderTeamExample: "Martina / Noureddine / Équipe", profileCategoryExample: "Privé / Travail / Famille",
    enterProfileCode: "Saisir le code du profil", secureWorkspaceAria: "Espace local sécurisé SafeBox",
    securityPropertiesAria: "Propriétés de sécurité SafeBox", controlsAria: "Commandes SafeBox",
    appearanceModeAria: "Mode d’apparence", selectSbxSafeBox: "Sélectionnez un fichier SafeBox .sbx.",
    browserFileSelected: "Fichier sélectionné dans le navigateur.", pickerFailed: "Impossible d’ouvrir le sélecteur de fichiers.",
    browserDownloadFlow: "En mode navigateur, l’enregistrement passe par le téléchargement du navigateur.", keepOneProfile: "Conservez au moins un profil.",
    globalCodeCleared: "Code global effacé.", settingsSaved: "Paramètres enregistrés.", naming: "Nommage",
    originalFilenameDefault: "nom du fichier original par défaut", sender: "Expéditeur", profiles: "Profils",
    fileSelected: "Fichier sélectionné.", dropFailed: "Échec du dépôt.", dragDropInitFailed: "Échec de l’initialisation du glisser-déposer.",
    sharedFileReady: "Fichier partagé prêt.", firstSharedFileLoaded: "Premier fichier partagé chargé.",
    systemOpenFailed: "Échec du gestionnaire d’ouverture système.", openFailed: "Échec de l’ouverture.", finderFailed: "Impossible d’afficher dans le Finder.",
    wrongCode: "Code incorrect", downloadedBrowser: "Téléchargé par votre navigateur.", sbxCompleted: "SBX terminé.",
    restoredBrowserBoom: "BOOOOM. Original restauré dans votre navigateur.", restoredBoom: "BOOOOM. Original restauré.",
    accessProfileTitle: "Profil d’accès", profilesOnlyWhenNeeded: "Utilisez les profils uniquement si vous avez besoin d’accès distincts.",
    saveSafeBox: "Enregistrer SafeBox", unknownSafeBoxError: "Erreur SafeBox inconnue", unknownPickerError: "Erreur inconnue du sélecteur Android"
  },
  de: {
    visibleInFileInfo: "in Dateiinfo sichtbar", categoryExample: "Familie / Arbeit / Privat",
    senderTeamExample: "Martina / Noureddine / Team", profileCategoryExample: "Privat / Arbeit / Familie",
    enterProfileCode: "Profilcode eingeben", secureWorkspaceAria: "Sicherer lokaler SafeBox-Arbeitsbereich",
    securityPropertiesAria: "SafeBox-Sicherheitseigenschaften", controlsAria: "SafeBox-Steuerung",
    appearanceModeAria: "Darstellungsmodus", selectSbxSafeBox: "Wählen Sie eine .sbx-SafeBox-Datei.",
    browserFileSelected: "Browserdatei ausgewählt.", pickerFailed: "Dateiauswahl konnte nicht geöffnet werden.",
    browserDownloadFlow: "Im Browsermodus wird über den Browser-Download gespeichert.", keepOneProfile: "Mindestens ein Profil beibehalten.",
    globalCodeCleared: "Globaler Code gelöscht.", settingsSaved: "Einstellungen gespeichert.", naming: "Benennung",
    originalFilenameDefault: "ursprünglicher Dateiname als Standard", sender: "Absender", profiles: "Profile",
    fileSelected: "Datei ausgewählt.", dropFailed: "Ablegen fehlgeschlagen.", dragDropInitFailed: "Initialisierung von Drag-and-drop fehlgeschlagen.",
    sharedFileReady: "Geteilte Datei bereit.", firstSharedFileLoaded: "Erste geteilte Datei geladen.",
    systemOpenFailed: "System-Öffnungsroutine fehlgeschlagen.", openFailed: "Öffnen fehlgeschlagen.", finderFailed: "Anzeige im Finder fehlgeschlagen.",
    wrongCode: "Falscher Code", downloadedBrowser: "Von Ihrem Browser heruntergeladen.", sbxCompleted: "SBX abgeschlossen.",
    restoredBrowserBoom: "BOOOOM. Original im Browser wiederhergestellt.", restoredBoom: "BOOOOM. Original wiederhergestellt.",
    accessProfileTitle: "Zugriffsprofil", profilesOnlyWhenNeeded: "Profile nur verwenden, wenn getrennte Zugriffe benötigt werden.",
    saveSafeBox: "SafeBox speichern", unknownSafeBoxError: "Unbekannter SafeBox-Fehler", unknownPickerError: "Unbekannter Android-Dateiauswahlfehler"
  },
  hr: {
    visibleInFileInfo: "vidljivo u informacijama o datoteci", categoryExample: "Obitelj / Posao / Privatno",
    senderTeamExample: "Martina / Noureddine / Tim", profileCategoryExample: "Privatno / Posao / Obitelj",
    enterProfileCode: "Unesite kod profila", secureWorkspaceAria: "Siguran lokalni SafeBox radni prostor",
    securityPropertiesAria: "SafeBox sigurnosna svojstva", controlsAria: "SafeBox kontrole",
    appearanceModeAria: "Način izgleda", selectSbxSafeBox: "Odaberite SafeBox .sbx datoteku.",
    browserFileSelected: "Datoteka odabrana u pregledniku.", pickerFailed: "Nije moguće otvoriti birač datoteka.",
    browserDownloadFlow: "U pregledniku se spremanje obavlja putem preuzimanja preglednika.", keepOneProfile: "Zadržite barem jedan profil.",
    globalCodeCleared: "Globalni kod je izbrisan.", settingsSaved: "Postavke su spremljene.", naming: "Imenovanje",
    originalFilenameDefault: "izvorni naziv datoteke kao zadani", sender: "Pošiljatelj", profiles: "Profili",
    fileSelected: "Datoteka odabrana.", dropFailed: "Ispuštanje nije uspjelo.", dragDropInitFailed: "Pokretanje povuci-i-ispusti nije uspjelo.",
    sharedFileReady: "Dijeljena datoteka je spremna.", firstSharedFileLoaded: "Prva dijeljena datoteka je učitana.",
    systemOpenFailed: "Sistemsko otvaranje nije uspjelo.", openFailed: "Otvaranje nije uspjelo.", finderFailed: "Prikaz u Finderu nije uspio.",
    wrongCode: "Pogrešan kod", downloadedBrowser: "Preuzeto putem preglednika.", sbxCompleted: "SBX je dovršen.",
    restoredBrowserBoom: "BOOOOM. Izvorna datoteka vraćena je u pregledniku.", restoredBoom: "BOOOOM. Izvorna datoteka je vraćena.",
    accessProfileTitle: "Profil pristupa", profilesOnlyWhenNeeded: "Profile koristite samo kada trebate odvojeni pristup.",
    saveSafeBox: "Spremi SafeBox", unknownSafeBoxError: "Nepoznata SafeBox greška", unknownPickerError: "Nepoznata greška Android birača datoteka"
  },
  es: {
    visibleInFileInfo: "visible en Información del archivo", categoryExample: "Familia / Trabajo / Privado",
    senderTeamExample: "Martina / Noureddine / Equipo", profileCategoryExample: "Privado / Trabajo / Familia",
    enterProfileCode: "Introducir código del perfil", secureWorkspaceAria: "Espacio local seguro de SafeBox",
    securityPropertiesAria: "Propiedades de seguridad de SafeBox", controlsAria: "Controles de SafeBox",
    appearanceModeAria: "Modo de apariencia", selectSbxSafeBox: "Seleccione un archivo SafeBox .sbx.",
    browserFileSelected: "Archivo seleccionado en el navegador.", pickerFailed: "No se pudo abrir el selector de archivos.",
    browserDownloadFlow: "En el navegador, el guardado usa el flujo de descarga del navegador.", keepOneProfile: "Mantenga al menos un perfil.",
    globalCodeCleared: "Código global borrado.", settingsSaved: "Ajustes guardados.", naming: "Nombres",
    originalFilenameDefault: "nombre original del archivo por defecto", sender: "Remitente", profiles: "Perfiles",
    fileSelected: "Archivo seleccionado.", dropFailed: "Error al soltar el archivo.", dragDropInitFailed: "Error al iniciar arrastrar y soltar.",
    sharedFileReady: "Archivo compartido listo.", firstSharedFileLoaded: "Primer archivo compartido cargado.",
    systemOpenFailed: "Error del gestor de apertura del sistema.", openFailed: "Error al abrir.", finderFailed: "Error al mostrar en Finder.",
    wrongCode: "Código incorrecto", downloadedBrowser: "Descargado por su navegador.", sbxCompleted: "SBX completado.",
    restoredBrowserBoom: "BOOOOM. Original restaurado en el navegador.", restoredBoom: "BOOOOM. Original restaurado.",
    accessProfileTitle: "Perfil de acceso", profilesOnlyWhenNeeded: "Use perfiles solo cuando necesite accesos separados.",
    saveSafeBox: "Guardar SafeBox", unknownSafeBoxError: "Error de SafeBox desconocido", unknownPickerError: "Error desconocido del selector Android"
  },
  ar: {
    visibleInFileInfo: "ظاهر في معلومات الملف", categoryExample: "العائلة / العمل / خاص",
    senderTeamExample: "Martina / Noureddine / الفريق", profileCategoryExample: "خاص / العمل / العائلة",
    enterProfileCode: "أدخل رمز الملف الشخصي", secureWorkspaceAria: "مساحة SafeBox محلية آمنة",
    securityPropertiesAria: "خصائص أمان SafeBox", controlsAria: "عناصر تحكم SafeBox",
    appearanceModeAria: "وضع المظهر", selectSbxSafeBox: "اختر ملف SafeBox بامتداد .sbx.",
    browserFileSelected: "تم اختيار الملف في المتصفح.", pickerFailed: "تعذر فتح منتقي الملفات.",
    browserDownloadFlow: "في وضع المتصفح يتم الحفظ عبر تنزيل المتصفح.", keepOneProfile: "احتفظ بملف وصول واحد على الأقل.",
    globalCodeCleared: "تم مسح الرمز العام.", settingsSaved: "تم حفظ الإعدادات.", naming: "التسمية",
    originalFilenameDefault: "اسم الملف الأصلي افتراضيًا", sender: "المرسل", profiles: "ملفات الوصول",
    fileSelected: "تم اختيار الملف.", dropFailed: "فشل إسقاط الملف.", dragDropInitFailed: "فشل تهيئة السحب والإفلات.",
    sharedFileReady: "الملف المشترك جاهز.", firstSharedFileLoaded: "تم تحميل أول ملف مشترك.",
    systemOpenFailed: "فشل معالج الفتح في النظام.", openFailed: "فشل الفتح.", finderFailed: "فشل العرض في Finder.",
    wrongCode: "رمز غير صحيح", downloadedBrowser: "تم التنزيل بواسطة المتصفح.", sbxCompleted: "اكتمل SBX.",
    restoredBrowserBoom: "BOOOOM. تمت استعادة الأصل في المتصفح.", restoredBoom: "BOOOOM. تمت استعادة الأصل.",
    accessProfileTitle: "ملف وصول", profilesOnlyWhenNeeded: "استخدم ملفات الوصول فقط عند الحاجة إلى وصول منفصل.",
    saveSafeBox: "حفظ SafeBox", unknownSafeBoxError: "خطأ SafeBox غير معروف", unknownPickerError: "خطأ غير معروف في منتقي ملفات Android"
  },
  it: {
    visibleInFileInfo: "visibile nelle informazioni file", categoryExample: "Famiglia / Lavoro / Privato",
    senderTeamExample: "Martina / Noureddine / Team", profileCategoryExample: "Privato / Lavoro / Famiglia",
    enterProfileCode: "Inserisci il codice del profilo", secureWorkspaceAria: "Area di lavoro locale sicura SafeBox",
    securityPropertiesAria: "Proprietà di sicurezza SafeBox", controlsAria: "Controlli SafeBox",
    appearanceModeAria: "Modalità aspetto", selectSbxSafeBox: "Seleziona un file SafeBox .sbx.",
    browserFileSelected: "File selezionato nel browser.", pickerFailed: "Impossibile aprire il selettore file.",
    browserDownloadFlow: "Nel browser il salvataggio usa il flusso di download del browser.", keepOneProfile: "Mantieni almeno un profilo.",
    globalCodeCleared: "Codice globale cancellato.", settingsSaved: "Impostazioni salvate.", naming: "Denominazione",
    originalFilenameDefault: "nome file originale come predefinito", sender: "Mittente", profiles: "Profili",
    fileSelected: "File selezionato.", dropFailed: "Rilascio non riuscito.", dragDropInitFailed: "Inizializzazione trascinamento non riuscita.",
    sharedFileReady: "File condiviso pronto.", firstSharedFileLoaded: "Primo file condiviso caricato.",
    systemOpenFailed: "Gestore apertura di sistema non riuscito.", openFailed: "Apertura non riuscita.", finderFailed: "Visualizzazione nel Finder non riuscita.",
    wrongCode: "Codice errato", downloadedBrowser: "Scaricato dal browser.", sbxCompleted: "SBX completato.",
    restoredBrowserBoom: "BOOOOM. Originale ripristinato nel browser.", restoredBoom: "BOOOOM. Originale ripristinato.",
    accessProfileTitle: "Profilo di accesso", profilesOnlyWhenNeeded: "Usa i profili solo quando servono accessi separati.",
    saveSafeBox: "Salva SafeBox", unknownSafeBoxError: "Errore SafeBox sconosciuto", unknownPickerError: "Errore sconosciuto del selettore Android"
  },
  pt: {
    visibleInFileInfo: "visível nas informações do ficheiro", categoryExample: "Família / Trabalho / Privado",
    senderTeamExample: "Martina / Noureddine / Equipa", profileCategoryExample: "Privado / Trabalho / Família",
    enterProfileCode: "Introduzir código do perfil", secureWorkspaceAria: "Espaço local seguro SafeBox",
    securityPropertiesAria: "Propriedades de segurança SafeBox", controlsAria: "Controlos SafeBox",
    appearanceModeAria: "Modo de aparência", selectSbxSafeBox: "Selecione um ficheiro SafeBox .sbx.",
    browserFileSelected: "Ficheiro selecionado no navegador.", pickerFailed: "Não foi possível abrir o seletor de ficheiros.",
    browserDownloadFlow: "No navegador, a gravação usa o fluxo de transferências do navegador.", keepOneProfile: "Mantenha pelo menos um perfil.",
    globalCodeCleared: "Código global limpo.", settingsSaved: "Definições guardadas.", naming: "Nomenclatura",
    originalFilenameDefault: "nome original do ficheiro por predefinição", sender: "Remetente", profiles: "Perfis",
    fileSelected: "Ficheiro selecionado.", dropFailed: "Falha ao largar o ficheiro.", dragDropInitFailed: "Falha ao iniciar arrastar e largar.",
    sharedFileReady: "Ficheiro partilhado pronto.", firstSharedFileLoaded: "Primeiro ficheiro partilhado carregado.",
    systemOpenFailed: "Falha no gestor de abertura do sistema.", openFailed: "Falha ao abrir.", finderFailed: "Falha ao mostrar no Finder.",
    wrongCode: "Código incorreto", downloadedBrowser: "Transferido pelo navegador.", sbxCompleted: "SBX concluído.",
    restoredBrowserBoom: "BOOOOM. Original restaurado no navegador.", restoredBoom: "BOOOOM. Original restaurado.",
    accessProfileTitle: "Perfil de acesso", profilesOnlyWhenNeeded: "Use perfis apenas quando precisar de acessos separados.",
    saveSafeBox: "Guardar SafeBox", unknownSafeBoxError: "Erro SafeBox desconhecido", unknownPickerError: "Erro desconhecido do seletor Android"
  }
};
Object.entries(SBX_RC8_STATUS_I18N).forEach(([locale, dict]) => {
  SBX_FULL_I18N[locale] = { ...(SBX_FULL_I18N[locale] || SBX_FULL_I18N.en), ...dict };
});

function sbxFullLocale(): SbxFullLocale {
  const stored = localStorage.getItem("safebox.language.v1") || "auto";
  const raw = stored === "auto" ? navigator.language : stored;
  const lang = raw.toLowerCase();

  if (lang.startsWith("fr")) return "fr";
  if (lang.startsWith("de")) return "de";
  if (lang.startsWith("hr") || lang.startsWith("sr") || lang.startsWith("bs")) return "hr";
  if (lang.startsWith("es")) return "es";
  if (lang.startsWith("ar")) return "ar";
  if (lang.startsWith("it")) return "it";
  if (lang.startsWith("pt")) return "pt";

  return "en";
}

function sbxFullDict() {
  return SBX_FULL_I18N[sbxFullLocale()] || SBX_FULL_I18N.en;
}

function sbxFullNorm(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function sbxFullVariantMap() {
  const variants = new Map<string, string>();

  (Object.keys(SBX_FULL_I18N) as SbxFullLocale[]).forEach((locale) => {
    const dict = SBX_FULL_I18N[locale];

    Object.keys(dict).forEach((key) => {
      variants.set(sbxFullNorm(dict[key]).toLowerCase(), key);
    });
  });

  const extra: Record<string, string> = {
    "auto – langue du système": "autoSystem",
    "auto - langue du système": "autoSystem",
    "auto – system language": "autoSystem",
    "auto - system language": "autoSystem",
    "default access profile": "accessProfile",
    "access profile": "accessProfile",
    "access profiles": "accessProfiles",
    "file info": "fileInfo",
    "global sender label": "globalSenderLabel",
    "sender label": "senderLabel",
    "clear global code": "clearGlobalCode",
    "save profile": "saveProfile",
    "create sbx": "createSbx",
    "open sbx": "openSbx"
  };

  Object.keys(extra).forEach((label) => {
    variants.set(sbxFullNorm(label).toLowerCase(), extra[label]);
  });

  const rc8Extra: Record<string, string> = {"Universal secure file format": "brandSubtitle", "Any file becomes a SafeBox file.": "createIntro", "Encrypted locally": "encryptedLocally", "Offline-capable": "offlineCapable", "Drop any file here": "dropAny", "Original file": "originalFile", "Choose": "choose", "Visible SBX name": "visibleSbxName", "Select a file first": "selectFileFirst", "Enter sender code": "enterSenderCode", "Access label": "accessLabel", "Public note optional": "publicNoteOptional", "visible before unlock, leave empty for privacy": "publicNoteHint", "Advanced": "advanced", "Output directory": "outputDirectory", "leave empty = same folder as original": "sameFolderOriginal", "Folder": "folder", "Keep SBX after unlock": "keepSbxAfterUnlock", "Unlock SBX": "unlockSbx", "Open a SafeBox file locally.": "unlockIntro", "Local decryption": "localDecryption", "Drop a SafeBox file here": "dropSbx", "SBX file": "sbxFile", "Select a .sbx file": "selectSbx", "Enter receiver code": "enterReceiverCode", "leave empty = same folder as SBX": "sameFolderSbx", "Replace existing file": "replaceExisting", "Off: keep both files. On: replace the existing file with the restored one.": "replaceHint", "Create new SBX": "createNewSbx", "SafeBox File": "safeBoxFile", "Type": "type", "Name": "name", "not set": "notSet", "File naming": "fileNaming", "New SafeBox files use the original filename by default. The name can be changed before creation.": "fileNamingText", "Default access profile": "defaultAccessProfile", "Enter global code": "enterGlobalCode", "Each profile block contains code, sender label and access label.": "profileBlockText", "Advertising privacy": "advertisingPrivacy", "Consent is handled by Google UMP. SafeBox never sends file names, codes or file contents to ads.": "advertisingPrivacyText", "Privacy choices": "privacyChoices", "test ads": "testAds", "Show password": "showPassword", "Hide password": "hidePassword", "Wrong code or damaged SafeBox.": "wrongCodeDamaged", "SafeBox damaged or modified.": "damagedModified", "This SafeBox version is not supported.": "unsupportedVersion", "Unsafe or unsupported SafeBox security parameters.": "unsafeParameters", "Could not read or restore this file.": "readRestoreFailed", "Unlock failed.": "unlockFailed", "Warning:": "warning", "Missing information.": "missingInformation", "File and code are required.": "fileAndCodeRequired", "SBX file and code are required.": "sbxAndCodeRequired", "SafeBox created in your browser.": "createdBrowser", "SafeBox created.": "created", "Download": "download", "Original hidden": "originalHidden", "Engine": "engine", "yes": "yes", "Output": "output", "Visible name": "visibleName", "Create failed.": "createFailed", "Original restored in your browser.": "restoredBrowser", "Original restored.": "restored", "Original": "original", "Size": "size", "SBX source": "sbxSource", "unchanged by browser": "unchangedBrowser", "Saved": "saved", "SBX deleted locally": "sbxDeletedLocally", "no": "no", "Opening Android file picker…": "openingPicker", "File ready.": "fileReady", "Save original": "saveOriginal", "Saving…": "saving", "Open original": "openOriginal", "Show in Finder": "showFinder", "Show in folder": "showFolder", "Appearance": "appearance", "Mode": "mode", "System": "system", "visible in File info": "visibleInFileInfo", "Family / Work / Private": "categoryExample", "Martina / Noureddine / Team": "senderTeamExample", "Private / Work / Family": "profileCategoryExample", "Enter profile code": "enterProfileCode", "SafeBox secure local workspace": "secureWorkspaceAria", "SafeBox security properties": "securityPropertiesAria", "SafeBox controls": "controlsAria", "Appearance mode": "appearanceModeAria", "Select a .sbx SafeBox file.": "selectSbxSafeBox", "Browser file selected.": "browserFileSelected", "Could not open the file picker.": "pickerFailed", "Browser mode saves through the browser download flow.": "browserDownloadFlow", "Keep at least one profile.": "keepOneProfile", "Global code cleared.": "globalCodeCleared", "Settings saved.": "settingsSaved", "Naming": "naming", "original filename by default": "originalFilenameDefault", "Sender": "sender", "Profiles": "profiles", "File selected.": "fileSelected", "Drop failed.": "dropFailed", "Drag/drop init failed.": "dragDropInitFailed", "Shared file ready.": "sharedFileReady", "First shared file loaded.": "firstSharedFileLoaded", "System open handler failed.": "systemOpenFailed", "Open failed.": "openFailed", "Show in Finder failed.": "finderFailed", "Wrong code": "wrongCode", "Downloaded by your browser.": "downloadedBrowser", "SBX completed.": "sbxCompleted", "BOOOOM. Original restored in your browser.": "restoredBrowserBoom", "BOOOOM. Original restored.": "restoredBoom", "Access Profile": "accessProfileTitle", "Use profiles only when you need separate access.": "profilesOnlyWhenNeeded", "Save SafeBox": "saveSafeBox"};
  Object.entries(rc8Extra).forEach(([label, key]) => variants.set(sbxFullNorm(label).toLowerCase(), key));

  return variants;
}

function sbxFullKeyForText(value: string) {
  const normalized = sbxFullNorm(value).toLowerCase();
  if (!normalized) return null;

  return sbxFullVariantMap().get(normalized) || null;
}

function sbxFullSetText(selector: string, key: string) {
  const value = sbxFullDict()[key];
  if (!value) return;

  document.querySelectorAll<HTMLElement>(selector).forEach((element) => {
    element.textContent = value;
  });
}

function sbxFullTranslateTextNodes(root: ParentNode) {
  const dict = sbxFullDict();

  const walker = document.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode(node) {
        const parent = node.parentElement;
        if (!parent) return NodeFilter.FILTER_REJECT;

        const tag = parent.tagName.toLowerCase();

        if (
          tag === "script" ||
          tag === "style" ||
          tag === "code" ||
          tag === "textarea" ||
          tag === "input" ||
          parent.closest("code") ||
          parent.closest("#hardReceiverFile") ||
          parent.closest("#hardInfoName") ||
          parent.closest("#hardInfoSender") ||
          parent.closest("#hardInfoAccess") ||
          parent.closest("#hardInfoNote")
        ) {
          return NodeFilter.FILTER_REJECT;
        }

        return sbxFullKeyForText(node.nodeValue || "") ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    }
  );

  const nodes: Text[] = [];

  while (walker.nextNode()) {
    nodes.push(walker.currentNode as Text);
  }

  nodes.forEach((node) => {
    const raw = node.nodeValue || "";
    const key = sbxFullKeyForText(raw);
    if (!key || !dict[key]) return;

    const prefix = raw.match(/^\s*/)?.[0] || "";
    const suffix = raw.match(/\s*$/)?.[0] || "";
    node.nodeValue = `${prefix}${dict[key]}${suffix}`;
  });
}

function sbxFullTranslateAttributes() {
  const dict = sbxFullDict();

  document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>("input[placeholder], textarea[placeholder]").forEach((element) => {
    const key = sbxFullKeyForText(element.placeholder);
    if (key && dict[key]) element.placeholder = dict[key];
  });

  document.querySelectorAll<HTMLElement>("[title]").forEach((element) => {
    const title = element.getAttribute("title") || "";
    const key = sbxFullKeyForText(title);
    if (key && dict[key]) element.setAttribute("title", dict[key]);
  });

  document.querySelectorAll<HTMLElement>("[aria-label]").forEach((element) => {
    const label = element.getAttribute("aria-label") || "";
    const key = sbxFullKeyForText(label);
    if (key && dict[key]) element.setAttribute("aria-label", dict[key]);
  });
}

function sbxFullTranslateKnownUi() {
  const dict = sbxFullDict();

  const settingsIconButton = document.querySelector<HTMLButtonElement>("#settingsBtn");
  if (settingsIconButton) {
    settingsIconButton.setAttribute("aria-label", dict.settings);
    settingsIconButton.setAttribute("title", dict.settings);
  }
  sbxFullSetText("#helpBtn", "help");
  sbxFullSetText("#howToUseBtn", "help");

  document.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    if (button.dataset.tab === "general") button.textContent = dict.general;
    if (button.dataset.tab === "profiles") button.textContent = dict.accessProfiles;
    if (button.dataset.tab === "security") button.textContent = dict.security;
  });

  const langTitle = document.querySelector<HTMLElement>("#settingsLanguageField .settings-language-title");
  if (langTitle) langTitle.textContent = dict.language;

  const languageSelect = document.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) {
    Array.from(languageSelect.options).forEach((option) => {
      if (option.value === "auto") option.textContent = dict.autoSystem;
      if (option.value === "en") option.textContent = "English";
      if (option.value === "fr") option.textContent = "Français";
      if (option.value === "de") option.textContent = "Deutsch";
      if (option.value === "hr") option.textContent = "Hrvatski / BCS";
      if (option.value === "ar") option.textContent = "العربية";
      if (option.value === "es") option.textContent = "Español";
      if (option.value === "it") option.textContent = "Italiano";
      if (option.value === "pt") option.textContent = "Português";
    });
  }

  sbxFullSetText("#addProfileBtn", "addProfile");
  sbxFullSetText("#saveProfileEditorBtn", "saveProfile");
  sbxFullSetText("#cancelProfileEditorBtn", "cancel");
  sbxFullSetText("#closeHowToUseFooterBtn", "close");

  const title = document.querySelector<HTMLElement>("#profileEditorTitle");
  if (title) {
    const current = sbxFullNorm(title.textContent || "").toLowerCase();
    const editWords = ["edit", "modifier", "bearbeiten", "uredi", "editar", "تعديل"];
    title.textContent = editWords.some((word) => current.includes(word)) ? dict.editAccessProfile : dict.newAccessProfile;
  }

  document.documentElement.lang = sbxFullLocale() === "hr" ? "hr" : sbxFullLocale();
  document.documentElement.dir = sbxFullLocale() === "ar" ? "rtl" : "ltr";
}

function sbxFullApplyAppLanguage() {
  try {
    sbxFullTranslateKnownUi();
    sbxFullTranslateTextNodes(document.body);
    sbxFullTranslateAttributes();
  } catch (error) {
    console.warn("SafeBox full app i18n failed", error);
  }
}

(window as any).sbxApplyI18n = sbxFullApplyAppLanguage;

window.addEventListener("storage", (event) => {
  if (event.key === SAFEBOX_LANGUAGE_KEY) sbxFullApplyAppLanguage();
  if (event.key === SAFEBOX_THEME_MODE_KEY) applyThemeMode(readThemeMode(), false);
});

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    setTimeout(sbxFullApplyAppLanguage, 20);
    setTimeout(sbxFullApplyAppLanguage, 120);
    setTimeout(sbxFullApplyAppLanguage, 350);
  }
});

document.addEventListener(
  "click",
  () => {
    setTimeout(sbxFullApplyAppLanguage, 80);
    setTimeout(sbxFullApplyAppLanguage, 260);
  },
  true
);

setTimeout(sbxFullApplyAppLanguage, 100);
setTimeout(sbxFullApplyAppLanguage, 500);
setTimeout(sbxFullApplyAppLanguage, 1200);
scheduleDesktopMaintenance(sbxFullApplyAppLanguage, 1200);

console.debug("sprint9c-full-app-i18n-v1");


// SafeBox Sprint 10A-1 — single Help button controller
// Marker: sprint10a1-help-single-controller-v1
function sbxSingleHelpButtonController() {
  const howToButtons = Array.from(document.querySelectorAll<HTMLButtonElement>("#howToUseBtn"));
  const legacyHelpButtons = Array.from(document.querySelectorAll<HTMLButtonElement>("#helpBtn"));

  // Remove old Sprint 9A Help buttons. Sprint 9B owns Help now.
  legacyHelpButtons.forEach((button) => button.remove());

  // Keep only the first Sprint 9B Help button.
  howToButtons.slice(1).forEach((button) => button.remove());

  const keep = document.querySelector<HTMLButtonElement>("#howToUseBtn");

  if (keep) {
    keep.classList.add("how-to-use-btn", "mini-btn");
  }

  // Remove legacy 9A modal if it exists. Keep #howToUseModal.
  document.querySelectorAll<HTMLElement>("#helpModal").forEach((modal) => modal.remove());
}

function sbxStartSingleHelpButtonController() {
  sbxSingleHelpButtonController();

  if (platformCapabilities.mobile || likelyMobileRuntime) return;
  if ((window as any).__safeboxSingleHelpObserver) return;

  const observer = new MutationObserver(() => {
    if (platformCapabilities.mobile || likelyMobileRuntime) {
      observer.disconnect();
      (window as any).__safeboxSingleHelpObserver = null;
      return;
    }
    sbxSingleHelpButtonController();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  (window as any).__safeboxSingleHelpObserver = observer;
}

setTimeout(sbxStartSingleHelpButtonController, 100);
setTimeout(sbxStartSingleHelpButtonController, 500);
setTimeout(sbxStartSingleHelpButtonController, 1200);

console.debug("sprint10a1-help-single-controller-v1");


// SafeBox Sprint 10A-2 — single Access Profiles controller
// Marker: sprint10a2-access-profiles-single-controller-v1
function sbxAccessProfilesSingleController10A2() {
  try {
    renderAccessProfilesSettings();
    renderCreateProfileSelect();
    sbxHideMainAccessProfileWhenEmpty();
  } catch (error) {
    console.warn("Access Profiles controller failed", error);
  }
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    const addButton = target?.closest<HTMLButtonElement>("#addProfileBtn");
    if (addButton) {
      event.preventDefault();
      event.stopPropagation();
      openAccessProfileEditor();
      setTimeout(sbxAccessProfilesSingleController10A2, 80);
      return;
    }

    const compactRow = target?.closest<HTMLElement>(".compact-profile-row");
    if (!compactRow) return;

    const profileId = compactRow.dataset.profileId || "";

    if (target?.closest(".compact-profile-edit")) {
      event.preventDefault();
      event.stopPropagation();
      openAccessProfileEditor(profileId);
      return;
    }

    if (target?.closest(".compact-profile-set-default")) {
      event.preventDefault();
      event.stopPropagation();
      setCompactAccessProfileDefault(profileId);
      return;
    }

    if (target?.closest(".compact-profile-delete")) {
      event.preventDefault();
      event.stopPropagation();
      deleteCompactAccessProfile(profileId);
    }
  },
  true
);

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxAccessProfilesSingleController10A2, 80);
  setTimeout(sbxAccessProfilesSingleController10A2, 260);
});

setTimeout(sbxAccessProfilesSingleController10A2, 100);
setTimeout(sbxAccessProfilesSingleController10A2, 500);
setTimeout(sbxAccessProfilesSingleController10A2, 1200);

console.debug("sprint10a2-access-profiles-single-controller-v1");

// SafeBox R7 — simple per-file SBX naming.
// The selected source filename is the default; the user can edit it freely.
// No UI badge, helper copy, or synthetic "document" fallback.
// Marker: safebox-r7-original-name-simple
function sanitizeEditableVisibleName(value: string): string {
  return (value || "")
    .trim()
    .replace(/\.sbx$/i, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .replace(/[\/\\<>:\"|?*]/g, " ")
    .replace(/\s+/g, " ")
    .replace(/[. ]+$/g, "")
    .trim()
    .slice(0, 120);
}

function visibleNameFromOriginalPath(path: string): string {
  const rawName = fileNameFromPath(path || "");
  let decoded = rawName;
  try { decoded = decodeURIComponent(rawName); } catch {}
  const cleanName = decoded.split(/[?#]/, 1)[0] || decoded;
  const dot = cleanName.lastIndexOf(".");
  const stem = dot > 0 ? cleanName.slice(0, dot) : cleanName;
  return sanitizeEditableVisibleName(stem);
}

function syncVisibleNameFromOriginal(path: string) {
  const input = document.querySelector<HTMLInputElement>("#visibleName");
  if (!input) return;
  input.value = visibleNameFromOriginalPath(path);
}

const createInputR7 = document.querySelector<HTMLInputElement>("#createInput");
createInputR7?.addEventListener("change", async () => {
  const path = createInputR7.value.trim();
  if (!path) return;

  let sourceName = path;
  if (!SAFEBOX_TAURI_RUNTIME) {
    sourceName = browserFileName(path);
  } else {
    try {
      sourceName = (await invoke<string | null>("get_document_display_name", { value: path })) || path;
    } catch {}
  }
  syncVisibleNameFromOriginal(sourceName);
});

// SafeBox Settings UX R3 — Appearance + Help live inside Settings.
// Also provides true System / Light / Dark theme modes.
// Marker: settings-appearance-help-light-fix-r3
function sbxSettingsUiLabelsR3() {
  const locale = (() => {
    try {
      const raw = localStorage.getItem("safebox.language.v1") || "auto";
      const lang = raw === "auto" ? navigator.language.toLowerCase() : raw.toLowerCase();
      if (lang.startsWith("fr")) return "fr";
      if (lang.startsWith("de")) return "de";
      if (lang.startsWith("hr") || lang.startsWith("bs") || lang.startsWith("sr")) return "hr";
      if (lang.startsWith("es")) return "es";
      if (lang.startsWith("ar")) return "ar";
      if (lang.startsWith("it")) return "it";
      if (lang.startsWith("pt")) return "pt";
    } catch {}
    return "en";
  })();

  const labels = {
    en: { appearance: "Appearance", mode: "Mode", system: "System", light: "Light", dark: "Dark", help: "Help", helpHint: "SafeBox guide and security notes" },
    fr: { appearance: "Apparence", mode: "Mode", system: "Système", light: "Clair", dark: "Sombre", help: "Aide", helpHint: "Guide SafeBox et notes de sécurité" },
    de: { appearance: "Darstellung", mode: "Modus", system: "System", light: "Hell", dark: "Dunkel", help: "Hilfe", helpHint: "SafeBox-Anleitung und Sicherheitshinweise" },
    hr: { appearance: "Izgled", mode: "Način", system: "Sistem", light: "Svijetlo", dark: "Tamno", help: "Pomoć", helpHint: "SafeBox vodič i sigurnosne napomene" },
    es: { appearance: "Apariencia", mode: "Modo", system: "Sistema", light: "Claro", dark: "Oscuro", help: "Ayuda", helpHint: "Guía de SafeBox y notas de seguridad" },
    ar: { appearance: "المظهر", mode: "الوضع", system: "النظام", light: "فاتح", dark: "داكن", help: "مساعدة", helpHint: "دليل SafeBox وملاحظات الأمان" },
    it: { appearance: "Aspetto", mode: "Modalità", system: "Sistema", light: "Chiaro", dark: "Scuro", help: "Aiuto", helpHint: "Guida SafeBox e note di sicurezza" },
    pt: { appearance: "Aparência", mode: "Modo", system: "Sistema", light: "Claro", dark: "Escuro", help: "Ajuda", helpHint: "Guia SafeBox e notas de segurança" }
  } as const;

  return labels[locale as keyof typeof labels] || labels.en;
}

function sbxEnsureSettingsUtilitiesR3() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  // R6 naming policy: per-file original name replaces the obsolete global default field.
  modal.querySelector("#settingsDefaultName")?.closest("label")?.remove();

  const generalPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  if (!generalPanel) return;

  // Top bar must contain Settings only.
  document.querySelector("#themeToggle")?.remove();
  document.querySelectorAll<HTMLElement>("#helpBtn").forEach((button) => button.remove());

  let utilities = modal.querySelector<HTMLElement>("#settingsUtilities");
  if (!utilities) {
    utilities = document.createElement("section");
    utilities.id = "settingsUtilities";
    utilities.className = "settings-utilities-r3";
    utilities.innerHTML = `
      <div class="settings-utility-row settings-appearance-row">
        <div class="settings-utility-copy">
          <strong id="settingsAppearanceTitle"></strong>
          <span id="settingsAppearanceModeLabel"></span>
        </div>
        <div class="settings-theme-choice" role="group" aria-label="Appearance mode">
          <button class="settings-theme-option" type="button" data-theme-mode="system"></button>
          <button class="settings-theme-option" type="button" data-theme-mode="light"></button>
          <button class="settings-theme-option" type="button" data-theme-mode="dark"></button>
        </div>
      </div>
      <div class="settings-utility-row settings-help-row">
        <div class="settings-utility-copy">
          <strong id="settingsHelpTitle"></strong>
          <span id="settingsHelpHint"></span>
        </div>
        <div id="settingsHelpButtonSlot"></div>
      </div>
    `;
  }

  // Keep Appearance/Help directly after language selector when possible.
  const language = generalPanel.querySelector<HTMLElement>("#settingsLanguageField");
  if (utilities.parentElement !== generalPanel) {
    if (language?.nextSibling) generalPanel.insertBefore(utilities, language.nextSibling);
    else generalPanel.prepend(utilities);
  }

  const labels = sbxSettingsUiLabelsR3();
  const title = utilities.querySelector<HTMLElement>("#settingsAppearanceTitle");
  const mode = utilities.querySelector<HTMLElement>("#settingsAppearanceModeLabel");
  const helpTitle = utilities.querySelector<HTMLElement>("#settingsHelpTitle");
  const helpHint = utilities.querySelector<HTMLElement>("#settingsHelpHint");
  if (title) title.textContent = labels.appearance;
  if (mode) mode.textContent = labels.mode;
  if (helpTitle) helpTitle.textContent = labels.help;
  if (helpHint) helpHint.textContent = labels.helpHint;

  const textByMode: Record<SafeBoxThemeMode, string> = {
    system: labels.system,
    light: labels.light,
    dark: labels.dark
  };

  utilities.querySelectorAll<HTMLButtonElement>(".settings-theme-option").forEach((button) => {
    const themeMode = button.dataset.themeMode as SafeBoxThemeMode;
    button.textContent = textByMode[themeMode] || themeMode;
    if (button.dataset.sbxThemeBoundR3 !== "1") {
      button.dataset.sbxThemeBoundR3 = "1";
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        applyThemeMode(themeMode);
        setTimeout(sbxEnsureSettingsUtilitiesR3, 0);
      });
    }
  });

  // Reuse the existing full Help modal/controller, but keep its button in Settings.
  let helpButton = document.querySelector<HTMLButtonElement>("#howToUseBtn");
  if (!helpButton) {
    try { helpButton = ensureHowToUseButton(); } catch {}
  }
  const slot = utilities.querySelector<HTMLElement>("#settingsHelpButtonSlot");
  if (helpButton && slot && helpButton.parentElement !== slot) slot.appendChild(helpButton);
  if (helpButton) {
    helpButton.textContent = labels.help;
    helpButton.classList.add("settings-help-button-r3");

    // R4: Settings repair controllers can recreate this button after the
    // legacy Help initializer ran. Bind the action here as the final owner.
    if (helpButton.dataset.sbxSettingsHelpBoundR4 !== "1") {
      helpButton.dataset.sbxSettingsHelpBoundR4 = "1";
      helpButton.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        openHowToUseModal();
        const helpModal = document.querySelector<HTMLElement>("#howToUseModal");
        helpModal?.setAttribute("data-opened-from-settings", "1");
        setTimeout(() => helpModal?.querySelector<HTMLElement>("#closeHowToUseBtn")?.focus(), 0);
      });
    }
  }

  applyThemeMode(readThemeMode(), false);
}

function sbxOpenSettingsUtilitiesR3() {
  // Existing legacy Settings repair controllers rebuild the tab DOM several times.
  // Run after them and own only this small stable surface.
  [40, 140, 320, 520].forEach((delay) => setTimeout(sbxEnsureSettingsUtilitiesR3, delay));
}

document.querySelector("#settingsBtn")?.addEventListener("click", sbxOpenSettingsUtilitiesR3);
document.addEventListener("change", (event) => {
  if ((event.target as HTMLElement | null)?.id === "settingsLanguageSelect") {
    setTimeout(sbxEnsureSettingsUtilitiesR3, 40);
  }
});

setTimeout(sbxEnsureSettingsUtilitiesR3, 650);
console.debug("settings-appearance-help-light-fix-r4");

// R78: production browser E2E is inert unless explicitly armed on loopback.
installWebBrowserE2E();
