//
//  GG977StationInfo.h
//  Simple .977 Music
//
//  Created by Gleb Gorelov on 01.10.14.
//  Copyright (c) 2014 Gleb Gorelov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GG977StationInfo : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, assign) NSUInteger externalID;

- (id)initWithTitle:(NSString *)title;

@end
