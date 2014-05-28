
/*
     File: APLGraphView.h
  Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface APLGraphView : UIView

@property (nonatomic, assign) CGColorRef lineColor;

-(id)initWithFrame:(CGRect)frame lineColor:(CGColorRef)thisLineColor;

- (void)add:(double)val;

@end
