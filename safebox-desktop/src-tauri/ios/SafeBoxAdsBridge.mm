#import <UIKit/UIKit.h>
#include <stdint.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <UserMessagingPlatform/UserMessagingPlatform.h>

// SafeBox iOS Ads & Privacy bridge.
// Security boundary: this file receives only visibility/privacy control signals.
// It never receives filenames, SBX metadata, passwords, codes, file contents,
// filesystem paths, or crypto state. Ad requests are generic GADRequest objects.

static NSString * const SBXAdMobBannerUnit = @"ca-app-pub-3940256099942544/2435281174";

static UIViewController *SBXAdsTopViewController(void) {
  UIApplication *application = UIApplication.sharedApplication;
  UIWindow *window = nil;

  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in application.connectedScenes) {
      if (scene.activationState != UISceneActivationStateForegroundActive ||
          ![scene isKindOfClass:UIWindowScene.class]) {
        continue;
      }
      UIWindowScene *windowScene = (UIWindowScene *)scene;
      for (UIWindow *candidate in windowScene.windows) {
        if (candidate.isKeyWindow) {
          window = candidate;
          break;
        }
      }
      if (!window) window = windowScene.windows.firstObject;
      if (window) break;
    }
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (!window) window = application.keyWindow;
#pragma clang diagnostic pop

  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController) {
    controller = controller.presentedViewController;
  }
  if ([controller isKindOfClass:UINavigationController.class]) {
    controller = ((UINavigationController *)controller).visibleViewController ?: controller;
  }
  if ([controller isKindOfClass:UITabBarController.class]) {
    controller = ((UITabBarController *)controller).selectedViewController ?: controller;
  }
  return controller;
}

@interface SBXAdsController : NSObject <GADBannerViewDelegate>
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) GADBannerView *bannerView;
@property(nonatomic, assign) BOOL desiredVisible;
@property(nonatomic, assign) BOOL bannerLoaded;
@property(nonatomic, assign) BOOL sdkInitializationStarted;
@property(nonatomic, assign) BOOL sdkReady;
@property(nonatomic, assign) BOOL consentUpdateStarted;
@property(nonatomic, assign) NSInteger rootRetryCount;
@end

@implementation SBXAdsController

+ (instancetype)shared {
  static SBXAdsController *controller;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ controller = [[SBXAdsController alloc] init]; });
  return controller;
}

- (void)bootstrap {
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[SBXAdsController shared] bootstrap]; });
    return;
  }
  if (self.consentUpdateStarted) return;

  UIViewController *root = SBXAdsTopViewController();
  if (!root) {
    if (self.rootRetryCount++ < 40) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{ [[SBXAdsController shared] bootstrap]; });
    } else {
      NSLog(@"SAFEBOX_IOS_ADS_ROOT_FAIL");
    }
    return;
  }

  self.consentUpdateStarted = YES;
  NSLog(@"SAFEBOX_IOS_UMP_UPDATE_BEGIN");

  UMPRequestParameters *parameters = [[UMPRequestParameters alloc] init];
  [UMPConsentInformation.sharedInstance
      requestConsentInfoUpdateWithParameters:parameters
      completionHandler:^(NSError * _Nullable requestConsentError) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (requestConsentError) {
            NSLog(@"SAFEBOX_IOS_UMP_UPDATE_WARNING: %@", requestConsentError.localizedDescription);
          } else {
            NSLog(@"SAFEBOX_IOS_UMP_UPDATE_PASS");
          }

          // UMP requires canRequestAds to be checked after the update.
          [self startAdsIfAllowed];

          UIViewController *presenting = SBXAdsTopViewController();
          [UMPConsentForm
              loadAndPresentIfRequiredFromViewController:presenting
              completionHandler:^(NSError * _Nullable formError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  if (formError) {
                    NSLog(@"SAFEBOX_IOS_UMP_FORM_WARNING: %@", formError.localizedDescription);
                  } else {
                    NSLog(@"SAFEBOX_IOS_UMP_FORM_COMPLETE");
                  }
                  // Check again after any required form. This call is idempotent.
                  [self startAdsIfAllowed];
                });
              }];
        });
      }];
}

- (void)startAdsIfAllowed {
  BOOL canRequest = UMPConsentInformation.sharedInstance.canRequestAds;
  NSLog(@"SAFEBOX_IOS_UMP_CAN_REQUEST_ADS: %@", canRequest ? @"YES" : @"NO");
  if (!canRequest || self.sdkInitializationStarted) return;

  self.sdkInitializationStarted = YES;
  [[GADMobileAds sharedInstance]
      startWithCompletionHandler:^(GADInitializationStatus * _Nonnull status) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.sdkReady = YES;
          NSLog(@"SAFEBOX_IOS_GMA_INIT_PASS");
          [self ensureBanner];
        });
      }];
}

- (void)ensureBanner {
  if (!self.sdkReady || self.bannerView) return;
  UIViewController *root = SBXAdsTopViewController();
  if (!root) {
    NSLog(@"SAFEBOX_IOS_BANNER_ROOT_PENDING");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self ensureBanner]; });
    return;
  }

  UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.backgroundColor = UIColor.systemBackgroundColor;
  container.hidden = YES;
  container.accessibilityIdentifier = @"safebox-admob-footer";
  [root.view addSubview:container];

  [NSLayoutConstraint activateConstraints:@[
    [container.leadingAnchor constraintEqualToAnchor:root.view.leadingAnchor],
    [container.trailingAnchor constraintEqualToAnchor:root.view.trailingAnchor],
    [container.bottomAnchor constraintEqualToAnchor:root.view.safeAreaLayoutGuide.bottomAnchor],
    [container.heightAnchor constraintEqualToConstant:54.0]
  ]];

  GADBannerView *banner = [[GADBannerView alloc] initWithAdSize:GADAdSizeBanner];
  banner.translatesAutoresizingMaskIntoConstraints = NO;
  banner.adUnitID = SBXAdMobBannerUnit;
  banner.rootViewController = root;
  banner.delegate = self;
  [container addSubview:banner];
  [NSLayoutConstraint activateConstraints:@[
    [banner.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
    [banner.centerYAnchor constraintEqualToAnchor:container.centerYAnchor]
  ]];

  self.container = container;
  self.bannerView = banner;
  [banner loadRequest:[GADRequest request]];
  NSLog(@"SAFEBOX_IOS_BANNER_LOAD_BEGIN");
}

- (void)setVisible:(BOOL)visible {
  self.desiredVisible = visible;
  if (self.container && self.bannerLoaded) {
    self.container.hidden = !visible;
  }
}

- (void)showPrivacyOptions {
  UIViewController *root = SBXAdsTopViewController();
  if (!root) {
    NSLog(@"SAFEBOX_IOS_PRIVACY_OPTIONS_ROOT_FAIL");
    return;
  }

  if (UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus !=
      UMPPrivacyOptionsRequirementStatusRequired) {
    NSLog(@"SAFEBOX_IOS_PRIVACY_OPTIONS_NOT_REQUIRED");
    return;
  }

  [UMPConsentForm
      presentPrivacyOptionsFormFromViewController:root
      completionHandler:^(NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (error) {
            NSLog(@"SAFEBOX_IOS_PRIVACY_OPTIONS_WARNING: %@", error.localizedDescription);
            return;
          }
          NSLog(@"SAFEBOX_IOS_PRIVACY_OPTIONS_COMPLETE");
          [self startAdsIfAllowed];
        });
      }];
}

- (void)bannerViewDidReceiveAd:(GADBannerView *)bannerView {
  self.bannerLoaded = YES;
  if (self.container) self.container.hidden = !self.desiredVisible;
  NSLog(@"SAFEBOX_IOS_BANNER_LOAD_PASS");
}

- (void)bannerView:(GADBannerView *)bannerView
    didFailToReceiveAdWithError:(NSError *)error {
  self.bannerLoaded = NO;
  if (self.container) self.container.hidden = YES;
  NSLog(@"SAFEBOX_IOS_BANNER_LOAD_WARNING: %@", error.localizedDescription);
}

@end

static BOOL SBXAdsReadMainThreadBool(BOOL (^block)(void)) {
  if ([NSThread isMainThread]) return block();
  __block BOOL value = NO;
  dispatch_sync(dispatch_get_main_queue(), ^{ value = block(); });
  return value;
}

extern "C" void safebox_ios_ads_register(
    void (*bootstrap)(void),
    void (*set_visible)(uint8_t),
    void (*show_privacy_options)(void),
    uint8_t (*can_request)(void),
    uint8_t (*privacy_required)(void),
    uint8_t (*sdk_ready)(void));

static void SBXAdsBootstrap(void) {
  dispatch_async(dispatch_get_main_queue(), ^{ [[SBXAdsController shared] bootstrap]; });
}

static void SBXAdsSetVisible(uint8_t visible) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[SBXAdsController shared] setVisible:visible != 0 ? YES : NO];
  });
}

static void SBXAdsShowPrivacyOptions(void) {
  dispatch_async(dispatch_get_main_queue(), ^{ [[SBXAdsController shared] showPrivacyOptions]; });
}

static uint8_t SBXAdsCanRequest(void) {
  return SBXAdsReadMainThreadBool(^BOOL{
    return UMPConsentInformation.sharedInstance.canRequestAds;
  }) ? 1 : 0;
}

static uint8_t SBXAdsPrivacyRequired(void) {
  return SBXAdsReadMainThreadBool(^BOOL{
    return UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus ==
           UMPPrivacyOptionsRequirementStatusRequired;
  }) ? 1 : 0;
}

static uint8_t SBXAdsSdkReady(void) {
  return SBXAdsReadMainThreadBool(^BOOL{
    return [SBXAdsController shared].sdkReady;
  }) ? 1 : 0;
}

// Called explicitly by generated main.mm immediately before ffi::start_app().
// This creates a resolved native->Rust link edge while keeping Rust free of
// unresolved Objective-C Ads symbols during Cargo's library build.
extern "C" void SBXAdsRegisterNativeBridge(void) {
  safebox_ios_ads_register(
      SBXAdsBootstrap,
      SBXAdsSetVisible,
      SBXAdsShowPrivacyOptions,
      SBXAdsCanRequest,
      SBXAdsPrivacyRequired,
      SBXAdsSdkReady);
}
