//
//  APMovieProcessor.m
//  tubenoise
//
//  Created by Charles Allen on 29/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import "APMovieProcessor.h"
#import <AVFoundation/AVFoundation.h>

@implementation APMovieProcessor

- (void)trimCAFAudio:(NSURL *)audioUrlIn startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime block:(void (^)(NSNumber *status))block {
    
    CMTime start = CMTimeMake(startTime * 100.0f, 100); //0.01 second resolution
    CMTime duration = CMTimeMake((endTime - startTime) * 100.0f, 100);
    CMTimeRange timeRange = CMTimeRangeMake(start, duration);
    NSError *error;
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempaudio2.caf"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    }
    NSURL *trimmedAudioUrl = [NSURL fileURLWithPath:path];
    [[NSFileManager defaultManager] copyItemAtURL:audioUrlIn toURL:trimmedAudioUrl error:&error];
    
    //delete original
    [[NSFileManager defaultManager] removeItemAtURL:audioUrlIn error:&error];
    
    //Create new composition
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    //Add audio - with cropped time range
    AVURLAsset* audioAsset = [[AVURLAsset alloc] initWithURL:trimmedAudioUrl options:nil];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange:timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:&error];
    
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    
    assetExport.outputFileType = AVFileTypeCoreAudioFormat;
    assetExport.outputURL = audioUrlIn;     //write to original url location
    assetExport.shouldOptimizeForNetworkUse = YES;
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        if (block) {
            if (assetExport.status == AVAssetExportSessionStatusCompleted) {
                block([NSNumber numberWithInteger:1]);
            }
            else {
                block([NSNumber numberWithInteger:0]);
            }
        }
    }];
}

- (void)trimM4AAudio:(NSURL *)audioUrlIn startTime:(NSTimeInterval)startTime endTime:(NSTimeInterval)endTime block:(void (^)(NSNumber *status))block {
    
    CMTime start = CMTimeMake(startTime * 100.0f, 100); //0.01 second resolution
    CMTime duration = CMTimeMake((endTime - startTime) * 100.0f, 100);
    CMTimeRange timeRange = CMTimeRangeMake(start, duration);
    NSError *error;

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempaudio2.m4a"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    }
    NSURL *trimmedAudioUrl = [NSURL fileURLWithPath:path];
    [[NSFileManager defaultManager] copyItemAtURL:audioUrlIn toURL:trimmedAudioUrl error:&error];

    //delete original
    [[NSFileManager defaultManager] removeItemAtURL:audioUrlIn error:&error];
    
    //Create new composition
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    //Add audio - with cropped time range
    AVURLAsset* audioAsset = [[AVURLAsset alloc] initWithURL:trimmedAudioUrl options:nil];
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange:timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:&error];
    
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    
    assetExport.outputFileType = AVFileTypeAppleM4A;
    assetExport.outputURL = audioUrlIn;     //write to original url location
    assetExport.shouldOptimizeForNetworkUse = YES;
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        if (block) {
            if (assetExport.status == AVAssetExportSessionStatusCompleted) {
                block([NSNumber numberWithInteger:1]);
            }
            else {
                block([NSNumber numberWithInteger:0]);
            }
        }
    }];
}

- (void)createMovieWithVideo:(NSURL *)videoUrl audio:(NSURL *)audioUrl output:(NSURL *)outputUrl block:(void (^)(NSNumber *status))block {
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoUrl options:nil];
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audioUrl options:nil];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    //Add audio
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration) ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]atTime:kCMTimeZero error:nil];
    
    //Add video
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];

    //delete file if exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:[outputUrl path]]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:[outputUrl path] error:&error];
    }

    assetExport.outputFileType = AVFileTypeMPEG4;
    assetExport.outputURL = outputUrl;
    assetExport.shouldOptimizeForNetworkUse = YES;
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        if (block) {
            if (assetExport.status == AVAssetExportSessionStatusCompleted) {
                block([NSNumber numberWithInteger:1]);
            }
            else {
                block([NSNumber numberWithInteger:0]);
            }
        }
    }];
}

@end
