//
//  GG977StationsViewController.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "GG977StationInfo.h"

@class GG977StationInfo;
@class GG977StationsProvider;
@class GG977StationsViewController;

@protocol GG977StationsViewControllerDelegate <NSObject>

- (void)stationsViewController:(GG977StationsViewController *)stationsViewController didSelectStation:(GG977StationInfo *)stationInfo;

@end

@interface GG977StationsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) id<GG977StationsViewControllerDelegate> delegate;
@property (nonatomic, strong) GG977StationsProvider *stationsProvider;

@end
