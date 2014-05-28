//
//  APHomeViewController.m
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Agile Projects Ltd. All rights reserved.
//

#import "APHomeViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "APPlotView.h"
#import <QuartzCore/QuartzCore.h>
#import "APEncodeMovie.h"
#import "APLGraphView.h"
#import "APPlotUtils.h"

#define kAccelerometerAverageInterval       1000    //10 sec bias calculation / averaging for z axis acceleration - for realtime display only
#define kFramesPerSec                       10
#define kChartInset                         25.0f

@interface APHomeViewController ()

@property (strong, nonatomic) APLGraphView *graphViewAccelerometer;
@property (strong, nonatomic) APLGraphView *graphViewSound;

@property (strong, nonatomic) NSMutableArray *accelerometerData;
@property (strong, nonatomic) NSMutableArray *soundData;
@property (strong, nonatomic) NSMutableArray *timeData;

@property (nonatomic, assign) BOOL isRecording;

@property (strong, nonatomic) NSURL *videoUrl;
@property (strong, nonatomic) NSURL *audioUrl;
@property (strong, nonatomic) NSURL *movieUrl;
@property (strong, nonatomic) NSURL *csvUrl;

@property(strong, nonatomic) AVAudioRecorder *recorder;
@property(strong, nonatomic) NSDate *startDate;

//Output views etc
@property (strong, nonatomic) UIView *outputView;
@property (strong, nonatomic) UIImageView *outputImageView;
@property (strong, nonatomic) UILabel *outputSubtitle;
@property (strong, nonatomic) APPlotView *plotAccelerometer;
@property (strong, nonatomic) APPlotView *plotSound;

@property (strong, nonatomic) UIView *viewLine1;
@property (strong, nonatomic) UIView *viewLine2;

@property (nonatomic, assign) BOOL isLowMemory;

@property (nonatomic, assign) BOOL isShowingEmail;

@property (strong, nonatomic) UISlider *sliderStartTime;
@property (strong, nonatomic) UISlider *sliderEndTime;

@end

@implementation APHomeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _graphViewAccelerometer = [[APLGraphView alloc] initWithFrame:CGRectMake(0.0f, 60.0f, 320.0f, 112.0f) lineColor:[UIColor redColor].CGColor];
    [self.view addSubview:_graphViewAccelerometer];
    [self.view sendSubviewToBack:_graphViewAccelerometer];
    _graphViewSound = [[APLGraphView alloc] initWithFrame:CGRectMake(0.0f, 220.0f, 320.0f, 112.0f) lineColor:[UIColor blueColor].CGColor];
    [self.view addSubview:_graphViewSound];
    [self.view sendSubviewToBack:_graphViewSound];
    
    _accelerometerData = [NSMutableArray new];
    _soundData = [NSMutableArray new];
    _timeData = [NSMutableArray new];
    
    [self setupFiles];
    
    // Setup audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    // Define the recorder setting
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithInt:AVAudioQualityMax],      AVEncoderAudioQualityKey,
                                   [NSNumber numberWithInt:kAudioFormatMPEG4AAC],   AVFormatIDKey,
                                   [NSNumber numberWithFloat:44100.0],              AVSampleRateKey,
                                   [NSNumber numberWithInt: 1],                     AVNumberOfChannelsKey,
                                   nil];
    
    // Initiate and prepare the recorder
    _recorder = [[AVAudioRecorder alloc] initWithURL:_audioUrl settings:recordSetting error:nil];
    _recorder.meteringEnabled = YES;

    //slider values
    [self sliderSoundValueChanged:nil];
    [self sliderAccelerometerValueChanged:nil];
    
    //Output view
    [self createOutputView];
    
    _isShowingEmail = NO;
    
    //Listener for foreground and background events
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)appDidEnterBackground {
    [self viewDidDisappear:NO];
}

- (void)appWillEnterForeground {
    [self viewWillAppear:YES];
}

- (void)didReceiveMemoryWarning {
    _isLowMemory = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    CMMotionManager *mManager = [AppDelegate sharedMotionManager];
    mManager.deviceMotionUpdateInterval = 0.01;
    
    __block double avg = 0.0f;
    [mManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
        
        double zAccel = motion.userAcceleration.z;
        avg = (avg * (kAccelerometerAverageInterval - 1) + zAccel) / kAccelerometerAverageInterval;
        zAccel =  zAccel - avg;
        [_graphViewAccelerometer add:zAccel * _sliderAccelerometerSensitivity.value];
        
        //Also update metering
        [_recorder updateMeters];
        double powerForChannel = [_recorder averagePowerForChannel:0];
        double amplitude =  powf(10.0f, powerForChannel / 20.0f);   //linear amplitude from dB Full Scale
        [_graphViewSound add:amplitude * _sliderSoundSensitivity.value - 48.5f];    //48.5 is the smallest value of the graph view
        
        if (_isRecording) {
            [_accelerometerData addObject:[NSNumber numberWithDouble:motion.userAcceleration.z]];
            [_soundData addObject:[NSNumber numberWithDouble:powerForChannel]];
            [_timeData addObject:[NSNumber numberWithDouble:-1.0f * [_startDate timeIntervalSinceNow]]];
            _labelElapsedTime.text = [NSString stringWithFormat:@"Elapsed time: %.1fs", -1.0f * [_startDate timeIntervalSinceNow]];
        }
    }];

    //Reset buttons etc - if not coming from email view
    if (!_isShowingEmail) {
        [self buttonResetClick:nil];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [[AppDelegate sharedMotionManager] stopDeviceMotionUpdates];
}

- (IBAction)sliderAccelerometerValueChanged:(id)sender {
    _labelAccelerometerSensitivity.text = [NSString stringWithFormat:@"Display Sensitivity: %.0f", _sliderAccelerometerSensitivity.value / (_sliderAccelerometerSensitivity.maximumValue - _sliderAccelerometerSensitivity.minimumValue) * 9.0f + 1.0f];
}

- (IBAction)sliderSoundValueChanged:(id)sender {
    _labelSoundSensitivity.text = [NSString stringWithFormat:@"Display Sensitivity: %.0f", _sliderSoundSensitivity.value / (_sliderSoundSensitivity.maximumValue - _sliderSoundSensitivity.minimumValue) * 9.0f + 1.0f];
}

- (IBAction)buttonStartStopClick:(UIButton *)sender {
    if (!_isRecording) {
        
        //stop / prepare (clear file) for sound recording
        [_recorder stop];
        [_recorder prepareToRecord];    //clears file

        _buttonReset.enabled = NO;
        _buttonProcess.enabled = NO;
        _buttonEmail.enabled = NO;
        
        [_buttonStartStop setTitle: @"Stop" forState:UIControlStateNormal];
        _buttonStartStop.enabled = NO;

        _labelFooter.text = @"Starting in 1 sec";
        _labelFooter.hidden = NO;

        //Start synchronised in 1 sec
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            //Clear all data points
            [_accelerometerData removeAllObjects];
            [_soundData removeAllObjects];
            [_timeData removeAllObjects];
            
            //Start sound recording
            [_recorder record];
            
            _startDate = [NSDate date];
            NSDateFormatter *dateFormatter = [NSDateFormatter new];
            dateFormatter.dateFormat = @"HH:mm:ss";
            
            _labelStartTime.text = [NSString stringWithFormat:@"Start time: %@", [dateFormatter stringFromDate:_startDate]];
            _labelElapsedTime.text = [NSString stringWithFormat:@"Elapsed time: 0s"];
            _labelStartTime.hidden = NO;
            _labelElapsedTime.hidden = NO;
            
            _isRecording = YES;
            _labelFooter.hidden = YES;
            _buttonStartStop.enabled = YES;
        });
    }
    else {
        [_recorder stop];

        _buttonReset.enabled = YES;
        _buttonStartStop.enabled = NO;
        _buttonProcess.enabled = YES;
        [_buttonStartStop setTitle: @"Start" forState:UIControlStateNormal];
        _isRecording = NO;
        
        //Create views with charts and show
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        [self setupStartEndSliders];    //sets sliders to 0 / duration
        [self buildOutputView];         //build charts based on 0 start and duration end
        
        _progressView.hidden = NO;
        _labelProgress.hidden = NO;
        _progressView.progress = 0.0f;
        _labelProgress.text = @"Ready to process";
    }
}

- (IBAction)buttonResetClick:(UIButton *)sender {
    _buttonStartStop.enabled = YES;
    _buttonReset.enabled = NO;
    _buttonProcess.enabled = NO;
    _buttonEmail.enabled = NO;
    
    _isRecording = NO;
    _isLowMemory = NO;

    _labelStartTime.hidden = YES;
    _labelElapsedTime.hidden = YES;
    
    _progressView.hidden = YES;
    _labelProgress.hidden = YES;

    _outputView.hidden = YES;
    _sliderStartTime.hidden = YES;
    _sliderEndTime.hidden = YES;

    _outputImageView.hidden = YES;

    _labelFooter.hidden = YES;
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [_recorder record];

    [self setupFiles];
}

- (void)createOutputView {
    const CGFloat width = 320.0f;
    const CGFloat height = 440.0f;
    const CGFloat titleHeight = 60.0f;
    const CGFloat plotHeight = 180.0f;
    const CGFloat plotGap = 20.0f;
    
    //Output view
    _outputView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, height)];
    _outputView.backgroundColor = [UIColor whiteColor];
    _outputView.userInteractionEnabled = YES;
    
    //title / subtitile
    [APPlotUtils addLabelToView:_outputView withFrame:CGRectMake(0.0f, 10.0f, width, 26.0f) withText:[NSString stringWithFormat:@"Sound & Vibration Recorder"] withSize:22];
    _outputSubtitle = [APPlotUtils addLabelToView:_outputView withFrame:CGRectMake(0.0f, 40.0f, width, 20.0f) withText:@"Recorded at ..." withSize:12];
    
    //plots
    _plotAccelerometer = [[APPlotView alloc] initWithFrame:CGRectMake(0.0f, titleHeight, width, plotHeight)];
    [_outputView addSubview:_plotAccelerometer];
    _plotAccelerometer.backgroundColor = [UIColor whiteColor];
    
    //Add sound view
    CGFloat plotSoundY = titleHeight + plotHeight + plotGap;
    _plotSound = [[APPlotView alloc] initWithFrame:CGRectMake(0.0f, plotSoundY, width, plotHeight)];
    [_outputView addSubview:_plotSound];
    _plotSound.backgroundColor = [UIColor whiteColor];
    
    //Add sliders for start / end cropping of video
    UIImage *greenLine = [APPlotUtils imageFromColor:[UIColor greenColor] withRect:CGRectMake(0.0, 0.0, 2.0, 2 * (plotHeight - kChartInset) + plotGap)];
    _sliderStartTime = [[UISlider alloc] initWithFrame:CGRectMake(kChartInset, titleHeight + kChartInset, width / 2 - kChartInset, 2 * (plotHeight - kChartInset) + plotGap)];
    _sliderStartTime.minimumTrackTintColor = [UIColor clearColor];
    _sliderStartTime.maximumTrackTintColor = [UIColor clearColor];
    [_sliderStartTime setThumbImage:greenLine forState:UIControlStateNormal];
    [_outputView addSubview:_sliderStartTime];

    _sliderEndTime = [[UISlider alloc] initWithFrame:CGRectMake(width / 2, titleHeight + kChartInset, width / 2 - kChartInset, 2 * (plotHeight - kChartInset) + plotGap)];
    _sliderEndTime.minimumTrackTintColor = [UIColor clearColor];
    _sliderEndTime.maximumTrackTintColor = [UIColor clearColor];
    [_sliderEndTime setThumbImage:greenLine forState:UIControlStateNormal];
    [_outputView addSubview:_sliderEndTime];
    
    //Add to main view and hide
    [self.view addSubview:_outputView];
    _outputView.hidden = YES;
    
    
    //Output image view - used to show individual frames while processing
    _outputImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, height)];
    [self.view addSubview:_outputImageView];
    _outputImageView.hidden = YES;
    
    //Add vertical lines for timeline
    _viewLine1 = [[UIView alloc] initWithFrame:CGRectMake(0.0, titleHeight + kChartInset, 1.0f, plotHeight - 2 * kChartInset)];
    _viewLine1.backgroundColor = [UIColor grayColor];
    [_outputImageView addSubview:_viewLine1];
    _viewLine2 = [[UIView alloc] initWithFrame:CGRectMake(0.0, plotSoundY + kChartInset, 1.0f, plotHeight- 2 * kChartInset)];
    _viewLine2.backgroundColor = [UIColor grayColor];
    [_outputImageView addSubview:_viewLine2];
}

- (void)setupStartEndSliders {
    double duration = [[_timeData lastObject] doubleValue];
    _sliderStartTime.hidden = NO;
    _sliderEndTime.hidden = NO;
    
    _sliderStartTime.minimumValue = 0.0f;
    _sliderStartTime.maximumValue = duration / 2.0f;
    _sliderStartTime.value = 0.0f;
    _sliderEndTime.minimumValue = duration / 2.0f;
    _sliderEndTime.maximumValue = duration;
    _sliderEndTime.value = duration;
}

- (NSDate *)segmentStartDate {
    //adjusts the start date for the slider start
    NSDate *segmentStartDate = [_startDate dateByAddingTimeInterval:_sliderStartTime.value];
    return segmentStartDate;
}

- (double)segmentDuration {
    return _sliderEndTime.value - _sliderStartTime.value;
}

- (void)buildOutputView {

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    _outputSubtitle.text = [NSString stringWithFormat:@"Recorded at %@", [dateFormatter stringFromDate:[self segmentStartDate]]];

    [self createAccelerometerChart];
    [self createSoundChart];
    
    _outputView.hidden = NO;
}

- (void)createAccelerometerChart {
    
    NSMutableArray *segmentData = [NSMutableArray new];
    NSMutableArray *segmentTimeData = [NSMutableArray new];
    
    double currentValue, accelInMMPerSec, currentSecs;
    
    for (int i = 0; i < [_accelerometerData count]; i++) {
        currentValue = [[_accelerometerData objectAtIndex:i] doubleValue];
        accelInMMPerSec = currentValue * 1000.0f;    //mm/s2
        
        //if within time, add to data and timeData arrays
        currentSecs = [[_timeData objectAtIndex:i] doubleValue];
        if ((currentSecs >= _sliderStartTime.value) && (currentSecs <= _sliderEndTime.value)) {
            [segmentData addObject:[NSNumber numberWithDouble:accelInMMPerSec]];
            [segmentTimeData addObject:[NSNumber numberWithDouble:currentSecs - _sliderStartTime.value]];    //re-bases time data to start time as 0
        }
    }
    
    //Clear points, add bounding box, add new points
    [_plotAccelerometer clear];
    [APPlotUtils removeAllSubviews:_plotAccelerometer];
    [APPlotUtils addLabelToView:_plotAccelerometer withFrame:CGRectMake(0.0f, 0.0f, 320.0f, kChartInset) withText:@"Vertical Acceleration, mm/s" withSize:12];
    [APPlotUtils addLabelToView:_plotAccelerometer withFrame:CGRectMake(228.0f, 5.0f, 10.0f, 12.0f) withText:@"2" withSize:8];
    if ([segmentData count] == 0)
        return;
    [APPlotUtils createChart:_plotAccelerometer withData:segmentData withTimeData:segmentTimeData withInset:kChartInset withLineColor:[UIColor redColor]];
}

- (void)createSoundChart {

    NSMutableArray *segmentData = [NSMutableArray new];
    NSMutableArray *segmentTimeData = [NSMutableArray new];

    double currentValue, amplitude, currentSecs;

    for (int i = 0; i < [_soundData count]; i++) {
        currentValue = [[_soundData objectAtIndex:i] doubleValue];  //dBFS ie db relative to Full Scale. Range: -160dB to 0dB
        amplitude =  powf(10.0f, currentValue / 20.0f);             //linear amplitude from dB Full Scale
        
        //if within time, add to data and timeData arrays
        currentSecs = [[_timeData objectAtIndex:i] doubleValue];
        if ((currentSecs >= _sliderStartTime.value) && (currentSecs <= _sliderEndTime.value)) {
            [segmentData addObject:[NSNumber numberWithDouble:amplitude]];
            [segmentTimeData addObject:[NSNumber numberWithDouble:currentSecs - _sliderStartTime.value]];
        }
    }
    
    [_plotSound clear];
    [APPlotUtils removeAllSubviews:_plotSound];
    [APPlotUtils addLabelToView:_plotSound withFrame:CGRectMake(0.0f, 0.0f, 320.0f, kChartInset) withText:@"Sound Level, amplitude" withSize:12];
    if ([segmentData count] == 0)
        return;
    [APPlotUtils createChart:_plotSound withData:segmentData withTimeData:segmentTimeData withInset:kChartInset withLineColor:[UIColor blueColor]];
}

- (void)createVideo:(void (^)(NSNumber *status))block {
    
    //Take a copy of the image - which we will use each time as the backdrop
    UIImage *background = [self imageWithView:_outputView];
    _outputImageView.image = background;
    _outputImageView.hidden = NO;
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];

    double duration = [self segmentDuration];
    NSInteger frames = (int)(duration * kFramesPerSec);

    CGFloat x;
    CGRect frame;
    APEncodeMovie *movie = [[APEncodeMovie alloc] initWithSize:CGSizeMake(640.0f, 880.0f) url:_videoUrl];
    
    for (int i = 0; i < frames; i++) {
        if (_isLowMemory) {
            //Alert user of low memory and stop
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Oops" message:@"The system has run out of memory - stopping processing and attempting to finalise movie. Try recording again with a shorter duration." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alertView show];
            [movie finaliseMovieWithBlock:^(NSNumber *status) {
                if (block) {
                    block(status);
                }
            }];
            return;
        }
        //Update progress
        _progressView.progress = ((CGFloat)i / (CGFloat)frames) * 0.95f;
        _labelProgress.text = [NSString stringWithFormat:@"Creating frame %d of %ld", i + 1, (long)frames];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];

        x = kChartInset + (320.0f - 2.0f * kChartInset) * (((CGFloat)i + 0.5f) / (CGFloat)frames);

        //Move lines
        frame = _viewLine1.frame;
        frame.origin.x = x;
        _viewLine1.frame = frame;
        frame = _viewLine2.frame;
        frame.origin.x = x;
        _viewLine2.frame = frame;
        
        //Create image and add to movie. Use autorelease pool to ensre the image is freed up quickly.
        @autoreleasepool {
            UIImage *image = [self imageWithView:_outputImageView];
            [movie addImage:image frameNum:i fps:kFramesPerSec];
            image = nil;
        }
    }
    [movie finaliseMovieWithBlock:^(NSNumber *status) {
        if (block) {
            block(status);
        }
    }];
}

- (UIImage *)imageWithView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 2.0f);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (IBAction)buttonProcessClick:(UIButton *)sender {
    _buttonStartStop.enabled = NO;
    _buttonReset.enabled = NO;
    _buttonProcess.enabled = NO;
    _buttonEmail.enabled = NO;
    
    //rebuild the output view taking into account start / end time settings
    _sliderStartTime.hidden = YES;
    _sliderEndTime.hidden = YES;
    [self buildOutputView];
    
    //Create csv
    _labelProgress.text = @"Creating csv file";
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
    [self createCSV];
    
    //Create video images
    _labelProgress.text = @"Creating video frames";
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
    [self createVideo:^(NSNumber *status) {
        //Now create the movie
        _labelProgress.text = @"Creating combined video and audio movie";
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
        [self createMovie];
    }];
}

- (IBAction)buttonEmailClick:(UIButton *)sender {
    NSString *emailTitle = @"Sound & Vibration Recording";
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    double duration = [self segmentDuration];
    NSString *messageBody = [NSString stringWithFormat:@"Recorded at %@, duration %.1f seconds", [dateFormatter stringFromDate:[self segmentStartDate]], duration];

    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:NO];
    //[mc setToRecipients:toRecipents];
    
    //add attachments
    dateFormatter.dateFormat = @"yyyy-MM-dd HH.mm.ss";
    NSData *fileData = [NSData dataWithContentsOfURL:_movieUrl];
    [mc addAttachmentData:fileData mimeType:@"video/mp4" fileName:[NSString stringWithFormat:@"recording%@.mp4", [dateFormatter stringFromDate:[self segmentStartDate]]]];

    fileData = [NSData dataWithContentsOfURL:_csvUrl];
    [mc addAttachmentData:fileData mimeType:@"text/csv" fileName:[NSString stringWithFormat:@"rawdata%@.csv", [dateFormatter stringFromDate:[self segmentStartDate]]]];

    // Present mail view controller on screen
    _isShowingEmail = YES;
    [self presentViewController:mc animated:YES completion:NULL];
}

#pragma mark - mailComposeController delegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:NULL];
    _isShowingEmail = NO;
}

- (void)createMovie {
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:_videoUrl options:nil];
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:_audioUrl options:nil];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    //Add audio - with cropped time range
    CMTime start = CMTimeMakeWithSeconds(_sliderStartTime.value, 1);
    CMTime duration = CMTimeMakeWithSeconds(_sliderEndTime.value - _sliderStartTime.value, 1);
    CMTimeRange timeRange = CMTimeRangeMake(start, duration);
    AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange:timeRange ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]atTime:kCMTimeZero error:nil];
    
    //Add video
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration) ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetPassthrough];
    
    assetExport.outputFileType = AVFileTypeMPEG4;
    assetExport.outputURL = _movieUrl;
    assetExport.shouldOptimizeForNetworkUse = YES;
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        if (assetExport.status != AVAssetExportSessionStatusCompleted) {
            NSLog(@"There was a problem exporting: status code %ld", (long)assetExport.status);
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                _progressView.progress = 1.0f;
                _labelProgress.text = @"Processing completed";
                _buttonStartStop.enabled = NO;
                _buttonReset.enabled = YES;
                _buttonProcess.enabled = NO;
                _buttonEmail.enabled = YES;
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
            });
        }
    }];
}

- (void)createCSV {
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    double duration = [self segmentDuration];
    NSMutableString *csv = [NSMutableString new];
    
    [csv appendString:[NSString stringWithFormat:@"Sound & Vibration Recording - Raw Data\nRecorded at %@ duration %.1f seconds\n\n", [dateFormatter stringFromDate:[self segmentStartDate]], duration]];
    [csv appendString:@"Date,Seconds,Acceleration (m/s/s),Sound (dBFS)"];
    
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSSS";
    NSDate *readingDate;
    NSTimeInterval readingSecs;
    for (int i = 0; i < [_timeData count]; i++) {
        readingSecs = [[_timeData objectAtIndex:i] doubleValue];
        readingDate = [_startDate dateByAddingTimeInterval:readingSecs];  //create full NSDate for this reading
        [csv appendFormat:@"\n\"%@\",%f,%f,%f",
            [dateFormatter stringFromDate:readingDate],
            readingSecs,
            [[_accelerometerData objectAtIndex:i] doubleValue],
            [[_soundData objectAtIndex:i] doubleValue]
         ];
    }
    NSError *error;
    [csv writeToURL:_csvUrl atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (void)setupFiles {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempvideo.mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    _videoUrl = [NSURL fileURLWithPath:path];

    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempaudio.m4a"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    _audioUrl = [NSURL fileURLWithPath:path];

    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    _movieUrl = [NSURL fileURLWithPath:path];

    path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rawdata.csv"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    _csvUrl = [NSURL fileURLWithPath:path];
}


@end
