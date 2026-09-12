#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-7 — Default SBX name sync
#
# Goal:
# - Settings → Default SBX name should prefill main Visible SBX name.
# - Do NOT overwrite main Visible SBX name if user typed a custom name.
# - Works after rollback to stable Settings state.
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
cp src/main.ts "src/main.ts.backup-sprint10a7-default-sbx-name-sync.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a7-default-sbx-name-sync.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a7-default-sbx-name-sync-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-7 — Default SBX name sync
// Marker: sprint10a7-default-sbx-name-sync-v1
function sbxTrim10A7(value: unknown) {
  return String(value || "").trim();
}

function sbxTextAroundInput10A7(input: HTMLInputElement) {
  const parts: string[] = [];
  const label = input.closest("label");
  const wrap =
    input.closest(".field") ||
    input.closest(".form-row") ||
    input.closest(".input-group") ||
    input.closest(".create-field") ||
    input.parentElement;

  if (label) parts.push(label.textContent || "");
  if (wrap) parts.push(wrap.textContent || "");
  parts.push(input.id || "", input.name || "", input.placeholder || "", input.getAttribute("aria-label") || "");

  return parts.join(" ").replace(/\s+/g, " ").trim().toLowerCase();
}

function sbxFindSettingsDefaultNameInput10A7() {
  const fixed =
    document.querySelector<HTMLInputElement>("#settingsDefaultName") ||
    document.querySelector<HTMLInputElement>("#settingsDefaultSbxName") ||
    document.querySelector<HTMLInputElement>("#settingsDefaultVisibleName") ||
    null;

  if (fixed) return fixed;

  return (
    Array.from(document.querySelectorAll<HTMLInputElement>("#settingsModal input")).find((input) => {
      const text = sbxTextAroundInput10A7(input);
      return (
        text.includes("default sbx name") ||
        text.includes("default name") ||
        text.includes("nom sbx") ||
        text.includes("nom par défaut") ||
        text.includes("nom par defaut") ||
        text.includes("standard sbx") ||
        text.includes("zadani sbx") ||
        text.includes("nombre sbx")
      );
    }) || null
  );
}

function sbxFindMainVisibleNameInput10A7() {
  const fixed =
    document.querySelector<HTMLInputElement>("#visibleNameInput") ||
    document.querySelector<HTMLInputElement>("#createVisibleName") ||
    document.querySelector<HTMLInputElement>("#visibleSbxName") ||
    document.querySelector<HTMLInputElement>("#createSbxName") ||
    document.querySelector<HTMLInputElement>("#visibleFileName") ||
    null;

  if (fixed && !fixed.closest("#settingsModal")) return fixed;

  return (
    Array.from(document.querySelectorAll<HTMLInputElement>("input")).find((input) => {
      if (input.closest("#settingsModal")) return false;
      if (input.closest("#accessProfileEditorModal")) return false;
      if (input.closest("#hardReceiverOverlay")) return false;
      if (input.closest("#howToUseModal")) return false;
      if (input.closest("#helpModal")) return false;

      const text = sbxTextAroundInput10A7(input);
      return (
        text.includes("visible sbx name") ||
        text.includes("visible name") ||
        text.includes("nom sbx visible") ||
        text.includes("vidljivi sbx") ||
        text.includes("nombre sbx visible") ||
        text.includes("visiblename") ||
        text.includes("displayname")
      );
    }) || null
  );
}

function sbxReadDefaultSbxName10A7() {
  const settingsInput = sbxFindSettingsDefaultNameInput10A7();
  if (settingsInput && sbxTrim10A7(settingsInput.value)) return sbxTrim10A7(settingsInput.value);

  try {
    const raw = localStorage.getItem("safebox.settings.v1");
    if (raw) {
      const s = JSON.parse(raw) as Record<string, unknown>;
      return sbxTrim10A7(
        s.defaultSbxName || s.defaultName || s.defaultVisibleName || s.visibleName || s.defaultFileName || ""
      );
    }
  } catch {}

  try {
    return sbxTrim10A7(localStorage.getItem("safebox.defaultSbxName.v1") || "");
  } catch {
    return "";
  }
}

function sbxAutoNames10A7() {
  const set = new Set<string>(["", "document", "Document", "DOCUMENT"]);
  try {
    const previous = localStorage.getItem("safebox.previousDefaultSbxName.10a7") || "";
    if (previous) set.add(previous);
  } catch {}
  try {
    const currentDefault = sbxReadDefaultSbxName10A7();
    if (currentDefault) set.add(currentDefault);
  } catch {}
  return set;
}

function sbxMainNameIsCustom10A7(input: HTMLInputElement) {
  if (input.dataset.sbxUserCustomizedName10A7 === "1") return true;
  return !sbxAutoNames10A7().has(sbxTrim10A7(input.value));
}

function sbxSyncDefaultNameToMain10A7(force = false) {
  const main = sbxFindMainVisibleNameInput10A7();
  const next = sbxReadDefaultSbxName10A7() || "document";
  if (!main) return;
  if (!force && sbxMainNameIsCustom10A7(main)) return;

  if (sbxTrim10A7(main.value) !== next) {
    main.value = next;
    main.dispatchEvent(new Event("input", { bubbles: true }));
    main.dispatchEvent(new Event("change", { bubbles: true }));
  }

  main.dataset.sbxUserCustomizedName10A7 = "0";
  try {
    localStorage.setItem("safebox.previousDefaultSbxName.10a7", next);
  } catch {}
}

function sbxInstallDefaultNameSync10A7() {
  const main = sbxFindMainVisibleNameInput10A7();
  if (main && main.dataset.sbxNameSyncInstalled10A7 !== "1") {
    main.dataset.sbxNameSyncInstalled10A7 = "1";
    main.addEventListener("input", () => {
      const auto = sbxAutoNames10A7();
      const value = sbxTrim10A7(main.value);
      main.dataset.sbxUserCustomizedName10A7 = value && !auto.has(value) ? "1" : "0";
    });
  }

  const settings = sbxFindSettingsDefaultNameInput10A7();
  if (settings && settings.dataset.sbxNameSyncInstalled10A7 !== "1") {
    settings.dataset.sbxNameSyncInstalled10A7 = "1";
    settings.addEventListener("input", () => sbxSyncDefaultNameToMain10A7(false));
    settings.addEventListener("change", () => setTimeout(() => sbxSyncDefaultNameToMain10A7(false), 30));
  }
}

function sbxTickDefaultNameSync10A7() {
  sbxInstallDefaultNameSync10A7();
  const main = sbxFindMainVisibleNameInput10A7();
  if (main && !sbxMainNameIsCustom10A7(main)) sbxSyncDefaultNameToMain10A7(false);
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;
    if (target?.closest("#settingsBtn") || target?.closest("#settingsModal") || target?.closest("button")) {
      sbxTickDefaultNameSync10A7();
      setTimeout(sbxTickDefaultNameSync10A7, 80);
      setTimeout(sbxTickDefaultNameSync10A7, 220);
    }
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;
  if (target?.closest("#settingsModal")) {
    setTimeout(() => sbxSyncDefaultNameToMain10A7(false), 40);
    setTimeout(() => sbxSyncDefaultNameToMain10A7(false), 180);
  }
});

if (!(window as any).__safeboxDefaultSbxNameObserver10A7) {
  const observer = new MutationObserver(() => sbxInstallDefaultNameSync10A7());
  observer.observe(document.body, { childList: true, subtree: true });
  (window as any).__safeboxDefaultSbxNameObserver10A7 = observer;
}

setTimeout(sbxTickDefaultNameSync10A7, 100);
setTimeout(sbxTickDefaultNameSync10A7, 500);
setTimeout(sbxTickDefaultNameSync10A7, 1200);

console.debug("sprint10a7-default-sbx-name-sync-v1");
TS
fi

if ! grep -q "sprint10a7-default-sbx-name-sync-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-7 — Default SBX name sync */
:root {
  --sprint10a7-default-sbx-name-sync-v1: 1;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-7 marker"
grep -R -- "sprint10a7-default-sbx-name-sync-v1" dist || echo "ERROR: Sprint 10A-7 marker absent from dist"

echo ""
echo "Sprint 10A-7 Default SBX name sync applied."
echo "Run:"
echo "  npm run tauri dev"
