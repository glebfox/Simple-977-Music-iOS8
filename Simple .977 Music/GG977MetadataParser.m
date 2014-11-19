//
//  GG977MetadataParser.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 18.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977MetadataParser.h"
#import "GG977TrackInfo.h"

@interface GG977MetadataParser ()

@property (nonatomic, strong) GG977TrackInfo *previousTrackInfo;
@property (nonatomic, weak) NSTimer *timer;

@end

@implementation GG977MetadataParser {
    BOOL _sentNilMetadata;
}

- (id)initWithInterval:(NSUInteger)interval {
    if ((self = [super init])) {
        _interval = interval;
    }
    return self;
}

- (void)start {
    NSLog(@"parser - start");
    self.previousTrackInfo = nil;
    _sentNilMetadata = NO;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:_interval target:self selector:@selector(parseTrackInfo) userInfo:nil repeats:YES];
}

- (void)stop {
    NSLog(@"parser - stop");
    [self.timer invalidate];
    self.timer = nil;
//    self.previousTrackInfo = nil;
}

- (void)parseTrackInfo {
//    NSLog(@"parseTrackInfo");
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://androidfm.org/977music/api/metadata/%lu/", (unsigned long)self.stationID]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    
    GG977TrackInfo __block *info = [GG977TrackInfo new];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            NSLog(@"CONNECTION ERROR: %@", connectionError);
            info = nil;
        } else {
            NSError *error;
            NSDictionary *dic  = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
            
            if (error) {
                NSLog(@"JSON ERROR: %@", error);
                info = nil;
            } else {
                info.artist = dic[@"artist"];
                info.track = dic[@"name"];
                
                NSString *urlString = dic[@"img_url"];
                if (urlString != nil && [urlString class] != [NSNull class]) {
//                    info.imageUrl = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
                    info.imageUrl = [NSURL URLWithString:urlString];
                }
                
                NSString *str = dic[@"album"];
                if (str != nil && [str class] != [NSNull class]) {
                    NSArray *array = [str componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
                    info.album = array[0];
                    if ([array count] > 1) info.year = array[1];
                }
                
                info.lyrics = dic[@"lyrics"];
            }
        }
        
        if ((info == nil && !_sentNilMetadata) || (info != nil && ![info isEqual:self.previousTrackInfo])) {
            self.previousTrackInfo = info;

            if ([self.delegate respondsToSelector:@selector(parser:didParseNewTrackInfo:)]) {
                [self.delegate parser:self didParseNewTrackInfo:info];
            }
            
            if (info == nil) {
                _sentNilMetadata = YES;
            } else {
                _sentNilMetadata = NO;
            }
        }
    }];
}

@end
