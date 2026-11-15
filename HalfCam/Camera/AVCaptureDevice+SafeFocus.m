#import "AVCaptureDevice+SafeFocus.h"

@implementation AVCaptureDevice (SafeFocus)

- (BOOL)hc_setFocusModeLockedWithLensPosition:(float)lensPosition
                            completionHandler:(void (^)(CMTime syncTime))handler {
    @try {
        [self setFocusModeLockedWithLensPosition:lensPosition completionHandler:handler];
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

@end
