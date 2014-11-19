//
//  GG977PlayStationViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977PlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "AppDelegate.h"
#import "GG977TrackInfo.h"
#import "GG977DetailTrackInfoViewController.h"

@interface GG977PlayerViewController ()

@property (strong, nonatomic) GG977AudioStreamPlayer *player;
@property (strong, nonatomic) GG977TrackInfo *trackInfo;

@property (weak, nonatomic) IBOutlet UIButton *playStopButton;
@property (weak, nonatomic) IBOutlet UILabel *artistInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *stationTitleLabel;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;

@end

@implementation GG977PlayerViewController

#pragma mark - init

- (id)init {
    if ((self = [super init])) {
        [self gg977PlayerViewControllerInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self gg977PlayerViewControllerInit];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        [self gg977PlayerViewControllerInit];
    }
    return self;
}

- (void)gg977PlayerViewControllerInit {
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.delegate = self;
}

#pragma mark - View life-cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self updateUIState];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (void)setStationInfo:(GG977StationInfo *)stationInfo
{
    if (![_stationInfo isEqual:stationInfo]) {
        _stationInfo = stationInfo;
    
        self.stationTitleLabel.text = _stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
        
        if (self.player != nil) {
            [self.player stop];
        }
        self.player = [[GG977AudioStreamPlayer alloc] initWithStation:_stationInfo];
        self.player.delegate = self;

//        self.trackInfo = nil;
//        [self updateUIState];
        
        [self playPause:nil];
    }
}

#pragma mark - UI Updates

- (BOOL)playerShouldBeStopped {
    return [self.player isPlaying] || [self.player isWaiting];
}

- (void)syncPlayPauseButton
{
    UIImage *image = [[UIImage imageNamed: [self playerShouldBeStopped] ? @"stop" : @"play"]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.playStopButton setImage: image forState:UIControlStateNormal];
}

- (void)updateUIState {
    if (self.stationInfo != nil) {
        self.stationTitleLabel.text = self.stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
    } else {
        self.stationTitleLabel.text = NSLocalizedString(@"No Station Title", nil);
        self.imageView.image = nil;
    }
    
    if (self.trackInfo != nil) {
        self.artistInfoLabel.text = self.trackInfo.artist;
        self.trackInfoLabel.text = self.trackInfo.track;
        
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
        
        [songInfo setObject:self.trackInfo.track forKey:MPMediaItemPropertyTitle];
        [songInfo setObject:self.trackInfo.artist forKey:MPMediaItemPropertyArtist];
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    } else {
        self.artistInfoLabel.text = @"";
        self.trackInfoLabel.text = @"";
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    }
    
    if (self.player == nil) {
        self.playStopButton.enabled = NO;
    } else {
        self.playStopButton.enabled = YES;
        if ([self.player isIdle]) {
            self.trackInfoLabel.text = NSLocalizedString(@"Press play button to listen", nil);
        } else if ([self.player isWaiting]) {
            self.trackInfoLabel.text = NSLocalizedString(@"Connecting...", nil);
        }
    }
    
    [self syncPlayPauseButton];
}

#pragma mark - Button Action Methods

- (IBAction)playPause:(id)sender
{
    self.trackInfo = nil;
    if ([self playerShouldBeStopped]) {
        [self stop];
    } else {
        [self start];
    }
    
    [self updateUIState];
}

- (void)start {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioSessionInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
    
    [self.player start];
}

- (void)stop {
    [self.player stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:[AVAudioSession sharedInstance]];

}

#pragma mark - GG977AudioStreamPlayerDelegate

- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error {
    self.stationInfo = nil;
    self.player = nil;
    self.trackInfo = nil;
    
    [self updateUIState];
    
    // Если UIAlertController существует, значит версия >= iOS8
    if ([UIAlertController class]) {
        UIAlertController * alertController = [UIAlertController
                                                alertControllerWithTitle:[error localizedDescription]
                                                message:[error localizedFailureReason]
                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* cancel = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [alertController dismissViewControllerAnimated:YES completion:nil];
                                     
                                 }];
        [alertController addAction:cancel];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {    // Иначе версия < iOS8
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)playerDidStartReceivingTrackInfo:(GG977AudioStreamPlayer *)player {
        self.trackInfoLabel.text = NSLocalizedString(@"Getting metadata...", nil);
}

- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info {
    NSLog(@"didReceiveTrackInfo");
    
    [self.spinner startAnimating];
    self.imageView.image = nil;
    
    self.trackInfo = info;
    
    if (self.trackInfo != nil) {
        [self updateUIState];
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:self.trackInfo.imageUrl] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            self.imageView.image = [UIImage imageWithData:data];
            [self.spinner stopAnimating];
        }];
    } else {
        [self updateUIState];
        self.trackInfoLabel.text = NSLocalizedString(@"No metadata", nil);
        [self.spinner stopAnimating];
    }
}

#pragma mark - AppRemoteControlDelegate

- (void)applicationReceivedRemoteControlWithEvent:(UIEvent *)receivedEvent {
    //    NSLog(@"player - remoteControlReceivedWithEvent");
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPlay:
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [self playPause:nil];
                break;
                
            default:
                break;
        }
    }
}

#pragma mark - Notifications

- (void)handleAudioSessionInterruption:(NSNotification*) notification
{
    NSNumber *interruptionType = [[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey];
    if (interruptionType.unsignedIntegerValue == AVAudioSessionInterruptionTypeBegan) {
        NSLog(@"AVAudioSessionInterruptionTypeBegan");
        if ([self playerShouldBeStopped]) {
            NSLog(@"playerShouldBeStopped");
            [self stop];
        }
        self.trackInfo = nil;
        [self updateUIState];
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ShowTrackDetail"]) {
        UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
        GG977DetailTrackInfoViewController *controller = (GG977DetailTrackInfoViewController *)navController.topViewController;
        controller.trackInfo = self.trackInfo;
    }
}

@end
