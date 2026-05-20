#import "FMRootListController.h"
#import "FMSocketClient.h"
#import "FMCommon.h"

#pragma mark - Main Settings Controller

@interface FMRootListController ()
@property (nonatomic, strong) NSTimer *statusTimer;
@property (nonatomic, strong) PSSpecifier *statusSpecifier;
@property (nonatomic, strong) PSSpecifier *portStatusSpecifier;
@property (nonatomic, strong) PSSpecifier *binaryPathSpecifier;
@property (nonatomic, strong) PSSpecifier *versionSpecifier;
@property (nonatomic, strong) PSSpecifier *sourceSpecifier;
@property (nonatomic, copy) NSString *pendingCustomVersion;
@property (nonatomic, strong) NSDictionary *cachedStatus;
@property (nonatomic, strong) PSSpecifier *customVersionSpecifier;
@end

@implementation FMRootListController

- (instancetype)init {
    self = [super init];
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self buildSpecifiers] mutableCopy];
    }
    return _specifiers;
}

- (NSArray *)buildSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];

    // === STATUS GROUP ===
    PSSpecifier *statusGroup = [PSSpecifier groupSpecifierWithName:@"Status"];
    [specs addObject:statusGroup];

    _statusSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Server Status"
                                                     target:self
                                                        set:nil
                                                        get:@selector(getStatusValue:)
                                                     detail:nil
                                                       cell:PSTitleValueCell
                                                       edit:nil];
    [_statusSpecifier setProperty:@"serverStatus" forKey:@"key"];
    [specs addObject:_statusSpecifier];

    _portStatusSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Active Port"
                                                         target:self
                                                            set:nil
                                                            get:@selector(getPortStatusValue:)
                                                         detail:nil
                                                           cell:PSTitleValueCell
                                                           edit:nil];
    [_portStatusSpecifier setProperty:@"activePort" forKey:@"key"];
    [specs addObject:_portStatusSpecifier];

    _binaryPathSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Binary Path"
                                                         target:self
                                                            set:nil
                                                            get:@selector(getBinaryPathValue:)
                                                         detail:nil
                                                           cell:PSTitleValueCell
                                                           edit:nil];
    [_binaryPathSpecifier setProperty:@"binaryPath" forKey:@"key"];
    [specs addObject:_binaryPathSpecifier];

    _versionSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Version"
                                                      target:self
                                                         set:nil
                                                         get:@selector(getVersionValue:)
                                                      detail:nil
                                                        cell:PSTitleValueCell
                                                        edit:nil];
    [_versionSpecifier setProperty:@"version" forKey:@"key"];
    [specs addObject:_versionSpecifier];

    _sourceSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Installed By"
                                                      target:self
                                                         set:nil
                                                         get:@selector(getSourceValue:)
                                                      detail:nil
                                                        cell:PSTitleValueCell
                                                        edit:nil];
    [_sourceSpecifier setProperty:@"source" forKey:@"key"];
    [specs addObject:_sourceSpecifier];

    // === CONFIGURATION GROUP ===
    PSSpecifier *configGroup = [PSSpecifier groupSpecifierWithName:@"Configuration"];
    [configGroup setProperty:@"Changes take effect on next start/restart." forKey:@"footerText"];
    [specs addObject:configGroup];

    PSSpecifier *portSpec = [PSSpecifier preferenceSpecifierNamed:@"Port"
                                                          target:self
                                                             set:@selector(setPortValue:specifier:)
                                                             get:@selector(getPortValue:)
                                                          detail:nil
                                                            cell:PSEditTextCell
                                                            edit:nil];
    [portSpec setProperty:@"Port" forKey:@"key"];
    [portSpec setProperty:@(YES) forKey:@"isNumeric"];
    [portSpec setProperty:@(UIKeyboardTypeNumberPad) forKey:@"keyboardType"];
    [portSpec setProperty:@"27042" forKey:@"placeholder"];
    [specs addObject:portSpec];

    PSSpecifier *localhostSpec = [PSSpecifier preferenceSpecifierNamed:@"USB Only (Block Wi-Fi)"
                                                               target:self
                                                                  set:@selector(setLocalhostValue:specifier:)
                                                                  get:@selector(getLocalhostValue:)
                                                               detail:nil
                                                                 cell:PSSwitchCell
                                                                 edit:nil];
    [localhostSpec setProperty:@"LocalhostOnly" forKey:@"key"];
    [localhostSpec setProperty:@(YES) forKey:@"default"];
    [specs addObject:localhostSpec];

    // === CONTROLS GROUP ===
    PSSpecifier *controlGroup = [PSSpecifier groupSpecifierWithName:@"Controls"];
    [specs addObject:controlGroup];

    PSSpecifier *startSpec = [PSSpecifier preferenceSpecifierNamed:@"Start Frida Server"
                                                           target:self
                                                              set:nil
                                                              get:nil
                                                           detail:nil
                                                             cell:PSButtonCell
                                                             edit:nil];
    startSpec->action = @selector(startServer);
    [specs addObject:startSpec];

    PSSpecifier *stopSpec = [PSSpecifier preferenceSpecifierNamed:@"Stop Frida Server"
                                                          target:self
                                                             set:nil
                                                             get:nil
                                                          detail:nil
                                                            cell:PSButtonCell
                                                            edit:nil];
    stopSpec->action = @selector(stopServer);
    [specs addObject:stopSpec];

    PSSpecifier *restartSpec = [PSSpecifier preferenceSpecifierNamed:@"Restart Frida Server"
                                                             target:self
                                                                set:nil
                                                                get:nil
                                                             detail:nil
                                                               cell:PSButtonCell
                                                               edit:nil];
    restartSpec->action = @selector(restartServer);
    [specs addObject:restartSpec];

    // === VERSION MANAGEMENT GROUP ===
    PSSpecifier *versionGroup = [PSSpecifier groupSpecifierWithName:@"Version Management"];
    [versionGroup setProperty:@"Download and install frida-server directly from GitHub. The server will be stopped during installation." forKey:@"footerText"];
    [specs addObject:versionGroup];

    PSSpecifier *browseSpec = [PSSpecifier preferenceSpecifierNamed:@"Browse Latest Versions"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:[FMVersionListController class]
                                                              cell:PSLinkCell
                                                              edit:nil];
    [specs addObject:browseSpec];

    _customVersionSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Custom Version"
                                                                   target:self
                                                                      set:@selector(setCustomVersion:specifier:)
                                                                      get:@selector(getCustomVersion:)
                                                                   detail:nil
                                                                     cell:PSEditTextCell
                                                                     edit:nil];
    [_customVersionSpecifier setProperty:@"customVersion" forKey:@"key"];
    [_customVersionSpecifier setProperty:@"e.g. 16.1.4" forKey:@"placeholder"];
    [specs addObject:_customVersionSpecifier];

    PSSpecifier *installCustomSpec = [PSSpecifier preferenceSpecifierNamed:@"Install Custom Version"
                                                                   target:self
                                                                      set:nil
                                                                      get:nil
                                                                   detail:nil
                                                                     cell:PSButtonCell
                                                                     edit:nil];
    installCustomSpec->action = @selector(installCustomVersion);
    [specs addObject:installCustomSpec];

    // === MAINTENANCE GROUP ===
    PSSpecifier *maintGroup = [PSSpecifier groupSpecifierWithName:@"Maintenance"];
    [specs addObject:maintGroup];

    PSSpecifier *historySpec = [PSSpecifier preferenceSpecifierNamed:@"Download History"
                                                             target:self
                                                                set:nil
                                                                get:nil
                                                             detail:[FMDownloadHistoryController class]
                                                               cell:PSLinkCell
                                                               edit:nil];
    [specs addObject:historySpec];

    PSSpecifier *uninstallSpec = [PSSpecifier preferenceSpecifierNamed:@"Uninstall Frida Server"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSButtonCell
                                                                 edit:nil];
    uninstallSpec->action = @selector(uninstallServer);
    [specs addObject:uninstallSpec];

    PSSpecifier *logSpec = [PSSpecifier preferenceSpecifierNamed:@"View Log"
                                                         target:self
                                                            set:nil
                                                            get:nil
                                                         detail:nil
                                                           cell:PSButtonCell
                                                           edit:nil];
    logSpec->action = @selector(viewLog);
    [specs addObject:logSpec];

    return specs;
}

#pragma mark - Status Getters

- (id)getStatusValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    if (!status) return @"Daemon Offline";
    if ([status[@"stopping"] boolValue]) return @"Stopping...";
    BOOL installed = [status[@"installed"] boolValue];
    if (!installed) return @"Not Installed";
    BOOL running = [status[@"running"] boolValue];
    return running ? @"Running" : @"Stopped";
}

- (id)getPortStatusValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    if (!status) return @"\u2014";
    NSInteger port = [status[@"port"] integerValue];
    return port > 0 ? [NSString stringWithFormat:@"%ld", (long)port] : @"\u2014";
}

- (id)getBinaryPathValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    if (!status) return @"Unknown";
    NSString *path = status[@"binaryPath"];
    if (!path || [path isEqualToString:@"not found"]) return @"Not Found";
    return path;
}

- (id)getVersionValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    if (!status) return @"Unknown";
    NSString *version = status[@"version"];
    if (!version || [version isEqualToString:@"unknown"]) return @"Unknown";
    return version;
}

- (id)getSourceValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    if (!status) return @"\u2014";
    NSString *source = status[@"source"];
    if (!source || [source isEqualToString:@"none"]) return @"\u2014";
    return source;
}

#pragma mark - Config Getters/Setters

- (id)getPortValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    NSDictionary *config = status[@"_config"];
    if (!config) return @"27042";
    return [NSString stringWithFormat:@"%ld", (long)[config[kFMConfigKeyPort] integerValue]];
}

- (void)setPortValue:(id)value specifier:(PSSpecifier *)specifier {
    NSInteger port = [value integerValue];
    if (port < 1 || port > 65535) return;
    NSString *cmd = [NSString stringWithFormat:@"%@:%ld", kFMCommandSetPort, (long)port];
    [[FMSocketClient sharedClient] sendCommand:cmd completion:^(NSString *response) {
        NSDictionary *status = self.cachedStatus;
        if (status && [status[@"running"] boolValue]) {
            [self promptRestartForPortChange];
        }
    }];
}

- (id)getLocalhostValue:(PSSpecifier *)specifier {
    NSDictionary *status = self.cachedStatus;
    NSDictionary *config = status[@"_config"];
    if (!config) return @(YES);
    return config[kFMConfigKeyLocalhostOnly] ?: @(YES);
}

- (void)setLocalhostValue:(id)value specifier:(PSSpecifier *)specifier {
    BOOL localhost = [value boolValue];
    NSString *cmd = [NSString stringWithFormat:@"%@:%d", kFMCommandSetLocalhost, localhost ? 1 : 0];
    [[FMSocketClient sharedClient] sendCommand:cmd completion:nil];
}

#pragma mark - Custom Version

- (id)getCustomVersion:(PSSpecifier *)specifier {
    return self.pendingCustomVersion ?: @"";
}

- (void)setCustomVersion:(id)value specifier:(PSSpecifier *)specifier {
    self.pendingCustomVersion = value;
}

#pragma mark - Actions

- (void)startServer {
    NSDictionary *status = self.cachedStatus;
    if (status && ![status[@"installed"] boolValue]) {
        [self showAlertWithTitle:@"Not Installed" message:@"No frida-server binary found. Use Version Management to download one."];
        return;
    }
    [[FMSocketClient sharedClient] sendCommand:kFMCommandStart completion:^(NSString *response) {
        if (![response hasPrefix:@"OK"]) {
            [self showAlertWithTitle:@"Error" message:response ?: @"Failed to connect to daemon"];
        }
        [self refreshStatusAsync];
    }];
}

- (void)stopServer {
    [[FMSocketClient sharedClient] sendCommand:kFMCommandStop completion:^(NSString *response) {
        if (![response hasPrefix:@"OK"]) {
            [self showAlertWithTitle:@"Error" message:response ?: @"Failed to connect to daemon"];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self refreshStatusAsync];
        });
    }];
}

- (void)restartServer {
    NSDictionary *status = self.cachedStatus;
    if (status && ![status[@"installed"] boolValue]) {
        [self showAlertWithTitle:@"Not Installed" message:@"No frida-server binary found. Use Version Management to download one."];
        return;
    }
    [[FMSocketClient sharedClient] sendCommand:kFMCommandRestart completion:^(NSString *response) {
        if (![response hasPrefix:@"OK"]) {
            [self showAlertWithTitle:@"Error" message:response ?: @"Failed to connect to daemon"];
        }
        [self refreshStatusAsync];
    }];
}

- (void)uninstallServer {
    NSDictionary *status = self.cachedStatus;
    if (status && ![status[@"installed"] boolValue]) {
        [self showAlertWithTitle:@"Not Installed" message:@"No frida-server binary is installed."];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uninstall Frida Server"
                                                                  message:@"This will stop and remove the managed frida-server binary. Are you sure?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Uninstall"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[FMSocketClient sharedClient] sendCommand:kFMCommandUninstall completion:^(NSString *response) {
            if ([response hasPrefix:@"OK"]) {
                [self showAlertWithTitle:@"Uninstalled" message:@"frida-server has been removed."];
            } else {
                [self showAlertWithTitle:@"Error" message:response ?: @"Failed to uninstall"];
            }
            [self refreshStatusAsync];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewLog {
    [[FMSocketClient sharedClient] sendCommand:kFMCommandGetLog completion:^(NSString *response) {
        NSString *log = response ?: @"(unable to read log)";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Daemon Log"
                                                                      message:log
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)installCustomVersion {
    [self.view endEditing:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *version = self.pendingCustomVersion;
        if (!version || version.length == 0) {
            [self showAlertWithTitle:@"Error" message:@"Please enter a version number (e.g. 16.1.4)"];
            return;
        }
        [self confirmAndDownloadVersion:version];
    });
}

#pragma mark - Download Flow

- (void)confirmAndDownloadVersion:(NSString *)version {
    // Check if frida is installed via a package manager
    NSDictionary *status = self.cachedStatus;
    NSString *source = status[@"source"];
    if ([source isEqualToString:@"Package Manager"]) {
        [self showAlertWithTitle:@"Cannot Install"
                         message:@"Frida is currently installed via a package manager (Sileo, Zebra, Cydia, etc.).\n\nPlease uninstall it from your package manager first, then use FridaManager to install the version you want."];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Download Frida Server"
                                                                  message:[NSString stringWithFormat:@"Download and install frida-server v%@?\n\nThe running server will be stopped.", version]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Download"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [self beginDownloadVersion:version];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)beginDownloadVersion:(NSString *)version {
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"Downloading..."
                                                                          message:[NSString stringWithFormat:@"Installing frida-server v%@\n\nPlease wait...", version]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    [[FMSocketClient sharedClient] sendCommand:kFMCommandStop completion:^(NSString *stopResp) {
        NSString *cmd = [NSString stringWithFormat:@"%@:%@", kFMCommandDownload, version];
        [[FMSocketClient sharedClient] sendCommand:cmd completion:^(NSString *response) {
            if (![response hasPrefix:@"OK"]) {
                NSString *errMsg = response ?: @"Failed to start download";
                if ([response containsString:@"PKGMGR"]) {
                    errMsg = @"Frida is installed via a package manager. Please uninstall it from your package manager first.";
                }
                [progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlertWithTitle:@"Error" message:errMsg];
                }];
                return;
            }

            __block NSTimer *pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                [[FMSocketClient sharedClient] sendCommand:kFMCommandDownloadProgress completion:^(NSString *resp) {
                    if (!resp) return;
                    NSData *data = [resp dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *progress = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (!progress) return;

                    BOOL downloading = [progress[@"downloading"] boolValue];
                    NSString *status = progress[@"status"];

                    progressAlert.message = [NSString stringWithFormat:@"Installing frida-server v%@\n\n%@", version, status];

                    if (!downloading) {
                        [pollTimer invalidate];
                        [progressAlert dismissViewControllerAnimated:YES completion:^{
                            if ([status hasPrefix:@"Installed"]) {
                                [self showAlertWithTitle:@"Success" message:[NSString stringWithFormat:@"frida-server v%@ installed successfully!", version]];
                            } else if (![status isEqualToString:@"Idle"]) {
                                [self showAlertWithTitle:@"Failed" message:status];
                            }
                            [self refreshStatusAsync];
                        }];
                    }
                }];
            }];
        }];
    }];
}

#pragma mark - Async Status Refresh

- (void)refreshStatusAsync {
    [[FMSocketClient sharedClient] sendCommand:kFMCommandStatus completion:^(NSString *statusResp) {
        NSDictionary *status = nil;
        if (statusResp) {
            NSData *data = [statusResp dataUsingEncoding:NSUTF8StringEncoding];
            status = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }

        [[FMSocketClient sharedClient] sendCommand:kFMCommandGetConfig completion:^(NSString *configResp) {
            NSDictionary *config = nil;
            if (configResp) {
                NSData *data = [configResp dataUsingEncoding:NSUTF8StringEncoding];
                config = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            }

            NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:status ?: @{}];
            if (config) merged[@"_config"] = config;
            self.cachedStatus = merged;

            [self reloadSpecifier:self->_statusSpecifier animated:NO];
            [self reloadSpecifier:self->_portStatusSpecifier animated:NO];
            [self reloadSpecifier:self->_binaryPathSpecifier animated:NO];
            [self reloadSpecifier:self->_versionSpecifier animated:NO];
            [self reloadSpecifier:self->_sourceSpecifier animated:NO];
        }];
    }];
}

#pragma mark - Helpers

- (void)promptRestartForPortChange {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Port Changed"
                                                                  message:@"Restart frida-server now with the new port?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart Now"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
        [[FMSocketClient sharedClient] sendCommand:kFMCommandRestart completion:^(NSString *resp) {
            [self refreshStatusAsync];
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - View Lifecycle

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshStatusAsync];
    _statusTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                   target:self
                                                 selector:@selector(refreshStatusAsync)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_statusTimer invalidate];
    _statusTimer = nil;
}

@end

#pragma mark - Version List Controller

@interface FMVersionListController ()
@property (nonatomic, assign) BOOL hasStartedLoading;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) int pollCount;
@property (nonatomic, strong) NSMutableArray *currentSpecs;
@end

@implementation FMVersionListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Latest Versions"];
        [group setProperty:@"Fetching from GitHub..." forKey:@"footerText"];
        [specs addObject:group];
        _specifiers = specs;

        if (!_hasStartedLoading) {
            _hasStartedLoading = YES;
            _pollCount = 0;
            // Delay to let the view finish loading first
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self fetchVersions];
            });
        }
    }
    return _specifiers;
}

- (void)fetchVersions {
    if (_isLoading) return;
    _isLoading = YES;

    [[FMSocketClient sharedClient] sendCommand:kFMCommandListVersions completion:^(NSString *response) {
        if (!response) {
            [self updateWithVersions:nil error:@"Failed to connect to daemon."];
            return;
        }

        if ([response hasPrefix:@"WAIT"]) {
            self->_pollCount++;
            if (self->_pollCount < 15) {
                self->_isLoading = NO;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self fetchVersions];
                });
            } else {
                [self updateWithVersions:nil error:@"Timed out. Check View Log."];
            }
            return;
        }

        if ([response hasPrefix:@"ERR"]) {
            [self updateWithVersions:nil error:response];
            return;
        }

        NSData *data = [response dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *versions = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([versions isKindOfClass:[NSArray class]] && versions.count > 0) {
            [self updateWithVersions:versions error:nil];
        } else {
            [self updateWithVersions:nil error:@"No versions found. Check View Log."];
        }
    }];
}

- (void)updateWithVersions:(NSArray *)versions error:(NSString *)error {
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Latest Versions"];

    if (versions && versions.count > 0) {
        [group setProperty:@"Tap a version to download and install." forKey:@"footerText"];
        [specs addObject:group];

        for (id item in versions) {
            NSString *version = nil;
            if ([item isKindOfClass:[NSString class]]) version = item;
            else if ([item isKindOfClass:[NSDictionary class]]) version = item[@"version"];
            if (!version) continue;

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:version
                                                              target:self
                                                                 set:nil
                                                                 get:nil
                                                              detail:nil
                                                                cell:PSButtonCell
                                                                edit:nil];
            spec->action = @selector(versionTapped:);
            [spec setProperty:version forKey:@"versionTag"];
            [specs addObject:spec];
        }
    } else {
        [group setProperty:(error ?: @"Failed to fetch versions.") forKey:@"footerText"];
        [specs addObject:group];

        PSSpecifier *retrySpec = [PSSpecifier preferenceSpecifierNamed:@"Retry"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSButtonCell
                                                                 edit:nil];
        retrySpec->action = @selector(retryFetch);
        [specs addObject:retrySpec];
    }

    _isLoading = NO;

    // Remove all existing specifiers one by one, then insert new ones
    // This avoids reloadSpecifiers which triggers the getter loop
    NSInteger oldCount = [self numberOfGroups] > 0 ? (NSInteger)_specifiers.count : 0;
    for (NSInteger i = oldCount - 1; i >= 0; i--) {
        [self removeSpecifierAtIndex:i animated:NO];
    }
    for (NSInteger i = 0; i < (NSInteger)specs.count; i++) {
        [self insertSpecifier:specs[i] atIndex:i animated:NO];
    }
}

- (void)retryFetch {
    _pollCount = 0;
    _isLoading = NO;
    _hasStartedLoading = NO;

    // Reset specifiers to loading state
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Latest Versions"];
    [group setProperty:@"Fetching from GitHub..." forKey:@"footerText"];
    [specs addObject:group];

    NSInteger oldCount = (NSInteger)_specifiers.count;
    for (NSInteger i = oldCount - 1; i >= 0; i--) {
        [self removeSpecifierAtIndex:i animated:NO];
    }
    for (NSInteger i = 0; i < (NSInteger)specs.count; i++) {
        [self insertSpecifier:specs[i] atIndex:i animated:NO];
    }

    _hasStartedLoading = YES;
    [self fetchVersions];
}

- (void)versionTapped:(PSSpecifier *)specifier {
    NSString *version = [specifier propertyForKey:@"versionTag"];
    if (!version) return;

    // First check source via a quick status query
    [[FMSocketClient sharedClient] sendCommand:kFMCommandStatus completion:^(NSString *resp) {
        NSDictionary *status = nil;
        if (resp) {
            NSData *data = [resp dataUsingEncoding:NSUTF8StringEncoding];
            status = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        NSString *source = status[@"source"];
        if ([source isEqualToString:@"Package Manager"]) {
            [self showAlertWithTitle:@"Cannot Install"
                             message:@"Frida is currently installed via a package manager (Sileo, Zebra, Cydia, etc.).\n\nPlease uninstall it from your package manager first, then use FridaManager to install the version you want."];
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Download Frida Server"
                                                                      message:[NSString stringWithFormat:@"Download and install frida-server v%@?\n\nThe running server will be stopped.", version]
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Download"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            [self beginDownloadVersion:version];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

- (void)beginDownloadVersion:(NSString *)version {
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"Downloading..."
                                                                          message:[NSString stringWithFormat:@"Installing frida-server v%@\n\nPlease wait...", version]
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:progressAlert animated:YES completion:nil];

    [[FMSocketClient sharedClient] sendCommand:kFMCommandStop completion:^(NSString *stopResp) {
        NSString *cmd = [NSString stringWithFormat:@"%@:%@", kFMCommandDownload, version];
        [[FMSocketClient sharedClient] sendCommand:cmd completion:^(NSString *response) {
            if (![response hasPrefix:@"OK"]) {
                NSString *errMsg = response ?: @"Failed to start download";
                if ([response containsString:@"PKGMGR"]) {
                    errMsg = @"Frida is installed via a package manager. Please uninstall it from your package manager first.";
                }
                [progressAlert dismissViewControllerAnimated:YES completion:^{
                    [self showAlertWithTitle:@"Error" message:errMsg];
                }];
                return;
            }

            __block NSTimer *pollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
                [[FMSocketClient sharedClient] sendCommand:kFMCommandDownloadProgress completion:^(NSString *resp) {
                    if (!resp) return;
                    NSData *data = [resp dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *progress = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if (!progress) return;

                    BOOL downloading = [progress[@"downloading"] boolValue];
                    NSString *status = progress[@"status"];

                    progressAlert.message = [NSString stringWithFormat:@"Installing frida-server v%@\n\n%@", version, status];

                    if (!downloading) {
                        [pollTimer invalidate];
                        [progressAlert dismissViewControllerAnimated:YES completion:^{
                            if ([status hasPrefix:@"Installed"]) {
                                [self showAlertWithTitle:@"Success" message:[NSString stringWithFormat:@"frida-server v%@ installed successfully!", version]];
                            } else if (![status isEqualToString:@"Idle"]) {
                                [self showAlertWithTitle:@"Failed" message:status];
                            }
                        }];
                    }
                }];
            }];
        }];
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)title {
    return @"Latest Versions";
}

@end

#pragma mark - Download History Controller

@implementation FMDownloadHistoryController {
    BOOL _hasStartedLoading;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self buildEmptySpecifiers] mutableCopy];
        if (!_hasStartedLoading) {
            _hasStartedLoading = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self loadHistory];
            });
        }
    }
    return _specifiers;
}

- (NSArray *)buildEmptySpecifiers {
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Downloaded Versions"];
    [group setProperty:@"Loading..." forKey:@"footerText"];
    [specs addObject:group];
    return specs;
}

- (void)loadHistory {
    [[FMSocketClient sharedClient] sendCommand:kFMCommandGetHistory completion:^(NSString *response) {
        NSArray *history = nil;
        if (response && ![response hasPrefix:@"ERR"]) {
            NSData *data = [response dataUsingEncoding:NSUTF8StringEncoding];
            history = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateWithHistory:([history isKindOfClass:[NSArray class]] ? history : nil)];
        });
    }];
}

- (void)updateWithHistory:(NSArray *)history {
    // Remove all existing specifiers one by one
    NSInteger count = _specifiers.count;
    for (NSInteger i = count - 1; i >= 0; i--) {
        [self removeSpecifierAtIndex:i animated:NO];
    }

    NSInteger insertIdx = 0;

    if (history.count > 0) {
        PSSpecifier *histGroup = [PSSpecifier groupSpecifierWithName:@"Downloaded Versions"];
        [histGroup setProperty:[NSString stringWithFormat:@"%lu version(s) downloaded.", (unsigned long)history.count] forKey:@"footerText"];
        [self insertSpecifier:histGroup atIndex:insertIdx++ animated:NO];

        for (NSDictionary *entry in history) {
            NSString *version = entry[@"version"] ?: @"?";
            NSString *date = entry[@"date"] ?: @"";

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"v%@", version]
                                                              target:self
                                                                 set:nil
                                                                 get:@selector(getDateForEntry:)
                                                              detail:nil
                                                                cell:PSTitleValueCell
                                                                edit:nil];
            [spec setProperty:date forKey:@"entryDate"];
            [self insertSpecifier:spec atIndex:insertIdx++ animated:NO];
        }

        PSSpecifier *clearGroup = [PSSpecifier groupSpecifierWithName:nil];
        [self insertSpecifier:clearGroup atIndex:insertIdx++ animated:NO];

        PSSpecifier *clearSpec = [PSSpecifier preferenceSpecifierNamed:@"Clear History"
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSButtonCell
                                                                 edit:nil];
        clearSpec->action = @selector(clearHistory);
        [self insertSpecifier:clearSpec atIndex:insertIdx++ animated:NO];
    } else {
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Downloaded Versions"];
        [group setProperty:@"No downloads yet." forKey:@"footerText"];
        [self insertSpecifier:group atIndex:insertIdx animated:NO];
    }
}

- (id)getDateForEntry:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"entryDate"] ?: @"";
}

- (void)clearHistory {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear History"
                                                                  message:@"Remove all download history entries?"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        [[FMSocketClient sharedClient] sendCommand:kFMCommandClearHistory completion:^(NSString *response) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateWithHistory:nil];
            });
        }];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)title {
    return @"Download History";
}

@end
