//
//  GG977MetadataParser.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 18.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GG977TrackInfo;
@class GG977MetadataParser;

@protocol GG977MetadataParserDelegate <NSObject>

- (void)parser:(GG977MetadataParser *)parser didParseNewTrackInfo:(GG977TrackInfo *)trackInfo;

@end

@interface GG977MetadataParser : NSObject

@property (nonatomic, weak) id <GG977MetadataParserDelegate> delegate;
@property (nonatomic, assign) NSUInteger interval;
@property (nonatomic, assign) NSUInteger stationID;

- (id)initWithInterval:(NSUInteger)interval;

- (void)start;
- (void)stop;

@end
