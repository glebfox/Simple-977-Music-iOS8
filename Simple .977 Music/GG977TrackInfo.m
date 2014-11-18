//
//  GG977TrackInfo.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 11.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977TrackInfo.h"

@implementation GG977TrackInfo

- (BOOL)isEqual:(id)object {
    if (object == nil) return false;
    if (object == self) return true;
    if ([object class] != [GG977TrackInfo class]) return false;
    
    GG977TrackInfo *obj = (GG977TrackInfo *)object;
    return  [self.artist isEqualToString:obj.artist] && [self.track isEqualToString:obj.track];
}

@end
