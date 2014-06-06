//
//  APDataProcessor.m
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import "APDataProcessor.h"

#define kSampleDuration     0.125   //sample data over this period in seconds

@implementation APDataProcessor

- (void)processData:(NSMutableDictionary *)data startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime {
    
    NSArray *accelerometerVals = [data objectForKey:@"accelerometerVals"];
    NSArray *accelerometerTime = [data objectForKey:@"accelerometerTime"];
    NSArray *soundVals = [data objectForKey:@"soundVals"];
    NSArray *soundTime = [data objectForKey:@"soundTime"];
    
    NSDictionary *ret;
    
    //acceleration
    ret = [self rebaseData:accelerometerVals time:accelerometerTime startTime:startTime endTime:endTime];
    [data setObject:[ret objectForKey:@"vals"] forKey:@"rebasedAccelerometerVals"];
    [data setObject:[ret objectForKey:@"time"] forKey:@"rebasedAccelerometerTime"];
    
    ret = [self sampleData:[ret objectForKey:@"vals"] time:[ret objectForKey:@"time"] startTime:startTime endTime:endTime];

    ret = [self processAccelerometerData:[ret objectForKey:@"vals"] time:[ret objectForKey:@"time"]];
    [data setObject:[ret objectForKey:@"vals"] forKey:@"processedAccelerometerVals"];
    [data setObject:[ret objectForKey:@"time"] forKey:@"processedAccelerometerTime"];

    //sound
    ret = [self rebaseData:soundVals time:soundTime startTime:startTime endTime:endTime];
    [data setObject:[ret objectForKey:@"vals"] forKey:@"rebasedSoundVals"];
    [data setObject:[ret objectForKey:@"time"] forKey:@"rebasedSoundTime"];

    ret = [self sampleData:[ret objectForKey:@"vals"] time:[ret objectForKey:@"time"] startTime:startTime endTime:endTime];

    ret = [self processSoundData:[ret objectForKey:@"vals"] time:[ret objectForKey:@"time"]];
    [data setObject:[ret objectForKey:@"vals"] forKey:@"processedSoundVals"];
    [data setObject:[ret objectForKey:@"time"] forKey:@"processedSoundTime"];
}

- (NSDictionary *)rebaseData:(NSArray *)vals time:(NSArray *)time startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime {
    
    NSMutableArray *rebaseVals = [NSMutableArray new];
    NSMutableArray *rebaseTime = [NSMutableArray new];
    
    double currentVal, currentSecs;
    
    //Rebase the data to start at startTime and end at endTime
    for (int i = 0; i < [vals count]; i++) {
        currentVal = [[vals objectAtIndex:i] doubleValue];
        currentSecs = [[time objectAtIndex:i] timeIntervalSinceDate:[time firstObject]];
        
        //if within time, add to segment arrays
        if ((currentSecs >= startTime) && (currentSecs <= endTime)) {
            [rebaseVals addObject:[vals objectAtIndex:i]];
            [rebaseTime addObject:[time objectAtIndex:i]];
        }
    }
    
    return [NSDictionary dictionaryWithObjectsAndKeys:rebaseVals, @"vals", rebaseTime, @"time", nil];
}

- (NSDictionary *)sampleData:(NSArray *)vals time:(NSArray *)time startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime {
    
    NSMutableArray *sampleVals = [NSMutableArray new];
    NSMutableArray *sampleTime = [NSMutableArray new];
    
    double currentVal, currentSecs;

    //Sample the data into kSampleDuration samples - take the max abs value within the sample period
    double currentSampleMaxVal = 0.0f;
    double currentSampleTime = 0.0f;
    double currentSampleTimeEnd = kSampleDuration;
    NSDate *currentSampleDate;
    BOOL didStartCurrentSampling = NO;
    for (int i = 0; i < [vals count]; i++) {
        currentVal = [[vals objectAtIndex:i] doubleValue];
        currentSecs = [[time objectAtIndex:i] timeIntervalSinceDate:[time firstObject]];
        
        //See if still in this sample period
        if (currentSecs < currentSampleTimeEnd) {
            //still in this sample - update currentSampleMaxVal and continue
            if (fabs(currentVal) > fabs(currentSampleMaxVal)) {
                currentSampleMaxVal = currentVal;   //keep sign of currentVal
            }
            didStartCurrentSampling = YES;
            continue;
        }
        
        //End of sample period. Save data and update currentSampleTime and currentSampleTimeEnd
        //Note: the sample time is set to the middle of the sample period
        currentSampleDate = [NSDate dateWithTimeInterval:(currentSampleTime + kSampleDuration / 2.0f) sinceDate:[time firstObject]];
        [sampleVals addObject:[NSNumber numberWithDouble:currentSampleMaxVal]];
        [sampleTime addObject:currentSampleDate];
        currentSampleMaxVal = 0.0f;
        currentSampleTime = currentSampleTimeEnd;
        currentSampleTimeEnd += kSampleDuration;
        didStartCurrentSampling = NO;
    }
    //add last datapoint - unless no sampling
    if (didStartCurrentSampling) {
        currentSampleDate = [NSDate dateWithTimeInterval:(currentSampleTime + kSampleDuration / 2.0f) sinceDate:[time firstObject]];
        [sampleVals addObject:[NSNumber numberWithDouble:currentSampleMaxVal]];
        [sampleTime addObject:currentSampleDate];
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:sampleVals, @"vals", sampleTime, @"time", nil];
}

- (NSDictionary *)processAccelerometerData:(NSArray *)vals time:(NSArray *)time {
    
    NSMutableArray *valsOut = [NSMutableArray new];
    NSMutableArray *timeOut = [NSMutableArray new];
    
    double currentValue, accelInMMPerSec;
    
    for (int i = 0; i < [vals count]; i++) {
        currentValue = [[vals objectAtIndex:i] doubleValue];

        //convert value to mm/sec2
        accelInMMPerSec = currentValue * 1000.0f;    //mm/s2

        //Make accels all positive for chart
        accelInMMPerSec = fabs(accelInMMPerSec);
        
        [valsOut addObject:[NSNumber numberWithDouble:accelInMMPerSec]];
        [timeOut addObject:[time objectAtIndex:i]];
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:valsOut, @"vals", timeOut, @"time", nil];
}

- (NSDictionary *)processSoundData:(NSArray *)vals time:(NSArray *)time {
    
    NSMutableArray *valsOut = [NSMutableArray new];
    NSMutableArray *timeOut = [NSMutableArray new];
    
    double currentValue, amplitude;
    
    for (int i = 0; i < [vals count]; i++) {
        currentValue = [[vals objectAtIndex:i] doubleValue]; //dBFS ie db relative to Full Scale. Range: -160dB to 0dB
        
        //linear amplitude from dB Full Scale
        //NOT USED
        amplitude = powf(10.0f, currentValue / 20.0f);
        
        [valsOut addObject:[NSNumber numberWithDouble:currentValue]];
        [timeOut addObject:[time objectAtIndex:i]];
    }
    
    return [NSDictionary dictionaryWithObjectsAndKeys:valsOut, @"vals", timeOut, @"time", nil];
}

@end
