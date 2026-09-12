# SAFEBOX v0.2.8 — iOS Native Share Extension R48

## Observed R47 reference-Mac failure
R47 built and signed the standalone Share Extension, validated `com.apple.share-services`, embedded the `.appex`, and validated App Group runtime entitlements. Simulator installation then failed with `IXErrorDomain code=2`, `Missing bundle ID`, while creating the app-extension placeholder.

## R48 decision
The canonical static Share Extension `Info.plist` now declares the complete minimal bundle identity contract instead of relying on Xcode to synthesize absent keys:
- `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`
- `CFBundleExecutable = $(EXECUTABLE_NAME)`
- `CFBundlePackageType = XPC!`
- `CFBundleInfoDictionaryVersion = 6.0`
- `CFBundleShortVersionString = 0.2.8`
- `CFBundleVersion = 28`
- `NSExtensionPointIdentifier = com.apple.share-services`

Before embed/sign/install, the simulator runner reads the compiled `.appex/Info.plist` and fails closed unless the bundle identifier, executable, package type, version, and extension point are all present and exact.

## Security / regression boundaries
- SBX/crypto unchanged.
- R42 Ads/UMP validated surfaces unchanged.
- R41 scoped Google linker strategy unchanged.
- R39 immutable Rust archive passthrough unchanged.
- Share App Group and inbox bridge unchanged.
- No Ruby/xcodeproj mutation reintroduced.

## Acceptance
R48 requires empirical reference-Mac `npm run ios:cold-dev` with simulator installation and runtime boot PASS, followed by a real Files → Share → SafeBox intake test.
