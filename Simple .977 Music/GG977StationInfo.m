//
//  GG977StationInfo.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationInfo.h"

@implementation GG977StationInfo

- (id)initWithTitle:(NSString *)title {
    if ((self = [super init])) {
        _title = [title copy];
        _externalID = 0;
    }
    return self;
}

#pragma mark NSObject

- (NSString *)description {
    NSMutableString *description = [[NSMutableString alloc] initWithString:[self.class description]];
    if (self.title) [description appendFormat:@" - %@", self.title];
    if (self.url) [description appendFormat:@" - %@", [self.url absoluteString]];
    if (self.externalID) [description appendFormat:@" - %lu", (unsigned long)self.externalID];
    
    return description;
}

- (BOOL)isEqual:(id)object {
    if (!object) return false;
    if (object == self) return true;
    if ([object class] != [GG977StationInfo class]) return false;
    GG977StationInfo *obj = (GG977StationInfo *)object;
    return [self.title isEqualToString:obj.title] && [self.url isEqual:obj.url] && self.externalID == obj.externalID;
}

- (NSComparisonResult)compare:(GG977StationInfo *)otherStationInfo {
    return [self.title localizedStandardCompare:otherStationInfo.title];
}

@end
