//
//  APPlotUtils.h
//  tubenoise
//
//  Created by Charles Allen on 27/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "APPlotView.h"

@interface APPlotUtils : NSObject

+ (void)createChart:(APPlotView *)plot withData:(NSArray *)data withTimeData:(NSArray *)timeData withInset:(CGFloat)inset withLineColor:(UIColor *)color;

+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withFont:(UIFont *)font withAlignment:(NSTextAlignment)alignment withColor:(UIColor *)color;
+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size withAlignment:(NSTextAlignment)alignment withColor:(UIColor *)color;
+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size withAlignment:(NSTextAlignment)alignment;
+ (UILabel *)addLabelToView:(UIView *)view withFrame:(CGRect)frame withText:(NSString *)text withSize:(NSInteger)size;

+ (UIImage *)imageFromColor:(UIColor *)color withRect:(CGRect)rect;

+ (void)removeAllSubviews:(UIView *)view;

+ (double)calculateMin:(NSArray *)data;
+ (double)calculateMax:(NSArray *)data;
+ (NSDictionary *)calcChartStepSize:(double)max min:(double)min targetSteps:(NSInteger)targetSteps;

@end
