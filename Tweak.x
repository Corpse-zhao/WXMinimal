#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CMessageMgr : NSObject
@end
@interface CMessageWrap : NSObject
@end

static NSString *const kWXMBundleID = @"com.tencent.xin";

static BOOL WXMIsWeChat(void) {
    static BOOL cached = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cached = [NSBundle.mainBundle.bundleIdentifier isEqualToString:kWXMBundleID];
    });
    return cached;
}

// Append one short line to the data-container log (no message content is ever written).
static void WXMLog(NSString *event) {
    static NSURL *url = nil;
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *caches = [[NSFileManager defaultManager]
            URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
        if (caches) {
            NSURL *dir = [caches URLByAppendingPathComponent:@"WXMinimal" isDirectory:YES];
            [[NSFileManager defaultManager] createDirectoryAtURL:dir
                withIntermediateDirectories:YES attributes:nil error:NULL];
            url = [dir URLByAppendingPathComponent:@"antirevoke.log"];
        }
        queue = dispatch_queue_create("local.wxminimal.log", DISPATCH_QUEUE_SERIAL);
    });
    if (!url) return;
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], event];
    dispatch_async(queue, ^{
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:url.path];
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        } else {
            [[line dataUsingEncoding:NSUTF8StringEncoding] writeToURL:url atomically:YES];
        }
    });
}

%hook CMessageMgr

// Confirmed in 8.0.75.33 report: 3-arg and 5-arg overloads. Both must be
// blocked — hooking only one leaves the other recall path open.
- (BOOL)RevokeMsg:(id)msg MsgWrap:(id)wrap Counter:(unsigned int)counter {
    if (WXMIsWeChat()) WXMLog(@"RevokeMsg:MsgWrap:Counter: -> NO");
    return NO;
}

- (BOOL)RevokeMsg:(id)msg MsgWrap:(id)wrap Counter:(unsigned int)counter revokeTicket:(id)ticket viewController:(id)vc {
    if (WXMIsWeChat()) WXMLog(@"RevokeMsg:...revokeTicket:viewController: -> NO");
    return NO;
}

// The recall notice is delivered as a sysmsg. Only suppress entries whose
// content clearly looks like a revokemsg; all other sysmessages pass through
// via %orig unchanged. If this selector turns out to be a post-insert hook,
// suppression is a harmless no-op and normal messages are unaffected.
- (void)PostInsertParsedXmlSysMsg:(id)msg ChatName:(id)chatName {
    if (WXMIsWeChat()) {
        NSString *text = nil;
        if ([msg isKindOfClass:NSString.class]) {
            text = (NSString *)msg;
        } else if ([msg respondsToSelector:@selector(m_nsContent)]) {
            text = [msg performSelector:@selector(m_nsContent)];
        }
        if ([text isKindOfClass:NSString.class] &&
            [text rangeOfString:@"revokemsg" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            WXMLog(@"suppressed revokemsg sysmsg");
            return;
        }
    }
    %orig;
}

%end

%hook CMessageWrap

// Batch "revoke history" feature. Side effect: your own batch-recall is also
// disabled while this is on. Logged so it can be identified in a real test.
- (BOOL)doRevokeHistoryRecord {
    if (WXMIsWeChat()) WXMLog(@"doRevokeHistoryRecord -> NO");
    return NO;
}

%end

%ctor {
    WXMLog(@"WXMinimal anti-revoke v0.2.0 loaded");
}
