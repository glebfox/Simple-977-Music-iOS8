//
//  GG977PlayStationViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 30.09.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977PlayerViewController.h"
#import "GG977StationsViewController.h"

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

@interface GG977PlayerViewController ()

@property (retain) AVPlayer *player;
@property (retain) AVPlayerItem *playerItem;

@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UISlider *audioVolumeSlider;
@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UILabel *artistInfo;
@property (weak, nonatomic) IBOutlet UILabel *trackInfo;
@property (weak, nonatomic) IBOutlet UILabel *stationTitle;

@property GG977StationsViewController *stationsController;  // Ссылка на форму с списом станций, чтобы знать какую выбрал пользователь

@end

@implementation GG977PlayerViewController

// Когда появляется форма с проигрывателем, мы должны узнать выбрал ли пользователь новую станцию и выбрал ли вообще
- (void)viewDidAppear:(BOOL)animated
{
    if (self.stationInfo != self.stationsController.selectedStation) {
        self.stationInfo = self.stationsController.selectedStation;
        
        self.stationTitle.text = self.stationInfo.title;
        self.trackInfo.text = @"Connecting...";
        self.artistInfo.text = @"";

        // Создаем asset для заданного url. Загружаем значения для ключей "tracks", "playable".
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.stationInfo.url options:nil];
        
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
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // При первом запуске получаем ссылку на форму с станциями и дисейблим кнопки, т.к. еще нечего проигрывать
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
    // В зависимости от состояния отображаем ту или иную картинку для кнопки
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
    [self isPlaying] ? [self.player pause] : [self.player play];
}

- (IBAction)changeVolume:(id)sender
{
    self.player.volume = self.audioVolumeSlider.value;
}

#pragma mark - Player Notifications

// Called when the player item has played to its end time.
// Не используется так как у стрима нет конца
- (void) playerItemDidReachEnd:(NSNotification*) notification
{
    NSLog(@"playerItemDidReachEnd");
}

#pragma mark - Timed metadata

// Обрабатывает метаданные
- (void)handleTimedMetadata:(AVMetadataItem*)timedMetadata
{
    if ([timedMetadata.commonKey isEqualToString:@"title"]) {
        // Здесь не совсем универсальная ситуация, поскольку разыне станцие по разному разделяют артиста и название трека
        NSArray *array = [[timedMetadata.value description] componentsSeparatedByString:@" - "];
        if (array.count > 1) {
            self.artistInfo.text = array[0];
            self.trackInfo.text = array[1];
        } else
            self.trackInfo.text = array[0];
    }
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
        NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"977Music" code:0 userInfo:errorDict];
        
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
    
    [self enablePlayerButtons];
    
    /* Если у нас уже был AVPlayerItem, то удаляем его обсервер. */
    if (self.playerItem)
    {
        [self.playerItem removeObserver:self forKeyPath:keyStatus];
        
//        [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                        name:AVPlayerItemDidPlayToEndTimeNotification
//                                                      object:self.playerItem];
    }
    
    // Создаем новый playerItem
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
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
    
    
    // Создаем нового player, если еще этого не делали
    if (![self player])
    {
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
        
        // Для отслеживания исзменения текущего playerItem
        [self.player addObserver:self
                      forKeyPath:keyCurrentItem
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:currentItemObserverContext];
        
        // Свойство 'currentItem.timedMetadata' для слежения за изменениями metadata
        [self.player addObserver:self
                      forKeyPath:keyTimedMetadata
                         options:0
                         context:timedMetadataObserverContext];
        
#warning посмотреть еще свойства
        // Свойство AVPlayer "rate", чтобы отслеживать запуск и останов проигрывания
        [self.player addObserver:self
                      forKeyPath:keyRate
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:rateObserverContext];
    }
    
    if (self.player.currentItem != self.playerItem)
    {
        [[self player] replaceCurrentItemWithPlayerItem:self.playerItem];
        
        NSLog(@"sync - self.player.currentItem != self.playerItem");
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
    // AVPlayerItem "status"
    if (context == playerItemStatusObserverContext)
    {
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            // Указывает на то, что player еще не имеет конкретного статуса, т.к. он еще не пробовал загрузить медиа данные
            case AVPlayerStatusUnknown:
            {
                [self disablePlayerButtons];
            }
                break;
            // AVPlayerItem готов к проигрыванию
            case AVPlayerStatusReadyToPlay:
            {
                [self enablePlayerButtons];
                self.audioVolumeSlider.value = self.player.volume;
                self.trackInfo.text = @"Getting metadata...";
                [self.player play];
                
            }
                break;
                
            case AVPlayerStatusFailed:
            {
                AVPlayerItem *thePlayerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:thePlayerItem.error];
            }
                break;
        }
    }
    // AVPlayer "rate"
    else if (context == rateObserverContext)
    {
        [self syncPlayPauseButton];
    }
    // AVPlayer "currentItem". Срабатывает когда AVPlayer вызывает replaceCurrentItemWithPlayerItem:
    else if (context == currentItemObserverContext)
    {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        // Если вдруг нечем проигрывать, то делаем кнопки неактивными
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            
        }
        else // А если есть чем проигрывать, то нам нечего тут делать пока что
        {
        }
    }
    // Обрабатываем изменения метаданных
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
