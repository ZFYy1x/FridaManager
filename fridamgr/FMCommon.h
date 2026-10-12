#ifndef FMCOMMON_H
#define FMCOMMON_H

#import <Foundation/Foundation.h>

// Dopamine 2 (roothide) jailbreak root is /var/jb. We define ROOT_PATH_NS locally
// instead of relying on external libroot/libroothide so the package links cleanly
// under roothide/theos. Adjacent NSString literals are concatenated at compile time,
// which keeps these usable in file-scope constant initializers.
#define ROOT_PATH_NS(path) (@"/var/jb" path)

#define kFMPreferencesPlistPath @"/var/mobile/Library/Preferences/com.b1tbreaker.fridamanager.plist"
#define kFMSocketPath @"/var/run/fridamgr.sock"

#define kFMDefaultPort 27042
#define kFMDefaultListenAddress @"127.0.0.1"

#define kFMLibSandyExtension "com.b1tbreaker.fridamanager.socket"

#define kFMConfigKeyPort @"Port"
#define kFMConfigKeyListenAddress @"ListenAddress"
#define kFMConfigKeyLocalhostOnly @"LocalhostOnly"

// Commands
#define kFMCommandStart @"START"
#define kFMCommandStop @"STOP"
#define kFMCommandRestart @"RESTART"
#define kFMCommandStatus @"STATUS"
#define kFMCommandGetConfig @"GETCONFIG"
#define kFMCommandSetPort @"SETPORT"
#define kFMCommandSetLocalhost @"SETLOCALHOST"
#define kFMCommandListVersions @"LISTVERSIONS"
#define kFMCommandDownload @"DOWNLOAD"
#define kFMCommandDownloadProgress @"DLPROGRESS"
#define kFMCommandGetVersion @"GETVERSION"
#define kFMCommandUninstall @"UNINSTALL"
#define kFMCommandGetLog @"GETLOG"
#define kFMCommandGetHistory @"GETHISTORY"
#define kFMCommandClearHistory @"CLEARHISTORY"

// Managed binary install path. frida-ios-stealth (our frida source) installs the
// server at /usr/sbin, and its server resolves the agent via ../lib/frida-1.0, so
// we keep our own copy at the same place to stay consistent.
#define kFMManagedBinaryPath ROOT_PATH_NS(@"/usr/sbin/frida-server")

// Managed agent dylib install path (needed for spawn/inject).
// frida-ios-stealth's server looks for the agent at ../lib/frida-1.0 relative to
// its own dir, i.e. /usr/lib/frida-1.0/frida-agent.dylib — NOT /usr/lib/frida.
#define kFMManagedAgentPath ROOT_PATH_NS(@"/usr/lib/frida-1.0/frida-agent.dylib")

// Sileo LaunchDaemon label
#define kFMSileoFridaLabel @"re.frida.server"

// Search paths for frida-server binary
#define kFMFridaServerSearchPaths @[ \
    ROOT_PATH_NS(@"/usr/sbin/frida-server"), \
    ROOT_PATH_NS(@"/usr/local/sbin/frida-server"), \
    ROOT_PATH_NS(@"/usr/bin/frida-server"), \
    ROOT_PATH_NS(@"/usr/local/bin/frida-server") \
]

// GitHub Atom feed (lightweight, no API rate limit) — our roothide stealth frida fork
#define kFMGitHubAtomURL @"https://github.com/ZFYy1x/frida-ios-stealth/releases.atom"
#define kFMGitHubReleasesPerPage 100

// Log file path
#define kFMLogPath @"/var/tmp/fridamgr.log"

// Download history file (separate from preferences to avoid cfprefsd conflicts)
#define kFMHistoryPath @"/var/mobile/Library/com.b1tbreaker.fridamanager.history.plist"

#endif
