//
//  GG977StationsViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationsViewController.h"
#import "GG977StationsCollection.h"
#import "GG977PlayerViewController.h"

@interface GG977StationsViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation GG977StationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.itemsToDisplay = [[GG977StationsCollection sharedInstance] allStations];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return self.itemsToDisplay.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentider = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentider forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [self.itemsToDisplay[indexPath.row] title];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UIView * fromView = self.tabBarController.selectedViewController.view;
    UIView * toView = [[self.tabBarController.viewControllers objectAtIndex:1] view];
    
    UIViewController *controller = [self.tabBarController.viewControllers objectAtIndex:1];
    if ([controller class] == [UINavigationController class]) {
        UINavigationController *navController = (UINavigationController *)controller;
        controller = navController.topViewController;
        if ([controller class] == [GG977PlayerViewController class]) {
            GG977PlayerViewController *player = (GG977PlayerViewController *)controller;
            [player setStationInfo:self.itemsToDisplay[indexPath.row]];
        }
    }
    
    [UIView transitionFromView:fromView
                        toView:toView
                      duration:0.5
                       options: UIViewAnimationOptionTransitionFlipFromRight
                    completion:^(BOOL finished) {
                        if (finished) {
                            self.tabBarController.selectedIndex = 1;
                        }
                    }];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
