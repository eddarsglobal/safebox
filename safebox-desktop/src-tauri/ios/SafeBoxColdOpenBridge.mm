#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern "C" void safebox_ios_cold_open_accept(const char *path_utf8);

static BOOL SBXColdOpenArmed = YES;
static BOOL SBXColdOpenCaptured = NO;
static id SBXColdOpenDidFinishObserver = nil;
static IMP SBXOriginalSceneConfigurationIMP = nullptr;
static IMP SBXOriginalSceneWillConnectIMP = nullptr;
static Class SBXSceneConfigurationDelegateClass = Nil;
static Class SBXSceneDelegateClass = Nil;

static NSString *const SBXColdOpenRootName = @"SafeBoxColdOpenIntake";

static BOOL SBXColdOpenEnsurePrivateDirectory(NSURL *url) {
  NSError *error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtURL:url
                               withIntermediateDirectories:YES
                                                attributes:@{NSFilePosixPermissions: @0700}
                                                     error:&error]) {
    return NO;
  }
  return YES;
}

static BOOL SBXColdOpenHardenFile(NSURL *url) {
  NSError *error = nil;
  NSDictionary *attrs = @{
    NSFilePosixPermissions: @0600,
    NSFileProtectionKey: NSFileProtectionComplete,
  };
  return [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:url.path error:&error];
}

static BOOL SBXColdOpenIsEligibleSbxURL(NSURL *url) {
  if (url == nil || !url.isFileURL) {
    return NO;
  }
  NSString *ext = url.pathExtension.lowercaseString;
  return [ext isEqualToString:@"sbx"];
}

static BOOL SBXColdOpenCopyCoordinated(NSURL *source, NSURL *destination) {
  __block BOOL copied = NO;
  __block NSError *coordinationError = nil;
  NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
  [coordinator coordinateReadingItemAtURL:source
                                  options:NSFileCoordinatorReadingWithoutChanges
                                    error:&coordinationError
                               byAccessor:^(NSURL *coordinatedURL) {
    NSNumber *isRegular = nil;
    NSNumber *isSymlink = nil;
    NSError *resourceError = nil;
    BOOL regularOK = [coordinatedURL getResourceValue:&isRegular
                                               forKey:NSURLIsRegularFileKey
                                                error:&resourceError];
    BOOL symlinkOK = [coordinatedURL getResourceValue:&isSymlink
                                               forKey:NSURLIsSymbolicLinkKey
                                                error:&resourceError];
    if (!regularOK || !symlinkOK || !isRegular.boolValue || isSymlink.boolValue) {
      return;
    }

    NSError *copyError = nil;
    copied = [[NSFileManager defaultManager] copyItemAtURL:coordinatedURL
                                                     toURL:destination
                                                     error:&copyError];
  }];
  return coordinationError == nil && copied;
}

static void SBXColdOpenCaptureURL(NSURL *url, NSString *source) {
  if (!SBXColdOpenArmed || SBXColdOpenCaptured || !SBXColdOpenIsEligibleSbxURL(url)) {
    return;
  }

  BOOL securityScoped = [url startAccessingSecurityScopedResource];
  @try {
    NSURL *privateRoot = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                          URLByAppendingPathComponent:SBXColdOpenRootName isDirectory:YES];
    if (!SBXColdOpenEnsurePrivateDirectory(privateRoot)) {
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL: reason=private-root");
      return;
    }

    NSURL *request = [privateRoot URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    if (!SBXColdOpenEnsurePrivateDirectory(request)) {
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL: reason=private-request");
      return;
    }

    // Deliberately do not retain the provider filename. The private payload
    // uses a fixed extension so Rust can route it without exposing metadata.
    NSURL *destination = [request URLByAppendingPathComponent:@"payload.sbx" isDirectory:NO];
    if (!SBXColdOpenCopyCoordinated(url, destination)) {
      [[NSFileManager defaultManager] removeItemAtURL:request error:nil];
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL: reason=copy");
      return;
    }
    if (!SBXColdOpenHardenFile(destination)) {
      [[NSFileManager defaultManager] removeItemAtURL:request error:nil];
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL: reason=hardening");
      return;
    }

    SBXColdOpenCaptured = YES;
    SBXColdOpenArmed = NO;
    NSLog(@"SAFEBOX_IOS_COLD_OPEN_CAPTURE_PASS: source=%@", source ?: @"unknown");
    NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_PASS");
    const char *path = destination.path.UTF8String;
    if (path != nullptr) {
      safebox_ios_cold_open_accept(path);
    } else {
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL: reason=encoding");
    }
  } @finally {
    if (securityScoped) {
      [url stopAccessingSecurityScopedResource];
    }
  }
}

static void SBXColdOpenCaptureConnectionOptions(UISceneConnectionOptions *options, NSString *source) {
  if (!SBXColdOpenArmed || SBXColdOpenCaptured || options == nil) {
    return;
  }
  NSUInteger inspected = 0;
  for (UIOpenURLContext *context in options.URLContexts) {
    if (inspected++ >= 8) {
      break;
    }
    SBXColdOpenCaptureURL(context.URL, source);
    if (SBXColdOpenCaptured) {
      break;
    }
  }
}

typedef UISceneConfiguration *(*SBXSceneConfigurationFn)(id, SEL, UIApplication *, UISceneSession *, UISceneConnectionOptions *);
static UISceneConfiguration *SBXColdOpenSceneConfigurationHook(id self,
                                                                SEL _cmd,
                                                                UIApplication *application,
                                                                UISceneSession *session,
                                                                UISceneConnectionOptions *options) {
  SBXColdOpenCaptureConnectionOptions(options, @"scene-config");
  if (SBXOriginalSceneConfigurationIMP != nullptr) {
    return ((SBXSceneConfigurationFn)SBXOriginalSceneConfigurationIMP)(self, _cmd, application, session, options);
  }
  return nil;
}

typedef void (*SBXSceneWillConnectFn)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *);
static void SBXColdOpenSceneWillConnectHook(id self,
                                            SEL _cmd,
                                            UIScene *scene,
                                            UISceneSession *session,
                                            UISceneConnectionOptions *options) {
  SBXColdOpenCaptureConnectionOptions(options, @"scene-delegate");
  if (SBXOriginalSceneWillConnectIMP != nullptr) {
    ((SBXSceneWillConnectFn)SBXOriginalSceneWillConnectIMP)(self, _cmd, scene, session, options);
  }
}

static BOOL SBXColdOpenInstallHookOnClass(Class cls, SEL selector, IMP hook, IMP *originalOut) {
  if (cls == Nil || selector == nullptr || hook == nullptr || originalOut == nullptr) {
    return NO;
  }
  Method method = class_getInstanceMethod(cls, selector);
  if (method == nullptr) {
    return NO;
  }
  IMP current = method_getImplementation(method);
  if (current == hook) {
    return YES;
  }
  const char *types = method_getTypeEncoding(method);
  *originalOut = current;

  // If the implementation is inherited, add the hook to the concrete class
  // instead of mutating a superclass shared by other UIKit components.
  if (class_addMethod(cls, selector, hook, types)) {
    return YES;
  }
  method_setImplementation(method, hook);
  return YES;
}

static void SBXColdOpenInstallSceneHooks(UIApplication *application) {
  id<UIApplicationDelegate> delegate = application.delegate;
  if (delegate != nil) {
    Class delegateClass = object_getClass(delegate);
    SEL selector = @selector(application:configurationForConnectingSceneSession:options:);
    if (SBXSceneConfigurationDelegateClass == Nil &&
        SBXColdOpenInstallHookOnClass(delegateClass,
                                      selector,
                                      (IMP)SBXColdOpenSceneConfigurationHook,
                                      &SBXOriginalSceneConfigurationIMP)) {
      SBXSceneConfigurationDelegateClass = delegateClass;
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_SCENE_OPTIONS_HOOK_PASS");
    }
  }

  Class taoSceneDelegate = NSClassFromString(@"TaoSceneDelegate");
  if (taoSceneDelegate != Nil && SBXSceneDelegateClass == Nil) {
    SEL selector = @selector(scene:willConnectToSession:options:);
    if (SBXColdOpenInstallHookOnClass(taoSceneDelegate,
                                      selector,
                                      (IMP)SBXColdOpenSceneWillConnectHook,
                                      &SBXOriginalSceneWillConnectIMP)) {
      SBXSceneDelegateClass = taoSceneDelegate;
      NSLog(@"SAFEBOX_IOS_COLD_OPEN_SCENE_DELEGATE_HOOK_PASS");
    }
  }
}

static void SBXColdOpenHandleDidFinish(NSNotification *note) {
  UIApplication *application = [note.object isKindOfClass:[UIApplication class]] ? (UIApplication *)note.object : UIApplication.sharedApplication;
  NSLog(@"SAFEBOX_IOS_COLD_OPEN_DID_FINISH_PASS");

  // Non-scene lifecycle compatibility. Apple exposes the same URL launch value
  // in UIApplicationDidFinishLaunchingNotification.userInfo.
  NSURL *legacyURL = note.userInfo[UIApplicationLaunchOptionsURLKey];
  if ([legacyURL isKindOfClass:[NSURL class]]) {
    SBXColdOpenCaptureURL(legacyURL, @"launch-options");
  }

  // Scene lifecycle: install before UIKit creates/connects the first scene.
  SBXColdOpenInstallSceneHooks(application);
}

extern "C" void SBXColdOpenInstall(void) {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    SBXColdOpenDidFinishObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
      SBXColdOpenHandleDidFinish(note);
    }];
    NSLog(@"SAFEBOX_IOS_COLD_OPEN_BRIDGE_INSTALL_PASS");
  });
}
