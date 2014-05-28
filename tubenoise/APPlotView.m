//
//  APPlotView.m
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//
//  Based on: http://stackoverflow.com/questions/3007153/drawing-pixels-objective-c-cocoa

#import "APPlotView.h"

@implementation APPlotView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGFloat width = frame.size.width;
        CGFloat height = frame.size.height;
        size_t bitsPerComponent = 8;
        size_t bytesPerRow = (4 * width);
        _context = CGBitmapContextCreate(NULL, width, height, bitsPerComponent, bytesPerRow, colorspace, (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
        CGColorSpaceRelease(colorspace);
        CGSize size = frame.size;
        _drawingLayer = CGLayerCreateWithContext(_context, size, NULL);
    }
    return self;
}

- (void) drawRect:(CGRect)rect {
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGImageRef image = CGBitmapContextCreateImage(_context);
    CGRect bounds = [self bounds];
    CGContextDrawImage(currentContext, bounds, image);
    CGImageRelease(image);
    CGContextDrawLayerInRect(currentContext, bounds, _drawingLayer);
}

- (void) plotLineFrom:(CGPoint)pointStart to:(CGPoint)pointEnd withColor:(UIColor *)color withWidth:(CGFloat)lineWidth {
    
    CGContextRef layerContext = CGLayerGetContext(_drawingLayer);
    
    CGContextSetLineWidth(layerContext, lineWidth);
    CGContextSetLineCap(layerContext, kCGLineCapRound);
    CGContextSetStrokeColorWithColor(layerContext, color.CGColor);
    
    CGContextBeginPath(layerContext);
    
    CGContextMoveToPoint(layerContext, pointStart.x, pointStart.y);
    CGContextAddLineToPoint(layerContext, pointEnd.x, pointEnd.y);
    
    CGContextStrokePath(layerContext);
    
    [self setNeedsDisplay];
}

- (void)clear {
    CGContextClearRect(CGLayerGetContext(_drawingLayer), [self bounds]);
    [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:self waitUntilDone:YES];
    //[self setNeedsDisplay];
}


@end
