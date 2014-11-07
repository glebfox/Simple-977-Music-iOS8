//
//  GG977StationInfo.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GG977StationInfo : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSURL *url;

- (id)initWithTitle:(NSString *)title url:(NSURL *)url;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end
