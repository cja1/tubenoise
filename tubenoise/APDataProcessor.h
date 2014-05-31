//
//  APDataProcessor.h
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APDataProcessor : NSObject

- (void)processData:(NSMutableDictionary *)data startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime;

@end
