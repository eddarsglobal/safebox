# SafeBox advertising activation — EDDARS only

Advertising is intentionally **OFF by default**. The SafeBox cryptographic Create/Open app remains ad-free and isolated from advertising code.

## Web — Google AdSense

1. Publish the final SafeBox landing page and complete the legal/contact pages. The Web-only landing build now includes the AdSense verification script and account meta tag for publisher `ca-pub-3925930420157238`; no ad unit is enabled.
2. Create/approve the site in Google AdSense and complete the Google consent/CMP setup required for the regions you serve.
3. Obtain the landing ad-slot id.
4. In `src/landing.ts`, replace the disabled placeholder with an `ins.adsbygoogle` slot only inside `#landing-ad` after approval. Revisit the landing-only CSP against Google's current AdSense guidance before serving ads.
5. Update the **landing-page** CSP to allow only the exact Google domains required by the current AdSense documentation. Do not loosen the crypto app CSP merely to enable ads.
6. Keep the ad physically separated from Create/Open/Download controls. Never animate the ad or direct attention to it.
7. Re-run the complete SafeBox Web production/deployment/remote gates before public activation.
8. Verify the privacy/Cookies & Advertising pages and consent controls match the real production configuration.

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
