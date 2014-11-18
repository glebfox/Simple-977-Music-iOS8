//
//  GG977DetailTrackInfoViewController.m
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 17.11.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import "GG977DetailTrackInfoViewController.h"
#import "GG977TrackInfo.h"
#import "GG977StationsProvider.h"
#import "GG977StationInfo.h"

@interface GG977DetailTrackInfoViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *albumImage;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UILabel *trackLabel;
@property (weak, nonatomic) IBOutlet UILabel *albumName;
@property (weak, nonatomic) IBOutlet UILabel *year;
@property (weak, nonatomic) IBOutlet UIWebView *lyricsWebView;

@end

@implementation GG977DetailTrackInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self updateTrackInfo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)done:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateTrackInfo {
    if (self.trackInfo) {
        
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:self.trackInfo.imageUrl] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            self.albumImage.image = [UIImage imageWithData:data];
        }];
        
        self.artistLabel.text = self.trackInfo.artist;
        self.trackLabel.text = self.trackInfo.track;
        self.albumName.text = self.trackInfo.album;
        self.year.text = self.trackInfo.year;
        UIFont *font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        NSString *html = [self htmlStringWithFont:(UIFont *)font];
        [self.lyricsWebView loadHTMLString:html baseURL:nil];
    } else {
        self.albumImage.image = [UIImage imageNamed:@"EmptyLogo"];
        self.artistLabel.text = @"";
        self.trackLabel.text = @"";
        self.albumName.text = @"";
        self.year.text = @"";
        [self.lyricsWebView loadHTMLString:@"" baseURL:nil];
    }
}

- (NSString *)htmlStringWithFont:(UIFont *)font {
    return [NSString stringWithFormat:@"<html><head><style type=\"text/css\">"
                      "body {font-family: \"%@\"; font-size: %f; margin: 0;}</style>"
                      "</head><body>%@</body></html>",
                      font.fontName, font.pointSize, self.trackInfo.lyrics];
}

@end
