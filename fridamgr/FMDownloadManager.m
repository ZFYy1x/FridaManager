#import "FMDownloadManager.h"
#import "FMCommon.h"
#import "FMFridaServer.h"
#import <compression.h>
#import <sys/stat.h>

void FMLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm:ss"];
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, msg];

    NSLog(@"[FridaManager] %@", msg);

    // Keep log file small: truncate if over 32KB
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:kFMLogPath]) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:kFMLogPath error:nil];
        if ([attrs fileSize] > 32768) {
            NSString *contents = [NSString stringWithContentsOfFile:kFMLogPath encoding:NSUTF8StringEncoding error:nil];
            if (contents.length > 8192) {
                contents = [contents substringFromIndex:contents.length - 8192];
            }
            [contents writeToFile:kFMLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kFMLogPath];
    if (!fh) {
        [@"" writeToFile:kFMLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        chmod([kFMLogPath UTF8String], 0666);
        fh = [NSFileHandle fileHandleForWritingAtPath:kFMLogPath];
    }
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

@implementation FMDownloadManager {
    float _downloadProgress;
    BOOL _isDownloading;
    NSString *_downloadStatus;
    NSArray<NSString *> *_cachedVersions;
    NSDate *_cacheTimestamp;
    BOOL _isFetchingReleases;
}

+ (instancetype)sharedManager {
    static FMDownloadManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FMDownloadManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloadProgress = -1;
        _isDownloading = NO;
        _downloadStatus = @"Idle";
    }
    return self;
}

- (float)downloadProgress { return _downloadProgress; }
- (BOOL)isDownloading { return _isDownloading; }
- (NSString *)downloadStatus { return _downloadStatus; }
- (NSArray<NSString *> *)cachedVersions { return _cachedVersions; }
- (BOOL)isFetchingReleases { return _isFetchingReleases; }

#pragma mark - Single HTTP method (same approach used for successful downloads)

- (NSData *)httpGet:(NSString *)urlString statusCode:(NSInteger *)outStatusCode {
    FMLog(@"GET %@", urlString);

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        FMLog(@"ERROR: bad URL");
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"FridaManager/2.0" forHTTPHeaderField:@"User-Agent"];
    [request setTimeoutInterval:20];

    __block NSData *resultData = nil;
    __block NSInteger statusCode = 0;
    __block NSError *resultError = nil;

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = 20;
    config.timeoutIntervalForResource = 120;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        resultData = data;
        resultError = error;
        if ([response isKindOfClass:[NSHTTPURLResponse class]])
            statusCode = ((NSHTTPURLResponse *)response).statusCode;
        dispatch_semaphore_signal(sem);
    }] resume];

    long waitResult = dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    [session invalidateAndCancel];

    if (waitResult != 0) {
        FMLog(@"ERROR: timed out");
        if (outStatusCode) *outStatusCode = 0;
        return nil;
    }

    if (resultError) {
        FMLog(@"ERROR: %@ (code %ld)", resultError.localizedDescription, (long)resultError.code);
    }

    FMLog(@"Response: HTTP %ld, %lu bytes", (long)statusCode, (unsigned long)resultData.length);

    if (outStatusCode) *outStatusCode = statusCode;
    if (statusCode >= 400) return nil;
    return resultData;
}

#pragma mark - Version Fetching (Atom feed)

- (NSArray<NSString *> *)fetchLatestVersions:(NSInteger)limit {
    if (_cachedVersions && _cacheTimestamp) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:_cacheTimestamp];
        if (age < 300) {
            FMLog(@"Cache hit: %lu versions (%.0fs old)", (unsigned long)_cachedVersions.count, age);
            return _cachedVersions;
        }
    }

    _isFetchingReleases = YES;

    NSInteger statusCode = 0;
    NSData *data = [self httpGet:kFMGitHubAtomURL statusCode:&statusCode];

    if (!data || data.length == 0) {
        FMLog(@"ERROR: Atom feed empty or failed (HTTP %ld)", (long)statusCode);
        _isFetchingReleases = NO;
        return _cachedVersions;
    }

    NSString *atom = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!atom) {
        FMLog(@"ERROR: Atom response not UTF-8");
        _isFetchingReleases = NO;
        return _cachedVersions;
    }

    // Parse versions using multiple strategies
    NSMutableArray<NSString *> *versions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    // Strategy 1: <id> tags — e.g. <id>tag:github.com,2008:Repository/xxx/16.7.4</id>
    NSRegularExpression *idRegex = [NSRegularExpression regularExpressionWithPattern:@"<id>[^<]*/([0-9]+\\.[0-9]+\\.[0-9]+)</id>"
                                                                            options:0
                                                                              error:nil];
    NSArray *idMatches = [idRegex matchesInString:atom options:0 range:NSMakeRange(0, atom.length)];
    FMLog(@"Regex strategy 1 (id tags): %lu matches", (unsigned long)idMatches.count);

    for (NSTextCheckingResult *match in idMatches) {
        if (match.numberOfRanges >= 2) {
            NSString *version = [atom substringWithRange:[match rangeAtIndex:1]];
            if (![seen containsObject:version]) {
                [seen addObject:version];
                [versions addObject:version];
            }
        }
    }

    // Strategy 2: <title> tags containing a version — e.g. <title>Frida 16.7.4</title>
    if (versions.count == 0) {
        NSRegularExpression *titleRegex = [NSRegularExpression regularExpressionWithPattern:@"<title[^>]*>[^<]*?(\\d+\\.\\d+\\.\\d+)[^<]*</title>"
                                                                                   options:0
                                                                                     error:nil];
        NSArray *titleMatches = [titleRegex matchesInString:atom options:0 range:NSMakeRange(0, atom.length)];
        FMLog(@"Regex strategy 2 (title tags): %lu matches", (unsigned long)titleMatches.count);

        for (NSTextCheckingResult *match in titleMatches) {
            if (match.numberOfRanges >= 2) {
                NSString *version = [atom substringWithRange:[match rangeAtIndex:1]];
                if (![seen containsObject:version]) {
                    [seen addObject:version];
                    [versions addObject:version];
                }
            }
        }
    }

    // Strategy 3: Any version-like pattern X.Y.Z in the feed
    if (versions.count == 0) {
        NSRegularExpression *anyRegex = [NSRegularExpression regularExpressionWithPattern:@"/tag/(\\d+\\.\\d+\\.\\d+)"
                                                                                 options:0
                                                                                   error:nil];
        NSArray *anyMatches = [anyRegex matchesInString:atom options:0 range:NSMakeRange(0, atom.length)];
        FMLog(@"Regex strategy 3 (/tag/ URLs): %lu matches", (unsigned long)anyMatches.count);

        for (NSTextCheckingResult *match in anyMatches) {
            if (match.numberOfRanges >= 2) {
                NSString *version = [atom substringWithRange:[match rangeAtIndex:1]];
                if (![seen containsObject:version]) {
                    [seen addObject:version];
                    [versions addObject:version];
                }
            }
        }
    }

    if (versions.count > 0) {
        FMLog(@"Found %lu versions: %@", (unsigned long)versions.count, [versions componentsJoinedByString:@", "]);
        _cachedVersions = [versions copy];
        _cacheTimestamp = [NSDate date];
    } else {
        // Log more of the feed for debugging
        NSString *snippet = atom.length > 500 ? [atom substringToIndex:500] : atom;
        snippet = [[snippet componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        FMLog(@"ERROR: No versions found. Feed: %@", snippet);
    }

    _isFetchingReleases = NO;
    return versions.count > 0 ? versions : _cachedVersions;
}

#pragma mark - Download & Install

- (BOOL)downloadAndInstallVersion:(NSString *)version {
    if (_isDownloading) return NO;

    _isDownloading = YES;
    _downloadProgress = 0;
    _downloadStatus = @"Downloading .deb...";

    NSString *debName = [NSString stringWithFormat:@"frida_%@_iphoneos-arm64.deb", version];
    NSString *downloadURL = [NSString stringWithFormat:
        @"https://github.com/frida/frida/releases/download/%@/%@", version, debName];

    NSInteger statusCode = 0;
    NSData *debData = [self httpGet:downloadURL statusCode:&statusCode];

    if (!debData || debData.length == 0) {
        FMLog(@"ERROR: Download failed for v%@ (HTTP %ld)", version, (long)statusCode);
        _downloadStatus = [NSString stringWithFormat:@"Download failed (HTTP %ld)", (long)statusCode];
        _isDownloading = NO;
        _downloadProgress = -1;
        return NO;
    }

    _downloadProgress = 0.5;
    _downloadStatus = @"Extracting frida-server...";

    NSData *agentData = nil;
    NSData *binaryData = [self extractFridaServerFromDeb:debData agentData:&agentData];
    if (!binaryData || binaryData.length == 0) {
        _downloadStatus = @"Extraction failed";
        _isDownloading = NO;
        _downloadProgress = -1;
        return NO;
    }

    FMLog(@"Extracted binary: %lu bytes", (unsigned long)binaryData.length);
    if (agentData) {
        FMLog(@"Extracted agent: %lu bytes", (unsigned long)agentData.length);
    }

    _downloadProgress = 0.9;
    _downloadStatus = @"Installing...";

    BOOL success = [self installBinary:binaryData];

    // Also install frida-agent.dylib if extracted
    if (success && agentData && agentData.length > 0) {
        success = [self installAgent:agentData];
    }

    if (success) {
        _downloadProgress = 1.0;
        _downloadStatus = [NSString stringWithFormat:@"Installed v%@", version];
        [[FMFridaServer sharedServer] refreshBinaryPath];
        FMLog(@"SUCCESS: v%@ installed", version);
    } else {
        _downloadStatus = @"Install failed";
    }

    _isDownloading = NO;
    return success;
}

#pragma mark - .deb extraction

- (NSData *)extractFridaServerFromDeb:(NSData *)debData {
    return [self extractFridaServerFromDeb:debData agentData:nil];
}

- (NSData *)extractFridaServerFromDeb:(NSData *)debData agentData:(NSData **)outAgentData {
    const uint8_t *bytes = debData.bytes;
    size_t len = debData.length;

    if (len < 8 || memcmp(bytes, "!<arch>\n", 8) != 0) {
        FMLog(@"ERROR: Not a valid ar archive");
        return nil;
    }

    size_t offset = 8;
    while (offset + 60 <= len) {
        char nameField[17] = {0};
        memcpy(nameField, bytes + offset, 16);

        char sizeField[11] = {0};
        memcpy(sizeField, bytes + offset + 48, 10);

        size_t memberSize = (size_t)atol(sizeField);
        size_t dataStart = offset + 60;

        NSString *name = [[NSString stringWithUTF8String:nameField]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([name hasSuffix:@"/"]) name = [name substringToIndex:name.length - 1];

        FMLog(@"  ar: '%@' (%zu bytes)", name, memberSize);

        if ([name isEqualToString:@"data.tar.xz"] || [name hasPrefix:@"data.tar"]) {
            if (dataStart + memberSize <= len) {
                NSData *dataTarXz = [NSData dataWithBytes:bytes + dataStart length:memberSize];
                return [self extractFridaServerFromTarXz:dataTarXz agentData:outAgentData];
            }
        }

        offset = dataStart + memberSize;
        if (offset % 2 != 0) offset++;
    }

    FMLog(@"ERROR: data.tar not found in .deb");
    return nil;
}

- (NSData *)extractFridaServerFromTarXz:(NSData *)tarXzData {
    return [self extractFridaServerFromTarXz:tarXzData agentData:nil];
}

- (NSData *)extractFridaServerFromTarXz:(NSData *)tarXzData agentData:(NSData **)outAgentData {
    FMLog(@"Decompressing XZ (%lu bytes)...", (unsigned long)tarXzData.length);

    NSData *tarData = [self decompressXZ:tarXzData];
    if (!tarData) {
        FMLog(@"ERROR: XZ decompression failed");
        return nil;
    }

    FMLog(@"Tar: %lu bytes", (unsigned long)tarData.length);

    // Extract both frida-server and frida-agent.dylib
    if (outAgentData) {
        *outAgentData = [self extractFileFromTar:tarData named:@"frida-agent.dylib"];
        if (*outAgentData) {
            FMLog(@"Extracted frida-agent.dylib: %lu bytes", (unsigned long)(*outAgentData).length);
        } else {
            FMLog(@"WARNING: frida-agent.dylib not found in tar");
        }
    }

    return [self extractFileFromTar:tarData named:@"frida-server"];
}

- (NSData *)extractFileFromTar:(NSData *)tarData named:(NSString *)targetName {
    const uint8_t *bytes = tarData.bytes;
    size_t len = tarData.length;
    size_t offset = 0;

    while (offset + 512 <= len) {
        const char *header = (const char *)(bytes + offset);

        BOOL allZero = YES;
        for (int i = 0; i < 512; i++) {
            if (header[i] != 0) { allZero = NO; break; }
        }
        if (allZero) break;

        char nameField[101] = {0};
        memcpy(nameField, header, 100);
        NSString *entryName = [NSString stringWithUTF8String:nameField];

        char prefixField[156] = {0};
        memcpy(prefixField, header + 345, 155);
        if (prefixField[0] != 0) {
            NSString *prefix = [NSString stringWithUTF8String:prefixField];
            entryName = [NSString stringWithFormat:@"%@/%@", prefix, entryName];
        }

        char sizeField[13] = {0};
        memcpy(sizeField, header + 124, 12);
        size_t fileSize = (size_t)strtoul(sizeField, NULL, 8);

        char typeFlag = header[156];
        size_t dataOffset = offset + 512;

        if ((typeFlag == '0' || typeFlag == 0) && fileSize > 0) {
            NSString *lastComponent = [entryName lastPathComponent];
            if ([entryName hasSuffix:targetName] ||
                [lastComponent isEqualToString:targetName]) {
                FMLog(@"Found '%@' (%zu bytes)", entryName, fileSize);
                if (dataOffset + fileSize <= len) {
                    return [NSData dataWithBytes:bytes + dataOffset length:fileSize];
                }
            }
        }

        size_t blocks = (fileSize + 511) / 512;
        offset = dataOffset + (blocks * 512);
    }

    FMLog(@"ERROR: '%@' not found in tar", targetName);
    return nil;
}

#pragma mark - XZ Decompression

- (NSData *)decompressXZ:(NSData *)xzData {
    if (xzData.length < 12) return nil;

    const uint8_t *srcBytes = (const uint8_t *)xzData.bytes;

    if (srcBytes[0] != 0xFD || srcBytes[1] != 0x37 || srcBytes[2] != 0x7A ||
        srcBytes[3] != 0x58 || srcBytes[4] != 0x5A || srcBytes[5] != 0x00) {
        FMLog(@"ERROR: Not XZ format");
        return nil;
    }

    NSData *result = [self tryDecompress:srcBytes length:xzData.length];
    if (result) return result;

    if (xzData.length > 24) {
        result = [self tryDecompress:srcBytes + 12 length:xzData.length - 12];
        if (result) return result;
    }

    if (xzData.length > 16) {
        uint8_t blockHeaderSizeByte = srcBytes[12];
        if (blockHeaderSizeByte > 0) {
            size_t blockHeaderSize = (blockHeaderSizeByte + 1) * 4;
            size_t dataOffset = 12 + blockHeaderSize;
            if (dataOffset < xzData.length) {
                result = [self tryDecompress:srcBytes + dataOffset length:xzData.length - dataOffset - 12];
                if (result) return result;
            }
        }
    }

    FMLog(@"ERROR: All XZ approaches failed");
    return nil;
}

- (NSData *)tryDecompress:(const uint8_t *)src length:(size_t)srcLen {
    size_t dstCapacity = 8 * 1024 * 1024;
    uint8_t *dstBuffer = malloc(dstCapacity);
    if (!dstBuffer) return nil;

    compression_stream stream;
    compression_status status;

    status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZMA);
    if (status != COMPRESSION_STATUS_OK) {
        free(dstBuffer);
        return nil;
    }

    stream.src_ptr = src;
    stream.src_size = srcLen;
    stream.dst_ptr = dstBuffer;
    stream.dst_size = dstCapacity;

    NSMutableData *output = [NSMutableData data];
    BOOL success = NO;

    while (1) {
        status = compression_stream_process(&stream, COMPRESSION_STREAM_FINALIZE);

        size_t produced = stream.dst_ptr - dstBuffer;
        if (produced > 0) {
            [output appendBytes:dstBuffer length:produced];
            stream.dst_ptr = dstBuffer;
            stream.dst_size = dstCapacity;
        }

        if (status == COMPRESSION_STATUS_END) { success = YES; break; }
        else if (status == COMPRESSION_STATUS_ERROR) break;
        if (stream.src_size == 0) break;
    }

    compression_stream_destroy(&stream);
    free(dstBuffer);

    if (success && output.length > 0) return output;
    return nil;
}

#pragma mark - Install Binary

- (BOOL)installBinary:(NSData *)binaryData {
    NSString *installPath = kFMManagedBinaryPath;

    NSString *dir = [installPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    if (![binaryData writeToFile:installPath atomically:YES]) {
        FMLog(@"ERROR: write failed: %@", installPath);
        return NO;
    }

    chmod([installPath UTF8String], 0755);
    chown([installPath UTF8String], 0, 0);

    FMLog(@"Installed to %@", installPath);
    return YES;
}

- (BOOL)installAgent:(NSData *)agentData {
    NSString *installPath = kFMManagedAgentPath;

    NSString *dir = [installPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    if (![agentData writeToFile:installPath atomically:YES]) {
        FMLog(@"ERROR: agent write failed: %@", installPath);
        return NO;
    }

    chmod([installPath UTF8String], 0755);
    chown([installPath UTF8String], 0, 0);

    FMLog(@"Installed agent to %@", installPath);
    return YES;
}

@end
