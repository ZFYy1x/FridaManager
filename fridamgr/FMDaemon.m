#import "FMDaemon.h"
#import "FMCommon.h"
#import "FMSocketServer.h"
#import "FMFridaServer.h"
#import "FMConfig.h"
#import "FMDownloadManager.h"

@interface FMDaemon () <FMSocketServerDelegate>
@property (nonatomic, strong) FMSocketServer *socketServer;
@property (nonatomic, strong) FMFridaServer *fridaServer;
@property (nonatomic, strong) FMConfig *config;
@property (nonatomic, strong) FMDownloadManager *downloadManager;
@property (nonatomic, assign) BOOL isStopping;
// Version list async state
@property (nonatomic, strong) NSArray<NSString *> *fetchedVersions;
@property (nonatomic, copy) NSString *fetchVersionsStatus; // nil=idle, "fetching"=in progress, "done"=ready, "error:..."=failed
@end

@implementation FMDaemon

+ (instancetype)sharedDaemon {
    static FMDaemon *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FMDaemon alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _socketServer = [[FMSocketServer alloc] init];
        _socketServer.delegate = self;
        _fridaServer = [FMFridaServer sharedServer];
        _config = [FMConfig sharedConfig];
        _downloadManager = [FMDownloadManager sharedManager];
        _isStopping = NO;
        _fetchVersionsStatus = nil;
    }
    return self;
}

- (void)start {
    FMLog(@"=== FridaManager daemon starting ===");
    FMLog(@"Managed binary path: %@", kFMManagedBinaryPath);

    if (![_socketServer startListening]) {
        FMLog(@"Failed to start socket server on %@", kFMSocketPath);
    } else {
        FMLog(@"Listening on %@", kFMSocketPath);
    }
}

#pragma mark - FMSocketServerDelegate

- (NSString *)handleCommand:(NSString *)command {
    NSArray *parts = [command componentsSeparatedByString:@":"];
    NSString *cmd = [parts[0] uppercaseString];

    // Only log important commands (not polling/frequent ones)
    if (![cmd isEqualToString:kFMCommandStatus] &&
        ![cmd isEqualToString:kFMCommandDownloadProgress] &&
        ![cmd isEqualToString:kFMCommandGetConfig] &&
        ![cmd isEqualToString:kFMCommandGetHistory] &&
        ![cmd isEqualToString:kFMCommandGetLog] &&
        ![cmd isEqualToString:kFMCommandListVersions]) {
        FMLog(@"CMD: %@", command);
    }

    if ([cmd isEqualToString:kFMCommandStatus]) {
        return [self handleStatus];
    } else if ([cmd isEqualToString:kFMCommandStart]) {
        return [self handleStart];
    } else if ([cmd isEqualToString:kFMCommandStop]) {
        return [self handleStop];
    } else if ([cmd isEqualToString:kFMCommandRestart]) {
        return [self handleRestart];
    } else if ([cmd isEqualToString:kFMCommandGetConfig]) {
        return [self handleGetConfig];
    } else if ([cmd isEqualToString:kFMCommandSetPort]) {
        if (parts.count > 1) {
            return [self handleSetPort:[parts[1] integerValue]];
        }
        return @"ERR:missing port value";
    } else if ([cmd isEqualToString:kFMCommandSetLocalhost]) {
        if (parts.count > 1) {
            return [self handleSetLocalhost:[parts[1] boolValue]];
        }
        return @"ERR:missing value";
    } else if ([cmd isEqualToString:kFMCommandListVersions]) {
        return [self handleListVersions];
    } else if ([cmd isEqualToString:kFMCommandDownload]) {
        if (parts.count > 1) {
            return [self handleDownload:parts[1]];
        }
        return @"ERR:missing version";
    } else if ([cmd isEqualToString:kFMCommandDownloadProgress]) {
        return [self handleDownloadProgress];
    } else if ([cmd isEqualToString:kFMCommandGetVersion]) {
        return [self handleGetVersion];
    } else if ([cmd isEqualToString:kFMCommandUninstall]) {
        return [self handleUninstall];
    } else if ([cmd isEqualToString:kFMCommandGetLog]) {
        return [self handleGetLog];
    } else if ([cmd isEqualToString:kFMCommandGetHistory]) {
        return [self handleGetHistory];
    } else if ([cmd isEqualToString:kFMCommandClearHistory]) {
        return [self handleClearHistory];
    }

    FMLog(@"Unknown command: %@", command);
    return @"ERR:unknown command";
}

- (NSString *)handleStatus {
    NSDictionary *status = [_fridaServer statusDictionary];
    NSMutableDictionary *dict = [status mutableCopy];
    if (_isStopping) dict[@"stopping"] = @(YES);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)handleStart {
    if (_isStopping) return @"ERR:stop in progress, please wait";
    [_config reload];
    [_fridaServer refreshBinaryPath];
    NSString *sourceStr = _fridaServer.source == 1 ? @"FridaManager" : (_fridaServer.source == 2 ? @"Package Manager" : @"none");
    FMLog(@"Starting frida-server on %@:%ld (source: %@)", [_config listenAddress], (long)_config.port, sourceStr);
    BOOL ok = [_fridaServer startWithPort:_config.port listenAddress:[_config listenAddress]];
    FMLog(@"Start result: %@", ok ? @"OK" : @"FAILED");
    return ok ? @"OK:started" : @"ERR:start failed";
}

- (NSString *)handleStop {
    if (_isStopping) return @"OK:already stopping";

    _isStopping = YES;
    NSString *sourceStr = _fridaServer.source == 1 ? @"FridaManager" : (_fridaServer.source == 2 ? @"Package Manager" : @"none");
    FMLog(@"Stopping frida-server (source: %@)...", sourceStr);

    [_fridaServer stop];
    _isStopping = NO;
    FMLog(@"Stop complete");

    return @"OK:stopped";
}

- (NSString *)handleRestart {
    if (_isStopping) return @"ERR:stop in progress, please wait";
    [_config reload];
    FMLog(@"Restarting frida-server on %@:%ld", [_config listenAddress], (long)_config.port);
    BOOL ok = [_fridaServer restartWithPort:_config.port listenAddress:[_config listenAddress]];
    FMLog(@"Restart result: %@", ok ? @"OK" : @"FAILED");
    return ok ? @"OK:restarted" : @"ERR:restart failed";
}

- (NSString *)handleGetConfig {
    [_config reload];
    NSDictionary *dict = @{
        kFMConfigKeyPort: @(_config.port),
        kFMConfigKeyLocalhostOnly: @(_config.localhostOnly)
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)handleSetPort:(NSInteger)port {
    if (port < 1 || port > 65535) return @"ERR:invalid port";
    _config.port = port;
    [_config save];
    FMLog(@"Port set to %ld", (long)port);
    return @"OK:port set";
}

- (NSString *)handleSetLocalhost:(BOOL)localhost {
    _config.localhostOnly = localhost;
    [_config save];
    FMLog(@"LocalhostOnly set to %d", localhost);
    return @"OK:localhost set";
}

- (NSString *)handleListVersions {
    // If we have cached versions, return them immediately
    NSArray *cached = _downloadManager.cachedVersions;
    if (cached && cached.count > 0) {
        // Also trigger background refresh if cache is old
        if (!_downloadManager.isFetchingReleases) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [self->_downloadManager fetchLatestVersions:kFMGitHubReleasesPerPage];
            });
        }
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:cached options:0 error:nil];
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    // If already fetching, tell client to poll
    if ([_fetchVersionsStatus isEqualToString:@"fetching"]) {
        return @"WAIT:fetching";
    }

    // If fetch completed, return results
    if ([_fetchVersionsStatus isEqualToString:@"done"] && _fetchedVersions.count > 0) {
        _fetchVersionsStatus = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_fetchedVersions options:0 error:nil];
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    // If fetch failed
    if (_fetchVersionsStatus && [_fetchVersionsStatus hasPrefix:@"error"]) {
        NSString *err = _fetchVersionsStatus;
        _fetchVersionsStatus = nil;
        return [NSString stringWithFormat:@"ERR:%@", err];
    }

    // Start async fetch
    _fetchVersionsStatus = @"fetching";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FMLog(@"Fetching versions async...");
        NSArray *versions = [self->_downloadManager fetchLatestVersions:kFMGitHubReleasesPerPage];
        if (versions && versions.count > 0) {
            self->_fetchedVersions = versions;
            self->_fetchVersionsStatus = @"done";
            FMLog(@"Fetched %lu versions", (unsigned long)versions.count);
        } else {
            self->_fetchVersionsStatus = @"error:failed to fetch versions";
            FMLog(@"Version fetch failed");
        }
    });

    return @"WAIT:fetching";
}

- (NSString *)handleDownload:(NSString *)version {
    if (_downloadManager.isDownloading) return @"ERR:download in progress";

    [_fridaServer refreshBinaryPath];
    if (_fridaServer.source == FMFridaSourcePackageManager) {
        FMLog(@"Download blocked: frida installed via package manager");
        return @"ERR:PKGMGR";
    }

    FMLog(@"Starting download of v%@", version);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = [self->_downloadManager downloadAndInstallVersion:version];
        FMLog(@"Download result for v%@: %@", version, success ? @"SUCCESS" : @"FAILED");
        if (success) {
            [self->_config addDownloadHistoryEntry:version];
            NSArray *history = [self->_config downloadHistory];
            FMLog(@"Added v%@ to download history (now %lu entries)", version, (unsigned long)history.count);
        }
    });

    return @"OK:download started";
}

- (NSString *)handleDownloadProgress {
    NSDictionary *dict = @{
        @"progress": @(_downloadManager.downloadProgress),
        @"downloading": @(_downloadManager.isDownloading),
        @"status": _downloadManager.downloadStatus ?: @"Idle"
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)handleGetVersion {
    [_fridaServer refreshBinaryPath];
    NSString *version = _fridaServer.installedVersion;
    NSString *path = _fridaServer.binaryPath;
    NSDictionary *dict = @{
        @"version": version ?: @"not installed",
        @"path": path ?: @"not found"
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)handleUninstall {
    [_fridaServer refreshBinaryPath];

    if (_fridaServer.source == FMFridaSourcePackageManager) {
        FMLog(@"Uninstall rejected: frida installed via package manager");
        return @"ERR:Frida was installed via a package manager. Use your package manager to remove it.";
    }

    FMLog(@"Uninstalling frida-server...");
    [_fridaServer stop];

    NSString *path = kFMManagedBinaryPath;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [_fridaServer refreshBinaryPath];
        FMLog(@"No managed binary at %@", path);
        return @"ERR:no managed binary found";
    }

    NSError *error;
    if ([fm removeItemAtPath:path error:&error]) {
        // Also remove frida-agent.dylib if it exists
        NSString *agentPath = kFMManagedAgentPath;
        if ([fm fileExistsAtPath:agentPath]) {
            [fm removeItemAtPath:agentPath error:nil];
            FMLog(@"Removed agent at %@", agentPath);
        }
        [_fridaServer refreshBinaryPath];
        FMLog(@"Uninstalled from %@", path);
        return @"OK:uninstalled";
    }
    FMLog(@"Uninstall failed: %@", error);
    return [NSString stringWithFormat:@"ERR:%@", error.localizedDescription];
}

- (NSString *)handleGetLog {
    NSString *contents = [NSString stringWithContentsOfFile:kFMLogPath encoding:NSUTF8StringEncoding error:nil];
    if (!contents || contents.length == 0) return @"No log entries yet.";
    // Return last 3KB — UIAlertController can't handle more
    if (contents.length > 3072) {
        contents = [@"...\n" stringByAppendingString:[contents substringFromIndex:contents.length - 3072]];
    }
    return contents;
}

- (NSString *)handleGetHistory {
    NSArray *history = [_config downloadHistory];
    if (!history || history.count == 0) return @"[]";
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:history options:0 error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSString *)handleClearHistory {
    [_config clearDownloadHistory];
    FMLog(@"Download history cleared");
    return @"OK:history cleared";
}

@end
