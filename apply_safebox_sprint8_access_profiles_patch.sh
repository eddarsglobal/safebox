#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint8-profiles.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint8-profiles.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/main.ts")
text = p.read_text()

# Add access profile types/constants after SafeBoxSettings
if "type AccessProfile = {" not in text:
    m = re.search(r"type SafeBoxSettings\s*=\s*\{[\s\S]*?\};", text)
    if not m:
        raise SystemExit("Cannot find SafeBoxSettings type")
    payload = '''

type AccessProfile = {
  id: string;
  profileName: string;
  senderLabel: string;
  accessLabel: string;
};

const ACCESS_PROFILES_KEY = "safebox.accessProfiles.v1";
const ACCESS_PROFILE_CODE_PREFIX = "safebox.accessProfileCode.v1.";
'''
    text = text[:m.end()] + payload + text[m.end():]

# Add helper functions before readSettings
if "function makeProfileId()" not in text:
    marker = "function readSettings(): SafeBoxSettings {"
    helpers = r'''
function makeProfileId(): string {
  return `profile_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

function defaultAccessProfiles(): AccessProfile[] {
  return [
    { id: "private", profileName: "Private", senderLabel: "", accessLabel: "Private" },
    { id: "family", profileName: "Family", senderLabel: "", accessLabel: "Family" },
    { id: "work", profileName: "Work", senderLabel: "", accessLabel: "Work" }
  ];
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
  try {
    const raw = localStorage.getItem(ACCESS_PROFILES_KEY);
    if (!raw) return defaultAccessProfiles();

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return defaultAccessProfiles();

    const profiles = parsed
      .map((item, index) => normalizeProfile(item, index))
      .filter((profile) => profile.profileName.trim());

    return profiles.length ? profiles : defaultAccessProfiles();
  } catch {
    return defaultAccessProfiles();
  }
}

function writeAccessProfiles(profiles: AccessProfile[]) {
  localStorage.setItem(
    ACCESS_PROFILES_KEY,
    JSON.stringify(profiles.map((profile, index) => normalizeProfile(profile, index)))
  );
}

function getProfileCode(profileId: string): string {
  return sessionStorage.getItem(`${ACCESS_PROFILE_CODE_PREFIX}${profileId}`) || "";
}

function setProfileCode(profileId: string, code: string) {
  const key = `${ACCESS_PROFILE_CODE_PREFIX}${profileId}`;

  if (code.trim()) {
    sessionStorage.setItem(key, code.trim());
  } else {
    sessionStorage.removeItem(key);
  }
}

function profileOptionLabel(profile: AccessProfile): string {
  return `${profile.profileName}${profile.accessLabel && profile.accessLabel !== profile.profileName ? ` · ${profile.accessLabel}` : ""}`;
}

'''
    if marker not in text:
        raise SystemExit("Cannot find readSettings marker")
    text = text.replace(marker, helpers + marker, 1)

# Add create profile dropdown
if 'id="createProfileSelect"' not in text:
    old_variants = [
'''          <div class="grid-2">
            <label>
              Sender label
              <input id="senderLabel" placeholder="visible before unlock" autocomplete="off" />
            </label>
            <label>
              Access profile
              <input id="accessProfile" placeholder="Family / Work / Private" autocomplete="off" />
            </label>
          </div>''',
'''          <div class="grid-2">
            <label>
              Sender label
              <input id="senderLabel" placeholder="visible in File info" autocomplete="off" />
            </label>
            <label>
              Access label
              <input id="accessProfile" placeholder="Family / Work / Private" autocomplete="off" />
            </label>
          </div>'''
    ]
    old = next((v for v in old_variants if v in text), None)
    new = '''          <label>
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
          </div>'''
    if old is None:
        raise SystemExit("Cannot find create sender/access grid around senderLabel")
    text = text.replace(old, new, 1)

# Add Settings access profiles section
if 'id="settingsProfilesList"' not in text:
    note = '''        <p class="settings-note">
          MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.
        </p>'''
    section = note + r'''

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
            MVP: profile codes are kept only for this app session. Profile names and labels are saved.
          </p>
        </section>'''
    if note in text:
        text = text.replace(note, section, 1)
    else:
        fallback = '<div class="settings-actions">'
        section2 = r'''        <div class="settings-section-divider"></div>

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
            MVP: profile codes are kept only for this app session. Profile names and labels are saved.
          </p>
        </section>

'''
        if fallback not in text:
            raise SystemExit("Cannot find insertion point for profiles section")
        text = text.replace(fallback, section2 + fallback, 1)

# Add UI functions before openSettings
if "function renderAccessProfilesSettings()" not in text:
    marker = "function openSettings() {"
    funcs = r'''
function renderCreateProfileSelect() {
  const select = document.querySelector<HTMLSelectElement>("#createProfileSelect");
  if (!select) return;

  const profiles = readAccessProfiles();
  const selectedId = settings.defaultAccessProfile || profiles[0]?.id || "";

  select.innerHTML = profiles
    .map((profile) => `<option value="${esc(profile.id)}">${esc(profileOptionLabel(profile))}</option>`)
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
  const defaultId = settings.defaultAccessProfile || profiles[0]?.id || "";

  container.innerHTML = profiles.map((profile, index) => {
    const code = getProfileCode(profile.id);
    const isDefault = profile.id === defaultId || (!defaultId && index === 0);

    return `
      <article class="profile-card" data-profile-id="${esc(profile.id)}">
        <div class="profile-card-top">
          <strong>${esc(profile.profileName)}</strong>
          <span>${isDefault ? "Default" : "Profile"}</span>
        </div>

        <div class="grid-2">
          <label>
            Profile name
            <input class="profile-name-input" value="${esc(profile.profileName)}" autocomplete="off" />
          </label>
          <label>
            Access label
            <input class="profile-access-input" value="${esc(profile.accessLabel)}" autocomplete="off" />
          </label>
        </div>

        <label>
          Sender label
          <input class="profile-sender-input" value="${esc(profile.senderLabel)}" placeholder="use global sender if empty" autocomplete="off" />
        </label>

        <label>
          Code
          <div class="password-action-row">
            <input class="profile-code-input" type="password" value="${esc(code)}" placeholder="kept only for this session" autocomplete="new-password" />
            <button class="mini-btn profile-toggle-code" type="button">Show</button>
          </div>
        </label>

        <div class="profile-actions">
          <button class="mini-btn profile-set-default" type="button">Set default</button>
          <button class="mini-btn danger-link profile-delete" type="button">Delete</button>
        </div>
      </article>
    `;
  }).join("");
}

function collectAccessProfilesFromSettings(): AccessProfile[] {
  const cards = Array.from(document.querySelectorAll<HTMLElement>(".profile-card"));

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
  const profiles = collectAccessProfilesFromSettings();
  const nextIndex = profiles.length + 1;

  profiles.push({
    id: makeProfileId(),
    profileName: `Profile ${nextIndex}`,
    senderLabel: settings.globalSenderLabel || "",
    accessLabel: `Profile ${nextIndex}`
  });

  writeAccessProfiles(profiles);
  renderAccessProfilesSettings();
}

'''
    if marker not in text:
        raise SystemExit("Cannot find openSettings marker")
    text = text.replace(marker, funcs + marker, 1)

# Patch applySettingsToUi to render select
apply_start = text.find("function applySettingsToUi()")
apply_end = text.find("\n}", apply_start)
if apply_start == -1 or apply_end == -1:
    raise SystemExit("Cannot find applySettingsToUi")
apply_block = text[apply_start:apply_end+2]
if "renderCreateProfileSelect();" not in apply_block:
    apply_block = re.sub(r'\n\s*setInput\("#senderLabel",[\s\S]*?;\n\s*setInput\("#accessProfile",[\s\S]*?;', '', apply_block)
    apply_block = apply_block.replace('  setInput("#visibleName", visibleName);', '  setInput("#visibleName", visibleName);\n  renderCreateProfileSelect();')
    text = text[:apply_start] + apply_block + text[apply_end+2:]

# Patch openSettings to render profiles
open_start = text.find("function openSettings()")
open_end = text.find("\n}", open_start)
if open_start != -1 and open_end != -1:
    open_block = text[open_start:open_end+2]
    if "renderAccessProfilesSettings();" not in open_block:
        open_block = open_block.replace('  settingsModal.classList.remove("hidden");', '  renderAccessProfilesSettings();\n  settingsModal.classList.remove("hidden");')
        text = text[:open_start] + open_block + text[open_end+2:]

# Patch save settings handler
save_marker = '$("#saveSettingsBtn").addEventListener("click", () => {'
save_start = text.find(save_marker)
save_end = text.find("\n});", save_start)
if save_start == -1 or save_end == -1:
    raise SystemExit("Cannot find save settings handler")
save_block = text[save_start:save_end+4]
if "const nextProfiles = collectAccessProfilesFromSettings();" not in save_block:
    save_block = save_block.replace(save_marker, save_marker + '\n  const nextProfiles = collectAccessProfilesFromSettings();\n  writeAccessProfiles(nextProfiles);\n  const currentDefault = settings.defaultAccessProfile || nextProfiles[0]?.id || "";')
    save_block = re.sub(
        r'defaultAccessProfile:\s*cleanPublicInput\(inputValue\("#settingsDefaultAccessProfile"\)\)',
        'defaultAccessProfile: currentDefault || nextProfiles[0]?.id || ""',
        save_block
    )
    if "defaultAccessProfile:" not in save_block:
        save_block = save_block.replace(
            'globalSenderLabel: cleanPublicInput(inputValue("#settingsGlobalSenderLabel"))',
            'globalSenderLabel: cleanPublicInput(inputValue("#settingsGlobalSenderLabel")),\n    defaultAccessProfile: currentDefault || nextProfiles[0]?.id || ""'
        )
    save_block = save_block.replace(
        '<span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>',
        '<span>Global code</span><code>${nextSettings.useGlobalCode && getGlobalCode() ? "enabled" : "disabled"}</code>\n      <span>Profiles</span><code>${nextProfiles.length}</code>'
    )
    text = text[:save_start] + save_block + text[save_end+4:]

# Add listeners after cancel settings
listener_marker = '$("#cancelSettingsBtn").addEventListener("click", closeSettings);'
listeners = r'''

$("#addProfileBtn").addEventListener("click", addAccessProfileCard);

$("#settingsProfilesList").addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  const card = target.closest<HTMLElement>(".profile-card");
  if (!card) return;

  if (target.closest(".profile-toggle-code")) {
    const input = card.querySelector<HTMLInputElement>(".profile-code-input");
    const button = target.closest<HTMLButtonElement>(".profile-toggle-code");
    if (!input || !button) return;

    const isHidden = input.type === "password";
    input.type = isHidden ? "text" : "password";
    button.textContent = isHidden ? "Hide" : "Show";
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
'''
if listener_marker in text and '$("#addProfileBtn").addEventListener' not in text:
    text = text.replace(listener_marker, listener_marker + listeners, 1)

# Build marker
if "SAFEBOX_ACCESS_PROFILES_SPRINT8_MARKER" not in text:
    text += r'''

function SAFEBOX_ACCESS_PROFILES_SPRINT8_MARKER() {
  return "access-profiles-blocks-add-profile";
}

console.debug(SAFEBOX_ACCESS_PROFILES_SPRINT8_MARKER());
'''

p.write_text(text)
print("Sprint 8 main.ts patch applied")
PY

cat >> src/style.css <<'CSS'

/* Sprint 8 — Access Profiles */
.settings-section-divider {
  height: 1px;
  background: rgba(142, 167, 194, 0.20);
  margin: 18px 0;
}

.profiles-section h3 {
  margin: 0;
  font-size: 15px;
  letter-spacing: -0.01em;
}

.profiles-section p {
  margin: 4px 0 0;
  color: #8EA7C2;
  font-size: 12px;
  line-height: 1.35;
}

.profiles-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.profiles-list {
  display: grid;
  gap: 12px;
}

.profile-card {
  border: 1px solid rgba(142, 167, 194, 0.22);
  border-radius: 18px;
  padding: 14px;
  background: rgba(8, 26, 49, 0.30);
}

.profile-card-top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.profile-card-top strong {
  color: #F8FBFF;
}

.profile-card-top span {
  color: #79D7FF;
  font-size: 12px;
  font-weight: 850;
}

.profile-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 10px;
  flex-wrap: wrap;
}

#createProfileSelect {
  width: 100%;
}
CSS

echo "==> Build check"
npm run build

echo ""
echo "==> Verify Sprint 8 marker"
grep -R "access-profiles-blocks-add-profile" dist || echo "ERROR: Sprint 8 marker absent from dist"

echo ""
echo "Sprint 8 Access Profiles patch applied."
echo "Run:"
echo "  npm run tauri dev"
