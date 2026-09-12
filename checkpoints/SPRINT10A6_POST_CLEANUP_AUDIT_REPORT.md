# SafeBox Sprint 10A-6 — Post-cleanup stability audit

Generated: 2026-07-11 21:48:56

This audit does **not** modify source files. It checks stability after Sprint 10A cleanup patches.

## Expected markers

- OK `sprint10a1-help-single-controller-v1`
- OK `sprint10a2-access-profiles-single-controller-v1`
- OK `sprint10a3d-settings-dedupe-v1`
- OK `sprint10a4-i18n-cleanup-v1`
- OK `sprint10a4b-i18n-no-flicker-v1`
- OK `sprint10a5-scroll-modal-state-v1`
- MISSING `receiver-main-screen-file-name-only`
- OK `sprint9b-how-to-use-safebox-v1`
- OK `sprint9c-full-app-i18n-v1`
- OK `hide-main-access-profile-when-empty-v1`
- OK `force-empty-access-profiles-v1`

## Risk counters

- CSS !important: 894
- main.ts lines: 6174
- style.css lines: 3368
- setTimeout calls: 112
- setInterval calls: 5
- MutationObserver: 6
- document click listeners: 14
- body overflow writes: 7
- html overflow writes: 7
- window any assignments: 19
- replaceAll usage: 0
- settingsTabsRoot references: 27
- settingsPanelSecurity references: 12
- AccessProfile references: 158

## Release assets

- OK .sbx file icon source
- OK Tauri icon finalizer
- OK Tauri wrapper script
- OK ensure icon source script

## Duplicate functions

- No duplicate function names found.

## CSS selectors repeated heavily

- `#hardInfoNoteRow.hidden` appears 7 times
- `#hardReceiverIdentity` appears 7 times
- `#hardReceiverNote` appears 7 times
- `.help-modal-card` appears 6 times
- `.hard-receiver-identity` appears 5 times
- `.hard-receiver-note` appears 5 times
- `.settings-modal` appears 5 times

## Hotfix / sprint marker inventory

- `--dedupe-help-buttons-9b-v1`
- `--hard-settings-tabs-click-handler-v1`
- `--hide-main-access-profile-when-empty-v1`
- `--main-page-scrollbar-always-v1`
- `--safebox-settings-padding-scroll-hotfix-v1`
- `--settings-content-restore-general-profiles-security-v1`
- `--sprint10a1-help-single-controller-v1`
- `--sprint10a2-access-profiles-single-controller-v1`
- `--sprint10a3-settings-single-controller-v1`
- `--sprint10a3b-settings-hotfix-horizontal-panels-v1`
- `--sprint10a3c-settings-hard-rebuild-v1`
- `--sprint10a3d-settings-dedupe-v1`
- `--sprint10a4-i18n-cleanup-v1`
- `--sprint10a4b-i18n-no-flicker-v1`
- `--sprint10a5-scroll-modal-state-v1`
- `--sprint9b-how-to-use-safebox-v1`
- `--sprint9c-full-app-i18n-v1`
- `force-empty-access-profiles-v1`
- `hard-settings-tabs-click-handler-v1`
- `hide-main-access-profile-when-empty-v1`
- `main-page-scrollbar-always-v1`
- `safebox-professional-ui-polish-v1`
- `safebox-settings-padding-scroll-hotfix-v1`
- `settings-content-restore-general-profiles-security-v1`
- `sprint10a1-help-single-controller-v1`
- `sprint10a2-access-profiles-single-controller-v1`
- `sprint10a3-settings-single-controller-v1`
- `sprint10a3b-settings-hotfix-horizontal-panels-v1`
- `sprint10a3c-settings-hard-rebuild-v1`
- `sprint10a3d-settings-dedupe-v1`
- `sprint10a4-i18n-cleanup-v1`
- `sprint10a4b-i18n-no-flicker-v1`
- `sprint10a5-scroll-modal-state-v1`
- `sprint9b-how-to-use-safebox-v1`
- `sprint9c-full-app-i18n-v1`

## Manual QA checklist

- [ ] Create simple SBX
- [ ] Create SBX with public sender/note
- [ ] Unlock correct code
- [ ] Unlock wrong code
- [ ] Double-click .sbx from Finder
- [ ] Receiver File info shows metadata only after File info
- [ ] Access Profiles empty by default
- [ ] No Private / Work / Family demo profiles
- [ ] Main page hides Access profile when profiles are empty
- [ ] Add/Edit/Delete Access Profile
- [ ] Settings tabs horizontal and clickable
- [ ] Only one Settings panel visible
- [ ] Language changes whole app, not only Help
- [ ] Security MVP note appears once without flicker
- [ ] Only one Help button
- [ ] Help modal scrolls internally
- [ ] Settings modal scrolls internally
- [ ] Background does not scroll while modal is open
- [ ] Main page scroll returns after modal closes
- [ ] Dark/light mode
- [ ] macOS .sbx icon in source and final bundle

## Recommendation

If build is OK and manual QA passes, save checkpoint `Sprint 10A cleanup OK` and move to Sprint 10B QA / release script. If CSS remains visually stable, do not do a risky full CSS deletion pass now.

## Build result

Build: OK
