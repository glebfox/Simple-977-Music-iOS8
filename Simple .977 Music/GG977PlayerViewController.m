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

@property (assign, nonatomic) BOOL playerBeginConnection;

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
//    NSLog(@"gg977PlayerViewControllerInit");
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.delegate = self;
}

#pragma mark - View life-cycle

- (void)viewDidLoad {
    [super viewDidLoad];
//    NSLog(@"GG977PlayerViewController - viewDidLoad");
    
    [self disablePlayerButtons];
    [self clearTrackInfoLabels];
    [self syncPlayPauseButton];
    
    if (self.stationInfo != nil) {
        self.stationTitleLabel.text = self.stationInfo.title;
        self.imageView.image = [UIImage imageNamed:_stationInfo.title];
    } else {
        self.stationTitleLabel.text = NSLocalizedString(@"No Station Title", nil);
    }
    
    if ([self.player isIdle]) {
        [self playerDidPrepareForPlayback:nil];
    }
    
    if (self.playerBeginConnection) {
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
//    NSLog(@"setStationInfo");
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
        self.playerBeginConnection = NO;

        if ([self.player isIdle]) {
            [self playerDidPrepareForPlayback:nil];
        }
    }
}

#pragma mark - UI Updates

- (BOOL)playerShouldBeStopped {
    return [self.player isPlaying] || self.playerBeginConnection;
}

- (void)clearTrackInfoLabels
{
//    NSLog(@"clearTrackInfoLabels");
    self.artistInfoLabel.text = @"";
    self.trackInfoLabel.text = @"";
}

- (void)syncPlayPauseButton
{
//    NSLog(@"syncPlayPauseButton");
    UIImage *image = [[UIImage imageNamed: [self playerShouldBeStopped] ? @"stop" : @"play"]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.playStopButton setImage: image forState:UIControlStateNormal];
}

-(void)enablePlayerButtons
{
//    NSLog(@"enablePlayerButtons");
    self.playStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
//    NSLog(@"disablePlayerButtons");
    self.playStopButton.enabled = NO;
}

#pragma mark - Button Action Methods

- (IBAction)playPause:(id)sender
{
//    [self.player togglePlayPause];
    if ([self playerShouldBeStopped]) {
        [self.player stop];
    } else {
        [self.player start];
    }
}

//#warning test only
//- (IBAction)pause:(id)sender {
//    [self.player pause];
//}

#pragma mark - GG977AudioStreamPlayerDelegate

- (void)playerDidBeginConnection:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidBeginConnection");
    
    self.playerBeginConnection = YES;
    
//    [self disablePlayerButtons];
    [self syncPlayPauseButton];
    
    [self clearTrackInfoLabels];
    self.trackInfoLabel.text = NSLocalizedString(@"Connecting...", nil);
}

- (void)player:(GG977AudioStreamPlayer *)player failedToPrepareForPlaybackWithError:(NSError *)error {
    NSLog(@"playerFailedToPrepareForPlayback");
    
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
    NSLog(@"playerDidPrepareForPlayback");
    
    [self enablePlayerButtons];
    [self clearTrackInfoLabels];
    
    self.trackInfoLabel.text = NSLocalizedString(@"Press play button to listen", nil);
    
#warning test only
    [self parseTrackFromStationID:self.stationInfo.externalID];
    
//    [self.player start];
}

- (void)playerDidStartPlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidStartPlaying");
    
    if (self.playerBeginConnection) {
        self.playerBeginConnection = NO;
    }
    
    [self syncPlayPauseButton];
    
    [self clearTrackInfoLabels];
    self.trackInfoLabel.text = _stationInfo.title;
}

- (void)playerDidPausePlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidPausePlaying");
    
    if (self.playerBeginConnection) {
        self.playerBeginConnection = NO;
    }
    
    [self syncPlayPauseButton];
}

- (void)playerDidStopPlaying:(GG977AudioStreamPlayer *)player {
    NSLog(@"playerDidStopPlaying");
    
    if (self.playerBeginConnection) {
        self.playerBeginConnection = NO;
    }
    
    [self syncPlayPauseButton];
}

- (void)playerDidStartReceivingTrackInfo:(GG977AudioStreamPlayer *)player {
    self.trackInfoLabel.text = NSLocalizedString(@"Getting metadata...", nil);
}

- (void)player:(GG977AudioStreamPlayer *)player didReceiveTrackInfo:(GG977TrackInfo *)info {
    NSLog(@"didReceiveTrackInfo");
    
    self.trackInfo = info;
    
    self.artistInfoLabel.text = info.artist;
    self.trackInfoLabel.text = info.track;
    
    self.imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:info.imageUrl]];
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

- (void)parseTrackFromStationID:(NSUInteger)externalID {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://androidfm.org/977music/api/metadata/%d/", externalID]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"CONNECTION ERROR: %@", connectionError);
        } else {
            NSError *error;
            NSDictionary *dic;
            id jsonResult = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
//            if ([jsonResult class] == [NSCFDictionary class]) {
                dic = jsonResult;
//            } else {
//                self.trackInfo = nil;
//                return;
//            }
            
            if (error) {
                NSLog(@"JSON ERROR: %@", error);
                self.trackInfo = nil;
            } else {
                self.trackInfo = [GG977TrackInfo new];
                self.trackInfo.artist = dic[@"artist"];
                self.trackInfo.track = dic[@"name"];
                
                NSString *urlString = dic[@"img_url"];
                if (urlString != nil && [urlString class] != [NSNull class]) {
                    self.trackInfo.imageUrl = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
                }
                
                NSString *str = dic[@"album"];
                if (str != nil && [str class] != [NSNull class]) {
                    NSArray *array = [str componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
                    self.trackInfo.album = array[0];
                    if ([array count] > 1) self.trackInfo.year = array[1];
                }
                
                self.trackInfo.lyrics = dic[@"lyrics"];
            }
        }
    }];
}

@end
