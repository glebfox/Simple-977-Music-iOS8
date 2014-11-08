//
//  GG977StationsViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationsViewController.h"
#import "GG977StationsCollection.h"

@interface GG977StationsViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation GG977StationsViewController

- (void)viewDidLoad {
    [super viewDidLoad];    
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
    return [[GG977StationsCollection sharedInstance] allStations].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentider = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentider forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [[[GG977StationsCollection sharedInstance] allStations][indexPath.row] title];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
    if ([self.delegate respondsToSelector:@selector(setPlayerStationInfo:)]) {
        [self.delegate setPlayerStationInfo:[[GG977StationsCollection sharedInstance] allStations][indexPath.row]];
    }

    if ([self.delegate respondsToSelector:@selector(transitionFromView:duration:options:)]) {
        [self.delegate transitionFromView:self.view duration:1 options:UIViewAnimationOptionTransitionFlipFromRight];
    }
}

@end