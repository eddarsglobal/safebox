# SAFEBOX v0.2.7 — iOS GMA source-slice linker scope R41

## Observed R40 evidence

The reference Mac passed the R40 CocoaPods rewrite and Rust archive passthrough.
The final Xcode link no longer reported the 426 Tauri duplicate symbols. Instead,
Xcode rejected the R40 `-force_load` input because it pointed into
`$(PODS_XCFRAMEWORKS_BUILD_DIR)`, a generated XCFrameworkIntermediates product.
The same build log proves CocoaPods copies the pinned GMA simulator slice from the
immutable `Pods/.../GoogleMobileAds.xcframework/ios-arm64_x86_64-simulator` source.

## R41 decision

- keep global `-ObjC` removed from the aggregate app target;
- keep Tauri `libapp.a` byte-for-byte untouched;
- force-load only the pinned GoogleMobileAds static framework;
- use conditional xcconfig source paths under `$(PODS_ROOT)`:
  - simulator: `ios-arm64_x86_64-simulator`;
  - device: `ios-arm64`;
- fail closed if either source binary is absent;
- reject the obsolete R40 generated-product force-load path;
- preserve normal CocoaPods GMA/UMP framework and library flags.

## Security / integrity

No SBX format, crypto, key derivation, unlock/create path, Ads data boundary, or
native registration contract is changed. The R41 change is linker-scope only.
The source framework paths are version-pinned by Podfile/Podfile.lock and exist
before Xcode build planning, avoiding a generated-artifact dependency race.

## Internal 9-council review

Approved as a narrower and more deterministic linker fix than archive mutation.
The mobile/device slice is defined now even though the current validation target
is the simulator, preventing a simulator-only architecture trap.

## Defensive HACKER / Red Team

R41 fails closed on missing source slices, unrelated xcconfigs, surviving global
`-ObjC`, stale R40 generated force-load paths, duplicate patch definitions, and
missing targeted force-load state. No signing or provisioning bypass is added.

## Acceptance

Static/package verification may pass off-device. Final v0.2.7 acceptance still
requires `SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS`,
`SAFEBOX_IOS_RUNTIME_BOOT_PASS`, then the Ads runtime gate on the reference Mac.
