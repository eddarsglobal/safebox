#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 8C — Simple Access Profiles UX
#
# Changes:
# - No default visible profiles (Private / Family / Work) at first launch.
# - Access Profiles tab initially shows only an empty state + "+ Add profile".
# - Profile block appears only after user clicks "+ Add profile".
# - Create SBX hides Access profile dropdown when there are no custom profiles.
# - Field labels become clearer:
#   - "Profile name" -> "Name in SafeBox"
#   - "Access label" -> "Shown in File info"
#
# Does not change encryption / unlock / SBX format.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint8c-simple-profiles.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint8c-simple-profiles.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

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
                i += 1
                continue
            if ch == "`":
                in_template = False
                i += 1
                continue
            # Count ${...} braces normally enough by not skipping braces in template literal.
            # This simple scanner is fine because the whole function ends after balanced braces.
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    return source[:start] + replacement + source[end:]
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
                end = i + 1
                return source[:start] + replacement + source[end:]

        i += 1

    raise SystemExit(f"Cannot find end of function {name}")

if "safebox.simpleProfiles.v1" not in text:
    text = text.replace(
        'const ACCESS_PROFILE_CODE_PREFIX = "safebox.accessProfileCode.v1.";',

        'const ACCESS_PROFILE_CODE_PREFIX = "safebox.accessProfileCode.v1.";\nconst SIMPLE_PROFILES_MIGRATION_KEY = "safebox.simpleProfiles.v1";'
    )

text = replace_function(text, "defaultAccessProfiles", r'''function defaultAccessProfiles(): AccessProfile[] {
  return [];
}''')

text = replace_function(text, "readAccessProfiles", r'''function readAccessProfiles(): AccessProfile[] {
  try {
    const migrated = localStorage.getItem(SIMPLE_PROFILES_MIGRATION_KEY);

    if (!migrated) {
      localStorage.setItem(SIMPLE_PROFILES_MIGRATION_KEY, "1");
      localStorage.removeItem(ACCESS_PROFILES_KEY);
      return [];
    }

    const raw = localStorage.getItem(ACCESS_PROFILES_KEY);
    if (!raw) return [];

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];

    return parsed
      .map((item, index) => normalizeProfile(item, index))
      .filter((profile) => profile.profileName.trim());
  } catch {
    return [];
  }
}''')

text = replace_function(text, "renderCreateProfileSelect", r'''function renderCreateProfileSelect() {
  const select = document.querySelector<HTMLSelectElement>("#createProfileSelect");
  if (!select) return;

  const wrapper =
    select.closest<HTMLElement>("label") ||
    select.closest<HTMLElement>(".field") ||
    select.parentElement;

  const profiles = readAccessProfiles();

  if (!profiles.length) {
    select.innerHTML = "";
    if (wrapper) {
      wrapper.classList.add("hidden", "simple-profile-hidden");
      wrapper.style.display = "none";
    }

    setInput("#senderLabel", settings.globalSenderLabel || "");
    setInput("#accessProfile", "");
    return;
  }

  if (wrapper) {
    wrapper.classList.remove("hidden", "simple-profile-hidden");
    wrapper.style.display = "";
  }

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
}''')

text = replace_function(text, "applySelectedProfileToCreate", r'''function applySelectedProfileToCreate() {
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
}''')

text = replace_function(text, "renderAccessProfilesSettings", r'''function renderAccessProfilesSettings() {
  const container = document.querySelector<HTMLElement>("#settingsProfilesList");
  if (!container) return;

  const profiles = readAccessProfiles();

  if (!profiles.length) {
    container.innerHTML = `
      <div class="profiles-empty-state">
        <strong>No access profiles yet.</strong>
        <p>Keep SafeBox simple: use the global code, or add a profile only when you need separate access for family, work, clients or private files.</p>
      </div>
    `;
    return;
  }

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
            Name in SafeBox
            <input class="profile-name-input" value="${esc(profile.profileName)}" autocomplete="off" />
          </label>
          <label>
            Shown in File info
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
}''')

text = replace_function(text, "addAccessProfileCard", r'''function addAccessProfileCard() {
  const profiles = collectAccessProfilesFromSettings();
  const nextIndex = profiles.length + 1;
  const suggestedName = profiles.length ? `Profile ${nextIndex}` : "Private";

  profiles.push({
    id: makeProfileId(),
    profileName: suggestedName,
    senderLabel: settings.globalSenderLabel || "",
    accessLabel: suggestedName
  });

  writeAccessProfiles(profiles);

  if (!settings.defaultAccessProfile) {
    settings = {
      ...readSettings(),
      defaultAccessProfile: profiles[0]?.id || ""
    };
    writeSettings(settings);
  }

  renderAccessProfilesSettings();
  renderCreateProfileSelect();
}''')

# Add marker
if "SAFEBOX_SIMPLE_ACCESS_PROFILES_SPRINT8C_MARKER" not in text:
    text += r'''

function SAFEBOX_SIMPLE_ACCESS_PROFILES_SPRINT8C_MARKER() {
  return "simple-access-profiles-add-profile-only";
}

console.debug(SAFEBOX_SIMPLE_ACCESS_PROFILES_SPRINT8C_MARKER());
'''

p.write_text(text)
print("Sprint 8C Simple Access Profiles patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* Sprint 8C — Simple Access Profiles UX */
.simple-profile-hidden {
  display: none !important;
}

.profiles-empty-state {
  border: 1px dashed rgba(121, 215, 255, 0.32);
  border-radius: 18px;
  padding: 16px;
  background: rgba(8, 26, 49, 0.22);
  color: var(--text);
}

.profiles-empty-state strong {
  display: block;
  margin-bottom: 6px;
  color: var(--text);
}

.profiles-empty-state p {
  margin: 0;
  color: var(--muted);
  line-height: 1.45;
}

.profile-card label {
  font-size: 13px;
}

.profile-card input::placeholder {
  color: rgba(142, 167, 194, 0.72);
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 8C marker"
grep -R "simple-access-profiles-add-profile-only" dist || echo "ERROR: Sprint 8C marker absent from dist"
grep -R "Name in SafeBox" dist || echo "ERROR: Name in SafeBox absent from dist"
grep -R "Shown in File info" dist || echo "ERROR: Shown in File info absent from dist"

echo ""
echo "Sprint 8C Simple Access Profiles patch applied."
echo "Run:"
echo "  npm run tauri dev"
