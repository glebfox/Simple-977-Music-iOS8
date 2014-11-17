//
//  GG977TrackInfo.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 11.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GG977TrackInfo : NSObject

@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *track;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSURL *imageUrl;
@property (nonatomic, copy) NSString *year;
@property (nonatomic, copy) NSString *lyrics;

@end
