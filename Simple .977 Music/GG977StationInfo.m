//
//  GG977StationInfo.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977StationInfo.h"

@implementation GG977StationInfo

- (id)initWithTitle:(NSString *)title url:(NSURL *)url
{
    if ((self = [super init])) {
        self.title = title;
        self.url = url;
    }
    return self;
}

#pragma mark NSObject

- (NSString *)description
{
    NSMutableString *description = [[NSMutableString alloc] initWithString:[self.class description]];
    if (self.title) [description appendFormat:@" - %@", self.title];
    if (self.url) [description appendFormat:@" - %@", [self.url absoluteString]];
    
    return description;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if ((self = [super init])) {
        self.title = [decoder decodeObjectForKey:@"title"];
        self.url = [decoder decodeObjectForKey:@"url"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    if (self.title) [encoder encodeObject:self.title forKey:@"title"];
    if (self.url) [encoder encodeObject:self.url forKey:@"url"];
}

@end
