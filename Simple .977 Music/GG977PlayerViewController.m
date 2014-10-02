//
//  GG977PlayStationViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977PlayerViewController.h"

static void *timedMetadataObserverContext = &timedMetadataObserverContext;
static void *rateObserverContext = &rateObserverContext;
static void *currentItemObserverContext = &currentItemObserverContext;
static void *playerItemStatusObserverContext = &playerItemStatusObserverContext;

@interface GG977PlayerViewController ()

@property (retain) AVPlayer *player;
@property (retain) AVPlayerItem *playerItem;

@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *audioVolumeSlider;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UILabel *artistInfo;
@property (weak, nonatomic) IBOutlet UILabel *trackInfo;
@property (weak, nonatomic) IBOutlet UILabel *stantionTitle;

@end

@implementation GG977PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.stationInfo = [[GG977StationInfo alloc] initWithTitle:@"Alternative" url:[NSURL URLWithString:@"http://www.977music.com/itunes/alternative.pls"]];
    
    self.stantionTitle.text = self.stationInfo.title;
    
    self.playerItem = [AVPlayerItem playerItemWithURL:self.stationInfo.url];
    [self.playerItem addObserver:self forKeyPath:@"status" options:0 context:playerItemStatusObserverContext];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    [self.player addObserver:self forKeyPath:@"currentItem.timedMetadata" options:0 context:timedMetadataObserverContext];
    [self.player addObserver:self forKeyPath:@"currentItem" options:0 context:currentItemObserverContext];
    [self.player addObserver:self forKeyPath:@"rate" options:0 context:rateObserverContext];
    
    self.audioVolumeSlider.value = self.player.volume;
    
    
    
    
    
    
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(playerItemDidReachEnd:)
//                                                 name:AVPlayerItemDidPlayToEndTimeNotification
//                                               object:self.playerItem];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Player

- (BOOL)isPlaying
{
    return self.player.rate != 0.f;
}

#pragma mark - Play, Stop Buttons

- (void)syncPlayPauseButton
{
    NSLog(@"syncPlayPauseButton");
    UIImage *image = [[UIImage imageNamed: [self isPlaying] ? @"pause" : @"play"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.playPauseButton setImage: image forState:UIControlStateNormal];
    //[self.playPauseButton setImage: [self isPlaying] ? [UIImage imageNamed:@"pause.png"] : [UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
}

-(void)enablePlayerButtons
{
    self.playPauseButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.playPauseButton.enabled = NO;
}

#pragma mark - Button Action Methods

- (IBAction)playPause:(id)sender
{
    [self isPlaying] ? [self pause:sender] : [self play:sender];
}

- (IBAction)play:(id)sender
{
    [self.player play];
}

- (IBAction)pause:(id)sender
{
    [self.player pause];
}

- (IBAction)changeVolume:(id)sender
{
    self.player.volume = self.audioVolumeSlider.value;
}

#pragma mark - Player Notifications

/* Called when the player item has played to its end time. */
- (void) playerItemDidReachEnd:(NSNotification*) notification
{
    NSLog(@"playerItemDidReachEnd");
}

#pragma mark - Timed metadata

- (void)handleTimedMetadata:(AVMetadataItem*)timedMetadata
{
    NSArray *array = [[timedMetadata.value description] componentsSeparatedByString:@" - "];
    self.artistInfo.text = array[0];
    self.trackInfo.text = array[1];
    
//    NSLog(@"handleTimedMetadata");

    /* We expect the content to contain plists encoded as timed metadata. AVPlayer turns these into NSDictionaries. */
//    if ([(NSString *)[timedMetadata key] isEqualToString:AVMetadataID3MetadataKeyGeneralEncapsulatedObject])
//    {
//        if ([[timedMetadata value] isKindOfClass:[NSDictionary class]])
//        {
//            NSDictionary *propertyList = (NSDictionary *)[timedMetadata value];
//            
//            /* Metadata payload could be the list of ads. */
//            NSArray *newAdList = [propertyList objectForKey:@"ad-list"];
//            if (newAdList != nil)
//            {
//                [self updateAdList:newAdList];
//                NSLog(@"ad-list is %@", newAdList);
//            }
//            
//            /* Or it might be an ad record. */
//            NSString *adURL = [propertyList objectForKey:@"url"];
//            if (adURL != nil)
//            {
//                if ([adURL isEqualToString:@""])
//                {
//                    /* Ad is not playing, so clear text. */
//                    self.isPlayingAdText.text = @"";
//                    
//                    [self enablePlayerButtons];
//                    [self enableScrubber]; /* Enable seeking for main content. */
//                    
//                    NSLog(@"enabling seek at %g", CMTimeGetSeconds([player currentTime]));
//                }
//                else
//                {
//                    /* Display text indicating that an Ad is now playing. */
//                    self.isPlayingAdText.text = @"< Ad now playing, seeking is disabled on the movie controller... >";
//                    
//                    [self disablePlayerButtons];
//                    [self disableScrubber]; 	/* Disable seeking for ad content. */
//                    
//                    NSLog(@"disabling seek at %g", CMTimeGetSeconds([self.player currentTime]));
//                }
//            }
//        }
//    }
}

#pragma mark Prepare to play asset

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
//    NSLog(@"prepareToPlayAsset");
    

}


#pragma mark - Asset Key Value Observing

#pragma mark Key Value Observer for player rate, currentItem, player item status

- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
    /* AVPlayerItem "status" property value observer. */
    if (context == playerItemStatusObserverContext)
    {
        [self syncPlayPauseButton];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
                /* Indicates that the status of the player is not yet known because
                 it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown:
            {
                NSLog(@"AVPlayerStatusUnknown");
//                [self removePlayerTimeObserver];
//                [self syncScrubber];
//                
//                [self disableScrubber];
//                [self disablePlayerButtons];
            }
                break;

            case AVPlayerStatusReadyToPlay:
            {
                NSLog(@"AVPlayerStatusReadyToPlay");
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
//                 its duration can be fetched from the item. */
//                
//                playerLayerView.playerLayer.hidden = NO;
//                
//                [toolBar setHidden:NO];
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                NSLog(@"AVPlayerStatusFailed");
//                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
//                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            }
                break;
        }
    }
    /* AVPlayer "rate" property value observer. */
    else if (context == rateObserverContext)
    {
        NSLog(@"rateObserverContext");
        [self syncPlayPauseButton];
    }
    /* AVPlayer "currentItem" property observer.
     Called when the AVPlayer replaceCurrentItemWithPlayerItem:
     replacement will/did occur. */
    else if (context == currentItemObserverContext)
    {
//        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
//        
//        /* New player item null? */
//        if (newPlayerItem == (id)[NSNull null])
//        {
//            [self disablePlayerButtons];
//            [self disableScrubber];
//            
//            self.isPlayingAdText.text = @"";
//        }
//        else /* Replacement of player currentItem has occurred */
//        {
//            /* Set the AVPlayer for which the player layer displays visual output. */
//            [playerLayerView.playerLayer setPlayer:self.player];
//            
//            /* Specifies that the player should preserve the video’s aspect ratio and
//             fit the video within the layer’s bounds. */
//            [playerLayerView setVideoFillMode:AVLayerVideoGravityResizeAspect];
//            
//            [self syncPlayPauseButtons];
//        }
    }
    /* Observe the AVPlayer "currentItem.timedMetadata" property to parse the media stream
     timed metadata. */
    else if (context == timedMetadataObserverContext)
    {
        NSArray* array = self.player.currentItem.timedMetadata;
        for (AVMetadataItem *metadataItem in array)
        {
            [self handleTimedMetadata:metadataItem];
        }
    }
    else
    {
        [super observeValueForKeyPath:path ofObject:object change:change context:context];
    }
    return;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
