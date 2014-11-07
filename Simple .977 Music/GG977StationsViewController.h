//
//  GG977StationsViewController.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GG977StationInfo.h"

@protocol GG977StationsViewControllerDelegate <NSObject>

- (void)setPlayerStationInfo:(GG977StationInfo *)info;
- (void)transitionFromView:(UIView *)fromView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options;

@end

@interface GG977StationsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) id<GG977StationsViewControllerDelegate> delegate;

@end
