//
//  GG977MainViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 06.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977MainViewController.h"
#import "GG977PlayerViewController.h"
#import "GG977DataModel.h"

@interface GG977MainViewController ()

@property (weak, nonatomic) GG977PlayerViewController *playerViewController;
@property (weak, nonatomic) GG977StationsViewController *stationsViewController;

@end

@implementation GG977MainViewController {
    int _playerViewControllerIndex;
}

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
    
    for (int i = 0; i < [self.viewControllers count]; i++) {
        UIViewController *controller = self.viewControllers[i];
        
        if ([controller class] == [UINavigationController class]) {
            controller = ((UINavigationController *)controller).topViewController;
        }
        
        if ([controller class] == [GG977PlayerViewController class]) {
            _playerViewController = (GG977PlayerViewController *)controller;
            _playerViewControllerIndex = i;
        }
        
        if ([controller class] == [GG977StationsViewController class]) {
            _stationsViewController = (GG977StationsViewController *)controller;
        }
    }
    
    if (_stationsViewController) {
        _stationsViewController.delegate = self;
        _stationsViewController.dataModel = [GG977DataModel new];
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

- (void)stationsViewController:(GG977StationsViewController *)stationsViewController didSelectStation:(GG977StationInfo *)stationInfo {
    
    if (self.playerViewController != nil) {
        [self.playerViewController setStationInfo:stationInfo];
        
//        CATransition *transition = [CATransition animation];
//        transition.type = kCATransitionFade;
//        transition.duration = 1;
//        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
//        
//        self.selectedIndex = _playerViewControllerIndex;
//        
//        [self.view.layer addAnimation:transition forKey:nil];
    }
}

//- (void)transitionFromView:(UIView *)fromView duration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options {
//    [UIView transitionFromView:fromView
//                        toView:self.playerViewController.view
//                      duration:duration
//                       options: options
//                    completion:^(BOOL finished) {
//                        if (finished) {
//                            self.selectedIndex = 1;
//                        }
//                    }];
//    
//
//}

@end
