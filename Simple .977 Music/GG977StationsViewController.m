//
//  GG977StationsViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationsViewController.h"
//#import "GG977PlayerViewController.h"
#import "GG977StationsCollection.h"

@interface GG977StationsViewController ()

@property (strong, nonatomic) NSArray *itemsToDisplay;
@property GG977StationsCollection *stationsCollection;

@end

@implementation GG977StationsViewController

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillAppear:animated];
    // Если свойство задано как YES, то очищаем выделения строк в таблице при ее отображении
    if (self.clearsSelectionOnViewWillAppear) {
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // При возвращении к таблице долдны очищаться выделения
    self.clearsSelectionOnViewWillAppear = YES;
    
    self.itemsToDisplay = [NSMutableArray new];
    [self loadStations];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadStations
{
    self.stationsCollection = [GG977StationsCollection sharedInstance];
    
    self.itemsToDisplay = [self.stationsCollection allStations];
    [self.tableView reloadData];
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
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentider];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // Configure the cell...
    cell.textLabel.text = [self.itemsToDisplay[indexPath.row] title];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    self.tabBarController.selectedIndex = 1;
    self.selectedStation = self.itemsToDisplay[indexPath.row];
    
    UIView * fromView = self.tabBarController.selectedViewController.view;
    UIView * toView = [[self.tabBarController.viewControllers objectAtIndex:1] view];
    
    // Transition using a page curl.
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
