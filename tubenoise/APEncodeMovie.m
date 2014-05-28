//
//  APEncodeMovie.m
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.

//  Based on code by Vladimir Boychentsov on 5/21/11, Copyright 2011 www.injoit.com. All rights reserved.


#import "APEncodeMovie.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@interface APEncodeMovie()

@property (strong, nonatomic) AVAssetWriter *videoWriter;
@property (strong, nonatomic) AVAssetWriterInput* writerInput;
@property (strong, nonatomic) AVAssetWriterInputPixelBufferAdaptor *adaptor;

@end

@implementation APEncodeMovie

- (id)initWithSize:(CGSize)size url:(NSURL *)url {

    self = [super init];
    if (self) {
        NSError *error = nil;
        
        //Video writer
        _videoWriter = [[AVAssetWriter alloc] initWithURL: url fileType:AVFileTypeMPEG4 error:&error];
        NSParameterAssert(_videoWriter);
        
        //Writer input
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecH264,                            AVVideoCodecKey,
                                       [NSNumber numberWithInt:size.width],         AVVideoWidthKey,
                                       [NSNumber numberWithInt:size.height],        AVVideoHeightKey,
                                       nil];
        _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        NSParameterAssert(_writerInput);
        
        NSParameterAssert([_videoWriter canAddInput:_writerInput]);
        [_videoWriter addInput:_writerInput];
        
        //Pixel buffer adapter
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey,
                                    [NSNumber numberWithUnsignedInt:size.width],           kCVPixelBufferWidthKey,
                                    [NSNumber numberWithUnsignedInt:size.height],          kCVPixelBufferHeightKey,
                                    nil];
        _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_writerInput sourcePixelBufferAttributes:attributes];
        
        //Start a session:
        [_videoWriter startWriting];
        [_videoWriter startSessionAtSourceTime:kCMTimeZero];
        
    }
    return self;
}

- (BOOL)addImage:(UIImage *)image frameNum:(NSInteger)frameNum fps:(NSInteger)fps {
    
    CVPixelBufferRef pixelBuffer;
    [self createPixelBufferFromCGImage:[image CGImage] withPixelBufferPtr:&pixelBuffer];
    
    CMTime presentTime = CMTimeMake(frameNum, (int32_t)fps);

    BOOL ret = [_adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentTime];
    CVPixelBufferRelease(pixelBuffer);
    [NSThread sleepForTimeInterval:0.05];
    return ret;
}

- (void)finaliseMovieWithBlock:(void (^)(NSNumber *status))block {
    //Finish the session:
    [_writerInput markAsFinished];
    [_videoWriter finishWritingWithCompletionHandler:^{
        if (block) {
            if (_videoWriter.status == AVAssetWriterStatusCompleted) {
                block([NSNumber numberWithInteger:1]);
            }
            else {
                block([NSNumber numberWithInteger:0]);
            }
        }
    }];
    CVPixelBufferPoolRelease(_adaptor.pixelBufferPool);
}

- (void)createPixelBufferFromCGImage:(CGImageRef)image withPixelBufferPtr:(CVPixelBufferRef *)pixelBufferPtr {
    CFDataRef imageData= CGDataProviderCopyData(CGImageGetDataProvider(image));

    CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
        CGImageGetWidth(image), CGImageGetHeight(image),
        kCVPixelFormatType_32BGRA, (void*)CFDataGetBytePtr(imageData),
        CGImageGetBytesPerRow(image), NULL, NULL, NULL, pixelBufferPtr);
    
    CFRelease(imageData);
}

@end
