//
//  GG977PlayStationViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977PlayerViewController.h"
#import "GG977StationsViewController.h"

static void *timedMetadataObserverContext = &timedMetadataObserverContext;
static void *rateObserverContext = &rateObserverContext;
static void *currentItemObserverContext = &currentItemObserverContext;
static void *playerItemStatusObserverContext = &playerItemStatusObserverContext;

NSString *keyTracks         = @"tracks";
NSString *keyStatus         = @"status";
NSString *keyRate			= @"rate";
NSString *keyPlayable		= @"playable";
NSString *keyCurrentItem	= @"currentItem";
NSString *keyTimedMetadata	= @"currentItem.timedMetadata";

@interface GG977PlayerViewController ()

@property (retain) AVPlayer *player;
@property (retain) AVPlayerItem *playerItem;

@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *audioVolumeSlider;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UILabel *artistInfo;
@property (weak, nonatomic) IBOutlet UILabel *trackInfo;
@property (weak, nonatomic) IBOutlet UILabel *stationTitle;

@property GG977StationsViewController *stationsController;

@end

@implementation GG977PlayerViewController

- (void)viewDidAppear:(BOOL)animated
{
    if (self.stationInfo != self.stationsController.selectedStation) {
        self.stationInfo = self.stationsController.selectedStation;
        self.stationTitle.text = self.stationInfo.title;

        /*
         Create an asset for inspection of a resource referenced by a given URL.
         Load the values for the asset keys "tracks", "playable".
         */
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.stationInfo.url options:nil];
        
        NSArray *requestedKeys = @[keyTracks, keyPlayable];
        
        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{
             dispatch_async( dispatch_get_main_queue(),
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UINavigationController *navController = (UINavigationController *)self.tabBarController.viewControllers[0];
    self.stationsController = (GG977StationsViewController *)navController.topViewController;
    [self disablePlayerButtons];
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
}

-(void)enablePlayerButtons
{
    self.playPauseButton.enabled = YES;
    self.infoButton.enabled = YES;
    self.audioVolumeSlider.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.playPauseButton.enabled = NO;
    self.infoButton.enabled = NO;
    self.audioVolumeSlider.enabled = NO;
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

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 **
 **  1) values of asset keys did not load successfully,
 **  2) the asset keys did load successfully, but the asset is not
 **     playable
 **  3) the item did not become ready to play.
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self disablePlayerButtons];
    
    /* Display the error. */
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

#pragma mark Prepare to play asset

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    NSLog(@"prepareToPlayAsset");
    /* Make sure that the value of each key has loaded successfully. */
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
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
    {
        /* Generate an error describing the failure. */
        NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
        NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
        NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                   localizedDescription, NSLocalizedDescriptionKey,
                                   localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                                   nil];
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
    
    /* At this point we're ready to set up for playback of the asset. */
    
    [self enablePlayerButtons];
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.playerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.playerItem removeObserver:self forKeyPath:keyStatus];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                      forKeyPath:keyStatus
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:playerItemStatusObserverContext];
    
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(playerItemDidReachEnd:)
//                                                 name:AVPlayerItemDidPlayToEndTimeNotification
//                                               object:self.playerItem];
    
    
    /* Create new player, if we don't already have one. */
    if (![self player])
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
        
        /* Observe the AVPlayer "currentItem" property to find out when any
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
         occur.*/
        [self.player addObserver:self
                      forKeyPath:keyCurrentItem
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:currentItemObserverContext];
        
        /* A 'currentItem.timedMetadata' property observer to parse the media stream timed metadata. */
        [self.player addObserver:self
                      forKeyPath:keyTimedMetadata
                         options:0
                         context:timedMetadataObserverContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self
                      forKeyPath:keyRate
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:rateObserverContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.playerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs
         asynchronously; observe the currentItem property to find out when the
         replacement will/did occur*/
        [[self player] replaceCurrentItemWithPlayerItem:self.playerItem];
        
        [self syncPlayPauseButton];
    }
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
                [self disablePlayerButtons];
            }
                break;

            case AVPlayerStatusReadyToPlay:
            {
                NSLog(@"AVPlayerStatusReadyToPlay");
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                [self enablePlayerButtons];
                self.audioVolumeSlider.value = self.player.volume;
                
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                NSLog(@"AVPlayerStatusFailed");
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            }
                break;
        }
    }
    /* AVPlayer "rate" property value observer. */
    else if (context == rateObserverContext)
    {
        [self syncPlayPauseButton];
    }
    /* AVPlayer "currentItem" property observer.
     Called when the AVPlayer replaceCurrentItemWithPlayerItem:
     replacement will/did occur. */
    else if (context == currentItemObserverContext)
    {
        NSLog(@"currentItemObserverContext");
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* New player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            NSLog(@"New player item null?");
            [self disablePlayerButtons];
            
//            self.isPlayingAdText.text = @"";
        }
        else /* Replacement of player currentItem has occurred */
        {
            NSLog(@"Replacement of player currentItem has occurred");
            [self syncPlayPauseButton];
        }
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
        NSLog(@"super observer");
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
