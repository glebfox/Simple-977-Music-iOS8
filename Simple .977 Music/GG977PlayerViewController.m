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
    
    [self disablePlayerButtons];
    [self clearTrackInfoLabels];
    [self syncPlayPauseButton];
    
    if ([self.player isIdle]) {
        [self playerDidPrepareForPlayback:nil];
    }
    
    if ([self.player isWaiting]) {
        NSLog(@"viewDidLoad - Connecting...");
        self.trackInfoLabel.text = NSLocalizedString(@"Connecting...", nil);
    }
    
    if ([self.player isPlaying]) {
        self.trackInfoLabel.text = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] objectForKey:MPMediaItemPropertyTitle];
        self.artistInfoLabel.text = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] objectForKey:MPMediaItemPropertyArtist];
        [self syncPlayPauseButton];
        [self enablePlayerButtons];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

- (void)setStationInfo:(GG977StationInfo *)stationInfo
{
//    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    if (![_stationInfo isEqual:stationInfo]) {
        _stationInfo = stationInfo;
    
        self.stationTitleLabel.text = _stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
        
        if (self.player != nil) {
            [self.player stop];
        }
        self.player = [[GG977AudioStreamPlayer alloc] initWithStation:_stationInfo];
        self.player.delegate = self;

        if ([self.player isIdle]) {
            [self playerDidPrepareForPlayback:nil];
        }
    }
}

#pragma mark - UI Updates

- (BOOL)playerShouldBeStopped {
    return [self.player isPlaying] || [self.player isWaiting];
}

- (void)clearTrackInfoLabels
{
    self.artistInfoLabel.text = @"";
    self.trackInfoLabel.text = @"";

    if (self.stationInfo != nil) {
        self.stationTitleLabel.text = self.stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
    } else {
        self.stationTitleLabel.text = NSLocalizedString(@"No Station Title", nil);
    }
}

- (void)syncPlayPauseButton
{
    UIImage *image = [[UIImage imageNamed: [self playerShouldBeStopped] ? @"stop" : @"play"]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.playStopButton setImage: image forState:UIControlStateNormal];
}

-(void)enablePlayerButtons
{
    self.playStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.playStopButton.enabled = NO;
}

#pragma mark - Button Action Methods

- (IBAction)playPause:(id)sender
{
    if ([self playerShouldBeStopped]) {
        [self.player stop];
    } else {
        [self.player start];
    }
    
    self.trackInfo = nil;
}

#pragma mark - GG977AudioStreamPlayerDelegate

- (void)playerBeginConnection:(GG977AudioStreamPlayer *)player {
    [self syncPlayPauseButton];
    
    [self clearTrackInfoLabels];
    self.trackInfoLabel.text = NSLocalizedString(@"Connecting...", nil);
}

- (void)playerBeginBuffering:(GG977AudioStreamPlayer *)player {

}

- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error {
    self.stationInfo = nil;
    
    [self disablePlayerButtons];
    [self clearTrackInfoLabels];
    [self syncPlayPauseButton];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)playerDidPrepareForPlayback:(GG977AudioStreamPlayer *)player {
//    NSLog(@"playerDidPrepareForPlayback");
    
    [self enablePlayerButtons];
    [self clearTrackInfoLabels];
    
    self.trackInfoLabel.text = NSLocalizedString(@"Press play button to listen", nil);
    
//    [self.player start];
}

- (void)playerDidStartPlaying:(GG977AudioStreamPlayer *)player {
    [self syncPlayPauseButton];
}

- (void)playerDidPausePlaying:(GG977AudioStreamPlayer *)player {
    [self syncPlayPauseButton];
}

- (void)playerDidStopPlaying:(GG977AudioStreamPlayer *)player {
    [self syncPlayPauseButton];
}

- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info {
    NSLog(@"didReceiveTrackInfo");
    
    [self.spinner startAnimating];
    self.imageView.image = nil;
    
    self.trackInfo = info;
    
    if (self.trackInfo != nil) {
        self.artistInfoLabel.text = info.artist;
        self.trackInfoLabel.text = info.track;
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:self.trackInfo.imageUrl] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            self.imageView.image = [UIImage imageWithData:data];
            [self.spinner stopAnimating];
        }];
    } else {
        [self clearTrackInfoLabels];
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
