#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVCaptureDevice (SafeFocus)

/// Wraps `-setFocusModeLockedWithLensPosition:completionHandler:` and swallows
/// NSInvalidArgumentException. Swift cannot catch that ObjC exception.
- (BOOL)hc_setFocusModeLockedWithLensPosition:(float)lensPosition
                            completionHandler:(nullable void (^)(CMTime syncTime))handler
    NS_SWIFT_NAME(hc_setFocusModeLocked(withLensPosition:completionHandler:));

@end

NS_ASSUME_NONNULL_END
