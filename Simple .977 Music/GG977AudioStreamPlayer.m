//
//  GG977AudioStreamPlayer.m
//  AudioQueueTest
//
//  Created by Gleb Gorelov on 12.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977AudioStreamPlayer.h"
#import <CFNetwork/CFNetwork.h>
#import <AudioToolbox/AudioToolbox.h>
#include <pthread.h>
#import "GG977StationInfo.h"

const int NUM_AQ_BUFS = 16;
const int AQ_DEFAULT_BUF_SIZE = 2048;
const int AQ_MAX_PACKET_DESCS = 512;

const int BIT_RATE_ESTIMATION_MAX_PACKETS = 5000;
const int BIT_RATE_ESTIMATION_MIN_PACKETS = 50;

NSString * const ASPAudioSessionInterruptionOccuredNotification = @"ASPAudioSessionInterruptionOccuredNotification";

NSString * const AS_NO_ERROR_STRING = @"No error.";
NSString * const AS_FILE_STREAM_GET_PROPERTY_FAILED_STRING = @"File stream get property failed.";
NSString * const AS_FILE_STREAM_SEEK_FAILED_STRING = @"File stream seek failed.";
NSString * const AS_FILE_STREAM_PARSE_BYTES_FAILED_STRING = @"Parse bytes failed.";
NSString * const AS_FILE_STREAM_OPEN_FAILED_STRING = @"Open audio file stream failed.";
NSString * const AS_FILE_STREAM_CLOSE_FAILED_STRING = @"Close audio file stream failed.";
NSString * const AS_AUDIO_QUEUE_CREATION_FAILED_STRING = @"Audio queue creation failed.";
NSString * const AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED_STRING = @"Audio buffer allocation failed.";
NSString * const AS_AUDIO_QUEUE_ENQUEUE_FAILED_STRING = @"Queueing of audio buffer failed.";
NSString * const AS_AUDIO_QUEUE_ADD_LISTENER_FAILED_STRING = @"Audio queue add listener failed.";
NSString * const AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED_STRING = @"Audio queue remove listener failed.";
NSString * const AS_AUDIO_QUEUE_START_FAILED_STRING = @"Audio queue start failed.";
NSString * const AS_AUDIO_QUEUE_BUFFER_MISMATCH_STRING = @"Audio queue buffers don't match.";
NSString * const AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING = @"Audio queue dispose failed.";
NSString * const AS_AUDIO_QUEUE_PAUSE_FAILED_STRING = @"Audio queue pause failed.";
NSString * const AS_AUDIO_QUEUE_STOP_FAILED_STRING = @"Audio queue stop failed.";
NSString * const AS_AUDIO_DATA_NOT_FOUND_STRING = @"No audio data found.";
NSString * const AS_AUDIO_QUEUE_FLUSH_FAILED_STRING = @"Audio queue flush failed.";
NSString * const AS_GET_AUDIO_TIME_FAILED_STRING = @"Audio queue get current time failed.";
NSString * const AS_AUDIO_STREAMER_FAILED_STRING = @"Audio playback failed";
NSString * const AS_NETWORK_CONNECTION_FAILED_STRING = @"Network connection failed";
NSString * const AS_AUDIO_BUFFER_TOO_SMALL_STRING = @"Audio packets are larger than %d.";


/**
 Enum Types
*/

typedef enum
{
    ASP_INITIALIZED = 0,
    ASP_STARTING_FILE_THREAD,
    ASP_WAITING_FOR_DATA,
    ASP_FLUSHING_EOF,
    ASP_WAITING_FOR_QUEUE_TO_START,
    ASP_PLAYING,
    ASP_BUFFERING,
    ASP_STOPPING,
    ASP_STOPPED,
    ASP_PAUSED
} AudioStreamPlayerState;

typedef enum
{
    ASP_NO_STOP = 0,
    ASP_STOPPING_EOF,
    ASP_STOPPING_USER_ACTION,
    ASP_STOPPING_ERROR,
    ASP_STOPPING_TEMPORARILY
} AudioStreamPlayerStopReason;

typedef enum
{
    ASP_NO_ERROR = 0,
    ASP_NETWORK_CONNECTION_FAILED,
    ASP_FILE_STREAM_GET_PROPERTY_FAILED,
    ASP_FILE_STREAM_SET_PROPERTY_FAILED,
    ASP_FILE_STREAM_SEEK_FAILED,
    ASP_FILE_STREAM_PARSE_BYTES_FAILED,
    ASP_FILE_STREAM_OPEN_FAILED,
    ASP_FILE_STREAM_CLOSE_FAILED,
    ASP_AUDIO_DATA_NOT_FOUND,
    ASP_AUDIO_QUEUE_CREATION_FAILED,
    ASP_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
    ASP_AUDIO_QUEUE_ENQUEUE_FAILED,
    ASP_AUDIO_QUEUE_ADD_LISTENER_FAILED,
    ASP_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
    ASP_AUDIO_QUEUE_START_FAILED,
    ASP_AUDIO_QUEUE_PAUSE_FAILED,
    ASP_AUDIO_QUEUE_BUFFER_MISMATCH,
    ASP_AUDIO_QUEUE_DISPOSE_FAILED,
    ASP_AUDIO_QUEUE_STOP_FAILED,
    ASP_AUDIO_QUEUE_FLUSH_FAILED,
    ASP_AUDIO_STREAMER_FAILED,
    ASP_GET_AUDIO_TIME_FAILED,
    ASP_AUDIO_BUFFER_TOO_SMALL
} AudioStreamPlayerErrorCode;

#pragma mark -

@interface GG977AudioStreamPlayer ()

/*
 Чтобы Си функции видели эти методы
 */
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags;
- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer;
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID;
- (void)handleReadFromStream:(CFReadStreamRef)aStream eventType:(CFStreamEventType)eventType;

@property (nonatomic, strong) GG977StationInfo *station;            // Данные станции с который стримим
@property (nonatomic, strong) GG977MetadataParser *metadataParser;  // Парсер метаданных

@end

#pragma mark - Audio Callback Function Implementations

/**
 Вызыватеся когда у AudioFileStream есть пакеты, которые можно проиграть. Создает AudioQueue для проигрывания.
 */
static void ASPPropertyListenerProc(void *						inClientData,
                                   AudioFileStreamID				inAudioFileStream,
                                   AudioFileStreamPropertyID		inPropertyID,
                                   UInt32 *						ioFlags)
{
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientData;
    [streamer handlePropertyChangeForFileStream:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

/**
 Когда у AudioStream есть пакеты для проигрывания, эта функция берет неактивные аудио буффер и копирует пакеты в него.
 */
static void ASPPacketsProc(void *						inClientData,
                          UInt32						inNumberBytes,
                          UInt32						inNumberPackets,
                          const void *					inInputData,
                          AudioStreamPacketDescription	*inPacketDescriptions)
{
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientData;
    [streamer handleAudioPackets:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
}

/**
 Вызывается AudioQueue когда некоторые бефферы были использованы для проигрывания. Эта функция сигнализирует, что есть буфферы готовые для новых данных.
 */
static void ASPAudioQueueOutputCallback(void*				inClientData,
                                       AudioQueueRef			inAQ,
                                       AudioQueueBufferRef		inBuffer)
{
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer*)inClientData;
    [streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

static void ASPAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inUserData;
    [streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

/**
 Обрабатывает прерывания аудио сессии
 */
static void ASPAudioSessionInterruptionListener(__unused void * inClientData, UInt32 inInterruptionState) {
    [[NSNotificationCenter defaultCenter] postNotificationName:ASPAudioSessionInterruptionOccuredNotification object:@(inInterruptionState)];
}

/**
 Обрабатывает вытаскивание наушников
 */
void ASPAudioRouteChangeListenerCallback (
                                          void                      *inUserData,
                                          AudioSessionPropertyID    inPropertyID,
                                          UInt32                    inPropertyValueSize,
                                          const void                *inPropertyValue)
{
    // Code here
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
    
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inUserData;
    
    CFDictionaryRef routeChangeDictionary = inPropertyValue;
    
    CFNumberRef routeChangeReasonRef =
    CFDictionaryGetValue (routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
    
    SInt32 routeChangeReason;
    
    CFNumberGetValue (routeChangeReasonRef,
                      kCFNumberSInt32Type,
                      &routeChangeReason);
    
    CFStringRef oldRouteRef =
    CFDictionaryGetValue (routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_OldRoute));
    
    NSString *oldRouteString = (__bridge NSString *)oldRouteRef;
    
    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
    {
        // Если причина заключается в том, что были извлечены наушники или внешний выход (?),
        // Тогда останавливаем прогирывание
        if ([oldRouteString isEqualToString:@"Headphone"] || [oldRouteString isEqualToString:@"LineOut"])
        {
            [streamer stop];
        }
    }
}

#pragma mark - CFReadStream Callback Function Implementations

/**
 Передает все что полученно из инета в AudioFileStream.
 */
static void ASReadStreamCallBack (CFReadStreamRef aStream, CFStreamEventType eventType, void* inClientInfo)
{
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientInfo;
    [streamer handleReadFromStream:aStream eventType:eventType];
}

#pragma mark -

@implementation GG977AudioStreamPlayer {
    
    AudioQueueRef                   _audioQueue;
    AudioFileStreamID               _audioFileStream;
    AudioStreamBasicDescription     _asbd;
    NSThread *                      _internalThread;  // поток, в котором происходит вся загрузка и парсинг
    
    AudioStreamPlayerState          _state;
    AudioStreamPlayerState          _laststate;
    AudioStreamPlayerStopReason     _stopReason;
    AudioStreamPlayerErrorCode      _errorCode;
    OSStatus                        _err;
    
    CFReadStreamRef                 _stream;
    
    AudioQueueBufferRef             _audioQueueBuffer[NUM_AQ_BUFS];
    AudioStreamPacketDescription    _packetDescs[AQ_MAX_PACKET_DESCS];
    unsigned int                    _fillBufferIndex;       // индекс audioQueueBuffer, который заполняется
    UInt32                          _packetBufferSize;
    size_t                          _bytesFilled;			// сколько байт заполнено
    size_t                          _packetsFilled;         // сколько пакетов заполнено
    bool                            _inuse[NUM_AQ_BUFS];	// флаги показывающие, что буферы все еще используются
    NSInteger                       _buffersUsed;
    NSDictionary *                  _httpHeaders;
    
    pthread_mutex_t                 _queueBuffersMutex;			// a mutex to protect the inuse flags
    pthread_cond_t                  _queueBufferReadyCondition;	// a condition varable for
                                                                // handling the inuse flags
    
    UInt64                          _processedPacketsCount;
    UInt64                          _processedPacketsSizeTotal;
    
    double                          _sampleRate;
    double                          _packetDuration;
}

#pragma mark - init

- (id)initWithStation:(GG977StationInfo *)station
{
    if (station == nil) {
        return nil;
    }
    
    self = [super init];
    if (self != nil)
    {
//        NSLog(@"PLAYER - INIT");
//        NSLog(@"%@", station);
        _station = station;
        _metadataParser = [[GG977MetadataParser alloc] initWithInterval:3];
        _metadataParser.stationID = _station.externalID;
        _metadataParser.delegate = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruptionChangeToState:) name:ASPAudioSessionInterruptionOccuredNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"PLAYER - DEALLOC");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASPAudioSessionInterruptionOccuredNotification object:nil];
    
    [self stop];
}

#pragma mark - _state handling

/**
 Отправляет оповещения делегату в главный поток
 */
- (void)mainThreadStateNotification
{
    NSString *strState;
    switch (_state) {
        case ASP_INITIALIZED:
            strState = @"AS_INITIALIZED";
//            if ([self.delegate respondsToSelector:@selector(playerDidPrepareForPlayback:)] && _errorCode == ASP_NO_ERROR) {
//                [self.delegate playerDidPrepareForPlayback:self];
//            }
            break;
        case ASP_STARTING_FILE_THREAD:
            strState = @"AS_STARTING_FILE_THREAD";
//            if ([self.delegate respondsToSelector:@selector(playerBeginConnection:)]) {
//                [self.delegate playerBeginConnection:self];
//            }
            break;
        case ASP_WAITING_FOR_DATA:
            strState = @"AS_WAITING_FOR_DATA";
            break;
        case ASP_FLUSHING_EOF:
            strState = @"AS_FLUSHING_EOF";
            break;
        case ASP_WAITING_FOR_QUEUE_TO_START:
            strState = @"AS_WAITING_FOR_QUEUE_TO_START";
            [self.metadataParser start];
            if ([self.delegate respondsToSelector:@selector(playerDidStartReceivingTrackInfo:)]) {
                [self.delegate playerDidStartReceivingTrackInfo:self];
            }
            break;
        case ASP_PLAYING:
            strState = @"AS_PLAYING";
//            if ([self.delegate respondsToSelector:@selector(playerDidStartPlaying:)]) {
//                [self.delegate playerDidStartPlaying:self];
//            }
            break;
        case ASP_BUFFERING:
            strState = @"AS_BUFFERING";
//            if ([self.delegate respondsToSelector:@selector(playerBeginBuffering:)]) {
//                [self.delegate playerBeginBuffering:self];
//            }
            break;
        case ASP_STOPPING:
            strState = @"AS_STOPPING";
//            if ([self.delegate respondsToSelector:@selector(playerDidStopPlaying:)]) {
//                [self.delegate playerDidStopPlaying:self];
//            }
            break;
        case ASP_STOPPED:
            strState = @"AS_STOPPED";
//            if ([self.delegate respondsToSelector:@selector(playerDidStopPlaying:)]) {
//                [self.delegate playerDidStopPlaying:self];
//            }
            break;
        case ASP_PAUSED:
            strState = @"AS_PAUSED";
//            if ([self.delegate respondsToSelector:@selector(playerDidPausePlaying:)]) {
//                [self.delegate playerDidPausePlaying:self];
//            }
            break;
        default:
            strState = @"UNKNOWN";
            break;
    }
    
    NSLog(@"state = %@", strState);
}

- (AudioStreamPlayerState)state
{
    @synchronized(self)
    {
        return _state;
    }
}

/**
 После установки состояния, отправляет уведомления делегату
 */
- (void)setState:(AudioStreamPlayerState)status
{
    @synchronized(self)
    {
        if (_state != status)
        {
            _state = status;
            
            if ([[NSThread currentThread] isEqual:[NSThread mainThread]])
            {
                [self mainThreadStateNotification];
            }
            else
            {
                [self
                 performSelectorOnMainThread:@selector(mainThreadStateNotification)
                 withObject:nil
                 waitUntilDone:NO];
            }
        }
    }
}

#pragma mark - Change Player state

/**
 Старует процесс прогирывания в новом потоке
*/
- (void)start
{
    NSLog(@"start");
    @synchronized (self)
    {
        // Если проигрывание было остановлено, то возобнавляем проигрывание
        if (_state == ASP_PAUSED)
        {
            [self resume];
        }
        // Если первый запуск, то запускаем работу внутреннего потока
        else if (_state == ASP_INITIALIZED)
        {
            NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
                     @"Playback can only be started from the main thread.");
            self.state = ASP_STARTING_FILE_THREAD;
            _internalThread =
            [[NSThread alloc]
             initWithTarget:self
             selector:@selector(startInternal)
             object:nil];
            [_internalThread start];
//#warning перенести?
//            // стартуем парсинг метаданных
//            [self.metadataParser start];
        }
    }
}

- (void)stop
{
    NSLog(@"stop");
    [self.metadataParser stop];
    @synchronized(self)
    {
        if (_audioQueue &&
            (_state == ASP_PLAYING || _state == ASP_PAUSED ||
             _state == ASP_BUFFERING || _state == ASP_WAITING_FOR_QUEUE_TO_START))
        {
            self.state = ASP_STOPPING;
            _stopReason = ASP_STOPPING_USER_ACTION;
            _err = AudioQueueStop(_audioQueue, true);
            if (_err)
            {
                [self failWithErrorCode:ASP_AUDIO_QUEUE_STOP_FAILED];
                return;
            }
        }
        else if (_state != ASP_INITIALIZED)
        {
            self.state = ASP_STOPPED;
            _stopReason = ASP_STOPPING_USER_ACTION;
        }
    }
    
    while (_state != ASP_INITIALIZED)
    {
        [NSThread sleepForTimeInterval:0.1];
    }
}

- (void)pause {
    NSLog(@"pause");
    @synchronized(self)
    {
        if (_state == ASP_PLAYING || _state == ASP_STOPPING)
        {
            _err = AudioQueuePause(_audioQueue);
            if (_err)
            {
                [self failWithErrorCode:ASP_AUDIO_QUEUE_PAUSE_FAILED];
                return;
            }
            _laststate = _state;
            self.state = ASP_PAUSED;
        }
    }
}

- (void)resume {
    @synchronized(self)
    {
        if (_state == ASP_PAUSED)
        {
            _err = AudioQueueStart(_audioQueue, NULL);
            if (_err)
            {
                [self failWithErrorCode:ASP_AUDIO_QUEUE_START_FAILED];
                return;
            }
            self.state = _laststate;
        }
    }
}

#pragma mark - Player state
- (BOOL)isPlaying {
    if (_state == ASP_PLAYING)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isPaused {
    if (_state == ASP_PAUSED)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isWaiting {
    @synchronized(self)
    {
        if (_state == ASP_STARTING_FILE_THREAD       ||
            _state == ASP_WAITING_FOR_DATA           ||
            _state == ASP_WAITING_FOR_QUEUE_TO_START ||
            _state == ASP_BUFFERING)
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isFinishing
{
    @synchronized (self)
    {
        if ((_errorCode != ASP_NO_ERROR && _state != ASP_INITIALIZED) ||
            ((_state == ASP_STOPPING || _state == ASP_STOPPED) &&
             _stopReason != ASP_STOPPING_TEMPORARILY))
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isIdle {
    if (_state == ASP_INITIALIZED)
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isAborted {
    if (_state == ASP_STOPPING && _stopReason == ASP_STOPPING_ERROR)
    {
        return YES;
    }
    
    return NO;
}

#pragma mark - Internal Thread Work

- (void)startInternal
{
    @synchronized(self)
    {
        if (_state != ASP_STARTING_FILE_THREAD)
        {
            if (_state != ASP_STOPPING &&
                _state != ASP_STOPPED)
            {
                NSLog(@"### Not starting audio thread. State code is: %ld", (long)_state);
            }
            self.state = ASP_INITIALIZED;
            return;
        }
        
        //
        // Натсройка audio session чтобы проигрывать в фоне музыку.
        //
        AudioSessionInitialize (
                                NULL,                          // 'NULL' to use the default (main) run loop
                                NULL,                          // 'NULL' to use the default run loop mode
                                ASPAudioSessionInterruptionListener,  // a reference to your interruption callback
                                (__bridge void *)(self)                       // data to pass to your interruption listener callback
                                );
        UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
        AudioSessionSetProperty (
                                 kAudioSessionProperty_AudioCategory,
                                 sizeof (sessionCategory),
                                 &sessionCategory
                                 );
        
        AudioSessionAddPropertyListener (
                                         kAudioSessionProperty_AudioRouteChange,
                                         ASPAudioRouteChangeListenerCallback,
                                         (__bridge void *)(self));
        
        AudioSessionSetActive(true);
        
        pthread_mutex_init(&_queueBuffersMutex, NULL);
        pthread_cond_init(&_queueBufferReadyCondition, NULL);
        
        // Если не смогли открыть стрим, то производим очистку
        if (![self openReadStream])
        {
            [self cleanup];
            return;
        }
    }
    
    //
    // Обрабатываем run loop до тех пор пока проигрывание не завершится или произойдет ошибка.
    //
    BOOL isRunning = YES;
    do
    {
        isRunning = [[NSRunLoop currentRunLoop]
                     runMode:NSDefaultRunLoopMode
                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
        
        if (_buffersUsed == 0 && self.state == ASP_PLAYING)
        {
            _err = AudioQueuePause(_audioQueue);
            if (_err)
            {
                [self failWithErrorCode:ASP_AUDIO_QUEUE_PAUSE_FAILED];
                return;
            }
            self.state = ASP_BUFFERING;
        }
    } while (isRunning && ![self runLoopShouldExit]);
    
    [self cleanup];
}

- (void)cleanup {
    NSLog(@"cleanup");
    @synchronized(self)
    {
        // Очищаем stream если он все еще открыт
        if (_stream)
        {
            CFReadStreamClose(_stream);
            CFRelease(_stream);
            _stream = nil;
        }
        
        // Закрываем стрим аудио файла
        if (_audioFileStream)
        {
            _err = AudioFileStreamClose(_audioFileStream);
            _audioFileStream = nil;
            if (_err)
            {
                [self failWithErrorCode:ASP_FILE_STREAM_CLOSE_FAILED];
            }
        }
        
        // Удаляем Audio Queue
        if (_audioQueue)
        {
            _err = AudioQueueDispose(_audioQueue, true);
            _audioQueue = nil;
            if (_err)
            {
                [self failWithErrorCode:ASP_AUDIO_QUEUE_DISPOSE_FAILED];
            }
        }
        
        pthread_mutex_destroy(&_queueBuffersMutex);
        pthread_cond_destroy(&_queueBufferReadyCondition);
        
        AudioSessionSetActive(false);
        
        _httpHeaders = nil;
        
        _bytesFilled = 0;
        _packetsFilled = 0;
        _packetBufferSize = 0;
        self.state = ASP_INITIALIZED;
        
        _internalThread = nil;
    }
}

/**
 Открыает audioFileStream для парсинга данных
 */
- (BOOL)openReadStream
{
//    NSLog(@"openReadStream");
    @synchronized(self)
    {
        NSAssert([[NSThread currentThread] isEqual:_internalThread],
                 @"File stream download must be started on the internalThread");
        NSAssert(_stream == nil, @"Download stream already initialized");
        
        // Создаем HTTP GET запрос
        CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL, (CFStringRef)@"GET", (__bridge CFURLRef)self.station.url, kCFHTTPVersion1_1);
        
        // Создаем read stream, который будет получать даныне с HTTP запроса
        _stream = CFReadStreamCreateForHTTPRequest(NULL, message);
        CFRelease(message);
        
        // Включаем редирект
        if (CFReadStreamSetProperty(
                                    _stream,
                                    kCFStreamPropertyHTTPShouldAutoredirect,
                                    kCFBooleanTrue) == false)
        {
            [self failWithErrorCode:ASP_FILE_STREAM_SET_PROPERTY_FAILED];
            
            return NO;
        }
        
        // Обрабатываем прокси
        CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
        CFReadStreamSetProperty(_stream, kCFStreamPropertyHTTPProxy, proxySettings);
        CFRelease(proxySettings);
        
        // устанавливаем состояние, что мы готовы к приему данных
        self.state = ASP_WAITING_FOR_DATA;
        
        // Открываем stream
        if (!CFReadStreamOpen(_stream))
        {
            CFRelease(_stream);
            [self failWithErrorCode:ASP_FILE_STREAM_OPEN_FAILED];
            return NO;
        }
        
        // Устанавливаем callback функцию, которая будет получать данные
        CFStreamClientContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        CFReadStreamSetClient(
                              _stream,
                              kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered,
                              ASReadStreamCallBack,
                              &context);
        CFReadStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    }
    
    return YES;
}

- (BOOL)runLoopShouldExit
{
    @synchronized(self)
    {
        if (_errorCode != ASP_NO_ERROR ||
            (_state == ASP_STOPPED &&
             _stopReason != ASP_STOPPING_TEMPORARILY))
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - NSNotificationCenter handlers

- (void)handleInterruptionChangeToState:(NSNotification *)notification {
    NSLog(@"handleInterruptionChangeToState");
    AudioQueuePropertyID inInterruptionState =
                (AudioQueuePropertyID) [notification.object unsignedIntValue];
    if (inInterruptionState == kAudioSessionBeginInterruption)
    {
            [self stop];
    }
}

#pragma mark - Errors handing

/**
 Преобразует код ошибки с сообщение
 */
+ (NSString *)stringForErrorCode:(AudioStreamPlayerErrorCode)anErrorCode
{
    switch (anErrorCode)
    {
        case ASP_NO_ERROR:
            return AS_NO_ERROR_STRING;
        case ASP_FILE_STREAM_GET_PROPERTY_FAILED:
            return AS_FILE_STREAM_GET_PROPERTY_FAILED_STRING;
        case ASP_FILE_STREAM_SEEK_FAILED:
            return AS_FILE_STREAM_SEEK_FAILED_STRING;
        case ASP_FILE_STREAM_PARSE_BYTES_FAILED:
            return AS_FILE_STREAM_PARSE_BYTES_FAILED_STRING;
        case ASP_AUDIO_QUEUE_CREATION_FAILED:
            return AS_AUDIO_QUEUE_CREATION_FAILED_STRING;
        case ASP_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED:
            return AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED_STRING;
        case ASP_AUDIO_QUEUE_ENQUEUE_FAILED:
            return AS_AUDIO_QUEUE_ENQUEUE_FAILED_STRING;
        case ASP_AUDIO_QUEUE_ADD_LISTENER_FAILED:
            return AS_AUDIO_QUEUE_ADD_LISTENER_FAILED_STRING;
        case ASP_AUDIO_QUEUE_REMOVE_LISTENER_FAILED:
            return AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED_STRING;
        case ASP_AUDIO_QUEUE_START_FAILED:
            return AS_AUDIO_QUEUE_START_FAILED_STRING;
        case ASP_AUDIO_QUEUE_BUFFER_MISMATCH:
            return AS_AUDIO_QUEUE_BUFFER_MISMATCH_STRING;
        case ASP_FILE_STREAM_OPEN_FAILED:
            return AS_FILE_STREAM_OPEN_FAILED_STRING;
        case ASP_FILE_STREAM_CLOSE_FAILED:
            return AS_FILE_STREAM_CLOSE_FAILED_STRING;
        case ASP_AUDIO_QUEUE_DISPOSE_FAILED:
            return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
        case ASP_AUDIO_QUEUE_PAUSE_FAILED:
            return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
        case ASP_AUDIO_QUEUE_FLUSH_FAILED:
            return AS_AUDIO_QUEUE_FLUSH_FAILED_STRING;
        case ASP_AUDIO_DATA_NOT_FOUND:
            return AS_AUDIO_DATA_NOT_FOUND_STRING;
        case ASP_GET_AUDIO_TIME_FAILED:
            return AS_GET_AUDIO_TIME_FAILED_STRING;
        case ASP_NETWORK_CONNECTION_FAILED:
            return AS_NETWORK_CONNECTION_FAILED_STRING;
        case ASP_AUDIO_QUEUE_STOP_FAILED:
            return AS_AUDIO_QUEUE_STOP_FAILED_STRING;
        case ASP_AUDIO_STREAMER_FAILED:
            return AS_AUDIO_STREAMER_FAILED_STRING;
        case ASP_AUDIO_BUFFER_TOO_SMALL:
            return [NSString stringWithFormat:AS_AUDIO_BUFFER_TOO_SMALL_STRING, AQ_DEFAULT_BUF_SIZE];
        default:
            return AS_AUDIO_STREAMER_FAILED_STRING;
    }
    
    return AS_AUDIO_STREAMER_FAILED_STRING;
}

- (void)failWithErrorCode:(AudioStreamPlayerErrorCode)anErrorCode
{
    @synchronized(self)
    {
        if (_errorCode != ASP_NO_ERROR)
        {
            return;
        }
        
        _errorCode = anErrorCode;
        
        if (_err)
        {
            char *errChars = (char *)&_err;
            NSLog(@"%@ err: %c%c%c%c %d\n",
                  [GG977AudioStreamPlayer stringForErrorCode:anErrorCode],
                  errChars[3], errChars[2], errChars[1], errChars[0],
                  (int)_err);
        }
        else
        {
            NSLog(@"%@", [GG977AudioStreamPlayer stringForErrorCode:anErrorCode]);
        }
        
        if (_state == ASP_PLAYING    ||
            _state == ASP_PAUSED     ||
            _state == ASP_BUFFERING)
        {
            self.state = ASP_STOPPING;
            _stopReason = ASP_STOPPING_ERROR;
            AudioQueueStop(_audioQueue, true);
        }
        
//        [self cleanup];
        
//        self.state = ASP_STOPPING;
//        _stopReason = ASP_STOPPING_ERROR;
//        AudioQueueStop(_audioQueue, true);
        
        if ([self.delegate respondsToSelector:@selector(player:failedToPrepareForPlaybackWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"GG977AudioStreamPlayer"
                    code:anErrorCode
                userInfo:[NSDictionary dictionaryWithObject:
                    [GG977AudioStreamPlayer stringForErrorCode:anErrorCode]
                                                        forKey:NSLocalizedDescriptionKey]];
            
            [self performSelectorOnMainThread:@selector(playerFailedToPrepareForPlaybackWithError:)
                                   withObject:error
                                waitUntilDone:NO];
        }
    }
}

- (void)playerFailedToPrepareForPlaybackWithError:(NSError *)error {
    [self.delegate player:self failedToPrepareForPlaybackWithError:error];
}

#pragma mark - handlers

/**
 Считывает данные со стрима в AudioFileStream
 */
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType
{
    if (aStream != _stream)
    {
        return;
    }
    
    if (eventType == kCFStreamEventErrorOccurred)
    {
        [self failWithErrorCode:ASP_AUDIO_DATA_NOT_FOUND];
    }
    else if (eventType == kCFStreamEventHasBytesAvailable)
    {
        if (!_httpHeaders)
        {
            CFTypeRef message =
            CFReadStreamCopyProperty(_stream, kCFStreamPropertyHTTPResponseHeader);
            _httpHeaders =
            (__bridge NSDictionary *)CFHTTPMessageCopyAllHeaderFields((CFHTTPMessageRef)message);
            CFRelease(message);
        }
        
        if (!_audioFileStream)
        {
            _err = AudioFileStreamOpen((__bridge void *)(self), ASPPropertyListenerProc, ASPPacketsProc,
                                      kAudioFileAAC_ADTSType, &_audioFileStream);
            if (_err)
            {
                [self failWithErrorCode:ASP_FILE_STREAM_OPEN_FAILED];
                return;
            }
        }
        
        UInt8 bytes[AQ_DEFAULT_BUF_SIZE];
        CFIndex length;
        @synchronized(self)
        {
            if ([self isFinishing] || !CFReadStreamHasBytesAvailable(_stream))
            {
                return;
            }
            
            length = CFReadStreamRead(_stream, bytes, AQ_DEFAULT_BUF_SIZE);
            if (length == -1)
            {
                [self failWithErrorCode:ASP_AUDIO_DATA_NOT_FOUND];
                return;
            }
            
            if (length == 0)
            {
                return;
            }
        }
        
        _err = AudioFileStreamParseBytes(_audioFileStream, length, bytes, 0);
        if (_err)
        {
            [self failWithErrorCode:ASP_FILE_STREAM_PARSE_BYTES_FAILED];
            return;
        }
    }
}

- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags
{
    @synchronized(self)
    {
        if ([self isFinishing])
        {
            return;
        }
        
        if (inPropertyID == kAudioFileStreamProperty_DataFormat)
        {
            if (_asbd.mSampleRate == 0)
            {
                UInt32 asbdSize = sizeof(_asbd);
                
                // get the stream format.
                _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &_asbd);
                if (_err)
                {
                    [self failWithErrorCode:ASP_FILE_STREAM_GET_PROPERTY_FAILED];
                    return;
                }
            }
        }
        else if (inPropertyID == kAudioFileStreamProperty_FormatList)
        {
            Boolean outWriteable;
            UInt32 formatListSize;
            _err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
            if (_err)
            {
                [self failWithErrorCode:ASP_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            
            AudioFormatListItem *formatList = malloc(formatListSize);
            _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (_err)
            {
                free(formatList);
                [self failWithErrorCode:ASP_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
            {
                AudioStreamBasicDescription pasbd = formatList[i].mASBD;
                
                if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE ||
                    pasbd.mFormatID == kAudioFormatMPEG4AAC_HE_V2)
                {
                    // We've found HE-AAC, remember this to tell the audio queue
                    // when we construct it.
#if !TARGET_IPHONE_SIMULATOR
                    _asbd = pasbd;
#endif
                    break;
                }
            }
            free(formatList);
        }
        else
        {
//            NSLog(@"Property is %c%c%c%c", ((char *)&inPropertyID)[3], ((char *)&inPropertyID)[2], ((char *)&inPropertyID)[1], ((char *)&inPropertyID)[0]);
        }
    }
}

- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
{
    @synchronized(self)
    {
        if ([self isFinishing])
        {
            return;
        }
        
        if (!_audioQueue)
        {
            [self createQueue];
        }
    }

    for (int i = 0; i < inNumberPackets; ++i)
    {
        SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize   = inPacketDescriptions[i].mDataByteSize;
        size_t bufSpaceRemaining;
        
        if (_processedPacketsCount < BIT_RATE_ESTIMATION_MAX_PACKETS)
        {
            _processedPacketsSizeTotal += packetSize;
            _processedPacketsCount += 1;
        }
        
        @synchronized(self)
        {
            if ([self isFinishing])
            {
                return;
            }
            
            if (packetSize > _packetBufferSize)
            {
                [self failWithErrorCode:ASP_AUDIO_BUFFER_TOO_SMALL];
            }
            
            bufSpaceRemaining = _packetBufferSize - _bytesFilled;
        }
        
        if (bufSpaceRemaining < packetSize)
        {
            [self enqueueBuffer];
        }
        
        @synchronized(self)
        {
            if ([self isFinishing])
            {
                return;
            }
            
            if (_bytesFilled + packetSize > _packetBufferSize)
            {
                return;
            }
            
            AudioQueueBufferRef fillBuf = _audioQueueBuffer[_fillBufferIndex];
            memcpy((char*)fillBuf->mAudioData + _bytesFilled, (const char*)inInputData + packetOffset, packetSize);
            
            _packetDescs[_packetsFilled] = inPacketDescriptions[i];
            _packetDescs[_packetsFilled].mStartOffset = _bytesFilled;
            
            _bytesFilled += packetSize;
            _packetsFilled += 1;
        }
        
        size_t packetsDescsRemaining = AQ_MAX_PACKET_DESCS - _packetsFilled;
        if (packetsDescsRemaining == 0) {
            [self enqueueBuffer];
        }
    }
}

- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer
{
    unsigned int bufIndex = -1;
    for (unsigned int i = 0; i < NUM_AQ_BUFS; ++i)
    {
        if (inBuffer == _audioQueueBuffer[i])
        {
            bufIndex = i;
            break;
        }
    }
    
    if (bufIndex == -1)
    {
        [self failWithErrorCode:ASP_AUDIO_QUEUE_BUFFER_MISMATCH];
        pthread_mutex_lock(&_queueBuffersMutex);
        pthread_cond_signal(&_queueBufferReadyCondition);
        pthread_mutex_unlock(&_queueBuffersMutex);
        return;
    }
    
    pthread_mutex_lock(&_queueBuffersMutex);
    _inuse[bufIndex] = false;
    _buffersUsed--;
    
//    NSLog(@"Queued buffers: %ld", (long)_buffersUsed);
    
    pthread_cond_signal(&_queueBufferReadyCondition);
    pthread_mutex_unlock(&_queueBuffersMutex);
}

- (void)handlePropertyChange:(NSNumber *)num
{
    [self handlePropertyChangeForQueue:NULL propertyID:[num intValue]];
}

- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID
{
    if (![[NSThread currentThread] isEqual:_internalThread])
    {
        [self
         performSelector:@selector(handlePropertyChange:)
         onThread:_internalThread
         withObject:[NSNumber numberWithInt:inID]
         waitUntilDone:NO
         modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
        return;
    }
    @synchronized(self)
    {
        if (inID == kAudioQueueProperty_IsRunning)
        {
            if (_state == ASP_STOPPING)
            {
                UInt32 isRunning = 0;
                UInt32 size = sizeof(UInt32);
                AudioQueueGetProperty(_audioQueue, inID, &isRunning, &size);
                if (isRunning == 0)
                {
                    self.state = ASP_STOPPED;
                }
            }
            else if (_state == ASP_WAITING_FOR_QUEUE_TO_START)
            {
                [NSRunLoop currentRunLoop];
                self.state = ASP_PLAYING;
            }
        }
    }
}

#pragma mark - Queue management

- (void)enqueueBuffer
{
    @synchronized(self)
    {
        if ([self isFinishing] || _stream == 0)
        {
            return;
        }
        
        _inuse[_fillBufferIndex] = true;
        _buffersUsed++;
        
        AudioQueueBufferRef fillBuf = _audioQueueBuffer[_fillBufferIndex];
        fillBuf->mAudioDataByteSize = _bytesFilled;
        
        if (_packetsFilled)
        {
            _err = AudioQueueEnqueueBuffer(_audioQueue, fillBuf, _packetsFilled, _packetDescs);
        }
        else
        {
            _err = AudioQueueEnqueueBuffer(_audioQueue, fillBuf, 0, NULL);
        }
        
        if (_err)
        {
            [self failWithErrorCode:ASP_AUDIO_QUEUE_ENQUEUE_FAILED];
            return;
        }
        
        
        if (_state == ASP_BUFFERING ||
            _state == ASP_WAITING_FOR_DATA ||
            _state == ASP_FLUSHING_EOF ||
            (_state == ASP_STOPPED && _stopReason == ASP_STOPPING_TEMPORARILY))
        {
            if (_state == ASP_FLUSHING_EOF || _buffersUsed == NUM_AQ_BUFS - 1)
            {
                if (self.state == ASP_BUFFERING)
                {
                    _err = AudioQueueStart(_audioQueue, NULL);
                    if (_err)
                    {
                        [self failWithErrorCode:ASP_AUDIO_QUEUE_START_FAILED];
                        return;
                    }
                    self.state = ASP_PLAYING;
                }
                else
                {
                    self.state = ASP_WAITING_FOR_QUEUE_TO_START;
                    
                    _err = AudioQueueStart(_audioQueue, NULL);
                    if (_err)
                    {
                        [self failWithErrorCode:ASP_AUDIO_QUEUE_START_FAILED];
                        return;
                    }
                }
            }
        }
        
        if (++_fillBufferIndex >= NUM_AQ_BUFS) _fillBufferIndex = 0;
        _bytesFilled = 0;
        _packetsFilled = 0;
    }
    
    pthread_mutex_lock(&_queueBuffersMutex);
    while (_inuse[_fillBufferIndex])
    {
        pthread_cond_wait(&_queueBufferReadyCondition, &_queueBuffersMutex);
    }
    pthread_mutex_unlock(&_queueBuffersMutex);
}

- (void)createQueue
{
    _sampleRate = _asbd.mSampleRate;
    _packetDuration = _asbd.mFramesPerPacket / _sampleRate;
    
    _err = AudioQueueNewOutput(&_asbd, ASPAudioQueueOutputCallback, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue);
    if (_err)
    {
        [self failWithErrorCode:ASP_AUDIO_QUEUE_CREATION_FAILED];
        return;
    }

    _err = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, ASPAudioQueueIsRunningCallback, (__bridge void *)(self));
    if (_err)
    {
        [self failWithErrorCode:ASP_AUDIO_QUEUE_ADD_LISTENER_FAILED];
        return;
    }
    
    UInt32 sizeOfUInt32 = sizeof(UInt32);
    _err = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_packetBufferSize);
    if (_err || _packetBufferSize == 0)
    {
        _err = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_packetBufferSize);
        if (_err || _packetBufferSize == 0)
        {
            _packetBufferSize = AQ_DEFAULT_BUF_SIZE;
        }
    }
    
    for (unsigned int i = 0; i < NUM_AQ_BUFS; ++i)
    {
        _err = AudioQueueAllocateBuffer(_audioQueue, _packetBufferSize, &_audioQueueBuffer[i]);
        if (_err)
        {
            [self failWithErrorCode:ASP_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
            return;
        }
    }
    
    UInt32 cookieSize;
    Boolean writable;
    OSStatus ignorableError;
    ignorableError = AudioFileStreamGetPropertyInfo(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (ignorableError)
    {
        return;
    }
    
    void* cookieData = calloc(1, cookieSize);
    ignorableError = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (ignorableError)
    {
        return;
    }
    
    ignorableError = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
    free(cookieData);
    if (ignorableError)
    {
        return;
    }
}

#pragma mark - GG977MetadataParserDelegate

- (void)parser:(GG977MetadataParser *)parser didParseNewTrackInfo:(GG977TrackInfo *)trackInfo {
    //  проверка состояния на тот редкий случай, когда плеер остановлен немного позже чем получены метаданные
    NSLog(@"player - didParseNewTrackInfo:");
    if ([self.delegate respondsToSelector:@selector(player:didReceiveTrackInfo:)] &&
        ![self isFinishing] && ![self isIdle]) {
        [self.delegate player:self didReceiveTrackInfo:trackInfo];
    }
}


@end