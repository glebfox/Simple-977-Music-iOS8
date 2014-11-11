//
//  AppDelegate.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AppRemoteControlDelegate <NSObject>

- (void)applicationReceivedRemoteControlWithEvent:(UIEvent *)receivedEvent;

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, weak) id<AppRemoteControlDelegate> delegate;

@end

