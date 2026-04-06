#import <Foundation/Foundation.h>

// Shared log function — writes to /var/tmp/fridamgr.log
extern void FMLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

@interface FMDownloadManager : NSObject

+ (instancetype)sharedManager;

// Fetch latest version strings by scraping GitHub releases HTML page
- (NSArray<NSString *> *)fetchLatestVersions:(NSInteger)limit;

// Download and install a specific version
- (BOOL)downloadAndInstallVersion:(NSString *)version;

// Download progress (0.0 - 1.0), -1 if not downloading
@property (nonatomic, readonly) float downloadProgress;
@property (nonatomic, readonly) BOOL isDownloading;
@property (nonatomic, readonly, copy) NSString *downloadStatus;

// Cached versions (nil if not fetched yet)
@property (nonatomic, readonly, strong) NSArray<NSString *> *cachedVersions;
@property (nonatomic, readonly) BOOL isFetchingReleases;

@end
