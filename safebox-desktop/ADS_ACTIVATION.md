# SafeBox advertising activation — EDDARS only

The Web landing page includes a Google AdSense display unit. The SafeBox cryptographic Create/Open app remains ad-free and isolated from advertising code.

## Web — Google AdSense

1. The Web-only landing build includes publisher `ca-pub-3925930420157238` and responsive display slot `2746924080` inside `#landing-ad`. Google serves ads only after it approves the site; the site is currently under review.
2. The Google consent message is configured in AdSense for regions that require it. Check that it appears and that all choices work after deployment.
3. The landing page has a broader CSP for AdSense and its consent message. Static Cloudflare Pages cannot issue a fresh CSP nonce per response; Google's domains can change, so a narrow domain allowlist is not reliable. The Create/Open app and legal pages retain the strict CSP.
4. Keep the ad physically separated from Create/Open/Download controls. Never animate the ad or direct attention to it.
5. Re-run the SafeBox Web production/deployment checks before deployment, then inspect the live page and AdSense review status. An empty slot during review is expected.
6. Keep the privacy/Cookies & Advertising pages and Google consent configuration accurate as the setup changes.

Never send file names, file contents, SBX bytes, passwords, unlock codes, cryptographic metadata or crypto-app events to advertising code.

## Android APK — Google AdMob

The repository already contains the native mobile-ad/privacy foundation and iOS/Google-Mobile-Ads bridge work from the validated mobile slices. For Android production activation:

1. Create the SafeBox Android app in Google AdMob.
2. Obtain the Android AdMob App ID and the approved banner/interstitial unit IDs.
3. Keep Google test ad IDs enabled during development and verification.
4. Put production IDs in the native/mobile advertising configuration — never in the Rust crypto core and never in an SBX file.
5. Complete UMP consent/privacy-options configuration for the regions you serve.
6. Ads may appear only on non-sensitive UI surfaces defined by SafeBox product policy; do not overlay file pickers, password/code inputs, Create/Unlock buttons, or success/error actions.
7. Build the signed APK, run the Android verification gates, publish the APK plus SHA-256 in GitHub Releases, then switch from test to production ad IDs only for the validated release.

## iOS

Do not claim App Store availability while the project remains at the strict 0 USD budget. The Web App remains the zero-cost iPhone/iPad installation path. Native iOS ad activation is relevant only for a legitimately distributable iOS build.
