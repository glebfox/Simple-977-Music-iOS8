//
//  GG977StationsViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationsViewController.h"
#import "GG977StationInfo.h"

@interface GG977StationsViewController ()

@property (strong, nonatomic) NSMutableArray *itemsToDisplay;

@end

@implementation GG977StationsViewController

-(void)viewWillAppear:(BOOL)animated{
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
    GG977StationInfo *info;
    
    info = [[GG977StationInfo alloc] initWithTitle:@"Alternative" url:[NSURL URLWithString:@"http://www.977music.com/itunes/alternative.pls"]];
    [self.itemsToDisplay addObject:info];
    
    info = [[GG977StationInfo alloc] initWithTitle:@"Hitz" url:[NSURL URLWithString:@"http://977music.com/itunes/hitz.pls"]];
    [self.itemsToDisplay addObject:info];
    
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


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
