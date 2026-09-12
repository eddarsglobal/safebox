#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-6 — Post-cleanup stability audit
#
# This script does NOT modify app source code.
# It audits the app after 10A-1..10A-5 and creates a report.
#
# Outputs:
# - checkpoints/SPRINT10A6_POST_CLEANUP_AUDIT_REPORT.md
# - checkpoints/SPRINT10A6_BUILD_REPORT.txt

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

DESKTOP="$ROOT/safebox-desktop"
REPORT_DIR="$ROOT/checkpoints"
REPORT="$REPORT_DIR/SPRINT10A6_POST_CLEANUP_AUDIT_REPORT.md"
BUILD_LOG="$REPORT_DIR/SPRINT10A6_BUILD_REPORT.txt"

mkdir -p "$REPORT_DIR"

cd "$DESKTOP"

echo "==> Sprint 10A-6 post-cleanup audit started"

python3 - <<'PY'
from pathlib import Path
import re
from collections import Counter
from datetime import datetime

root = Path.cwd()
workspace = root.parent
report_dir = workspace / "checkpoints"
report = report_dir / "SPRINT10A6_POST_CLEANUP_AUDIT_REPORT.md"

main = root / "src/main.ts"
css = root / "src/style.css"
pkg = root / "package.json"

main_text = main.read_text() if main.exists() else ""
css_text = css.read_text() if css.exists() else ""
pkg_text = pkg.read_text() if pkg.exists() else ""

markers_expected = [
    "sprint10a1-help-single-controller-v1",
    "sprint10a2-access-profiles-single-controller-v1",
    "sprint10a3d-settings-dedupe-v1",
    "sprint10a4-i18n-cleanup-v1",
    "sprint10a4b-i18n-no-flicker-v1",
    "sprint10a5-scroll-modal-state-v1",
    "receiver-main-screen-file-name-only",
    "sprint9b-how-to-use-safebox-v1",
    "sprint9c-full-app-i18n-v1",
    "hide-main-access-profile-when-empty-v1",
    "force-empty-access-profiles-v1",
]

markers_found = {marker: (marker in main_text or marker in css_text) for marker in markers_expected}

functions = re.findall(r"\bfunction\s+([A-Za-z0-9_]+)\s*\(", main_text)
func_counts = Counter(functions)
duplicate_functions = [(name, count) for name, count in sorted(func_counts.items()) if count > 1]

css_selectors = re.findall(r"(^|\n)\s*([.#][A-Za-z0-9_-]+(?:\s+[.#A-Za-z0-9_:-]+)?|#[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*)\s*[,{]", css_text)
selector_counts = Counter(sel for _, sel in css_selectors)
duplicate_selectors = [(sel, count) for sel, count in selector_counts.items() if count > 4]

hotfix_markers = sorted(set(re.findall(r"sprint[0-9]+[a-z0-9-]*[-a-z0-9]*v[0-9]+|[-a-z0-9]+-v[0-9]+", (main_text + "\n" + css_text).lower())))

risk_patterns = {
    "CSS !important": css_text.count("!important"),
    "main.ts lines": len(main_text.splitlines()),
    "style.css lines": len(css_text.splitlines()),
    "setTimeout calls": main_text.count("setTimeout("),
    "setInterval calls": main_text.count("setInterval("),
    "MutationObserver": main_text.count("MutationObserver"),
    "document click listeners": main_text.count('document.addEventListener(\n  "click"') + main_text.count('document.addEventListener("click"'),
    "body overflow writes": len(re.findall(r"document\.body\.style\.overflow", main_text)),
    "html overflow writes": len(re.findall(r"document\.documentElement\.style\.overflow", main_text)),
    "window any assignments": main_text.count("(window as any)"),
    "replaceAll usage": len(re.findall(r"\.replaceAll\s*\(", main_text)),
    "settingsTabsRoot references": main_text.count("settingsTabsRoot"),
    "settingsPanelSecurity references": main_text.count("settingsPanelSecurity"),
    "AccessProfile references": main_text.count("AccessProfile"),
}

asset_checks = {
    ".sbx file icon source": (root / "src-tauri/icons/safebox-file.icns").exists(),
    "Tauri icon finalizer": (root / "scripts/finalize_macos_bundle.sh").exists(),
    "Tauri wrapper script": "scripts/safebox_tauri.sh" in pkg_text,
    "ensure icon source script": (root / "scripts/ensure_sbx_icon_source.sh").exists(),
}

sections = []
sections.append("# SafeBox Sprint 10A-6 — Post-cleanup stability audit\n\n")
sections.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
sections.append("This audit does **not** modify source files. It checks stability after Sprint 10A cleanup patches.\n\n")

sections.append("## Expected markers\n\n")
for marker, ok in markers_found.items():
    sections.append(f"- {'OK' if ok else 'MISSING'} `{marker}`\n")

sections.append("\n## Risk counters\n\n")
for name, value in risk_patterns.items():
    sections.append(f"- {name}: {value}\n")

sections.append("\n## Release assets\n\n")
for name, ok in asset_checks.items():
    sections.append(f"- {'OK' if ok else 'MISSING'} {name}\n")

sections.append("\n## Duplicate functions\n\n")
if duplicate_functions:
    for name, count in duplicate_functions:
        sections.append(f"- `{name}` appears {count} times\n")
else:
    sections.append("- No duplicate function names found.\n")

sections.append("\n## CSS selectors repeated heavily\n\n")
if duplicate_selectors:
    for sel, count in sorted(duplicate_selectors, key=lambda x: (-x[1], x[0]))[:80]:
        sections.append(f"- `{sel}` appears {count} times\n")
else:
    sections.append("- No heavily repeated selectors found.\n")

sections.append("\n## Hotfix / sprint marker inventory\n\n")
for marker in hotfix_markers[:160]:
    sections.append(f"- `{marker}`\n")

sections.append("\n## Manual QA checklist\n\n")
qa_items = [
    "Create simple SBX",
    "Create SBX with public sender/note",
    "Unlock correct code",
    "Unlock wrong code",
    "Double-click .sbx from Finder",
    "Receiver File info shows metadata only after File info",
    "Access Profiles empty by default",
    "No Private / Work / Family demo profiles",
    "Main page hides Access profile when profiles are empty",
    "Add/Edit/Delete Access Profile",
    "Settings tabs horizontal and clickable",
    "Only one Settings panel visible",
    "Language changes whole app, not only Help",
    "Security MVP note appears once without flicker",
    "Only one Help button",
    "Help modal scrolls internally",
    "Settings modal scrolls internally",
    "Background does not scroll while modal is open",
    "Main page scroll returns after modal closes",
    "Dark/light mode",
    "macOS .sbx icon in source and final bundle",
]
for item in qa_items:
    sections.append(f"- [ ] {item}\n")

sections.append("\n## Recommendation\n\n")
sections.append("If build is OK and manual QA passes, save checkpoint `Sprint 10A cleanup OK` and move to Sprint 10B QA / release script. If CSS remains visually stable, do not do a risky full CSS deletion pass now.\n")

report.write_text("".join(sections))
print(f"Audit report created: {report}")
PY

echo "==> Build check"
set +e
rm -rf dist node_modules/.vite
npm run build > "$BUILD_LOG" 2>&1
BUILD_EXIT=$?
set -e

if [ "$BUILD_EXIT" -eq 0 ]; then
  echo "" >> "$REPORT"
  echo "## Build result" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "Build: OK" >> "$REPORT"
  echo "==> Build OK"
else
  echo "" >> "$REPORT"
  echo "## Build result" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "Build: FAILED — see SPRINT10A6_BUILD_REPORT.txt" >> "$REPORT"
  echo "==> Build FAILED. See: $BUILD_LOG"
fi

echo ""
echo "==> Report:"
echo "$REPORT"
echo ""
echo "==> Build log:"
echo "$BUILD_LOG"
echo ""
echo "==> Preview:"
tail -n 120 "$REPORT"
