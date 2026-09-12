# SafeBox Sprint 10A — Stabilization Audit
Generated: 2026-07-11 18:36:27
This audit does **not** change product behavior. It identifies what must be cleaned safely.
## Source size
- `src/main.ts`: 3955 lines
- `src/style.css`: 2733 lines
- CSS `!important`: 654
- `setTimeout(...)`: 51
- `setInterval(...)`: 5
- document click listeners: 6
- `MutationObserver`: 2
- `localStorage`: 22
- `sessionStorage`: 9
## Validated behavior markers found
- `--dedupe-help-buttons-9b-v1`
- `--hard-settings-tabs-click-handler-v1`
- `--hide-main-access-profile-when-empty-v1`
- `--main-page-scrollbar-always-v1`
- `--safebox-settings-padding-scroll-hotfix-v1`
- `--settings-content-restore-general-profiles-security-v1`
- `--sprint9b-how-to-use-safebox-v1`
- `--sprint9c-full-app-i18n-v1`
- `compact-access-profiles-edit-modal`
- `dedupe-help-buttons-9b-v2`
- `force-empty-access-profiles-v1`
- `hard-settings-tabs-click-handler-v1`
- `hide-main-access-profile-when-empty-v1`
- `main-page-scrollbar-always-v1`
- `safebox-professional-ui-polish-v1`
- `safebox-settings-padding-scroll-hotfix-v1`
- `settings-content-restore-general-profiles-security-v1`
- `sprint9b-how-to-use-safebox-v1`
- `sprint9c-full-app-i18n-v1`
- `v1`
## Duplicate functions
- No duplicated function names found.
## CSS selectors repeated many times
- `#hardInfoNoteRow.hidden` appears 7 times
- `#hardReceiverIdentity` appears 7 times
- `#hardReceiverNote` appears 7 times
- `.help-modal-card` appears 6 times
- `.hard-receiver-identity` appears 5 times
- `.hard-receiver-note` appears 5 times
- `.settings-modal` appears 5 times
- `#settingsModal` appears 4 times
- `.help-content` appears 4 times
- `.modal-backdrop` appears 4 times
- `.settings-tab-panel` appears 4 times
- `.settings-tabs-nav` appears 4 times
## High-risk patterns
- replaceAll usage: 0
- body inline overflow writes: 3
- html inline overflow writes: 3
- direct body append modal: 4
- global window assignment: 4
- duplicate id query helpBtn: 4
- duplicate id query howToUseBtn: 4
- settingsTabsRoot references: 11
- settingsModal references: 19
- accessProfiles references: 118
## Key build/release assets
- .sbx icon source: OK
- SafeBox tauri wrapper: OK
- finalize macOS bundle script: OK
- ensure sbx icon source script: OK
- package.json exists: OK
- tauri config exists: OK
## Recommended Sprint 10A cleanup plan
1. Freeze validated behavior markers before cleaning.
2. Extract a single Settings controller and remove old Settings repair blocks.
3. Extract a single Help/How-To controller and remove duplicate Help button guards.
4. Extract a single Access Profiles controller, preserving empty-by-default behavior.
5. Extract a single i18n controller, preserving full-app language switching.
6. Extract a single Scrollbar/Modal state guard.
7. Consolidate CSS into ordered sections: base, layout, forms, receiver, settings, help, profiles, responsive.
8. Rebuild and run QA matrix after every cleanup step.
## QA matrix to run after cleanup
- [ ] Create simple SBX
- [ ] Create SBX with public sender/note
- [ ] Unlock correct code
- [ ] Unlock wrong code
- [ ] Double-click .sbx from Finder
- [ ] Receiver File info
- [ ] Access Profiles empty by default
- [ ] Main app hides Access profile when profiles empty
- [ ] Add/Edit/Delete Access Profile
- [ ] Settings tabs clickable
- [ ] Language changes whole app, not only Help
- [ ] Only one Help button
- [ ] Help modal scroll
- [ ] Main page scrollbar when window reduced
- [ ] Dark/light mode
- [ ] macOS .sbx icon in source and final bundle
Build: OK
