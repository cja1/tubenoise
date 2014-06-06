//
//  APPlotView.h
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


@interface APPlotView : UIView

@property (nonatomic) CGContextRef context;
@property (nonatomic) CGLayerRef drawingLayer;

- (void) plotLineFrom:(CGPoint)pointStart to:(CGPoint)pointEnd withColor:(UIColor *)color withWidth:(CGFloat)lineWidth;

- (void) clear;

@end
