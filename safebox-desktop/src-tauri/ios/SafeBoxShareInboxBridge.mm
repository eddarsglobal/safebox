#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <limits.h>
#include <stdint.h>

extern "C" uint8_t safebox_ios_share_inbox_accept(const char *path_utf8);
extern "C" void safebox_ios_share_register(void (*drain)(void));
extern "C" void safebox_ios_share_foreground(void);

static NSString *const SBXShareAppGroup = @"group.com.safebox.desktop.share";
static NSString *const SBXShareInboxName = @"ShareInbox";
static NSString *const SBXShareProcessingName = @"ShareProcessing";
static const unsigned long long SBXShareMaxPayloadBytes = 512ULL * 1024ULL * 1024ULL;
static const NSUInteger SBXShareMaxRequestsPerDrain = 8;
static const unsigned long long SBXShareMaxInboxBytes = 1024ULL * 1024ULL * 1024ULL;
static const NSTimeInterval SBXShareStaleReadyAge = 24.0 * 60.0 * 60.0;
static const NSTimeInterval SBXShareStaleIncompleteAge = 60.0 * 60.0;
static const NSTimeInterval SBXShareStaleProcessingAge = 60.0 * 60.0;
static const NSTimeInterval SBXSharePrivateRetentionAge = 24.0 * 60.0 * 60.0;

static BOOL SBXEnsurePrivateDirectory(NSURL *url) {
  NSError *error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtURL:url
                               withIntermediateDirectories:YES
                                                attributes:@{NSFilePosixPermissions: @0700}
                                                     error:&error]) {
    return NO;
  }
  return YES;
}

static BOOL SBXHardenFile(NSURL *url) {
  NSError *error = nil;
  NSDictionary *attrs = @{
    NSFilePosixPermissions: @0600,
    NSFileProtectionKey: NSFileProtectionComplete,
  };
  return [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:url.path error:&error];
}

static NSDate *SBXItemDate(NSURL *url) {
  NSDate *date = nil;
  [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:nil];
  if (date == nil) {
    [url getResourceValue:&date forKey:NSURLCreationDateKey error:nil];
  }
  return date ?: [NSDate date];
}

static BOOL SBXIsDirectoryNoSymlink(NSURL *url) {
  NSNumber *isDirectory = nil;
  NSNumber *isSymlink = nil;
  [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
  [url getResourceValue:&isSymlink forKey:NSURLIsSymbolicLinkKey error:nil];
  return [isDirectory boolValue] && ![isSymlink boolValue];
}

static BOOL SBXIsRegularNoSymlink(NSURL *url) {
  NSNumber *isRegular = nil;
  NSNumber *isSymlink = nil;
  [url getResourceValue:&isRegular forKey:NSURLIsRegularFileKey error:nil];
  [url getResourceValue:&isSymlink forKey:NSURLIsSymbolicLinkKey error:nil];
  return [isRegular boolValue] && ![isSymlink boolValue];
}

static unsigned long long SBXFileSize(NSURL *url) {
  NSNumber *size = nil;
  [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
  return size == nil ? ULLONG_MAX : [size unsignedLongLongValue];
}

static NSUInteger SBXCleanupDirectory(NSURL *root, NSTimeInterval maxAge) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSURL *> *items = [fm contentsOfDirectoryAtURL:root
                              includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey,
                                                           NSURLCreationDateKey, NSURLContentModificationDateKey]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];
  NSUInteger removed = 0;
  NSDate *now = [NSDate date];
  for (NSURL *item in items ?: @[]) {
    if (!SBXIsDirectoryNoSymlink(item)) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
      continue;
    }
    NSTimeInterval age = MAX(0.0, [now timeIntervalSinceDate:SBXItemDate(item)]);
    if (age > maxAge) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
    }
  }
  return removed;
}

static BOOL SBXWriteCommitMarker(NSURL *url) {
  NSError *error = nil;
  NSData *empty = [NSData data];
  if (![empty writeToURL:url options:NSDataWritingAtomic error:&error]) {
    return NO;
  }
  return SBXHardenFile(url);
}

static NSUInteger SBXCleanupProcessing(NSURL *root) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSURL *> *items = [fm contentsOfDirectoryAtURL:root
                              includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey,
                                                           NSURLCreationDateKey, NSURLContentModificationDateKey]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];
  NSUInteger removed = 0;
  NSUInteger ackedRemoved = 0;
  NSDate *now = [NSDate date];
  for (NSURL *item in items ?: @[]) {
    if (!SBXIsDirectoryNoSymlink(item)) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
      continue;
    }
    NSURL *delivered = [item URLByAppendingPathComponent:@"DELIVERED" isDirectory:NO];
    if ([fm fileExistsAtPath:delivered.path]) {
      if (!SBXIsRegularNoSymlink(delivered)) {
        [fm removeItemAtURL:item error:nil];
        removed += 1;
        continue;
      }
      // A crash after Rust ACK but before request deletion leaves this receipt.
      // It proves the request was already handed off, so cleanup removes it
      // without ever replaying the payload.
      [fm removeItemAtURL:item error:nil];
      removed += 1;
      ackedRemoved += 1;
      continue;
    }
    NSTimeInterval age = MAX(0.0, [now timeIntervalSinceDate:SBXItemDate(item)]);
    if (age > SBXShareStaleProcessingAge) {
      // Unacknowledged crash claims are fail-closed: expire, never replay.
      [fm removeItemAtURL:item error:nil];
      removed += 1;
    }
  }
  NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_ACKED_CLEANUP_PASS count=%lu", (unsigned long)ackedRemoved);
  return removed;
}

static NSUInteger SBXCleanupInbox(NSURL *inbox) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray<NSURL *> *items = [fm contentsOfDirectoryAtURL:inbox
                              includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey,
                                                           NSURLCreationDateKey, NSURLContentModificationDateKey]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];
  NSUInteger removed = 0;
  NSDate *now = [NSDate date];
  for (NSURL *item in items ?: @[]) {
    if (!SBXIsDirectoryNoSymlink(item)) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
      continue;
    }
    NSURL *ready = [item URLByAppendingPathComponent:@"READY" isDirectory:NO];
    BOOL readyExists = [fm fileExistsAtPath:ready.path];
    if (readyExists && !SBXIsRegularNoSymlink(ready)) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
      continue;
    }
    BOOL isReady = readyExists;
    NSTimeInterval age = MAX(0.0, [now timeIntervalSinceDate:SBXItemDate(item)]);
    NSTimeInterval limit = isReady ? SBXShareStaleReadyAge : SBXShareStaleIncompleteAge;
    if (age > limit) {
      [fm removeItemAtURL:item error:nil];
      removed += 1;
    }
  }
  return removed;
}

static void SBXDrainShareInboxNow(void) {
  NSLog(@"SAFEBOX_IOS_SHARE_INBOX_NATIVE_DRAIN_TRIGGER");
  @autoreleasepool {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:SBXShareAppGroup];
    if (groupURL == nil) {
      NSLog(@"SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL");
      return;
    }
    NSLog(@"SAFEBOX_IOS_SHARE_INBOX_CONTAINER_PASS");

    NSURL *inbox = [groupURL URLByAppendingPathComponent:SBXShareInboxName isDirectory:YES];
    NSURL *processing = [groupURL URLByAppendingPathComponent:SBXShareProcessingName isDirectory:YES];
    NSURL *privateRoot = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
                          URLByAppendingPathComponent:@"SafeBoxShareIntake" isDirectory:YES];
    if (!SBXEnsurePrivateDirectory(inbox) || !SBXEnsurePrivateDirectory(processing) || !SBXEnsurePrivateDirectory(privateRoot)) {
      NSLog(@"SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL");
      return;
    }

    NSUInteger cleaned = 0;
    cleaned += SBXCleanupInbox(inbox);
    // Processing requests are never replayed automatically. An abandoned claim
    // expires fail-closed and the user can share the source again.
    cleaned += SBXCleanupProcessing(processing);
    cleaned += SBXCleanupDirectory(privateRoot, SBXSharePrivateRetentionAge);
    NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_CLEANUP_PASS removed=%lu", (unsigned long)cleaned);

    NSArray<NSURL *> *requests = [fm contentsOfDirectoryAtURL:inbox
                                  includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey]
                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                       error:nil];
    NSUInteger accepted = 0;
    NSUInteger examined = 0;
    unsigned long long acceptedBytes = 0;
    NSLog(@"SAFEBOX_IOS_SHARE_INBOX_DRAIN_BEGIN");

    for (NSURL *request in requests ?: @[]) {
      if (examined >= SBXShareMaxRequestsPerDrain) {
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_DRAIN_LIMIT_PASS");
        break;
      }
      examined += 1;

      if (!SBXIsDirectoryNoSymlink(request) || [[NSUUID alloc] initWithUUIDString:request.lastPathComponent] == nil) {
        [fm removeItemAtURL:request error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=request-shape");
        continue;
      }

      NSURL *ready = [request URLByAppendingPathComponent:@"READY" isDirectory:NO];
      if (![fm fileExistsAtPath:ready.path] || !SBXIsRegularNoSymlink(ready)) {
        continue;
      }

      // Atomic claim prevents two foreground/setup drains from accepting the
      // same request concurrently.
      NSURL *claimed = [processing URLByAppendingPathComponent:request.lastPathComponent isDirectory:YES];
      NSError *claimError = nil;
      if (![fm moveItemAtURL:request toURL:claimed error:&claimError]) {
        continue;
      }
      NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS");

      NSArray<NSURL *> *entries = [fm contentsOfDirectoryAtURL:claimed
                                    includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLIsSymbolicLinkKey, NSURLFileSizeKey]
                                                       options:0
                                                         error:nil];
      NSURL *payload = nil;
      BOOL malformed = NO;
      for (NSURL *entry in entries ?: @[]) {
        if ([entry.lastPathComponent isEqualToString:@"READY"]) {
          if (!SBXIsRegularNoSymlink(entry)) malformed = YES;
          continue;
        }
        if (!SBXIsRegularNoSymlink(entry)) {
          malformed = YES;
          continue;
        }
        if (payload != nil) {
          malformed = YES;
          break;
        }
        payload = entry;
      }
      if (malformed || payload == nil) {
        [fm removeItemAtURL:claimed error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=payload-shape");
        continue;
      }

      unsigned long long payloadSize = SBXFileSize(payload);
      if (payloadSize == ULLONG_MAX || payloadSize > SBXShareMaxPayloadBytes) {
        [fm removeItemAtURL:claimed error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=payload-size");
        continue;
      }
      if (acceptedBytes > SBXShareMaxInboxBytes - payloadSize) {
        [fm removeItemAtURL:claimed error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=byte-quota");
        continue;
      }
      NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS");

      NSURL *privateRequest = [privateRoot URLByAppendingPathComponent:claimed.lastPathComponent isDirectory:YES];
      [fm removeItemAtURL:privateRequest error:nil];
      if (!SBXEnsurePrivateDirectory(privateRequest)) {
        [fm removeItemAtURL:claimed error:nil];
        continue;
      }
      NSURL *destination = [privateRequest URLByAppendingPathComponent:payload.lastPathComponent isDirectory:NO];
      NSURL *partial = [privateRequest URLByAppendingPathComponent:@".payload.partial" isDirectory:NO];
      NSError *copyError = nil;
      if (![fm copyItemAtURL:payload toURL:partial error:&copyError] || !SBXHardenFile(partial)) {
        [fm removeItemAtURL:privateRequest error:nil];
        [fm removeItemAtURL:claimed error:nil];
        continue;
      }
      unsigned long long copiedSize = SBXFileSize(partial);
      if (copiedSize != payloadSize || copiedSize > SBXShareMaxPayloadBytes) {
        [fm removeItemAtURL:privateRequest error:nil];
        [fm removeItemAtURL:claimed error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=copy-verification");
        continue;
      }
      NSError *renameError = nil;
      if (![fm moveItemAtURL:partial toURL:destination error:&renameError] || !SBXHardenFile(destination)) {
        [fm removeItemAtURL:privateRequest error:nil];
        [fm removeItemAtURL:claimed error:nil];
        continue;
      }
      NSLog(@"SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS");

      const char *path = destination.path.UTF8String;
      if (path != nullptr) {
        uint8_t deliveryAck = safebox_ios_share_inbox_accept(path);
        if (deliveryAck == 1) {
          NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS");
          accepted += 1;
          acceptedBytes += payloadSize;
          NSURL *delivered = [claimed URLByAppendingPathComponent:@"DELIVERED" isDirectory:NO];
          if (SBXWriteCommitMarker(delivered)) {
            NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS");
            [fm removeItemAtURL:claimed error:nil];
          } else {
            NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_RECEIPT_FAIL");
            // Keep the acknowledged claim fail-closed. It is never replayed.
          }
        } else {
          NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_NACK_PASS");
          [fm removeItemAtURL:privateRequest error:nil];
          // Keep the unacknowledged claim fail-closed; stale cleanup expires it.
        }
      } else {
        [fm removeItemAtURL:privateRequest error:nil];
        NSLog(@"SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_NACK_PASS");
        // Keep the claim fail-closed; stale cleanup expires it.
      }
    }

    NSLog(@"SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=%lu", (unsigned long)accepted);
  }
}

static id SBXApplicationDidBecomeActiveObserver = nil;
static id SBXSceneDidActivateObserver = nil;

static void SBXInstallForegroundObservers(void) {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    SBXApplicationDidBecomeActiveObserver =
        [center addObserverForName:UIApplicationDidBecomeActiveNotification
                          object:nil
                           queue:nil
                      usingBlock:^(__unused NSNotification *note) {
      NSLog(@"SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_NATIVE_PASS: source=application");
      safebox_ios_share_foreground();
    }];

    if (@available(iOS 13.0, *)) {
      SBXSceneDidActivateObserver =
          [center addObserverForName:UISceneDidActivateNotification
                              object:nil
                               queue:nil
                          usingBlock:^(__unused NSNotification *note) {
        NSLog(@"SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_NATIVE_PASS: source=scene");
        safebox_ios_share_foreground();
      }];
    }
    NSLog(@"SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_OBSERVER_PASS");
  });
}

extern "C" void SBXShareInboxRegisterNativeBridge(void) {
  safebox_ios_share_register(SBXDrainShareInboxNow);
  SBXInstallForegroundObservers();
  NSLog(@"SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_PASS");
}
