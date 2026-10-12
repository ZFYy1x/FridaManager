#import <UIKit/UIKit.h>
#import "FMRootListController.h"

#pragma mark - App Delegate

@interface FMAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation FMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	(void)launchOptions;

	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.window.backgroundColor = [UIColor systemBackgroundColor];

	FMRootListController *rootController = [[FMRootListController alloc] init];
	rootController.title = @"Frida 管理器";

	UINavigationController *navigationController =
		[[UINavigationController alloc] initWithRootViewController:rootController];

	if (@available(iOS 13.0, *)) {
		UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
		[appearance configureWithOpaqueBackground];
		navigationController.navigationBar.standardAppearance = appearance;
		navigationController.navigationBar.scrollEdgeAppearance = appearance;
	}

	self.window.rootViewController = navigationController;
	[self.window makeKeyAndVisible];
	return YES;
}

@end

#pragma mark - Entry Point

int main(int argc, char *argv[]) {
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([FMAppDelegate class]));
	}
}
