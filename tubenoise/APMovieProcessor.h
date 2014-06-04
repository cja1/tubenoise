//
//  APMovieProcessor.h
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APMovieProcessor : NSObject

- (void)trimCAFAudio:(NSURL *)audioUrlIn startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime block:(void (^)(NSNumber *status))block;

- (void)trimM4AAudio:(NSURL *)audioUrlIn startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime block:(void (^)(NSNumber *status))block;

- (void)createMovieWithVideo:(NSURL *)videoUrl audio:(NSURL *)audioUrl output:(NSURL *)outputUrl block:(void (^)(NSNumber *status))block;

@end
