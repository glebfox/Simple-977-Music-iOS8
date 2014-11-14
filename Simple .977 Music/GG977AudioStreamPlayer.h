//
//  GG977AudioStreamPlayer.h
//  AudioQueueTest
//
//  Created by Gleb Gorelov on 12.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

@class GG977AudioStreamPlayer;

@protocol GG977AudioStreamPlayerDelegate <NSObject>

- (void)playerDidBeginConnection:(GG977AudioStreamPlayer *)player;
- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error;
- (void)playerDidPrepareForPlayback:(GG977AudioStreamPlayer *)player;

- (void)playerDidStartPlaying:(GG977AudioStreamPlayer *)player;
- (void)playerDidPausePlaying:(GG977AudioStreamPlayer *)player;
- (void)playerDidStopPlaying:(GG977AudioStreamPlayer *)player;

//- (void)playerDidStartReceivingTrackInfo:(GG977AudioStreamPlayer *)player;
//- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info;

@end

@interface GG977AudioStreamPlayer : NSObject

@property (nonatomic, weak) id<GG977AudioStreamPlayerDelegate> delegate;

- (id)initWithURL:(NSURL *)url;

- (void)start;
- (void)stop;
- (void)pause;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)isWaiting;
- (BOOL)isIdle;
- (BOOL)isAborted;

@end

extern NSString * const ASStatusChangedNotification;