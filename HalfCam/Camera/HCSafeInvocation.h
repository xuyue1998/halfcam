#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Invokes an optional aperture setter only when its argument ABI is understood.
FOUNDATION_EXPORT BOOL HCSetApertureSafely(NSObject *device, float value);

/// Optional hardware getters can throw Objective-C exceptions, which Swift cannot catch.
FOUNDATION_EXPORT id _Nullable HCValueForKeySafely(NSObject *object, NSString *key);

NS_ASSUME_NONNULL_END
