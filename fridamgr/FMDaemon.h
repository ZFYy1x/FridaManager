#import <Foundation/Foundation.h>

@interface FMDaemon : NSObject

+ (instancetype)sharedDaemon;
- (void)start;

@end
