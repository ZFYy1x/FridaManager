#import <Foundation/Foundation.h>

@protocol FMSocketServerDelegate <NSObject>
- (NSString *)handleCommand:(NSString *)command;
@end

@interface FMSocketServer : NSObject

@property (nonatomic, weak) id<FMSocketServerDelegate> delegate;

- (BOOL)startListening;
- (void)stopListening;

@end
