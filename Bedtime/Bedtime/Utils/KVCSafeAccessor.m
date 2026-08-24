//
//  KVCSafeAccessor.m
//  Bedtime
//

#import "KVCSafeAccessor.h"

@implementation KVCSafeAccessor

+ (nullable id)safeValue:(NSString *)key forObject:(id)object {
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        return nil;
    }
}

@end
