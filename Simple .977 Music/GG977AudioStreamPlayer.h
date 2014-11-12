//
//  GG977AudioStreamPlayer.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 11.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GG977AudioStreamPlayer;
@class GG977TrackInfo;

@protocol GG977AudioStreamPlayerDelegate <NSObject>

- (void)playerDidBeginConnection:(GG977AudioStreamPlayer *)player;
- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error;
- (void)playerDidPrepareForPlayback:(GG977AudioStreamPlayer *)player;

- (void)playerDidStartPlaying:(GG977AudioStreamPlayer *)player;
- (void)playerDidPausePlaying:(GG977AudioStreamPlayer *)player;
//- (void)playerDidStopPlaying:(GG977AudioStreamPlayer *)player;

- (void)playerDidStartReceivingTrackInfo:(GG977AudioStreamPlayer *)player;
- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info;

@end

@interface GG977AudioStreamPlayer : NSObject

@property (nonatomic, weak) id<GG977AudioStreamPlayerDelegate> delegate;

@property (nonatomic, assign) BOOL autoPlay;

- (void)play;
- (void)pause;
//- (void)stop;
- (void)togglePlayPause;

- (BOOL)isPlaying;

- (void)startNewConnectionWithUrl:(NSURL *)url;

@end
