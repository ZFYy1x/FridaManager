#import <Foundation/Foundation.h>

@interface FMSocketClient : NSObject

+ (instancetype)sharedClient;
- (NSString *)sendCommand:(NSString *)command;
- (void)sendCommand:(NSString *)command completion:(void (^)(NSString *response))completion;

@end
