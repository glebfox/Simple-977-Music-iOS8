//
//  GG977StationInfo.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationInfo.h"

@implementation GG977StationInfo

- (NSString *)description
{
    NSMutableString *description = [[NSMutableString alloc] initWithString:[self.class description]];
    if (self.title) [description appendFormat:@" - %@", self.title];
    if (self.url) [description appendFormat:@" - %@", [self.url absoluteString]];
    
    return description;
}

- (id)initWithTitle:(NSString *)title url:(NSURL *)url
{
    if ((self = [super init])) {
        self.title = title;
        self.url = url;
    }
    return self;
}

@end
