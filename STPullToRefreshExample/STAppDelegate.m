//  Copyright (c) 2013 Scott Talbot. All rights reserved.

#import "STAppDelegate.h"
#import "STViewController.h"


@implementation STAppDelegate

- (void)setWindow:(UIWindow *)window {
    _window = window;
    [_window makeKeyAndVisible];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UIScreen * const mainScreen = [UIScreen mainScreen];
    UIWindow * const window = [[UIWindow alloc] initWithFrame:mainScreen.applicationFrame];

    STViewController * const vc = [[STViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController * const nc = [[UINavigationController alloc] initWithRootViewController:vc];
    window.rootViewController = nc;

    self.window = window;

    return YES;
}

@end
