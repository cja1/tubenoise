//
//  APCSVUtils.h
//  tubenoise
//
//  Created by Charles Allen on 30/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APCSVUtils : NSObject

- (void)createCSVFiles:(NSDictionary *)data rebasedUrl:(NSURL *)rebasedUrl processedUrl:(NSURL *)processedUrl;

@end
