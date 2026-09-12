#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — Compact Access Profiles UX
#
# Goal:
# - Do NOT show the full profile form permanently in Settings.
# - Access Profiles tab shows only:
#   - explanation
#   - compact profile rows, if profiles exist
#   - + Add profile
# - Full profile fields open only in Add/Edit profile modal.
#
# Does NOT change encryption / SBX format / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-compact-access-profiles.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-compact-access-profiles.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

def replace_function(source: str, name: str, replacement: str) -> str:
    marker = f"function {name}("
    start = source.find(marker)
    if start == -1:
        raise SystemExit(f"Cannot find function {name}")

    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit(f"Cannot find opening brace for function {name}")

    depth = 0
    i = brace
    in_single = False
    in_double = False
    in_template = False
    escaped = False
    line_comment = False
    block_comment = False

    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue

        if block_comment:
            if ch == "*" and nxt == "/":
                block_comment = False
                i += 2
                continue
            i += 1
            continue

        if escaped:
            escaped = False
            i += 1
            continue

        if in_single:
            if ch == "\\":
                escaped = True
            elif ch == "'":
                in_single = False
            i += 1
            continue

        if in_double:
            if ch == "\\":
                escaped = True
            elif ch == '"':
                in_double = False
            i += 1
            continue

        if in_template:
            if ch == "\\":
                escaped = True
            elif ch == "`":
                in_template = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            block_comment = True
            i += 2
            continue

        if ch == "'":
            in_single = True
            i += 1
            continue

        if ch == '"':
            in_double = True
            i += 1
            continue

        if ch == "`":
            in_template = True
            i += 1
            continue

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[:start] + replacement + source[i + 1:]

        i += 1

    raise SystemExit(f"Cannot find end of function {name}")

# Replace permanent full-form renderer with compact renderer.
text = replace_function(text, "renderAccessProfilesSettings", r'''function renderAccessProfilesSettings() {
  const container = document.querySelector<HTMLElement>("#settingsProfilesList");
  if (!container) return;

  const profiles = readAccessProfiles();
  const defaultId = settings.defaultAccessProfile || profiles[0]?.id || "";

  if (!profiles.length) {
    container.innerHTML = `
      <div class="profiles-empty-state compact-profiles-empty">
        <strong>No access profiles yet.</strong>
        <p>Keep SafeBox simple: add a profile only when you need separate access for family, work, clients or private files.</p>
      </div>
    `;
    return;
  }

  container.innerHTML = `
    <div class="compact-profiles-list">
      ${profiles.map((profile, index) => {
        const isDefault = profile.id === defaultId || (!defaultId && index === 0);
        const access = profile.accessLabel || profile.profileName;

        return `
          <article class="compact-profile-row" data-profile-id="${esc(profile.id)}">
            <div class="compact-profile-main">
              <strong>${esc(profile.profileName)}</strong>
              <span>${esc(access)}</span>
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
}''')

# Ensure save handler does not wipe profiles just because compact rows are not .profile-card.
text = replace_function(text, "collectAccessProfilesFromSettings", r'''function collectAccessProfilesFromSettings(): AccessProfile[] {
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
}''')

# Add Profile now opens editor modal instead of adding full inline card.
text = replace_function(text, "addAccessProfileCard", r'''function addAccessProfileCard() {
  openAccessProfileEditor();
}''')

if "function ensureAccessProfileEditorModal()" not in text:
    text += r'''

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
          <div class="password-action-row">
            <input id="profileEditorCode" type="password" placeholder="kept only for this app session" autocomplete="new-password" />
            <button id="toggleProfileEditorCodeBtn" class="mini-btn" type="button">Show</button>
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

  const close = () => modal.classList.add("hidden");

  modal.querySelector("#closeProfileEditorBtn")?.addEventListener("click", close);
  modal.querySelector("#cancelProfileEditorBtn")?.addEventListener("click", close);

  modal.addEventListener("click", (event) => {
    if (event.target === modal) close();
  });

  modal.querySelector("#toggleProfileEditorCodeBtn")?.addEventListener("click", () => {
    const input = modal.querySelector<HTMLInputElement>("#profileEditorCode");
    const button = modal.querySelector<HTMLButtonElement>("#toggleProfileEditorCodeBtn");

    if (!input || !button) return;

    const hidden = input.type === "password";
    input.type = hidden ? "text" : "password";
    button.textContent = hidden ? "Hide" : "Show";
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
  if (toggleButton) toggleButton.textContent = "Show";

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
'''

p.write_text(text)
print("Compact Access Profiles patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* SafeBox Sprint 9A — Compact Access Profiles
   Marker variable: --compact-access-profiles-edit-modal
*/
:root {
  --compact-access-profiles-edit-modal: 1;
}

.compact-profiles-empty {
  margin-top: 12px !important;
}

.compact-profiles-list {
  display: grid !important;
  gap: 10px !important;
  margin-top: 12px !important;
}

.compact-profile-row {
  display: grid !important;
  grid-template-columns: minmax(0, 1fr) auto !important;
  align-items: center !important;
  gap: 14px !important;
  padding: 14px !important;
  border: 1px solid rgba(150, 170, 195, 0.22) !important;
  border-radius: 14px !important;
  background: rgba(255, 255, 255, 0.04) !important;
}

.compact-profile-main {
  display: grid !important;
  gap: 3px !important;
  min-width: 0 !important;
}

.compact-profile-main strong {
  font-size: 14px !important;
  font-weight: 850 !important;
  color: var(--text) !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
}

.compact-profile-main span {
  font-size: 12px !important;
  color: var(--muted) !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
}

.compact-profile-actions {
  display: flex !important;
  align-items: center !important;
  gap: 8px !important;
  flex-wrap: wrap !important;
  justify-content: flex-end !important;
}

.compact-profile-badge {
  display: inline-flex !important;
  align-items: center !important;
  min-height: 34px !important;
  padding: 0 11px !important;
  border-radius: 999px !important;
  border: 1px solid rgba(93, 190, 255, 0.24) !important;
  background: rgba(93, 190, 255, 0.10) !important;
  color: #8FD3FF !important;
  font-size: 12px !important;
  font-weight: 850 !important;
}

.access-profile-editor-modal {
  z-index: 1000003 !important;
}

.access-profile-editor-card {
  width: min(560px, calc(100vw - 44px)) !important;
  max-height: calc(100vh - 44px) !important;
}

.access-profile-editor-body {
  display: grid !important;
  gap: 14px !important;
  padding: 20px 24px !important;
  overflow-y: auto !important;
}

.profile-editor-actions {
  display: grid !important;
  grid-template-columns: 1fr auto !important;
  gap: 12px !important;
}

@media (max-width: 760px) {
  .compact-profile-row {
    grid-template-columns: 1fr !important;
  }

  .compact-profile-actions {
    justify-content: stretch !important;
  }

  .compact-profile-actions .mini-btn,
  .compact-profile-badge {
    flex: 1 1 auto !important;
    justify-content: center !important;
  }

  .profile-editor-actions {
    grid-template-columns: 1fr !important;
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify compact profile marker"
grep -R "compact-access-profiles-edit-modal" dist || echo "ERROR: compact profile marker absent from dist"

echo ""
echo "Compact Access Profiles applied."
echo "Run:"
echo "  npm run tauri dev"
