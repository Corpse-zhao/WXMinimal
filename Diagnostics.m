#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <stdlib.h>

// Diagnostic build only. Never hooks, invokes, or replaces WeChat methods.
static NSString *const WXMBundleID = @"com.tencent.xin";
static NSString *const WXMVersion = @"0.1.0-diagnostic";

static BOOL WXMInterestingSelector(NSString *name) {
    NSString *lower = name.lowercaseString;
    for (NSString *keyword in @[@"revoke", @"retract", @"sysmsg"]) {
        if ([lower containsString:keyword]) return YES;
    }
    return NO;
}

static NSDictionary *WXMDescribeClass(NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return @{@"name": className, @"present": @NO};
    NSMutableArray *methods = [NSMutableArray array];
    // Only the named class, not all objects or all runtime classes.
    for (NSNumber *isClassMethod in @[@NO, @YES]) {
        Class target = isClassMethod.boolValue ? object_getClass(cls) : cls;
        unsigned int count = 0;
        Method *list = class_copyMethodList(target, &count);
        if (list) {
            for (unsigned int i = 0; i < count; i++) {
                NSString *selector = NSStringFromSelector(method_getName(list[i]));
                if (!WXMInterestingSelector(selector)) continue;
                const char *encoding = method_getTypeEncoding(list[i]);
                [methods addObject:@{
                    @"selector": selector,
                    @"typeEncoding": encoding ? @(encoding) : @"",
                    @"kind": isClassMethod.boolValue ? @"class" : @"instance"
                }];
            }
        }
        free(list);
    }
    [methods sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"selector"] compare:b[@"selector"]];
    }];
    return @{@"name": className, @"present": @YES, @"candidateMethods": methods};
}

static NSURL *WXMReportURL(void) {
    NSURL *cache = [[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
    return [[cache URLByAppendingPathComponent:@"WXMinimal" isDirectory:YES]
        URLByAppendingPathComponent:@"diagnostics.json"];
}

static void WXMWriteReport(NSInteger sampleSeconds) {
    @autoreleasepool {
        @try {
            NSBundle *bundle = NSBundle.mainBundle;
            if (![bundle.bundleIdentifier isEqualToString:WXMBundleID]) return;
            NSMutableArray *classes = [NSMutableArray array];
            // Candidate names only, not validated 8.0.75 interfaces.
            for (NSString *name in @[@"CMessageMgr", @"CMessageWrap", @"MessageService"]) {
                [classes addObject:WXMDescribeClass(name)];
            }
            NSDictionary *report = @{
                @"schema": @1,
                @"pluginVersion": WXMVersion,
                @"mode": @"diagnostic-only",
                @"sampleSecondsAfterLoad": @(sampleSeconds),
                @"bundleIdentifier": bundle.bundleIdentifier ?: @"",
                @"appVersion": [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
                @"appBuild": [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"",
                @"iOSVersion": UIDevice.currentDevice.systemVersion ?: @"",
                @"candidateClasses": classes,
                @"antiRevokeImplemented": @NO,
                @"realNameFeatureImplemented": @NO,
                @"note": @"Candidate selectors do not prove compatibility. No message data collected."
            };
            NSError *error = nil;
            NSData *data = [NSJSONSerialization dataWithJSONObject:report
                options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys) error:&error];
            if (!data) {
                NSLog(@"[WXMinimal] Report serialization failed: %@", error.localizedDescription);
                return;
            }
            NSURL *url = WXMReportURL();
            if (!url) { NSLog(@"[WXMinimal] Cache directory unavailable"); return; }
            BOOL created = [[NSFileManager defaultManager]
                createDirectoryAtURL:[url URLByDeletingLastPathComponent]
                withIntermediateDirectories:YES attributes:nil error:&error];
            if (!created || ![data writeToURL:url options:NSDataWritingAtomic error:&error]) {
                NSLog(@"[WXMinimal] Report write failed: %@", error.localizedDescription);
                return;
            }
            NSLog(@"[WXMinimal] Diagnostic report ready: %@", url.path);
        } @catch (NSException *exception) {
            NSLog(@"[WXMinimal] Diagnostic exception: %@", exception.name);
        }
    }
}

__attribute__((constructor)) static void WXMInitialize(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:WXMBundleID]) return;
        // Two bounded samples; no polling, notifications, network or background service.
        for (NSNumber *seconds in @[@5, @20]) {
            NSInteger delay = seconds.integerValue;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)delay * NSEC_PER_SEC),
                dispatch_get_main_queue(), ^{ WXMWriteReport(delay); });
        }
    }
}
