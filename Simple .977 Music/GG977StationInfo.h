//
//  GG977StationInfo.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GG977StationInfo : NSObject

@property NSString *title;
@property NSURL *url;

- (id)initWithTitle:(NSString *)title url:(NSURL *)url;

@end
