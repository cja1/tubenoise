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
    
    double min = [self calculateMin:data];
    double max = [self calculateMax:data];
    NSDictionary *dict = [self calcChartStepSize:max min:min targetSteps:5];
    double stepSize = [[dict objectForKey:@"stepSize"] doubleValue];
    double yStart = [[dict objectForKey:@"yStart"] doubleValue];
    double yEnd = [[dict objectForKey:@"yEnd"] doubleValue];

    [self boxAround:plot withInset:inset withColor:[UIColor grayColor]];
    [self addTimeLabelsToPlot:plot withTimeData:timeData withInset:inset];
    
    [self addValueLabelsLinesToPlot:plot yStart:yStart yEnd:yEnd stepSize:stepSize withInset:inset];
    
    //Add min / max values to top right of chart
    [self addLabelToView:plot withFrame:CGRectMake(plot.frame.size.width - 65.0f, 2.5f, 60.0f, 10.0f) withText:[NSString stringWithFormat:@"Min: %.3g", min] withSize:8 withAlignment:NSTextAlignmentLeft];
    [self addLabelToView:plot withFrame:CGRectMake(plot.frame.size.width - 65.0f, 12.5f, 60.0f, 10.0f) withText:[NSString stringWithFormat:@"Max: %.3g", max] withSize:8 withAlignment:NSTextAlignmentLeft];

    [self addLinesToPlot:plot withData:data withTimeData:timeData yStart:yStart yEnd:yEnd withInset:inset withLineColor:color];
}

+ (void)addLinesToPlot:(APPlotView *)plot withData:(NSArray *)data withTimeData:(NSArray *)timeData  yStart:(double)yStart yEnd:(double)yEnd withInset:(CGFloat)inset withLineColor:(UIColor *)color {
    
    double currentValue, currentTime;
    double duration = [[timeData lastObject] timeIntervalSinceDate:[timeData firstObject]];
    
    CGFloat yRange = plot.frame.size.height - 2 * inset;
    CGFloat xRange = (plot.frame.size.width - 2 * inset);
    
    CGFloat x, y, prevX = 0.0, prevY = 0.0, percentOfRange;
    
    for (int i = 0; i < [data count]; i++) {
        currentValue = [[data objectAtIndex:i] doubleValue];
        currentTime = [[timeData objectAtIndex:i] timeIntervalSinceDate:[timeData firstObject]];
        x = currentTime / duration * xRange + inset;
        percentOfRange = (currentValue - yStart) / (yEnd - yStart);
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
    double duration = [[timeData lastObject] timeIntervalSinceDate:[timeData firstObject]];
    
    CGFloat xRange = (plot.frame.size.width - 2 * inset);
    CGFloat x;
    NSInteger maxLabels = 10;   //only show 10 labels (otherwise labels overlap)
    NSInteger secsIncrement = (int)ceil(duration / (CGFloat)maxLabels);
    NSDate *currentDate;
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"mm.ss";
    for (int i = 0; i < [timeData count]; i++) {
        currentTime = [[timeData objectAtIndex:i] timeIntervalSinceDate:[timeData firstObject]];
        currentTimeSecs = (int)currentTime;
        if (currentTimeSecs < lastTimeSecs) {
            continue;
        }
        //Show this time as 03.54
        currentDate = [timeData objectAtIndex:i];
        x = currentTime / duration * xRange + inset; //this is the centre point
        [self addLabelToView:plot withFrame:CGRectMake(x - 20.0f, plot.frame.size.height - inset, 40.0f, inset) withText:[NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:currentDate]] withSize:8];
        [plot plotLineFrom:CGPointMake(x, inset) to:CGPointMake(x, plot.frame.size.height - inset) withColor:[UIColor grayColor] withWidth:0.5f];

        lastTimeSecs += secsIncrement;
    }
}

+ (void)addValueLabelsLinesToPlot:(APPlotView *)plot yStart:(double)yStart yEnd:(double)yEnd stepSize:(double)stepSize withInset:(CGFloat)inset {
    
    CGFloat yRange = plot.frame.size.height - 2 * inset;
    CGFloat percentOfRange;
    CGFloat y;
    
    double yVal = yStart;
    while (yVal <= yEnd) {
        
        percentOfRange =  (yVal - yStart) / (yEnd - yStart);
        y = plot.frame.size.height - inset - percentOfRange * yRange;

        [self addLabelToView:plot withFrame:CGRectMake(5.0f, y - 4.0f, 40.0f, 8.0f) withText:[NSString stringWithFormat:@"%.2g", yVal]withSize:8 withAlignment:NSTextAlignmentLeft];

        [plot plotLineFrom:CGPointMake(inset, y) to:CGPointMake(plot.frame.size.width - inset, y) withColor:[UIColor grayColor] withWidth:1.0f];
        
        yVal+= stepSize;
    }
}


+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size withAlignment:(NSTextAlignment)alignment withColor:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    label.textColor = color;
    label.textAlignment = alignment;
    if (view) {
        [view addSubview:label];
    }
    return label;
}

+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size withAlignment:(NSTextAlignment)alignment {
    return [self addLabelToView:view withFrame:frame withText:text withSize:size withAlignment:alignment withColor:[UIColor blackColor]];
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

+ (double)calculateMin:(NSArray *)data {
    double min = CGFLOAT_MAX;
    for (NSNumber *val in data) {
        if ([val doubleValue] < min) {
            min = [val doubleValue];
        }
    }
    return min;
}

+ (double)calculateMax:(NSArray *)data {
    double max = -CGFLOAT_MAX;
    for (NSNumber *val in data) {
        if ([val doubleValue] > max) {
            max = [val doubleValue];
        }
    }
    return max;
}

+ (NSDictionary *)calcChartStepSize:(double)max min:(double)min targetSteps:(NSInteger)targetSteps {
    //based on http://stackoverflow.com/questions/361681/algorithm-for-nice-grid-line-intervals-on-a-graph
    
    double range = max - min;
    
    // calculate an initial guess at step size
    double tempStep = range / (double)targetSteps;
    
    // get the magnitude of the step size
    double mag = floor(log10(tempStep));
    double magPow = pow(10.0f, mag);
    
    // calculate most significant digit of the new step size
    double magMsd = (int)(tempStep / magPow + 0.5);
    
    // promote the MSD to either 1, 2, or 5
    if (magMsd > 5.0)
        magMsd = 10.0f;
    else if (magMsd > 2.0)
        magMsd = 5.0f;
    else if (magMsd > 1.0)
        magMsd = 2.0f;
    
    double stepSize = magMsd * magPow;
    
    double yStart = min - (fmod(min, stepSize));
    //adjust for neagtive
    if (yStart < 0)
        yStart -= stepSize;
    double yEnd = max - (fmod(max, stepSize));
    //adjust for positive
    if (yEnd > 0)
        yEnd += stepSize;
    
    return @{@"yStart": [NSNumber numberWithDouble:yStart], @"yEnd": [NSNumber numberWithDouble:yEnd], @"stepSize": [NSNumber numberWithDouble:stepSize]};
}

@end
