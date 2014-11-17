//
//  GG977AudioStreamPlayer.m
//  AudioQueueTest
//
//  Created by Gleb Gorelov on 12.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977AudioStreamPlayer.h"
#import <CFNetwork/CFNetwork.h>
//#import <AVFoundation/AVFoundation.h>
#include <pthread.h>
#import "GG977StationInfo.h"

#define LOG_QUEUED_BUFFERS 0

const int NUM_AQ_BUFS = 16;
const int AQ_DEFAULT_BUF_SIZE = 2048;
const int AQ_MAX_PACKET_DESCS = 512;

const int BIT_RATE_ESTIMATION_MAX_PACKETS = 5000;
const int BIT_RATE_ESTIMATION_MIN_PACKETS = 50;

NSString * const ASStatusChangedNotification = @"ASStatusChangedNotification";
NSString * const ASAudioSessionInterruptionOccuredNotification = @"ASAudioSessionInterruptionOccuredNotification";

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
    AS_INITIALIZED = 0,
    AS_STARTING_FILE_THREAD,
    AS_WAITING_FOR_DATA,
    AS_FLUSHING_EOF,
    AS_WAITING_FOR_QUEUE_TO_START,
    AS_PLAYING,
    AS_BUFFERING,
    AS_STOPPING,
    AS_STOPPED,
    AS_PAUSED
} AudioStreamerState;

typedef enum
{
    AS_NO_STOP = 0,
    AS_STOPPING_EOF,
    AS_STOPPING_USER_ACTION,
    AS_STOPPING_ERROR,
    AS_STOPPING_TEMPORARILY
} AudioStreamerStopReason;

typedef enum
{
    AS_NO_ERROR = 0,
    AS_NETWORK_CONNECTION_FAILED,
    AS_FILE_STREAM_GET_PROPERTY_FAILED,
    AS_FILE_STREAM_SET_PROPERTY_FAILED,
    AS_FILE_STREAM_SEEK_FAILED,
    AS_FILE_STREAM_PARSE_BYTES_FAILED,
    AS_FILE_STREAM_OPEN_FAILED,
    AS_FILE_STREAM_CLOSE_FAILED,
    AS_AUDIO_DATA_NOT_FOUND,
    AS_AUDIO_QUEUE_CREATION_FAILED,
    AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
    AS_AUDIO_QUEUE_ENQUEUE_FAILED,
    AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,
    AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
    AS_AUDIO_QUEUE_START_FAILED,
    AS_AUDIO_QUEUE_PAUSE_FAILED,
    AS_AUDIO_QUEUE_BUFFER_MISMATCH,
    AS_AUDIO_QUEUE_DISPOSE_FAILED,
    AS_AUDIO_QUEUE_STOP_FAILED,
    AS_AUDIO_QUEUE_FLUSH_FAILED,
    AS_AUDIO_STREAMER_FAILED,
    AS_GET_AUDIO_TIME_FAILED,
    AS_AUDIO_BUFFER_TOO_SMALL
} AudioStreamerErrorCode;

@interface GG977AudioStreamPlayer ()

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

//- (void)handleInterruptionChangeToState:(NSNotification *)notification;

//- (void)internalSeekToTime:(double)newSeekTime;
//- (void)enqueueBuffer;
- (void)handleReadFromStream:(CFReadStreamRef)aStream eventType:(CFStreamEventType)eventType;

@property (nonatomic, strong) GG977StationInfo *station;

@end

#pragma mark - Audio Callback Function Implementations

/**
 Receives notification when the AudioFileStream has audio packets to be
 played. In response, this function creates the AudioQueue, getting it
 ready to begin playback (playback won't begin until audio packets are
 sent to the queue in ASEnqueueBuffer).

 This function is adapted from Apple's example in AudioFileStreamExample with
 kAudioQueueProperty_IsRunning listening added.
 */
static void ASPropertyListenerProc(void *						inClientData,
                                   AudioFileStreamID				inAudioFileStream,
                                   AudioFileStreamPropertyID		inPropertyID,
                                   UInt32 *						ioFlags)
{
//    NSLog(@"ASPropertyListenerProc");
    // this is called by audio file stream when it finds property values
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientData;
    [streamer handlePropertyChangeForFileStream:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

/**
 When the AudioStream has packets to be played, this function gets an
 idle audio buffer and copies the audio packets into it. The calls to
 ASEnqueueBuffer won't return until there are buffers available (or the
 playback has been stopped).

 This function is adapted from Apple's example in AudioFileStreamExample with
 CBR functionality added.
 */
static void ASPacketsProc(void *						inClientData,
                          UInt32						inNumberBytes,
                          UInt32						inNumberPackets,
                          const void *					inInputData,
                          AudioStreamPacketDescription	*inPacketDescriptions)
{
//    NSLog(@"ASPacketsProc");
    // this is called by audio file stream when it finds packets of audio
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientData;
    [streamer handleAudioPackets:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
}

/**
 Called from the AudioQueue when playback of specific buffers completes. This
 function signals from the AudioQueue thread to the AudioStream thread that
 the buffer is idle and available for copying data.

 This function is unchanged from Apple's example in AudioFileStreamExample.
 */
static void ASAudioQueueOutputCallback(void*				inClientData,
                                       AudioQueueRef			inAQ,
                                       AudioQueueBufferRef		inBuffer)
{
    //    NSLog(@"ASAudioQueueOutputCallback");
    // this is called by the audio queue when it has finished decoding our data.
    // The buffer is now free to be reused.
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer*)inClientData;
    [streamer handleBufferCompleteForQueue:inAQ buffer:inBuffer];
}

/**
 Called from the AudioQueue when playback is started or stopped. This
 information is used to toggle the observable "isPlaying" property and
 set the "finished" flag.
 */
static void ASAudioQueueIsRunningCallback(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID)
{
    //    NSLog(@"ASAudioQueueIsRunningCallback");
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inUserData;
    [streamer handlePropertyChangeForQueue:inAQ propertyID:inID];
}

/**
 Invoked if the audio session is interrupted (like when the phone rings)
 */
static void ASAudioSessionInterruptionListener(__unused void * inClientData, UInt32 inInterruptionState) {
//    NSLog(@"ASAudioSessionInterruptionListener");
    [[NSNotificationCenter defaultCenter] postNotificationName:ASAudioSessionInterruptionOccuredNotification object:@(inInterruptionState)];
}

#pragma mark - CFReadStream Callback Function Implementations

/**
 ReadStreamCallBack

 This is the callback for the CFReadStream from the network connection. This
 is where all network data is passed to the AudioFileStream.

 Invoked when an error occurs, the stream ends or we have data to read.
 */
static void ASReadStreamCallBack (CFReadStreamRef aStream, CFStreamEventType eventType, void* inClientInfo)
{
//    NSLog(@"ASReadStreamCallBack");
    GG977AudioStreamPlayer* streamer = (__bridge GG977AudioStreamPlayer *)inClientInfo;
    [streamer handleReadFromStream:aStream eventType:eventType];
}

#pragma mark - AudioRouteChange

void audioRouteChangeListenerCallback (
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
    CFDictionaryGetValue (
                          routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_Reason));
    
    SInt32 routeChangeReason;
    
    CFNumberGetValue (
                      routeChangeReasonRef,
                      kCFNumberSInt32Type,
                      &routeChangeReason);
    
    CFStringRef oldRouteRef =
    CFDictionaryGetValue (
                          routeChangeDictionary,
                          CFSTR (kAudioSession_AudioRouteChangeKey_OldRoute));
    
    NSString *oldRouteString = (__bridge NSString *)oldRouteRef;
    
    if (routeChangeReason == kAudioSessionRouteChangeReason_NewDeviceAvailable)
    {
        if ([oldRouteString isEqualToString:@"Speaker"])
        {
//            [controller.audioPlayer play];
        }
    }
    
    if (routeChangeReason ==
        kAudioSessionRouteChangeReason_OldDeviceUnavailable)
    {
        if ((([oldRouteString isEqualToString:@"Headphone"]) ||
             ([oldRouteString isEqualToString:@"LineOut"])))
        {
            [streamer stop];
        }
    }
}

@implementation GG977AudioStreamPlayer {
    NSURL *_url;     // URL стрима
    
    //
    // Special threading consideration:
    //	The audioQueue property should only ever be accessed inside a
    //	synchronized(self) block and only *after* checking that ![self isFinishing]
    //
    AudioQueueRef                   _audioQueue;
    AudioFileStreamID               _audioFileStream;	// the audio file stream parser
    AudioStreamBasicDescription     _asbd;              // description of the audio
    NSThread *                      _internalThread;	// the thread where the download and audio file
                                                        // stream parsing occurs
    
    AudioStreamerState              _state;
    AudioStreamerState              _laststate;
    AudioStreamerStopReason         _stopReason;
    AudioStreamerErrorCode          _errorCode;
    OSStatus                        _err;
    
    CFReadStreamRef                 _stream;            // Стрим для чтения потока
    NSNotificationCenter *          _notificationCenter;
    
    AudioQueueBufferRef             _audioQueueBuffer[NUM_AQ_BUFS];		// audio queue buffers
    AudioStreamPacketDescription    _packetDescs[AQ_MAX_PACKET_DESCS];	// packet descriptions
                                                                        // for enqueuing audio
    unsigned int                    _fillBufferIndex;       // the index of the audioQueueBuffer
                                                            // that is being filled
    UInt32                          _packetBufferSize;
    size_t                          _bytesFilled;			// how many bytes have been filled
    size_t                          _packetsFilled;         // how many packets have been filled
    bool                            _inuse[NUM_AQ_BUFS];	// flags to indicate that a buffer is still in use
    NSInteger                       _buffersUsed;
    NSDictionary *                  _httpHeaders;
#warning не нужен
    bool                            _discontinuous;             // flag to indicate middle of the stream
    
    pthread_mutex_t                 _queueBuffersMutex;			// a mutex to protect the inuse flags
    pthread_cond_t                  _queueBufferReadyCondition;	// a condition varable for
                                                                // handling the inuse flags
    
    UInt32                          _bitRate;                   // Bits per second in the file
    NSInteger                       _dataOffset;        // Offset of the first audio packet in the stream
    NSInteger                       _fileLength;		// Length of the file in bytes
    NSInteger                       _seekByteOffset;	// Seek offset within the file in bytes
    UInt64                          _audioDataByteCount;// Used when the actual number of audio bytes in
                                                        // the file is known (more accurate than assuming
                                                        // the whole file is audio)
    
    UInt64                          _processedPacketsCount;		// number of packets accumulated for bitrate estimation
    UInt64                          _processedPacketsSizeTotal;	// byte size of accumulated estimation packets
    
    double                          _seekTime;
    BOOL                            _seekWasRequested;
    double                          _requestedSeekTime;
    double                          _sampleRate;		// Sample rate of the file (used to compare with
                                                        // samples played by the queue for current playback
                                                        // time)
    double                          _packetDuration;	// sample rate times frames per packet
    double                          _lastProgress;		// last calculated progress point
    
//    BOOL                            _pausedByInterruption;
}

#pragma mark - init

- (id)initWithStation:(GG977StationInfo *)station
{
    self = [super init];
    if (self != nil)
    {
        NSLog(@"PLAYER - INIT");
        NSLog(@"%@", station);
        _station = station;
#warning delete _url
        _url = _station.url;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruptionChangeToState:) name:ASAudioSessionInterruptionOccuredNotification object:nil];
        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(routeChanged:)
//                                                     name:AVAudioSessionRouteChangeNotification
//                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"PLAYER - DEALLOC");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASAudioSessionInterruptionOccuredNotification object:nil];
    
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:name:AVAudioSessionRouteChangeNotification object:nil];
    
    [self stop];
}

//#pragma mark -
//
//- (void)setURL:(NSURL *)url {
//    _url = url;
//    self.state = AS_INITIALIZED;
//}

#pragma mark - _state handling

/**
 Method invoked on main thread to send notifications to the main thread's notification center.
 */
- (void)mainThreadStateNotification
{
    //    NSLog(@"mainThreadStateNotification");
    //    NSNotification *notification = [NSNotification
    //                                    notificationWithName:ASStatusChangedNotification object:self];
    //    [[NSNotificationCenter defaultCenter] postNotification:notification];
    
    NSString *strState;
    switch (_state) {
        case AS_INITIALIZED:
            strState = @"AS_INITIALIZED";
            if ([self.delegate respondsToSelector:@selector(playerDidPrepareForPlayback:)]) {
                [self.delegate playerDidPrepareForPlayback:self];
            }
            break;
        case AS_STARTING_FILE_THREAD:
            strState = @"AS_STARTING_FILE_THREAD";
            if ([self.delegate respondsToSelector:@selector(playerDidBeginConnection:)]) {
                [self.delegate playerDidBeginConnection:self];
            }
            break;
        case AS_WAITING_FOR_DATA:
            strState = @"AS_WAITING_FOR_DATA";
            break;
        case AS_FLUSHING_EOF:
            strState = @"AS_FLUSHING_EOF";
            break;
        case AS_WAITING_FOR_QUEUE_TO_START:
            strState = @"AS_WAITING_FOR_QUEUE_TO_START";
            break;
        case AS_PLAYING:
            strState = @"AS_PLAYING";
            if ([self.delegate respondsToSelector:@selector(playerDidStartPlaying:)]) {
                [self.delegate playerDidStartPlaying:self];
            }
            break;
        case AS_BUFFERING:
            strState = @"AS_BUFFERING";
            break;
        case AS_STOPPING:
            strState = @"AS_STOPPING";
            if ([self.delegate respondsToSelector:@selector(playerDidStopPlaying:)]) {
                [self.delegate playerDidStopPlaying:self];
            }
            break;
        case AS_STOPPED:
            strState = @"AS_STOPPED";
            if ([self.delegate respondsToSelector:@selector(playerDidStopPlaying:)]) {
                [self.delegate playerDidStopPlaying:self];
            }
            break;
        case AS_PAUSED:
            strState = @"AS_PAUSED";
            if ([self.delegate respondsToSelector:@selector(playerDidPausePlaying:)]) {
                [self.delegate playerDidPausePlaying:self];
            }
            break;
        default:
            strState = @"UNKNOWN";
            break;
    }
    
    NSLog(@"state = %@", strState);
}

- (AudioStreamerState)state
{
    //    NSLog(@"state");
    @synchronized(self)
    {
        return _state;
    }
}

/**
 Sets the state and sends a notification that the state has changed.
 */
- (void)setState:(AudioStreamerState)status
{
    //    NSLog(@"setState");
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
 Calls startInternal in a new thread.
*/
- (void)start
{
    NSLog(@"start");
    @synchronized (self)
    {
        // Если проигрывание было остановлено, то возобнавляем проигрывание
        if (_state == AS_PAUSED)
        {
            [self resume];
        }
        // Если первый запуск, то запускаем работу внутреннего потока
        else if (_state == AS_INITIALIZED)
        {
            NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
                     @"Playback can only be started from the main thread.");
            _notificationCenter = [NSNotificationCenter defaultCenter];
            self.state = AS_STARTING_FILE_THREAD;
            _internalThread =
            [[NSThread alloc]
             initWithTarget:self
             selector:@selector(startInternal)
             object:nil];
            [_internalThread start];
        }
    }
}

/**
 This method can be called to stop downloading/playback before it completes.
 It is automatically called when an error occurs.

 If playback has not started before this method is called, it will toggle the
 "isPlaying" property so that it is guaranteed to transition to true and
 back to false
 */
- (void)stop
{
    NSLog(@"stop");
    @synchronized(self)
    {
        if (_audioQueue &&
            (_state == AS_PLAYING || _state == AS_PAUSED ||
             _state == AS_BUFFERING || _state == AS_WAITING_FOR_QUEUE_TO_START))
        {
            self.state = AS_STOPPING;
            _stopReason = AS_STOPPING_USER_ACTION;
            _err = AudioQueueStop(_audioQueue, true);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_STOP_FAILED];
                return;
            }
        }
        else if (_state != AS_INITIALIZED)
        {
            self.state = AS_STOPPED;
            _stopReason = AS_STOPPING_USER_ACTION;
        }
//        seekWasRequested = NO;
    }
    
    while (_state != AS_INITIALIZED)
    {
        [NSThread sleepForTimeInterval:0.1];
    }
}

/**
 A togglable pause function.
 */
- (void)pause {
    NSLog(@"pause");
    @synchronized(self)
    {
        if (_state == AS_PLAYING || _state == AS_STOPPING)
        {
            _err = AudioQueuePause(_audioQueue);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
                return;
            }
            _laststate = _state;
            self.state = AS_PAUSED;
        }
        /*
        else if (_state == AS_PAUSED)
        {
            _err = AudioQueueStart(_audioQueue, NULL);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
                return;
            }
            self.state = _laststate;
        }
         */
    }
}

- (void)resume {
    NSLog(@"resume");
    @synchronized(self)
    {
        /*
        if (_state == AS_PLAYING || _state == AS_STOPPING)
        {
            _err = AudioQueuePause(_audioQueue);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
                return;
            }
            _laststate = _state;
            self.state = AS_PAUSED;
        }
        else */
        if (_state == AS_PAUSED)
        {
            _err = AudioQueueStart(_audioQueue, NULL);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
                return;
            }
            self.state = _laststate;
        }
    }
}

#pragma mark - Player state
/**
 returns YES if the audio currently playing.
 */
- (BOOL)isPlaying {
//    NSLog(@"isPlaying");
    if (_state == AS_PLAYING)
    {
        return YES;
    }
    
    return NO;
}

/**
 returns YES if the audio currently paused.
 */
- (BOOL)isPaused {
//    NSLog(@"isPaused");
    if (_state == AS_PAUSED)
    {
        return YES;
    }
    
    return NO;
}

/**
 returns YES if the AudioStreamer is waiting for a state transition of some kind.
 */
- (BOOL)isWaiting {
//    NSLog(@"isWaiting");
    @synchronized(self)
    {
        if ([self isFinishing]                      ||
            _state == AS_STARTING_FILE_THREAD       ||
            _state == AS_WAITING_FOR_DATA           ||
            _state == AS_WAITING_FOR_QUEUE_TO_START ||
            _state == AS_BUFFERING)
        {
            return YES;
        }
    }
    
    return NO;
}

/**
 returns YES if the audio has reached a stopping condition.
 */
- (BOOL)isFinishing
{
//    NSLog(@"isFinishing");
    @synchronized (self)
    {
        if ((_errorCode != AS_NO_ERROR && _state != AS_INITIALIZED) ||
            ((_state == AS_STOPPING || _state == AS_STOPPED) &&
             _stopReason != AS_STOPPING_TEMPORARILY))
        {
            return YES;
        }
    }
    
    return NO;
}

/**
  returns YES if the AudioStream is in the AS_INITIALIZED state (i.e. isn't doing anything).
 */
- (BOOL)isIdle {
//    NSLog(@"isIdle");
    if (_state == AS_INITIALIZED)
    {
        return YES;
    }
    
    return NO;
}

/**
 returns YES if the AudioStream was stopped due to some errror, handled through failWithCodeError.
 */
- (BOOL)isAborted {
//    NSLog(@"isAborted");
    if (_state == AS_STOPPING && _stopReason == AS_STOPPING_ERROR)
    {
        return YES;
    }
    
    return NO;
}

#pragma mark - Internal Thread Work

/**
 This is the start method for the AudioStream thread. This thread is created
 because it will be blocked when there are no audio buffers idle (and ready
 to receive audio data).

 Activity in this thread:
	- Creation and cleanup of all AudioFileStream and AudioQueue objects
	- Receives data from the CFReadStream
	- AudioFileStream processing
	- Copying of data from AudioFileStream into audio buffers
  - Stopping of the thread because of end-of-file
	- Stopping due to error or failure

 Activity *not* in this thread:
	- AudioQueue playback and notifications (happens in AudioQueue thread)
  - Actual download of NSURLConnection data (NSURLConnection's thread)
	- Creation of the AudioStreamer (other, likely "main" thread)
	- Invocation of -start method (other, likely "main" thread)
	- User/manual invocation of -stop (other, likely "main" thread)

 This method contains bits of the "main" function from Apple's example in
 AudioFileStreamExample.
 */
- (void)startInternal
{
    NSLog(@"startInternal");
    
    @synchronized(self)
    {
        if (_state != AS_STARTING_FILE_THREAD)
        {
            if (_state != AS_STOPPING &&
                _state != AS_STOPPED)
            {
                NSLog(@"### Not starting audio thread. State code is: %ld", (long)_state);
            }
            self.state = AS_INITIALIZED;
            return;
        }
        
        //
        // Натсройка audio session чтобы проигрывать в фоне музыку.
        //
        AudioSessionInitialize (
                                NULL,                          // 'NULL' to use the default (main) run loop
                                NULL,                          // 'NULL' to use the default run loop mode
                                ASAudioSessionInterruptionListener,  // a reference to your interruption callback
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
                                         audioRouteChangeListenerCallback,
                                         (__bridge void *)(self));
        
        AudioSessionSetActive(true);
        
        // initialize a mutex and condition so that we can block on buffers in use.
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
        /*
        @synchronized(self) {
            if (seekWasRequested) {
                [self internalSeekToTime:requestedSeekTime];
                seekWasRequested = NO;
            }
        }
        */
        //
        // If there are no queued buffers, we need to check here since the
        // handleBufferCompleteForQueue:buffer: should not change the state
        // (may not enter the synchronized section).
        //
        if (_buffersUsed == 0 && self.state == AS_PLAYING)
        {
            _err = AudioQueuePause(_audioQueue);
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_PAUSE_FAILED];
                return;
            }
            self.state = AS_BUFFERING;
        }
    } while (isRunning && ![self runLoopShouldExit]);
    
    [self cleanup];
}

- (void)cleanup {
    NSLog(@"cleanup");
    @synchronized(self)
    {
        //
        // Очищаем stream если он все еще открыт
        //
        if (_stream)
        {
            CFReadStreamClose(_stream);
            CFRelease(_stream);
            _stream = nil;
        }
        
        //
        // Закрываем стрим аудио файла
        //
        if (_audioFileStream)
        {
            _err = AudioFileStreamClose(_audioFileStream);
            _audioFileStream = nil;
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_CLOSE_FAILED];
            }
        }
        
        //
        // Удаляем Audio Queue
        //
        if (_audioQueue)
        {
            _err = AudioQueueDispose(_audioQueue, true);
            _audioQueue = nil;
            if (_err)
            {
                [self failWithErrorCode:AS_AUDIO_QUEUE_DISPOSE_FAILED];
            }
        }
        
        pthread_mutex_destroy(&_queueBuffersMutex);
        pthread_cond_destroy(&_queueBufferReadyCondition);
        
        AudioSessionSetActive(false);
        
        _httpHeaders = nil;
        
        _bytesFilled = 0;
        _packetsFilled = 0;
        _seekByteOffset = 0;
        _packetBufferSize = 0;
        self.state = AS_INITIALIZED;
        
        _internalThread = nil;
    }
}

/**
 Open the audioFileStream to parse data
 */
- (BOOL)openReadStream
{
    NSLog(@"openReadStream");
    @synchronized(self)
    {
        NSAssert([[NSThread currentThread] isEqual:_internalThread],
                 @"File stream download must be started on the internalThread");
        NSAssert(_stream == nil, @"Download stream already initialized");
        
        //
        // Создаем HTTP GET запрос
        //
        CFHTTPMessageRef message= CFHTTPMessageCreateRequest(NULL, (CFStringRef)@"GET", (__bridge CFURLRef)_url, kCFHTTPVersion1_1);
        
        //
        // If we are creating this request to seek to a location, set the
        // requested byte range in the headers.
        //
//        if (_fileLength > 0 && _seekByteOffset > 0)
//        {
//            NSLog(@"openReadStream - fileLength > 0 && seekByteOffset > 0");
//            CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Range"),
//                                             (__bridge CFStringRef)[NSString stringWithFormat:@"bytes=%ld-%ld", (long)_seekByteOffset, (long)_fileLength]);
//            _discontinuous = YES;
//        }
        
        //
        // Создаем read stream, который будет получать даныне с HTTP запроса
        //
        _stream = CFReadStreamCreateForHTTPRequest(NULL, message);
        CFRelease(message);
        
        //
        // Включаем редирект
        //
        if (CFReadStreamSetProperty(
                                    _stream,
                                    kCFStreamPropertyHTTPShouldAutoredirect,
                                    kCFBooleanTrue) == false)
        {
            [self failWithErrorCode:AS_FILE_STREAM_SET_PROPERTY_FAILED];
            
            return NO;
        }
        
        //
        // Обрабатываем прокси
        //
        CFDictionaryRef proxySettings = CFNetworkCopySystemProxySettings();
        CFReadStreamSetProperty(_stream, kCFStreamPropertyHTTPProxy, proxySettings);
        CFRelease(proxySettings);
        
        //
        // We're now ready to receive data
        //
        self.state = AS_WAITING_FOR_DATA;
        
        //
        // Открываем stream
        //
        if (!CFReadStreamOpen(_stream))
        {
            CFRelease(_stream);
            
            [self failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
            
            return NO;
        }
        
        //
        // Устанавливаем callback функцию, которая будет получать данные
        //
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

/**
 returns YES if the run loop should exit.
 */
- (BOOL)runLoopShouldExit
{
//    NSLog(@"runLoopShouldExit");
    @synchronized(self)
    {
        if (_errorCode != AS_NO_ERROR ||
            (_state == AS_STOPPED &&
             _stopReason != AS_STOPPING_TEMPORARILY))
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - NSNotificationCenter handlers

/**
 Implementation for ASAudioQueueInterruptionListener
 */
- (void)handleInterruptionChangeToState:(NSNotification *)notification {
    NSLog(@"handleInterruptionChangeToState");
    AudioQueuePropertyID inInterruptionState =
                (AudioQueuePropertyID) [notification.object unsignedIntValue];
    if (inInterruptionState == kAudioSessionBeginInterruption)
    {
//        if ([self isPlaying]) {
//            [self pause];
            [self stop];

//            _pausedByInterruption = YES;
//        }
    }
//    else if (inInterruptionState == kAudioSessionEndInterruption)
//    {
//        AudioSessionSetActive(true);
//
//        if ([self isPaused] && _pausedByInterruption) {
//            [self start]; // this is actually resume
//
//            _pausedByInterruption = NO; // this is redundant
//        }
//    }
}

/**
 
 */
- (void)routeChanged:(NSNotification *)notification {
    NSLog(@"%@", notification);
}

#pragma mark - Errors handing

/**
 Converts an error code to a string that can be localized or presented to the user.
 */
+ (NSString *)stringForErrorCode:(AudioStreamerErrorCode)anErrorCode
{
    switch (anErrorCode)
    {
        case AS_NO_ERROR:
            return AS_NO_ERROR_STRING;
        case AS_FILE_STREAM_GET_PROPERTY_FAILED:
            return AS_FILE_STREAM_GET_PROPERTY_FAILED_STRING;
        case AS_FILE_STREAM_SEEK_FAILED:
            return AS_FILE_STREAM_SEEK_FAILED_STRING;
        case AS_FILE_STREAM_PARSE_BYTES_FAILED:
            return AS_FILE_STREAM_PARSE_BYTES_FAILED_STRING;
        case AS_AUDIO_QUEUE_CREATION_FAILED:
            return AS_AUDIO_QUEUE_CREATION_FAILED_STRING;
        case AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED:
            return AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED_STRING;
        case AS_AUDIO_QUEUE_ENQUEUE_FAILED:
            return AS_AUDIO_QUEUE_ENQUEUE_FAILED_STRING;
        case AS_AUDIO_QUEUE_ADD_LISTENER_FAILED:
            return AS_AUDIO_QUEUE_ADD_LISTENER_FAILED_STRING;
        case AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED:
            return AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED_STRING;
        case AS_AUDIO_QUEUE_START_FAILED:
            return AS_AUDIO_QUEUE_START_FAILED_STRING;
        case AS_AUDIO_QUEUE_BUFFER_MISMATCH:
            return AS_AUDIO_QUEUE_BUFFER_MISMATCH_STRING;
        case AS_FILE_STREAM_OPEN_FAILED:
            return AS_FILE_STREAM_OPEN_FAILED_STRING;
        case AS_FILE_STREAM_CLOSE_FAILED:
            return AS_FILE_STREAM_CLOSE_FAILED_STRING;
        case AS_AUDIO_QUEUE_DISPOSE_FAILED:
            return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
        case AS_AUDIO_QUEUE_PAUSE_FAILED:
            return AS_AUDIO_QUEUE_DISPOSE_FAILED_STRING;
        case AS_AUDIO_QUEUE_FLUSH_FAILED:
            return AS_AUDIO_QUEUE_FLUSH_FAILED_STRING;
        case AS_AUDIO_DATA_NOT_FOUND:
            return AS_AUDIO_DATA_NOT_FOUND_STRING;
        case AS_GET_AUDIO_TIME_FAILED:
            return AS_GET_AUDIO_TIME_FAILED_STRING;
        case AS_NETWORK_CONNECTION_FAILED:
            return AS_NETWORK_CONNECTION_FAILED_STRING;
        case AS_AUDIO_QUEUE_STOP_FAILED:
            return AS_AUDIO_QUEUE_STOP_FAILED_STRING;
        case AS_AUDIO_STREAMER_FAILED:
            return AS_AUDIO_STREAMER_FAILED_STRING;
        case AS_AUDIO_BUFFER_TOO_SMALL:
            return [NSString stringWithFormat:AS_AUDIO_BUFFER_TOO_SMALL_STRING, AQ_DEFAULT_BUF_SIZE];
        default:
            return AS_AUDIO_STREAMER_FAILED_STRING;
    }
    
    return AS_AUDIO_STREAMER_FAILED_STRING;
}

/**
 Sets the playback state to failed and logs the error.
 */
- (void)failWithErrorCode:(AudioStreamerErrorCode)anErrorCode
{
//    NSLog(@"failWithErrorCode");
    @synchronized(self)
    {
        if (_errorCode != AS_NO_ERROR)
        {
            // Only set the error once.
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
        
        if (_state == AS_PLAYING    ||
            _state == AS_PAUSED     ||
            _state == AS_BUFFERING)
        {
            self.state = AS_STOPPING;
            _stopReason = AS_STOPPING_ERROR;
            AudioQueueStop(_audioQueue, true);
        }
        
        if ([self.delegate respondsToSelector:@selector(player:failedToPrepareForPlaybackWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"GG977AudioStreamPlayer"
                    code:anErrorCode
                userInfo:[NSDictionary dictionaryWithObject:
                    [GG977AudioStreamPlayer stringForErrorCode:anErrorCode]
                                                        forKey:NSLocalizedDescriptionKey]];
            [self.delegate player:self failedToPrepareForPlaybackWithError:error];
        }
    }
}

#pragma mark - handlers

/**
 Reads data from the network file stream into the AudioFileStream

 Parameters:
    aStream - the network file stream
    eventType - the event which triggered this method
 */
- (void)handleReadFromStream:(CFReadStreamRef)aStream
                   eventType:(CFStreamEventType)eventType
{
//    NSLog(@"handleReadFromStream");
    if (aStream != _stream)
    {
        //
        // Ignore messages from old streams
        //
        return;
    }
    
    if (eventType == kCFStreamEventErrorOccurred)
    {
        [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
    }
    /*
#warning нужен ли?
    else if (eventType == kCFStreamEventEndEncountered)
    {
        @synchronized(self)
        {
            if ([self isFinishing])
            {
                return;
            }
        }
        
        //
        // If there is a partially filled buffer, pass it to the AudioQueue for
        // processing
        //
        if (_bytesFilled)
        {
            if (self.state == AS_WAITING_FOR_DATA)
            {
                //
                // Force audio data smaller than one whole buffer to play.
                //
                self.state = AS_FLUSHING_EOF;
            }
            [self enqueueBuffer];
        }
        
        @synchronized(self)
        {
            if (_state == AS_WAITING_FOR_DATA)
            {
                [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
            }
            
            //
            // We left the synchronized section to enqueue the buffer so we
            // must check that we are !finished again before touching the
            // audioQueue
            //
            else if (![self isFinishing])
            {
                if (_audioQueue)
                {
                    //
                    // Set the progress at the end of the stream
                    //
                    _err = AudioQueueFlush(_audioQueue);
                    if (_err)
                    {
                        [self failWithErrorCode:AS_AUDIO_QUEUE_FLUSH_FAILED];
                        return;
                    }
                    
                    self.state = AS_STOPPING;
                    _stopReason = AS_STOPPING_EOF;
                    _err = AudioQueueStop(_audioQueue, false);
                    if (_err)
                    {
                        [self failWithErrorCode:AS_AUDIO_QUEUE_FLUSH_FAILED];
                        return;
                    }
                }
                else
                {
                    self.state = AS_STOPPED;
                    _stopReason = AS_STOPPING_EOF;
                }
            }
        }
    }*/
    else if (eventType == kCFStreamEventHasBytesAvailable)
    {
        if (!_httpHeaders)
        {
            CFTypeRef message =
            CFReadStreamCopyProperty(_stream, kCFStreamPropertyHTTPResponseHeader);
            _httpHeaders =
            (__bridge NSDictionary *)CFHTTPMessageCopyAllHeaderFields((CFHTTPMessageRef)message);
            CFRelease(message);
            
            /*
            // Only read the content length if we seeked to time zero, otherwise
            // we only have a subset of the total bytes.
            // НЕТУ
            if (_seekByteOffset == 0)
            {
                _fileLength = [[_httpHeaders objectForKey:@"Content-Length"] integerValue];
            }
             */
        }
        
        if (!_audioFileStream)
        {
            // create an audio file stream parser
            _err = AudioFileStreamOpen((__bridge void *)(self), ASPropertyListenerProc, ASPacketsProc,
                                      kAudioFileAAC_ADTSType, &_audioFileStream);
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
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
            
            //
            // Read the bytes from the stream
            //
            length = CFReadStreamRead(_stream, bytes, AQ_DEFAULT_BUF_SIZE);
            
            if (length == -1)
            {
                [self failWithErrorCode:AS_AUDIO_DATA_NOT_FOUND];
                return;
            }
            
            if (length == 0)
            {
                return;
            }
        }
        /*
//        if (_discontinuous)
//        {
//            _err = AudioFileStreamParseBytes(_audioFileStream, length, bytes, kAudioFileStreamParseFlag_Discontinuity);
//            if (_err)
//            {
//                [self failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
//                return;
//            }
//        }
//        else
         */
        {
            _err = AudioFileStreamParseBytes(_audioFileStream, length, bytes, 0);
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
                return;
            }
        }
    }
}

/**
 Object method which handles implementation of ASPropertyListenerProc

 Parameters:
    inAudioFileStream - should be the same as self->audioFileStream
    inPropertyID - the property that changed
    ioFlags - the ioFlags passed in
 */
- (void)handlePropertyChangeForFileStream:(AudioFileStreamID)inAudioFileStream
                     fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                  ioFlags:(UInt32 *)ioFlags
{
    NSLog(@"handlePropertyChangeForFileStream");
    @synchronized(self)
    {
        if ([self isFinishing])
        {
            return;
        }
        
        if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets)
        {
            NSLog(@"kAudioFileStreamProperty_ReadyToProducePackets");
            _discontinuous = true;
        }
        else if (inPropertyID == kAudioFileStreamProperty_DataOffset)
        {
            NSLog(@"kAudioFileStreamProperty_DataOffset");
            SInt64 offset;
            UInt32 offsetSize = sizeof(offset);
            _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            _dataOffset = offset;
            NSLog(@"_dataOffset = %d", _dataOffset);
            if (_audioDataByteCount)
            {
                _fileLength = _dataOffset + _audioDataByteCount;
                NSLog(@"_fileLength = %d", _fileLength);
            }
        }
        else if (inPropertyID == kAudioFileStreamProperty_AudioDataByteCount)
        {
            NSLog(@"kAudioFileStreamProperty_AudioDataByteCount");
            UInt32 byteCountSize = sizeof(UInt64);
            _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &_audioDataByteCount);
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            _fileLength = _dataOffset + _audioDataByteCount;
            NSLog(@"_fileLength = %d", _fileLength);
        }
        else if (inPropertyID == kAudioFileStreamProperty_DataFormat)
        {
            NSLog(@"kAudioFileStreamProperty_DataFormat");
            if (_asbd.mSampleRate == 0)
            {
                NSLog(@"mBitsPerChannel = %d", (unsigned int)_asbd.mBitsPerChannel);
                NSLog(@"mBytesPerFrame = %d", (unsigned int)_asbd.mBytesPerFrame);
                NSLog(@"mBytesPerPacket = %d", (unsigned int)_asbd.mBytesPerPacket);
                NSLog(@"mChannelsPerFrame = %d", (unsigned int)_asbd.mChannelsPerFrame);
                NSLog(@"mFormatFlags = %d", (unsigned int)_asbd.mFormatFlags);
                NSLog(@"mFormatID = %d", (unsigned int)_asbd.mFormatID);
                NSLog(@"mFramesPerPacket = %d", (unsigned int)_asbd.mFramesPerPacket);
                NSLog(@"mReserved = %d", (unsigned int)_asbd.mReserved);
                NSLog(@"mSampleRate = %d", (unsigned int)_asbd.mSampleRate);
                
                UInt32 asbdSize = sizeof(_asbd);
                
                // get the stream format.
                _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &_asbd);
                if (_err)
                {
                    [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                    return;
                }
            }
            
            NSLog(@"mBitsPerChannel = %d", (unsigned int)_asbd.mBitsPerChannel);
            NSLog(@"mBytesPerFrame = %d", (unsigned int)_asbd.mBytesPerFrame);
            NSLog(@"mBytesPerPacket = %d", (unsigned int)_asbd.mBytesPerPacket);
            NSLog(@"mChannelsPerFrame = %d", (unsigned int)_asbd.mChannelsPerFrame);
            NSLog(@"mFormatFlags = %d", (unsigned int)_asbd.mFormatFlags);
            NSLog(@"mFormatID = %d", (unsigned int)_asbd.mFormatID);
            NSLog(@"mFramesPerPacket = %d", (unsigned int)_asbd.mFramesPerPacket);
            NSLog(@"mReserved = %d", (unsigned int)_asbd.mReserved);
            NSLog(@"mSampleRate = %d", (unsigned int)_asbd.mSampleRate);
        }
        else if (inPropertyID == kAudioFileStreamProperty_FormatList)
        {
            NSLog(@"kAudioFileStreamProperty_FormatList");
            Boolean outWriteable;
            UInt32 formatListSize;
            _err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
            if (_err)
            {
                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            
            AudioFormatListItem *formatList = malloc(formatListSize);
            _err = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (_err)
            {
                free(formatList);
                [self failWithErrorCode:AS_FILE_STREAM_GET_PROPERTY_FAILED];
                return;
            }
            
            for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
            {
                AudioStreamBasicDescription pasbd = formatList[i].mASBD;
                
                NSLog(@"%d pasbd.mFormatID = %d", i, (unsigned int)pasbd.mFormatID);
                
                if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE ||
                    pasbd.mFormatID == kAudioFormatMPEG4AAC_HE_V2)
                {
                    //
                    // We've found HE-AAC, remember this to tell the audio queue
                    // when we construct it.
                    //
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
            NSLog(@"Property is %c%c%c%c", ((char *)&inPropertyID)[3], ((char *)&inPropertyID)[2], ((char *)&inPropertyID)[1], ((char *)&inPropertyID)[0]);
        }
    }
}

/**
 Object method which handles the implementation of ASPacketsProc

 Parameters:
    inInputData - the packet data
    inNumberBytes - byte size of the data
    inNumberPackets - number of packets in the data
    inPacketDescriptions - packet descriptions
 */
- (void)handleAudioPackets:(const void *)inInputData
               numberBytes:(UInt32)inNumberBytes
             numberPackets:(UInt32)inNumberPackets
        packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
{
    //    NSLog(@"handleAudioPackets");
    @synchronized(self)
    {
        if ([self isFinishing])
        {
            return;
        }
        
        if (_bitRate == 0)
        {
            //
            // m4a and a few other formats refuse to parse the bitrate so
            // we need to set an "unparseable" condition here. If you know
            // the bitrate (parsed it another way) you can set it on the
            // class if needed.
            //
            _bitRate = ~0;
        }
        
        // we have successfully read the first packests from the audio stream, so
        // clear the "discontinuous" flag
        if (_discontinuous)
        {
            _discontinuous = false;
        }
        
        if (!_audioQueue)
        {
            [self createQueue];
        }
    }
    
    // the following code assumes we're streaming VBR data. for CBR data, the second branch is used.
    if (inPacketDescriptions)
    {
        for (int i = 0; i < inNumberPackets; ++i)
        {
            SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
            SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;
            size_t bufSpaceRemaining;
            
            if (_processedPacketsCount < BIT_RATE_ESTIMATION_MAX_PACKETS)
            {
                _processedPacketsSizeTotal += packetSize;
                _processedPacketsCount += 1;
            }
            
            @synchronized(self)
            {
                // If the audio was terminated before this point, then
                // exit.
                if ([self isFinishing])
                {
                    return;
                }
                
                if (packetSize > _packetBufferSize)
                {
                    [self failWithErrorCode:AS_AUDIO_BUFFER_TOO_SMALL];
                }
                
                bufSpaceRemaining = _packetBufferSize - _bytesFilled;
            }
            
            // if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
            if (bufSpaceRemaining < packetSize)
            {
                [self enqueueBuffer];
            }
            
            @synchronized(self)
            {
                // If the audio was terminated while waiting for a buffer, then
                // exit.
                if ([self isFinishing])
                {
                    return;
                }
                
                //
                // If there was some kind of issue with enqueueBuffer and we didn't
                // make space for the new audio data then back out
                //
                if (_bytesFilled + packetSize > _packetBufferSize)
                {
                    return;
                }
                
                // copy data to the audio queue buffer
                AudioQueueBufferRef fillBuf = _audioQueueBuffer[_fillBufferIndex];
                memcpy((char*)fillBuf->mAudioData + _bytesFilled, (const char*)inInputData + packetOffset, packetSize);
                
                // fill out packet description
                _packetDescs[_packetsFilled] = inPacketDescriptions[i];
                _packetDescs[_packetsFilled].mStartOffset = _bytesFilled;
                // keep track of bytes filled and packets filled
                _bytesFilled += packetSize;
                _packetsFilled += 1;
            }
            
            // if that was the last free packet description, then enqueue the buffer.
            size_t packetsDescsRemaining = AQ_MAX_PACKET_DESCS - _packetsFilled;
            if (packetsDescsRemaining == 0) {
                [self enqueueBuffer];
            }
        }
    }
    else
    {
        size_t offset = 0;
        while (inNumberBytes)
        {
            // if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
            size_t bufSpaceRemaining = AQ_DEFAULT_BUF_SIZE - _bytesFilled;
            if (bufSpaceRemaining < inNumberBytes)
            {
                [self enqueueBuffer];
            }
            
            @synchronized(self)
            {
                // If the audio was terminated while waiting for a buffer, then
                // exit.
                if ([self isFinishing])
                {
                    return;
                }
                
                bufSpaceRemaining = AQ_DEFAULT_BUF_SIZE - _bytesFilled;
                size_t copySize;
                if (bufSpaceRemaining < inNumberBytes)
                {
                    copySize = bufSpaceRemaining;
                }
                else
                {
                    copySize = inNumberBytes;
                }
                
                //
                // If there was some kind of issue with enqueueBuffer and we didn't
                // make space for the new audio data then back out
                //
                if (_bytesFilled > _packetBufferSize)
                {
                    return;
                }
                
                // copy data to the audio queue buffer
                AudioQueueBufferRef fillBuf = _audioQueueBuffer[_fillBufferIndex];
                memcpy((char*)fillBuf->mAudioData + _bytesFilled, (const char*)(inInputData + offset), copySize);
                
                
                // keep track of bytes filled and packets filled
                _bytesFilled += copySize;
                _packetsFilled = 0;
                inNumberBytes -= copySize;
                offset += copySize;
            }
        }
    }
}

/**
 Handles the buffer completetion notification from the audio queue

 Parameters:
    inAQ - the queue
    inBuffer - the buffer
 */
- (void)handleBufferCompleteForQueue:(AudioQueueRef)inAQ
                              buffer:(AudioQueueBufferRef)inBuffer
{
    //    NSLog(@"handleBufferCompleteForQueue");
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
        [self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_MISMATCH];
        pthread_mutex_lock(&_queueBuffersMutex);
        pthread_cond_signal(&_queueBufferReadyCondition);
        pthread_mutex_unlock(&_queueBuffersMutex);
        return;
    }
    
    // signal waiting thread that the buffer is free.
    pthread_mutex_lock(&_queueBuffersMutex);
    _inuse[bufIndex] = false;
    _buffersUsed--;
    
#if LOG_QUEUED_BUFFERS
    NSLog(@"Queued buffers: %ld", (long)_buffersUsed);
#endif
    
    pthread_cond_signal(&_queueBufferReadyCondition);
    pthread_mutex_unlock(&_queueBuffersMutex);
}

- (void)handlePropertyChange:(NSNumber *)num
{
    //    NSLog(@"handlePropertyChange");
    [self handlePropertyChangeForQueue:NULL propertyID:[num intValue]];
}

/**
 Implementation for ASAudioQueueIsRunningCallback

 Parameters:
    inAQ - the audio queue
    inID - the property ID
 */
- (void)handlePropertyChangeForQueue:(AudioQueueRef)inAQ
                          propertyID:(AudioQueuePropertyID)inID
{
    //    NSLog(@"handlePropertyChangeForQueue");
//    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
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
            if (_state == AS_STOPPING)
            {
                // Should check value of isRunning to ensure this kAudioQueueProperty_IsRunning isn't
                // the *start* of a very short stream
                UInt32 isRunning = 0;
                UInt32 size = sizeof(UInt32);
                AudioQueueGetProperty(_audioQueue, inID, &isRunning, &size);
                if (isRunning == 0)
                {
                    self.state = AS_STOPPED;
                }
            }
            else if (_state == AS_WAITING_FOR_QUEUE_TO_START)
            {
                //
                // Note about this bug avoidance quirk:
                //
                // On cleanup of the AudioQueue thread, on rare occasions, there would
                // be a crash in CFSetContainsValue as a CFRunLoopObserver was getting
                // removed from the CFRunLoop.
                //
                // After lots of testing, it appeared that the audio thread was
                // attempting to remove CFRunLoop observers from the CFRunLoop after the
                // thread had already deallocated the run loop.
                //
                // By creating an NSRunLoop for the AudioQueue thread, it changes the
                // thread destruction order and seems to avoid this crash bug -- or
                // at least I haven't had it since (nasty hard to reproduce error!)
                //
                [NSRunLoop currentRunLoop];
                
                self.state = AS_PLAYING;
            }
            else
            {
                NSLog(@"AudioQueue changed state in unexpected way.");
            }
        }
    }
    
//    [pool release];
}

#pragma mark - Queue management

/**
 Called from ASPacketsProc and connectionDidFinishLoading to pass filled audio
 bufffers (filled by ASPacketsProc) to the AudioQueue for playback. This
 function does not return until a buffer is idle for further filling or
 the AudioQueue is stopped.

 This function is adapted from Apple's example in AudioFileStreamExample with
 CBR functionality added.
 */
- (void)enqueueBuffer
{
//    NSLog(@"enqueueBuffer");
    @synchronized(self)
    {
        if ([self isFinishing] || _stream == 0)
        {
            return;
        }
        
        _inuse[_fillBufferIndex] = true;		// set in use flag
        _buffersUsed++;
        
        // enqueue buffer
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
            [self failWithErrorCode:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
            return;
        }
        
        
        if (_state == AS_BUFFERING ||
            _state == AS_WAITING_FOR_DATA ||
            _state == AS_FLUSHING_EOF ||
            (_state == AS_STOPPED && _stopReason == AS_STOPPING_TEMPORARILY))
        {
            //
            // Fill all the buffers before starting. This ensures that the
            // AudioFileStream stays a small amount ahead of the AudioQueue to
            // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
            //
            if (_state == AS_FLUSHING_EOF || _buffersUsed == NUM_AQ_BUFS - 1)
            {
                if (self.state == AS_BUFFERING)
                {
                    _err = AudioQueueStart(_audioQueue, NULL);
                    if (_err)
                    {
                        [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
                        return;
                    }
                    self.state = AS_PLAYING;
                }
                else
                {
                    self.state = AS_WAITING_FOR_QUEUE_TO_START;
                    
                    _err = AudioQueueStart(_audioQueue, NULL);
                    if (_err)
                    {
                        [self failWithErrorCode:AS_AUDIO_QUEUE_START_FAILED];
                        return;
                    }
                }
            }
        }
        
        // go to next buffer
        if (++_fillBufferIndex >= NUM_AQ_BUFS) _fillBufferIndex = 0;
        _bytesFilled = 0;		// reset bytes filled
        _packetsFilled = 0;		// reset packets filled
    }
    
    // wait until next buffer is not in use
    pthread_mutex_lock(&_queueBuffersMutex);
    while (_inuse[_fillBufferIndex])
    {
        pthread_cond_wait(&_queueBufferReadyCondition, &_queueBuffersMutex);
    }
    pthread_mutex_unlock(&_queueBuffersMutex);
}

/**
 Method to create the AudioQueue from the parameters gathered by the
 AudioFileStream.

 Creation is deferred to the handling of the first audio packet (although
 it could be handled any time after kAudioFileStreamProperty_ReadyToProducePackets
 is true).
 */
- (void)createQueue
{
    //    NSLog(@"createQueue");
    _sampleRate = _asbd.mSampleRate;
    _packetDuration = _asbd.mFramesPerPacket / _sampleRate;
    
    // create the audio queue
    _err = AudioQueueNewOutput(&_asbd, ASAudioQueueOutputCallback, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue);
    if (_err)
    {
        [self failWithErrorCode:AS_AUDIO_QUEUE_CREATION_FAILED];
        return;
    }
    
    // start the queue if it has not been started already
    // listen to the "isRunning" property
    _err = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, ASAudioQueueIsRunningCallback, (__bridge void *)(self));
    if (_err)
    {
        [self failWithErrorCode:AS_AUDIO_QUEUE_ADD_LISTENER_FAILED];
        return;
    }
    
    // get the packet size if it is available
    UInt32 sizeOfUInt32 = sizeof(UInt32);
    _err = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_packetBufferSize);
    if (_err || _packetBufferSize == 0)
    {
        _err = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_packetBufferSize);
        if (_err || _packetBufferSize == 0)
        {
            // No packet size available, just use the default
            _packetBufferSize = AQ_DEFAULT_BUF_SIZE;
        }
    }
    
    // allocate audio queue buffers
    for (unsigned int i = 0; i < NUM_AQ_BUFS; ++i)
    {
        _err = AudioQueueAllocateBuffer(_audioQueue, _packetBufferSize, &_audioQueueBuffer[i]);
        if (_err)
        {
            [self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
            return;
        }
    }
    
    // get the cookie size
    UInt32 cookieSize;
    Boolean writable;
    OSStatus ignorableError;
    ignorableError = AudioFileStreamGetPropertyInfo(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (ignorableError)
    {
        return;
    }
    
    // get the cookie data
    void* cookieData = calloc(1, cookieSize);
    ignorableError = AudioFileStreamGetProperty(_audioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (ignorableError)
    {
        return;
    }
    
    // set the cookie on the queue.
    ignorableError = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
    free(cookieData);
    if (ignorableError)
    {
        return;
    }
}


@end