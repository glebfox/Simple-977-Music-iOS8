//
//  AppDelegate.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
}

#pragma mark - 

- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent {
    if ([self.delegate respondsToSelector:@selector(applicationReceivedRemoteControlWithEvent:)]) {
        [self.delegate applicationReceivedRemoteControlWithEvent:receivedEvent];
    }
}

@end
