//
//  GG977PlayStationViewController.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GG977StationInfo.h"
#import "AppDelegate.h"
#import "GG977AudioStreamPlayer.h"

@interface GG977PlayerViewController : UIViewController <AppRemoteControlDelegate, GG977AudioStreamPlayerDelegate>

@property (strong, nonatomic) GG977StationInfo *stationInfo;

@end
