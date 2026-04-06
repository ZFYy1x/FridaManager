#import <Foundation/Foundation.h>

@interface FMConfig : NSObject

+ (instancetype)sharedConfig;

@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) BOOL localhostOnly;

- (void)reload;
- (void)save;
- (NSString *)listenAddress;

// Download history
- (void)addDownloadHistoryEntry:(NSString *)version;
- (NSArray<NSDictionary *> *)downloadHistory;
- (void)clearDownloadHistory;

@end
