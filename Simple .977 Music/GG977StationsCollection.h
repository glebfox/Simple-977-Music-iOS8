//
//  GG977StationsCollection.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 02.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GG977StationInfo.h"

@interface GG977StationsCollection : NSObject

@property (nonatomic, strong, readonly) NSArray *allStations;

+ (id)sharedInstance;

- (GG977StationInfo *)stationByName:(NSString *)name;
//- (NSArray *)allStations;


@end
