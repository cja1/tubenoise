//
//  APCSVUtils.m
//  tubenoise
//
//  Created by Charles Allen on 30/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import "APCSVUtils.h"

@implementation APCSVUtils

- (void)createCSVFiles:(NSDictionary *)data rebasedUrl:(NSURL *)rebasedUrl processedUrl:(NSURL *)processedUrl {

    //Output both raw rebased data and processed data

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";

    //Rebased data
    NSArray *accelerometerVals = [data objectForKey:@"rebasedAccelerometerVals"];
    NSArray *accelerometerTime = [data objectForKey:@"rebasedAccelerometerTime"];
    NSArray *soundVals = [data objectForKey:@"rebasedSoundVals"];
    NSMutableString *csvRebased = [NSMutableString new];
    
    double duration = [[accelerometerTime lastObject] timeIntervalSinceDate:[accelerometerTime firstObject]];
    [csvRebased appendString:[NSString stringWithFormat:@"Sound & Vibration Recording - Raw Data\nRecorded at %@ duration %.1f seconds\n\n", [dateFormatter stringFromDate:[accelerometerTime firstObject]], duration]];
    [csvRebased appendString:@"Date,Seconds,Acceleration (m/s/s),Sound (dBFS)"];
    
    [self addVals1:accelerometerVals vals2:soundVals time:accelerometerTime toCSVString:csvRebased];
    NSError *error;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[rebasedUrl path]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[rebasedUrl path] error:nil];
    }
    [csvRebased writeToURL:rebasedUrl atomically:YES encoding:NSUTF8StringEncoding error:&error];

    //Processed data (note: mm/s/s not m/s/s
    accelerometerVals = [data objectForKey:@"processedAccelerometerVals"];
    accelerometerTime = [data objectForKey:@"processedAccelerometerTime"];
    soundVals = [data objectForKey:@"processedSoundVals"];
    NSMutableString *csvProcessed = [NSMutableString new];
    
    [csvProcessed appendString:[NSString stringWithFormat:@"Sound & Vibration Recording - Processed Data\nRecorded at %@ duration %.1f seconds\n\n", [dateFormatter stringFromDate:[accelerometerTime firstObject]], duration]];
    [csvProcessed appendString:@"Date,Seconds,Acceleration (mm/s/s),Sound (dBFS)"];
    
    [self addVals1:accelerometerVals vals2:soundVals time:accelerometerTime toCSVString:csvProcessed];

    if ([[NSFileManager defaultManager] fileExistsAtPath:[processedUrl path]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[processedUrl path] error:nil];
    }
    [csvProcessed writeToURL:processedUrl atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (void)addVals1:(NSArray *)vals1 vals2:(NSArray *)vals2 time:(NSArray *)time toCSVString:(NSMutableString *)csvString {
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSSS";
    NSDate *readingDate;
    NSTimeInterval readingSecs;
    for (int i = 0; i < [time count]; i++) {
        readingDate = [time objectAtIndex:i];
        readingSecs = [readingDate timeIntervalSinceDate:[time firstObject]];
        [csvString appendFormat:@"\n\"%@\",%f,%f,%f",
         [dateFormatter stringFromDate:readingDate],
         readingSecs,
         [[vals1 objectAtIndex:i] doubleValue],
         [[vals2 objectAtIndex:i] doubleValue]
         ];
    }
}

@end
