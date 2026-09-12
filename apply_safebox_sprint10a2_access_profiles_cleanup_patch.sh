#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-2 — Access Profiles Cleanup
#
# Goal:
# - Access Profiles empty by default.
# - No auto-created Private / Work / Family demo profiles.
# - Compact list only in Settings.
# - Full profile editor only via + Add profile or Edit.
# - Main app hides Access profile when profiles list is empty.
#
# Does NOT touch encryption / SBX format / receiver unlock logic / macOS icon.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a2-access-profiles.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a2-access-profiles.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

def replace_function(source: str, name: str, replacement: str) -> str:
    marker = f"function {name}("
    start = source.find(marker)
    if start == -1:
        return source + "\n\n" + replacement + "\n"

    brace = source.find("{", start)
    if brace == -1:
        raise SystemExit(f"Cannot find opening brace for {name}")

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

# 1. No default demo profiles.
text = replace_function(text, "defaultAccessProfiles", r'''function defaultAccessProfiles(): AccessProfile[] {
  return [];
}''')

# 2. Read profiles safely, with one-time cleanup of old demo profiles.
text = replace_function(text, "readAccessProfiles", r'''function readAccessProfiles(): AccessProfile[] {
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
}''')

# 3. Compact renderer only.
text = replace_function(text, "renderAccessProfilesSettings", r'''function renderAccessProfilesSettings() {
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
}''')

# 4. Do not erase profiles when no inline .profile-card exists.
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

# 5. Add profile opens editor modal only.
text = replace_function(text, "addAccessProfileCard", r'''function addAccessProfileCard() {
  openAccessProfileEditor();
}''')

# 6. Main page profile select hidden when there are no profiles.
text = replace_function(text, "renderCreateProfileSelect", r'''function renderCreateProfileSelect() {
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
}''')

# 7. Strong hide guard for main page Access profile select.
text = replace_function(text, "sbxHideMainAccessProfileWhenEmpty", r'''function sbxHideMainAccessProfileWhenEmpty() {
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
}''')

# 8. Ensure profile editor exists if previous compact patch was absent.
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
  const suggestedName = profiles.length ? `Profile ${profiles.length + 1}` : "";
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
  sbxHideMainAccessProfileWhenEmpty();

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
  sbxHideMainAccessProfileWhenEmpty();
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
  sbxHideMainAccessProfileWhenEmpty();
}
'''

# 9. Single compact event controller. This avoids permanent inline profile-card behavior.
if "sprint10a2-access-profiles-single-controller-v1" not in text:
    text += r'''

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
'''

p.write_text(text)
print("OK: Sprint 10A-2 Access Profiles cleanup patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-2 — Access Profiles Cleanup */
:root {
  --sprint10a2-access-profiles-single-controller-v1: 1;
}

/* Access Profiles tab: compact by default */
#settingsProfilesList .profile-card {
  display: none !important;
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

.compact-profile-main strong,
.compact-profile-main span {
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
}

.compact-profile-actions {
  display: flex !important;
  align-items: center !important;
  justify-content: flex-end !important;
  gap: 8px !important;
  flex-wrap: wrap !important;
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

/* Main page: hide Access profile when no profiles exist */
.sbx-hide-main-access-profile {
  display: none !important;
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
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-2 marker"
grep -R -- "sprint10a2-access-profiles-single-controller-v1" dist || echo "ERROR: Sprint 10A-2 marker absent from dist"

echo ""
echo "Sprint 10A-2 Access Profiles Cleanup applied."
echo "Run:"
echo "  npm run tauri dev"
