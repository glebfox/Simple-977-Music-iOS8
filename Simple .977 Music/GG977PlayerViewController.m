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
//#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import "AppDelegate.h"
#import "GG977TrackInfo.h"

enum {
    StatePlayerNone,
    StatePlayerDidBeginConnection,
    StatePlayerDidPrepareForPlayback,
    StatePlayerFailed
};

@interface GG977PlayerViewController ()

@property (strong, nonatomic) GG977AudioStreamPlayer *player;

@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UILabel *artistInfo;
@property (weak, nonatomic) IBOutlet UILabel *trackInfo;
@property (weak, nonatomic) IBOutlet UILabel *stationTitle;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation GG977PlayerViewController {
    int _playerState;
}

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
    NSLog(@"gg977PlayerViewControllerInit");
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.delegate = self;
    
    _playerState = StatePlayerNone;
}

#pragma mark - View life-cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"GG977PlayerViewController - viewDidLoad");
    
    [self disablePlayerButtons];
    [self clearTrackInfoLabels];
    
    if (self.stationInfo != nil) {
        self.stationTitle.text = self.stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
    } else {
        self.stationTitle.text = NSLocalizedString(@"No Station Title", nil);
    }
    
    if (_playerState == StatePlayerDidBeginConnection) {
        NSLog(@"viewDidLoad - Connecting...");
        self.trackInfo.text = NSLocalizedString(@"Connecting...", nil);
    }
    
    if ([self.player isPlaying]) {
        self.trackInfo.text = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] objectForKey:MPMediaItemPropertyTitle];
        self.artistInfo.text = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] objectForKey:MPMediaItemPropertyArtist];
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
    NSLog(@"setStationInfo");
    if (![_stationInfo isEqual:stationInfo]) {
        _stationInfo = stationInfo;
    
        self.stationTitle.text = _stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
        
        if (self.player == nil) {
            self.player = [GG977AudioStreamPlayer new];
            self.player.delegate = self;
        }
        
        [self.player startNewConnectionWithUrl:_stationInfo.url];
    }
}

#pragma mark - UI Updates

- (void)clearTrackInfoLabels
{
    NSLog(@"clearTrackInfoLabels");
    self.artistInfo.text = @"";
    self.trackInfo.text = @"";
}

- (void)syncPlayPauseButton
{
    UIImage *image = [[UIImage imageNamed: [self.player isPlaying] ? @"pause" : @"play"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.playPauseButton setImage: image forState:UIControlStateNormal];
}

-(void)enablePlayerButtons
{
    NSLog(@"enablePlayerButtons");
    self.playPauseButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    NSLog(@"disablePlayerButtons");
    self.playPauseButton.enabled = NO;
}

#pragma mark - Button Action Methods

- (IBAction)playPause:(id)sender
{
    [self.player togglePlayPause];
}

#pragma mark - GG977AudioStreamPlayerDelegate

- (void)playerDidBeginConnection:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidBeginConnection");
    
    _playerState = StatePlayerDidBeginConnection;
    
    [self disablePlayerButtons];
    
    [self clearTrackInfoLabels];
    self.trackInfo.text = NSLocalizedString(@"Connecting...", nil);
}

- (void)playerFailedToPrepareForPlayback:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerFailedToPrepareForPlayback");
    
    _playerState = StatePlayerFailed;
    
    self.stationInfo = nil;
    
    [self disablePlayerButtons];
    [self clearTrackInfoLabels];
}

- (void)playerDidPrepareForPlayback:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidPrepareForPlayback");
    
    _playerState = StatePlayerDidPrepareForPlayback;
    
    [self enablePlayerButtons];
    [self clearTrackInfoLabels];
    self.trackInfo.text = NSLocalizedString(@"Getting metadata...", nil);
    
//    [self.player play];
}

- (void)playerDidStartPlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidStartPlaying");
    
    [self syncPlayPauseButton];
}

- (void)playerDidPausePlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidPausePlaying");
    
    [self syncPlayPauseButton];
}

- (void)playerDidStopPlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidStopPlaying");
    
    [self syncPlayPauseButton];
}

- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info {
    NSLog(@"didReceiveTrackInfo");
    
    self.artistInfo.text = info.artist;
    self.trackInfo.text = info.track;
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

@end
