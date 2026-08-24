//
//  KVCSafeAccessor.h
//  Bedtime
//
//  Guards reads of undocumented Key-Value Coding properties (e.g. HKSample's private
//  "creationTimestamp") against crashing if the key is ever removed or renamed.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Swift's `NSObject.value(forKey:)` does not catch Objective-C exceptions, so an undefined
/// KVC key raises `NSUndefinedKeyException` and crashes the app. This trampoline exists purely
/// to make undocumented/private KVC reads safe to attempt speculatively.
@interface KVCSafeAccessor : NSObject

/// Returns `[object valueForKey:key]`, or `nil` if that raises any exception (e.g. the key is
/// undefined) instead of crashing.
+ (nullable id)safeValue:(NSString *)key forObject:(id)object;

@end

NS_ASSUME_NONNULL_END
