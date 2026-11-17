#import "HCSafeInvocation.h"
#include <math.h>
#include <string.h>

#if DEBUG
static const char *unqualifiedType(const char *type) {
    while (*type && strchr("rnNoORV", *type)) type++;
    return type;
}

BOOL HCSetApertureSafely(NSObject *device, float value) {
    if (!isfinite(value) || value <= 0.4f || value >= 32.0f) return NO;
    @try {
        SEL selector = NSSelectorFromString(@"setAperture:");
        if (![device respondsToSelector:selector]) return NO;
        NSMethodSignature *signature = [device methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 3 ||
            strcmp(unqualifiedType(signature.methodReturnType), @encode(void)) != 0) {
            return NO;
        }
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = device;
        invocation.selector = selector;
        const char *type = unqualifiedType([signature getArgumentTypeAtIndex:2]);
        __attribute__((objc_precise_lifetime)) NSNumber *boxed = @(value);
        if (strcmp(type, @encode(float)) == 0) {
            [invocation setArgument:&value atIndex:2];
        } else if (strcmp(type, @encode(double)) == 0) {
            double argument = value;
            [invocation setArgument:&argument atIndex:2];
        } else if (strcmp(type, @encode(id)) == 0 ||
                   strncmp(type, "@\"", 2) == 0) {
            // NSInvocation copies the argument bytes, not the object. Keep boxed alive
            // until the synchronous invocation returns.
            __unsafe_unretained NSNumber *argument = boxed;
            [invocation setArgument:&argument atIndex:2];
        } else {
            return NO;
        }
        [invocation invoke];
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

id HCValueForKeySafely(NSObject *object, NSString *key) {
    @try {
        if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        return nil;
    }
}
#else
// No non-public hardware selectors are compiled into distribution builds.
BOOL HCSetApertureSafely(NSObject *device, float value) {
    (void)device;
    (void)value;
    return NO;
}

id HCValueForKeySafely(NSObject *object, NSString *key) {
    (void)object;
    (void)key;
    return nil;
}
#endif
