//
//  GG977AudioStreamPlayer.h
//  AudioQueueTest
//
//  Created by Gleb Gorelov on 12.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GG977MetadataParser.h"

@class GG977StationInfo;

@class GG977AudioStreamPlayer;

@protocol GG977AudioStreamPlayerDelegate <NSObject>

- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error;

- (void)playerDidStartReceivingTrackInfo:(GG977AudioStreamPlayer *)player;
- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info;

@end

@interface GG977AudioStreamPlayer : NSObject <GG977MetadataParserDelegate>

@property (nonatomic, weak) id<GG977AudioStreamPlayerDelegate> delegate;

- (id)initWithStation:(GG977StationInfo *)station;

- (void)start;
- (void)stop;
- (void)pause;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)isWaiting;
- (BOOL)isIdle;
- (BOOL)isAborted;

@end
