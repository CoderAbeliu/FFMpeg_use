//
//  AppDelegate.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    ViewController *viewVC = [[ViewController alloc] init];
    self.window.rootViewController = viewVC;
    [self.window makeKeyAndVisible];
    return YES;
}



@end
