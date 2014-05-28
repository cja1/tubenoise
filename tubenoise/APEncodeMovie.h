//
//  APEncodeMovie.h
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.

//  Based on code by Vladimir Boychentsov on 5/21/11, Copyright 2011 www.injoit.com. All rights reserved.


#import <Foundation/Foundation.h>

@interface APEncodeMovie : NSObject

- (id)initWithSize:(CGSize)size url:(NSURL *)url;
- (BOOL)addImage:(UIImage *)image frameNum:(NSInteger)frameNum fps:(NSInteger)fps;
- (void)finaliseMovieWithBlock:(void (^)(NSNumber *status))block;

@end
