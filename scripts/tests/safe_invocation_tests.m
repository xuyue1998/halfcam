#import <Foundation/Foundation.h>
#import "HCSafeInvocation.h"
#include <assert.h>
#include <math.h>

@interface FloatDevice : NSObject
@property(nonatomic) float received;
- (void)setAperture:(float)value;
@end
@implementation FloatDevice
- (void)setAperture:(float)value { self.received = value; }
@end

@interface DoubleDevice : NSObject
@property(nonatomic) double received;
- (void)setAperture:(double)value;
@end
@implementation DoubleDevice
- (void)setAperture:(double)value { self.received = value; }
@end

@interface ObjectDevice : NSObject
@property(nonatomic, strong) NSNumber *received;
- (void)setAperture:(NSNumber *)value;
@end
@implementation ObjectDevice
- (void)setAperture:(NSNumber *)value { self.received = value; }
@end

@interface IntegerDevice : NSObject
@property(nonatomic) BOOL called;
- (void)setAperture:(int)value;
@end
@implementation IntegerDevice
- (void)setAperture:(int)value { self.called = YES; }
@end

@interface ReturningDevice : NSObject
- (BOOL)setAperture:(float)value;
@end
@implementation ReturningDevice
- (BOOL)setAperture:(float)value { abort(); }
@end

@interface ThrowingDevice : NSObject
- (void)setAperture:(float)value;
- (NSArray *)supportedApertures;
@end
@implementation ThrowingDevice
- (void)setAperture:(float)value {
    [NSException raise:NSInvalidArgumentException format:@"Simulated hardware rejection"];
}
- (NSArray *)supportedApertures {
    [NSException raise:NSInvalidArgumentException format:@"Simulated getter rejection"];
    return nil;
}
@end

int main(void) {
    @autoreleasepool {
        FloatDevice *floatDevice = [FloatDevice new];
        assert(HCSetApertureSafely(floatDevice, 2.8f));
        assert(fabsf(floatDevice.received - 2.8f) < 0.0001f);
        DoubleDevice *doubleDevice = [DoubleDevice new];
        assert(HCSetApertureSafely(doubleDevice, 4.0f));
        assert(fabs(doubleDevice.received - 4.0) < 0.0001);
        ObjectDevice *objectDevice = [ObjectDevice new];
        assert(HCSetApertureSafely(objectDevice, 5.6f));
        assert(fabsf(objectDevice.received.floatValue - 5.6f) < 0.0001f);
        assert([HCValueForKeySafely(objectDevice, @"received") isKindOfClass:NSNumber.class]);

        IntegerDevice *integerDevice = [IntegerDevice new];
        assert(!HCSetApertureSafely(integerDevice, 2.8f));
        assert(!integerDevice.called);
        assert(!HCSetApertureSafely([ReturningDevice new], 2.8f));
        assert(!HCSetApertureSafely([NSObject new], 2.8f));
        assert(!HCSetApertureSafely([ThrowingDevice new], 2.8f));
        assert(HCValueForKeySafely([ThrowingDevice new], @"supportedApertures") == nil);
        assert(HCValueForKeySafely([NSObject new], @"missingGetter") == nil);

        for (NSNumber *invalid in @[@(NAN), @(INFINITY), @(-INFINITY), @0, @(-1), @32]) {
            assert(!HCSetApertureSafely(floatDevice, invalid.floatValue));
            assert(fabsf(floatDevice.received - 2.8f) < 0.0001f);
        }
        puts("Safe invocation: scalar/object ABI, invalid signatures/values, exceptions passed.");
    }
    return 0;
}
