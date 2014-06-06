//
//  APPDFRenderer.h
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APPDFRenderer : NSObject

- (void)createPDF:(NSDictionary *)data url:(NSURL *)url;

@end
