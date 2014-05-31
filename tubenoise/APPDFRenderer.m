//
//  APPDFRenderer.m
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import "APPDFRenderer.h"
#import "CoreText/CoreText.h"
#import "APPlotUtils.h"
#import <QuartzCore/QuartzCore.h>

#define kTagStartDate   1
#define kTagAccelMin    100
#define kTagAccelMax    101
#define kTagSoundMin    200
#define kTagSoundMax    201

@implementation APPDFRenderer

- (void)createPDF:(NSDictionary *)data url:(NSURL *)url  {
    CGFloat width = 595.0;
    CGFloat height = 842.0f;
    
    NSArray *accelerometerVals = [data objectForKey:@"processedAccelerometerVals"];
    NSArray *accelerometerTime = [data objectForKey:@"processedAccelerometerTime"];
    NSArray *soundVals = [data objectForKey:@"processedSoundVals"];
    NSArray *soundTime = [data objectForKey:@"processedSoundTime"];
    
    //delete file if exisst
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[url path] error:nil];
    }

    // Create the PDF context
    UIGraphicsBeginPDFContextToFile([url path], CGRectMake(0.0f, 0.0f, width, height), nil);
    // New page
    UIGraphicsBeginPDFPageWithInfo(CGRectMake(0.0f, 0.0f, width, height), nil);
    
    //load the xib template
    UIView *template = [self loadTemplate];
    
    //Update the tagged labels text
    [self setTagsInTemplate:template accelVals:accelerometerVals soundVals:soundVals time:accelerometerTime];
    
    //Copy the elements from the template to the pdf
    [self loadElementsFromTemplate: template];
    
    //Create the chart boxes
    [self drawBox:CGRectMake(20.0f, 103.0f, 555.05, 350.0f) width:1.0f color:[UIColor blackColor]];
    [self drawBox:CGRectMake(20.0f, 472.0f, 555.05, 350.0f) width:1.0f color:[UIColor blackColor]];
    
    //Create chart plots
    CGFloat xInset = 10.0f;
    CGFloat yTopInset = 40.0f;
    CGFloat yBottomInset = 10.0f;
    [self drawChart:accelerometerVals time:accelerometerTime rect:CGRectMake(20.0f + xInset, 103.0f + yTopInset, 555.0f - 2 * xInset, 350.0f - yTopInset - yBottomInset) color:[UIColor redColor]];
    [self drawChart:soundVals time:soundTime rect:CGRectMake(20.0f + xInset, 472.0f + yTopInset, 555.0f - 2 * xInset, 350.0f - yTopInset - yBottomInset) color:[UIColor blueColor]];
    
    UIGraphicsEndPDFContext();
}

- (void)drawChart:(NSArray *)vals time:(NSArray *)time rect:(CGRect)rect color:(UIColor *)color {
    //1. calculate min, max and axes range / step size
    double min = [APPlotUtils calculateMin:vals];
    double max = [APPlotUtils calculateMax:vals];
    NSDictionary *dict = [APPlotUtils calcChartStepSize:max min:min targetSteps:8];
    double stepSize = [[dict objectForKey:@"stepSize"] doubleValue];
    double yStart = [[dict objectForKey:@"yStart"] doubleValue];
    double yEnd = [[dict objectForKey:@"yEnd"] doubleValue];
    
    //2. draw axes and labels
    CGFloat insetBottomLeft = 40.0f;
    [self drawTimeLabelsLines:time withRect:rect chartInsetLeftBottom: insetBottomLeft];
    [self drawValueLabelsLines:yStart yEnd:yEnd stepSize:stepSize withRect:rect chartInsetLeftBottom: insetBottomLeft];
    
    //3. draw line
    [self drawLine:vals time:time yStart:yStart yEnd:yEnd rect:CGRectMake(rect.origin.x + insetBottomLeft, rect.origin.y, rect.size.width - insetBottomLeft, rect.size.height - insetBottomLeft) color:color];
}

- (void)drawLine:(NSArray *)vals time:(NSArray *)time yStart:(double)yStart yEnd:(double)yEnd rect:(CGRect)rect color:(UIColor *)color {
    
    CGFloat percentOfRange;
    double duration = [[time lastObject] timeIntervalSinceDate:[time firstObject]];
    
    CGFloat xRange = rect.size.width;
    CGFloat yRange = rect.size.height;
    
    CGFloat x, y;
    CGFloat prevX = 0.0, prevY = 0.0;
    double currentVal, currentTime;
    
    for (int i = 0; i < [vals count]; i++) {
        currentVal = [[vals objectAtIndex:i] doubleValue];
        currentTime = [[time objectAtIndex:i] timeIntervalSinceDate:[time firstObject]];
        
        x = rect.origin.x + currentTime / duration * xRange;
        percentOfRange =  (currentVal - yStart) / (yEnd - yStart);
        y = rect.origin.y + yRange * (1.0f - percentOfRange);
        if (i != 0) {
            [self drawLineFrom:CGPointMake(prevX, prevY) to:CGPointMake(x, y) width:1.0f color:color];
        }
        prevX = x; prevY = y;
    }
}

- (void)drawTimeLabelsLines:(NSArray *)time withRect:(CGRect)rect chartInsetLeftBottom:(CGFloat)insetLeftBottom {
    
    NSDictionary *att = [self labelAttributes:NSTextAlignmentCenter];
    double currentTime;
    NSInteger currentTimeSecs, lastTimeSecs = 0;
    double duration = [[time lastObject] timeIntervalSinceDate:[time firstObject]];
    
    CGFloat xRange = rect.size.width - insetLeftBottom;
    CGFloat x;
    NSInteger maxLabels = 10;
    NSInteger secsIncrement = (int)ceil(duration / (CGFloat)maxLabels);
    NSDate *currentDate;
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"mm.ss";
    for (int i = 0; i < [time count]; i++) {
        currentTime = [[time objectAtIndex:i] timeIntervalSinceDate:[time firstObject]];
        currentTimeSecs = (int)currentTime;
        if (currentTimeSecs < lastTimeSecs) {
            continue;
        }
        //Show this time as 03.54
        currentDate = [time objectAtIndex:i];
        x = currentTime / duration * xRange + rect.origin.x + insetLeftBottom; //this is the centre point
        
        [self drawText:[NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:currentDate]] inFrame:CGRectMake(x - 20.0f, rect.origin.y + rect.size.height - insetLeftBottom + 10.0f, 40.0f, 16.0f) withAttributes:att];
    
        [self drawLineFrom:CGPointMake(x, rect.origin.y) to:CGPointMake(x, rect.origin.y + rect.size.height - insetLeftBottom) width:1.0f color:[UIColor grayColor]];
        
        lastTimeSecs += secsIncrement;
    }
    
    //add vertical lines at start / end (don't start / end on whole number of seconds)
    x = rect.origin.x + insetLeftBottom;
    [self drawLineFrom:CGPointMake(x, rect.origin.y) to:CGPointMake(x, rect.origin.y + rect.size.height - insetLeftBottom) width:1.0f color:[UIColor grayColor]];
    x = rect.origin.x + rect.size.width;
    [self drawLineFrom:CGPointMake(x, rect.origin.y) to:CGPointMake(x, rect.origin.y + rect.size.height - insetLeftBottom) width:1.0f color:[UIColor grayColor]];
}

- (void)drawValueLabelsLines:(double)yStart yEnd:(double)yEnd stepSize:(double)stepSize withRect:(CGRect)rect chartInsetLeftBottom:(CGFloat)insetLeftBottom {
    
    NSDictionary *att = [self labelAttributes:NSTextAlignmentRight];

    CGFloat yRange = rect.size.height - insetLeftBottom;
    CGFloat percentOfRange;
    CGFloat y;

    double yVal = yStart;
    while (yVal <= yEnd) {
        percentOfRange =  (yVal - yStart) / (yEnd - yStart);
        y = rect.origin.y + rect.size.height -  insetLeftBottom - percentOfRange * yRange;

        [self drawText:[NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"%.3g", yVal]] inFrame:CGRectMake(rect.origin.x, y - 8.0f, insetLeftBottom - 5.0f, 12.0f) withAttributes:att];
        
        [self drawLineFrom:CGPointMake(rect.origin.x + insetLeftBottom, y) to:CGPointMake(rect.origin.x + rect.size.width, y) width:1.0f color:[UIColor grayColor]];

        yVal+= stepSize;
    }
}

- (NSDictionary *)labelAttributes:(NSTextAlignment)alignment {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = alignment;
    NSDictionary *att = @{ NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue-Light" size:12.0f], NSForegroundColorAttributeName:[UIColor blackColor], NSParagraphStyleAttributeName: paragraphStyle };
    return att;
}

- (void)setTagsInTemplate:(UIView *)template accelVals:(NSArray *)accelerometerVals soundVals:(NSArray *)soundVals time:(NSArray *)time {

    for (UIView *view in [template subviews]) {
        if (![view isKindOfClass:[UILabel class]]) {
            continue;
        }
        UILabel *label = (UILabel *)view;
        switch (view.tag) {
            case kTagStartDate: {
                NSDateFormatter *dateFormatter = [NSDateFormatter new];
                dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                label.text = [NSString stringWithFormat:@"Recorded at: %@", [dateFormatter stringFromDate:[time firstObject]]];
            }
                break;
                
            case kTagAccelMin:
                label.text = [NSString stringWithFormat:@"%.4g", [APPlotUtils calculateMin:accelerometerVals]];
                break;
                
            case kTagAccelMax:
                label.text = [NSString stringWithFormat:@"%.4g", [APPlotUtils calculateMax:accelerometerVals]];
                break;
                
            case kTagSoundMin:
                label.text = [NSString stringWithFormat:@"%.4g", [APPlotUtils calculateMin:soundVals]];
                break;
                
            case kTagSoundMax:
                label.text = [NSString stringWithFormat:@"%.4g", [APPlotUtils calculateMax:soundVals]];
                break;
        }
    }
}

- (UIView *)loadTemplate {
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"PDFTemplate" owner:nil options:nil];
    for (id view in nib) {
        if ([view isKindOfClass:[UIView class]])
            return view;
    }
    return nil;
}

- (void)loadElementsFromTemplate:(UIView *)template {
    
    for (UIView *view in [template subviews]) {
        if ([view isKindOfClass:[UILabel class]]) {
            [self addLabel:(UILabel *)view];
        }
        //Add other types here
    }
}

- (void)addLabel:(UILabel *)label {

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = label.textAlignment;
    
    NSDictionary *att = @{ NSFontAttributeName: label.font, NSForegroundColorAttributeName:label.textColor, NSParagraphStyleAttributeName: paragraphStyle };
    [self drawText:label.text inFrame:label.frame withAttributes:att];
}

- (void)drawText:(NSString *)text inFrame:(CGRect)frame withAttributes:(NSDictionary *)attributes {
    [text drawInRect:frame withAttributes:attributes];
}

- (void)drawLineFrom:(CGPoint)from to:(CGPoint)to width:(CGFloat)width color:(UIColor *)color {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, width);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextMoveToPoint(context, from.x, from.y);
    CGContextAddLineToPoint(context, to.x, to.y);
    CGContextStrokePath(context);
}

- (void)drawBox:(CGRect)rect width:(CGFloat)width color:(UIColor *)color {
    [self drawLineFrom:CGPointMake(rect.origin.x, rect.origin.y) to:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y) width:width color:color];
    [self drawLineFrom:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y) to:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height) width:width color:color];
    [self drawLineFrom:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height) to:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height) width:width color:color];
    [self drawLineFrom:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height) to:CGPointMake(rect.origin.x, rect.origin.y) width:width color:color];
}

@end
