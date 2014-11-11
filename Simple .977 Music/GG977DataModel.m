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

//@property (nonatomic, strong) NSDictionary *stations;
@property (nonatomic, strong) NSArray *allStations;

@end

@implementation GG977DataModel

//+ (id)sharedInstance
//{
//    static GG977DataModel *sharedInstance = nil;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        sharedInstance = [self new];
//    });
//    
//    return sharedInstance;
//}

- (id)init
{
    if ((self = [super init])) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Stations" ofType:@"plist"];
        NSDictionary *stationsDic = [NSDictionary dictionaryWithContentsOfFile:path];
        
        NSArray *keys = [stationsDic allKeys];
        NSMutableArray *stations = [NSMutableArray new];
        
        for (NSString *key in keys) {
            [stations addObject:[[GG977StationInfo alloc] initWithTitle:key url:[NSURL URLWithString:stationsDic[key]]]];
        }
        
        _allStations = [NSArray arrayWithArray:stations];

        
    }
    return self;
}

//- (GG977StationInfo *)stationByName:(NSString *)name
//{
//    if (!name) return nil;
//    
////    NSString *urlString = self.stations[name];
////    if (urlString != nil) {
////        GG977StationInfo *info = [[GG977StationInfo alloc] initWithTitle:name url:[NSURL URLWithString:urlString]];
////        return info;
////    }
////    return nil;
//    
//    for (GG977StationInfo *station in self.allStations) {
//        if ([station.title isEqualToString:name]) return station;
//    }
//    
//    return nil;
//}

//- (NSArray *)allStations
//{
//    if (!_allStations) {
//        NSArray *keys = [self.stations allKeys];
//        NSMutableArray *stations = [NSMutableArray new];
//        
//        for (NSString *key in keys) {
//            [stations addObject:[[GG977StationInfo alloc] initWithTitle:key url:[NSURL URLWithString:self.stations[key]]]];
//        }
//        
//        _allStations = [NSArray arrayWithArray:stations];
//    }
//    return _allStations;
//}


@end
