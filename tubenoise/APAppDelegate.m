//
//  APAppDelegate.m
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import "APAppDelegate.h"
#import "APHomeViewController.h"

@implementation APAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.rootViewController = [APHomeViewController new];

    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (CMMotionManager *)sharedMotionManager {
    static CMMotionManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[CMMotionManager alloc] init];
    });
    return sharedManager;
}

@end
