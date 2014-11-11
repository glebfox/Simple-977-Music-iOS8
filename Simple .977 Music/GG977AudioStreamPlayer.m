//
//  GG977AudioStreamPlayer.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 11.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977AudioStreamPlayer.h"
#import "GG977TrackInfo.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>

// Переменные хранящие контекст наблюдателя
static void *timedMetadataObserverContext = &timedMetadataObserverContext;
static void *rateObserverContext = &rateObserverContext;
static void *currentItemObserverContext = &currentItemObserverContext;
static void *playerItemStatusObserverContext = &playerItemStatusObserverContext;

// Переменные - заменители ручного вписывания ключей для наблюдателя
NSString *keyTracks         = @"tracks";
NSString *keyStatus         = @"status";
NSString *keyRate			= @"rate";
NSString *keyPlayable		= @"playable";
NSString *keyCurrentItem	= @"currentItem";
NSString *keyTimedMetadata	= @"currentItem.timedMetadata";

@interface GG977AudioStreamPlayer ()

@property (strong) AVPlayer *player;
@property (strong) AVPlayerItem *playerItem;

@property(getter=isInterrupted) BOOL interrupted;
@property(getter=isNewStation) BOOL newStation;
@property (weak) NSTimer *timer;

@end

@implementation GG977AudioStreamPlayer

#pragma mark - init

- (id)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioSessionInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:[AVAudioSession sharedInstance]];

        // Apple recommends that you explicitly activate your session—typically as part of your app’s viewDidLoad method, and set preferred hardware values prior to activating your audio session.
        NSError *activationError = nil;
        BOOL success = [[AVAudioSession sharedInstance] setActive: YES error: &activationError];
        if (!success) {
            NSLog(@"%@", activationError);
        }
        
        NSError *setCategoryError = nil;
        success = [[AVAudioSession sharedInstance]
                        setCategory: AVAudioSessionCategoryPlayback
                        error: &setCategoryError];
        
        if (!success) {
            NSLog(@"%@", setCategoryError);
        }
    }
    return self;
}

- (void)dealloc
{
    //    NSLog(@"dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:[AVAudioSession sharedInstance]];
}

#pragma mark - Control state

- (void)play {
    [self.player play];
    
    if ([self.delegate respondsToSelector:@selector(playerDidStartPlaying:)]) {
        [self.delegate playerDidStartPlaying:self];
    }
}

- (void)pause {
    [self.player pause];
    
    if ([self.delegate respondsToSelector:@selector(playerDidPausePlaying:)]) {
        [self.delegate playerDidPausePlaying:self];
    }
}

- (void)stop {
    if ([self.delegate respondsToSelector:@selector(playerDidStopPlaying:)]) {
        [self.delegate playerDidStopPlaying:self];
    }
}

- (void)togglePlayPause {
    [self isPlaying] ? [self pause] : [self play];
}

- (BOOL)isPlaying {
    return self.player.rate != 0.f;
}

#pragma mark - AVPlayer prepare

- (void)startNewConnectionWithUrl:(NSURL *)url {
    
    if ([self.timer isValid]) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    // Создаем asset для заданного url. Загружаем значения для ключей "tracks", "playable".
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    
    NSArray *requestedKeys = @[keyTracks, keyPlayable];
    
    // Загружаем ключи, которые еще не были загруженны.
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
     ^{
         dispatch_async( dispatch_get_main_queue(),
                        ^{
                            [self prepareToPlayAsset:asset withKeys:requestedKeys];
                        });
     }];
}

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    if ([self.delegate respondsToSelector:@selector(playerDidBeginConnection:)]) {
        [self.delegate playerDidBeginConnection:self];
    }
    
    //    NSLog(@"prepareToPlayAsset");
    // Убеждаемся, что значение каждого ключа успешно загруженно
    for (NSString *thisKey in requestedKeys)
    {
        NSError *error = nil;
        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        if (keyStatus == AVKeyValueStatusFailed)
        {
            [self assetFailedToPrepareForPlayback:error];
            return;
        }
    }
    
    // Проверяем может ли asset проигрываться.
    if (!asset.playable)
    {
        NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
        NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"GG977Music" code:0 userInfo:errorDict];
        
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
    
    self.newStation = YES;
    
    /* Если у нас уже был AVPlayerItem, то удаляем его слушателя. */
    if (self.playerItem)
    {
        [self.playerItem removeObserver:self forKeyPath:keyStatus];
    }
    
    // Создаем новый playerItem
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [self.playerItem addObserver:self
                      forKeyPath:keyStatus
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:playerItemStatusObserverContext];
    
    // Создаем нового player, если еще этого не делали
    if (!self.player)
    {
        self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
        
        // Для отслеживания исзменения текущего playerItem
        [self.player addObserver:self
                      forKeyPath:keyCurrentItem
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:currentItemObserverContext];
        
        // Свойство 'currentItem.timedMetadata' для слежения за изменениями metadata
        [self.player addObserver:self
                      forKeyPath:keyTimedMetadata
                         options:NSKeyValueObservingOptionNew
                         context:timedMetadataObserverContext];
        
        // Свойство AVPlayer "rate", чтобы отслеживать запуск и останов проигрывания
        [self.player addObserver:self
                      forKeyPath:keyRate
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:rateObserverContext];
    }
    
    if (self.player.currentItem != self.playerItem)
    {
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    }
}

#pragma mark - Preparing Assets for Playback Failed

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(playerFailedToPrepareForPlayback:)]) {
        [self.delegate playerFailedToPrepareForPlayback:self];
    }
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView show];
}


#pragma mark - Timed metadata

// Обрабатывает метаданные
- (void)handleTimedMetadata:(AVMetadataItem*)timedMetadata
{
    //    NSLog(@"handleTimedMetadata");
    [self.timer invalidate];
    self.timer = nil;
    if ([timedMetadata.commonKey isEqualToString:@"title"]) {
        // Здесь не совсем универсальная ситуация, поскольку разные станцие по разному разделяют артиста и название трека, но с .977 всегда через "-"
        NSArray *array = [[timedMetadata.value description] componentsSeparatedByString:@" - "];
        GG977TrackInfo *info = [GG977TrackInfo new];
        if (array.count > 1) {
            info.artist = array[0];
            info.track = array[1];
        } else {
            info.artist = @"";
            info.track = array[0];
        }
        
        [self setInfoCenterWithArtist:info.artist title:info.track];
        
        if ([self.delegate respondsToSelector:@selector(player:didReceiveTrackInfo:)]) {
            [self.delegate player:self didReceiveTrackInfo:info];
        }
    }
}

- (void)timerFired:(NSTimer *)timer
{
    GG977TrackInfo *info = [GG977TrackInfo new];
    info.artist = @"";
    info.track = NSLocalizedString(@"No metadata", nil);
    
    [self setInfoCenterWithArtist:info.artist title:info.track];
    
    if ([self.delegate respondsToSelector:@selector(player:didReceiveTrackInfo:)]) {
        [self.delegate player:self didReceiveTrackInfo:info];
    }
}

- (void)setInfoCenterWithArtist:(NSString *)artist title:(NSString *)title {
    
    NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
    
    [songInfo setObject:title forKey:MPMediaItemPropertyTitle];
    [songInfo setObject:artist forKey:MPMediaItemPropertyArtist];
    
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
}

#pragma mark - Asset Key Value Observing

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    // AVPlayerItem "status"
    if (context == playerItemStatusObserverContext)
    {
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
                // Указывает на то, что player еще не имеет конкретного статуса, т.к. он еще не пробовал загрузить медиа данные
            case AVPlayerStatusUnknown:
            {
                //                NSLog(@"AVPlayerStatusUnknown");
//                [self disablePlayerButtons];
            }
                break;
                // AVPlayerItem готов к проигрыванию
            case AVPlayerStatusReadyToPlay:
            {
                //                NSLog(@"AVPlayerStatusReadyToPlay");
                if (!self.isInterrupted && self.isNewStation) {
                    
                    if ([self.delegate respondsToSelector:@selector(playerDidPrepareForPlayback:)]) {
                        [self.delegate playerDidPrepareForPlayback:self];
                    }
#warning сделать свойство автостарт
                    [self play];
                    
                    self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                                  target:self
                                                                selector:@selector(timerFired:)
                                                                userInfo:nil
                                                                 repeats:NO];
                    
                    self.newStation = NO;
                }
                self.interrupted = NO;
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                //                NSLog(@"AVPlayerStatusFailed");
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            }
                break;
        }
    }
    // AVPlayer "rate"
    else if (context == rateObserverContext)
    {
        //        NSLog(@"rateObserverContext - syncPlayPauseButton");
//        [self syncPlayPauseButton];
    }
    // AVPlayer "currentItem". Срабатывает когда AVPlayer вызывает replaceCurrentItemWithPlayerItem:
    else if (context == currentItemObserverContext)
    {
        //        NSLog(@"currentItemObserverContext");
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        // Если вдруг нечем проигрывать, то делаем кнопки неактивными
        if (newPlayerItem == (id)[NSNull null])
        {
//            [self disablePlayerButtons];
            
        }
        else // А если есть чем проигрывать, то нам нечего тут делать пока что
        {
        }
    }
    // Обрабатываем изменения метаданных
    else if (context == timedMetadataObserverContext)
    {
        //        NSLog(@"timedMetadataObserverContext");
        NSArray* array = self.player.currentItem.timedMetadata;
        for (AVMetadataItem *metadataItem in array)
        {
            [self handleTimedMetadata:metadataItem];
        }
    }
    else
    {
        //        NSLog(@"observeValueForKeyPath - super");
        [super observeValueForKeyPath:path ofObject:object change:change context:context];
    }
    return;
}

#pragma mark - Notifications

- (void)handleAudioSessionInterruption:(NSNotification*) notification
{
    NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    //    NSNumber *interruptionOption = [[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
    //    NSLog(@"interruptionType - %lu", (unsigned long)interruptionType.unsignedIntegerValue);
    
    switch (interruptionType.unsignedIntegerValue) {
        case AVAudioSessionInterruptionTypeBegan: {
            //            NSLog(@"AVAudioSessionInterruptionTypeBegan");
            self.interrupted = YES;
            if ([self isPlaying]) {
                [self pause];
            }
        } break;
        case AVAudioSessionInterruptionTypeEnded: {
            //            NSLog(@"AVAudioSessionInterruptionTypeEnded");
            //            [self.player play];
        } break;
        default:
            break;
    }
}

@end
