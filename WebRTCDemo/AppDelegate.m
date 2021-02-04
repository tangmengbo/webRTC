//
//  AppDelegate.m
//  WebRTCDemo
//
//  Created by tang bo on 2021/1/13.
//

#import "AppDelegate.h"
#import "VideoViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    VideoViewController * videoVC = [[VideoViewController alloc] init];
    self.window.rootViewController = videoVC;

    return YES;
}




@end
