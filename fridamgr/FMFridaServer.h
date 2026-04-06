#import <Foundation/Foundation.h>

// Source of the frida-server binary
typedef NS_ENUM(NSInteger, FMFridaSource) {
    FMFridaSourceNone = 0,       // not installed
    FMFridaSourceFridaManager,   // installed by this tweak (/usr/local/bin/)
    FMFridaSourcePackageManager, // installed by a package manager (Sileo, Zebra, Cydia, etc.)
};

@interface FMFridaServer : NSObject

+ (instancetype)sharedServer;

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, readonly) pid_t serverPID;
@property (nonatomic, readonly, copy) NSString *binaryPath;
@property (nonatomic, readonly) NSInteger activePort;
@property (nonatomic, readonly, copy) NSString *installedVersion;
@property (nonatomic, readonly) FMFridaSource source;

- (BOOL)startWithPort:(NSInteger)port listenAddress:(NSString *)address;
- (BOOL)stop;
- (BOOL)restartWithPort:(NSInteger)port listenAddress:(NSString *)address;
- (NSDictionary *)statusDictionary;
- (void)refreshBinaryPath;

@end
