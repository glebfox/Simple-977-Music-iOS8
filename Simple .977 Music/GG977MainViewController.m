//
//  GG977MainViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 06.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977MainViewController.h"

@interface GG977MainViewController ()

@property (weak, nonatomic) GG977PlayerViewController *playerViewController;
@property (weak, nonatomic) GG977StationsViewController *stationsViewController;

@end

@implementation GG977MainViewController

- (id)init {
    if ((self = [super init])) {
        [self gg977MasterViewControllerInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self gg977MasterViewControllerInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        [self gg977MasterViewControllerInit];
    }
    return self;
}

- (void)gg977MasterViewControllerInit {
//    UINavigationController *nav = [self.viewControllers objectAtIndex:0];
//    _stationsViewController = (GG977StationsViewController *)nav.topViewController;
//    
//    nav = [self.viewControllers objectAtIndex:1];
//    _playerViewController = (GG977PlayerViewController *)nav.topViewController;

    for (UIViewController *child in self.viewControllers) {
        UIViewController *controller = child;
        if ([controller class] == [UINavigationController class]) {
            controller = ((UINavigationController *)controller).topViewController;
        }
        
        if ([controller class] == [GG977PlayerViewController class]) {
            _playerViewController = (GG977PlayerViewController *)controller;
        }
        
        if ([controller class] == [GG977StationsViewController class]) {
            _stationsViewController = (GG977StationsViewController *)controller;
        }
    }
    
    if (_stationsViewController) {
        _stationsViewController.delegate = self;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - GG977StationsViewControllerDelegate

- (void)setPlayerStationInfo:(GG977StationInfo *)info {
    [self.playerViewController setStationInfo:info];
}

- (void)transitionFromView:(UIView *)fromView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options {
    [UIView transitionFromView:fromView
                        toView:self.playerViewController.view
                      duration:duration
                       options: options
                    completion:^(BOOL finished) {
                        if (finished) {
                            self.selectedIndex = 1;
                        }
                    }];
}

@end
