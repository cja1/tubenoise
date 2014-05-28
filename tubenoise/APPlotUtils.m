//
//  APPlotUtils.m
//  tubenoise
//
//  Created by Charles Allen on 27/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import "APPlotUtils.h"

@implementation APPlotUtils

+ (void)createChart:(APPlotView *)plot withData:(NSArray *)data withTimeData:(NSArray *)timeData withInset:(CGFloat)inset withLineColor:(UIColor *)color {
    [self boxAround:plot];
    if ([data count] == 0)
        return;
    [self boxAround:plot withInset:inset withColor:[UIColor grayColor]];
    [self addTimeLabelsToPlot:plot withTimeData:timeData withInset:inset];
    [self addValueLabelsToPlot:plot withData:data withInset:inset];
    [self addLinesToPlot:plot withData:data withTimeData:timeData withInset:inset withLineColor:color];
}

+ (void)addLinesToPlot:(APPlotView *)plot withData:(NSArray *)data withTimeData:(NSArray *)timeData withInset:(CGFloat)inset withLineColor:(UIColor *)color {
    
    double currentValue, currentTime, min = CGFLOAT_MAX, max = CGFLOAT_MIN;
    double duration = [[timeData lastObject] doubleValue];
    
    for (int i = 0; i < [data count]; i++) {
        currentValue = [[data objectAtIndex:i] doubleValue];
        min = MIN(min, currentValue);
        max = MAX(max, currentValue);
    }
    
    CGFloat yRange = plot.frame.size.height - 2 * inset;
    CGFloat xRange = (plot.frame.size.width - 2 * inset);
    
    CGFloat x, y, prevX = 0.0, prevY = 0.0, percentOfRange;
    
    for (int i = 0; i < [data count]; i++) {
        currentValue = [[data objectAtIndex:i] doubleValue];
        currentTime = [[timeData objectAtIndex:i] doubleValue];
        x = currentTime / duration * xRange + inset;
        percentOfRange = (currentValue - min) / (max - min);
        y = plot.frame.size.height -  inset - percentOfRange * yRange;
        if (i != 0) {
            [plot plotLineFrom:CGPointMake(prevX, prevY) to:CGPointMake(x, y) withColor:color withWidth:1.0f];
        }
        prevX = x; prevY = y;
    }
}

+ (void)addTimeLabelsToPlot:(APPlotView *)plot withTimeData:(NSArray *)timeData withInset:(CGFloat)inset {
    
    double currentTime;
    NSInteger currentTimeSecs, lastTimeSecs = 0;
    double duration = [[timeData lastObject] doubleValue];
    
    CGFloat xRange = (plot.frame.size.width - 2 * inset);
    CGFloat x;
    NSInteger maxLabels = (duration < 100) ? 20 : 10;   //over 100secs long, only show 10 labels (otherwise labels overlap)
    NSInteger secsIncrement = (int)ceil(duration / (CGFloat)maxLabels);
    
    for (int i = 0; i < [timeData count]; i++) {
        currentTime = [[timeData objectAtIndex:i] doubleValue];
        currentTimeSecs = (int)currentTime;
        if (currentTimeSecs < lastTimeSecs) {
            continue;
        }
        //Show this time in secs next to the vertical line
        x = currentTime / duration * xRange + inset; //this is the centre point
        [self addLabelToView:plot withFrame:CGRectMake(x - 10.0f, plot.frame.size.height - inset, 20.0f, inset) withText:[NSString stringWithFormat:@"%d", currentTimeSecs] withSize:8];
        
        lastTimeSecs += secsIncrement;
    }
    //Add 'sec' at end of line
    [self addLabelToView:plot withFrame:CGRectMake(plot.frame.size.width - inset, plot.frame.size.height - inset, inset, inset) withText:@"sec" withSize:8];
}

+ (void)addValueLabelsToPlot:(APPlotView *)plot withData:(NSArray *)data withInset:(CGFloat)inset {
    
    double currentValue, min = CGFLOAT_MAX, max = CGFLOAT_MIN;
    
    for (int i = 0; i < [data count]; i++) {
        currentValue = [[data objectAtIndex:i] doubleValue];
        min = MIN(min, currentValue);
        max = MAX(max, currentValue);
    }
    
    //CGFloat yRange = plot.frame.size.height - 2 * kChartInset;
    //Add val at top / bottom
    [self addLabelToView:plot withFrame:CGRectMake(5.0f, inset - 9.0f, 40.0f, 8.0f) withText:[NSString stringWithFormat:@"%.2g", max] withSize:8 withAlignment:NSTextAlignmentLeft];
    [self addLabelToView:plot withFrame:CGRectMake(5.0f, plot.frame.size.height - inset, 40.0f, 8.0f) withText:[NSString stringWithFormat:@"%.2g", min] withSize:8 withAlignment:NSTextAlignmentLeft];
    
    //If min -> max passes through 0 add zero line and label
    if (min < 0 && max > 0) {
        CGFloat yRange = plot.frame.size.height - 2 * inset;
        CGFloat percentOfRange =  -1.0f * min / (max - min);
        CGFloat y = plot.frame.size.height -  inset - percentOfRange * yRange;
        [plot plotLineFrom:CGPointMake(inset, y) to:CGPointMake(plot.frame.size.width - inset, y) withColor:[UIColor grayColor] withWidth:1.0f];
        [self addLabelToView:plot withFrame:CGRectMake(5.0f, y - 4.0f, 40.0f, 8.0f) withText:@"0" withSize:8 withAlignment:NSTextAlignmentLeft];
    }
    
    //Add min / max values to top right of chart
    [self addLabelToView:plot withFrame:CGRectMake(plot.frame.size.width - 65.0f, 2.5f, 60.0f, 10.0f) withText:[NSString stringWithFormat:@"Min: %.3g", min] withSize:8 withAlignment:NSTextAlignmentLeft];
    [self addLabelToView:plot withFrame:CGRectMake(plot.frame.size.width - 65.0f, 12.5f, 60.0f, 10.0f) withText:[NSString stringWithFormat:@"Max: %.3g", max] withSize:8 withAlignment:NSTextAlignmentLeft];
}

+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size withAlignment:(NSTextAlignment)alignment {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    label.textAlignment = alignment;
    if (view) {
        [view addSubview:label];
    }
    return label;
}

+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size {
    return [self addLabelToView:view withFrame:frame withText:text withSize:size withAlignment:NSTextAlignmentCenter];
}

+ (void)boxAround:(APPlotView *)plot {
    [self boxAround:plot withInset:0.0f withColor:[UIColor blackColor]];
}

+ (void)boxAround:(APPlotView *)plot withInset:(CGFloat)inset withColor:(UIColor *)color {
    CGRect frame = plot.frame;
    [plot plotLineFrom:CGPointMake(0.5 + inset, 0.5 + inset) to:CGPointMake(frame.size.width - 0.5f - inset, 0.5f + inset) withColor:color withWidth:1.0f];
    [plot plotLineFrom:CGPointMake(frame.size.width - 0.5f - inset, 0.5f + inset) to:CGPointMake(frame.size.width - 0.5f - inset, frame.size.height - 0.5f - inset) withColor:color withWidth:1.0f];
    [plot plotLineFrom:CGPointMake(frame.size.width - 0.5f - inset, frame.size.height - 0.5f - inset) to:CGPointMake(0.5f + inset, frame.size.height - 0.5f - inset) withColor:color withWidth:1.0f];
    [plot plotLineFrom:CGPointMake(0.5f + inset, frame.size.height - 0.5f - inset) to:CGPointMake(0.5f + inset, 0.5f + inset) withColor:color withWidth:1.0f];
}

+ (UIImage *)imageFromColor:(UIColor *)color withRect:(CGRect)rect {
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (void)removeAllSubviews:(UIView *)view {
    for (UIView *subview in [view subviews]) {
        [subview removeFromSuperview];
    }
}

@end
