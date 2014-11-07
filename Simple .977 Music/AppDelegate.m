//
//  AppDelegate.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "GG977StationsCollection.h"
#import "GG977StationsViewController.h"
#import "GG977PlayerViewController.h"
#import "GG977MainViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
//    UIViewController *root = self.window.rootViewController;
//    if ([root class] == [UITabBarController class]) {
//        UITabBarController *tabBar = (UITabBarController *)root;
//        UIViewController *controller = [tabBar.viewControllers objectAtIndex:0];
//        if ([controller class] == [UINavigationController class]) {
//            UINavigationController *navController = (UINavigationController *)controller;
//            controller = navController.topViewController;
//            if ([controller class] == [GG977StationsViewController class]) {
//                GG977StationsViewController *master = (GG977StationsViewController *)controller;
//                [master setItemsToDisplay:[[GG977StationsCollection sharedInstance] allStations]];
//            }
//        }
//    }
    
    // Turn on remote control event delivery
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    NSLog(@"applicationWillResignActive");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    NSLog(@"applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSLog(@"applicationWillTerminate");
//    UIViewController *root = self.window.rootViewController;
//    if ([root class] == [GG977MainViewController class]) {
//        UITabBarController *tabBar = (UITabBarController *)root;
//        UIViewController *controller = [tabBar.viewControllers objectAtIndex:1];
//        if ([controller class] == [UINavigationController class]) {
//            UINavigationController *navController = (UINavigationController *)controller;
//            controller = navController.topViewController;
//            if ([controller class] == [GG977PlayerViewController class]) {
//                GG977PlayerViewController *player = (GG977PlayerViewController *)controller;
//                NSLog(@"%@", player);
//                [[NSNotificationCenter defaultCenter] removeObserver:player
//                                                                name:AVAudioSessionInterruptionNotification
//                                                              object:[AVAudioSession sharedInstance]];
//                
                // Turn off remote control event delivery
                [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
//
//                // Resign as first responder
//                [player resignFirstResponder];
//            }
//        }
//    }
}

@end
