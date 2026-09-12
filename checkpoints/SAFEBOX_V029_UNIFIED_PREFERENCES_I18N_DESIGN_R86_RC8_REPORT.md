# SafeBox v0.2.9 — R86 RC8
## Unified Preferences, Legal Theme, Translation Closure & High-Importance UI

### Release intent
RC8 resolves three product-level conflicts found during pre-Play review without changing the validated SafeBox cryptographic/native core:
1. Landing, crypto application and legal surfaces now share one language preference and one appearance preference.
2. Legal pages resolve System/Light/Dark before CSS paints, so they cannot remain stuck on the dark default while the product is light.
3. The SafeBox application receives an urgent full visible-text translation closure plus a restrained high-importance security-product design boost.

### Canonical preference contract
- Language: `safebox.language.v1`
- Appearance: `safebox-theme-mode.v1`
- Choices: Auto/System where applicable + EN, FR, IT, PT, AR, DE, ES, HR/BCS.
- Historical landing keys are migration/fallback inputs only (`safebox.lang`, `safebox.theme`); the old app theme key (`safebox-theme`) is also accepted as fallback.
- Landing/app/legal listen for storage changes to stay synchronized in same-origin browser tabs/pages.

### Legal theme closure
Every legal HTML page loads `legal-theme-init.js` before `legal.css`. The preflight resolves `system` to a concrete `light` or `dark` theme before first paint. `legal.js` then maintains the same canonical mode, reacts to operating-system changes, and exposes language + appearance controls using localized labels.

### Translation closure
RC8 adds Italian and Portuguese to the crypto application and closes visible strings that previously escaped the older i18n layers: asynchronous picker/status messages, result labels, settings/profile status, placeholders, accessibility labels, mobile save actions, receiver results and common errors. Result labels can now be translated while `<code>` values remain excluded, preventing paths, filenames and technical values from being rewritten.

### Nine-axis Design Council review
This is an internal product-governance review, not a claim of external human certification.
1. **Security clarity** — explicit secure-local-workspace trust line and protocol proof (`LOCAL · AEAD · SBX1`).
2. **Accessibility/contrast** — stronger light-mode text, borders, focus rings and surface separation.
3. **Mobile ergonomics** — clearer primary actions, drop zones and responsive spacing.
4. **Information hierarchy** — stronger separation of Create/Open/Settings and controlled secure surfaces.
5. **Internationalization/RTL** — eight locale surfaces and Arabic RTL retained across app/legal.
6. **Legal consistency** — canonical language/theme contract shared with the product shell.
7. **Trust/branding** — restrained premium cyber-security treatment instead of decorative novelty.
8. **Interaction safety** — clearer focus/action states; dynamic filenames/paths are not translated.
9. **Release regression safety** — protected crypto/native hashes remain pinned and web release gates pin the reviewed RC8 UI shell.

### Protected runtime status
Byte-identical to the validated RC7 baseline for:
- `safebox-core/src/crypto.rs`
- `safebox-core/src/format.rs`
- `safebox-core/src/memory.rs`
- `safebox-web-wasm/src/lib.rs`
- `safebox-desktop/src/web-sbx-engine.ts`
- `safebox-desktop/src-tauri/src/lib.rs`

### Acceptance
Static verifier:
`verification/verify_v029_unified_preferences_i18n_design_r86_rc8.sh`

Final npm compilation, browser E2E, Android signing/build and physical-device validation remain machine gates and must run on the reference Mac/device before Play submission.
