//
//  GG977StationsCollection.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 02.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977DataModel.h"
#import "GG977StationInfo.h"

@interface GG977DataModel ()

@property (nonatomic, strong) NSArray *allStations;

@end

@implementation GG977DataModel

- (id)init
{
    if ((self = [super init])) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Stations" ofType:@"plist"];
        NSDictionary *stationsDic = [NSDictionary dictionaryWithContentsOfFile:path];
        
        NSArray *keys = [stationsDic allKeys];
        NSMutableArray *stations = [NSMutableArray new];
        
        for (NSString *key in keys) {
            [stations addObject:[[GG977StationInfo alloc] initWithTitle:key]];
            
            NSDictionary *currentStationInfo = stationsDic[key];
            
            [[stations lastObject] setUrl:[NSURL URLWithString:currentStationInfo[@"url"]]];
            NSNumber *number = (NSNumber *)currentStationInfo[@"id"];
            [[stations lastObject] setExternalID:[number integerValue]];
        }
        
        [stations sortUsingSelector:@selector(compare:)];
        _allStations = [stations copy];
    }
    return self;
}

@end
