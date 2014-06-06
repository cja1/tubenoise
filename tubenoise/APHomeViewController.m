//
//  APHomeViewController.m
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import "APHomeViewController.h"
#import <CoreMotion/CoreMotion.h>
#import "APPlotView.h"
#import <QuartzCore/QuartzCore.h>
#import "APEncodeMovie.h"
#import "APLGraphView.h"
#import "APPlotUtils.h"
#import "APDataProcessor.h"
#import "APMovieProcessor.h"
#import "APPDFRenderer.h"
#import "APCSVUtils.h"

#define kAccelerometerAverageInterval       1000    //10 sec bias calculation / averaging for z axis acceleration - for realtime display only
#define kFramesPerSec                       10
#define kChartInset                         25.0f

@interface APHomeViewController ()

@property (strong, nonatomic) APLGraphView *graphViewAccelerometer;
@property (strong, nonatomic) APLGraphView *graphViewSound;

@property (strong, nonatomic) NSMutableArray *accelerometerData;
@property (strong, nonatomic) NSMutableArray *soundData;
@property (strong, nonatomic) NSMutableArray *timeData;
@property (strong, nonatomic) NSMutableDictionary *processedData;

@property (nonatomic, assign) BOOL isRecording;

@property (strong, nonatomic) NSURL *videoUrl;
@property (strong, nonatomic) NSURL *audioUrl;
@property (strong, nonatomic) NSURL *movieUrl;
@property (strong, nonatomic) NSURL *csvRebasedUrl;
@property (strong, nonatomic) NSURL *csvProcessedUrl;
@property (strong, nonatomic) NSURL *pdfUrl;

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
@property (strong, nonatomic) UILabel *labelStartEndTime;

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
    
    _graphViewAccelerometer = [[APLGraphView alloc] initWithFrame:CGRectMake(0.0f, 260.0f, 320.0f, 112.0f) lineColor:[UIColor redColor].CGColor];
    [self.view addSubview:_graphViewAccelerometer];
    [self.view sendSubviewToBack:_graphViewAccelerometer];
    _graphViewSound = [[APLGraphView alloc] initWithFrame:CGRectMake(0.0f, 80.0f, 320.0f, 112.0f) lineColor:[UIColor blueColor].CGColor];
    [self.view addSubview:_graphViewSound];
    [self.view sendSubviewToBack:_graphViewSound];
    
    _accelerometerData = [NSMutableArray new];
    _soundData = [NSMutableArray new];
    _timeData = [NSMutableArray new];
    
    //setup all files urls
    _videoUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"tempvideo.mp4"]];
    _audioUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"tempaudio.caf"]];
    _movieUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.mp4"]];
    _csvRebasedUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"rebaseddata.csv"]];
    _csvProcessedUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"processeddata.csv"]];
    _pdfUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temppdf.pdf"]];

    [self deleteAudioFileIfExists];
    
    // Setup audio session
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setMode: AVAudioSessionModeMeasurement error:nil]; //When this mode is in use, the device does minimal signal processing on input and output audio
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    // Define the recorder setting
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithInt:AVAudioQualityMax],      AVEncoderAudioQualityKey,
                                   [NSNumber numberWithInt:kAudioFormatAppleLossless],   AVFormatIDKey,  //
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
            [_timeData addObject:[NSDate date]];
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

- (IBAction)sliderSoundValueChanged:(id)sender {
    _labelSoundSensitivity.text = [NSString stringWithFormat:@"Display Sensitivity: %.0f", _sliderSoundSensitivity.value / (_sliderSoundSensitivity.maximumValue - _sliderSoundSensitivity.minimumValue) * 9.0f + 1.0f];
}

- (IBAction)sliderAccelerometerValueChanged:(id)sender {
    _labelAccelerometerSensitivity.text = [NSString stringWithFormat:@"Display Sensitivity: %.0f", _sliderAccelerometerSensitivity.value / (_sliderAccelerometerSensitivity.maximumValue - _sliderAccelerometerSensitivity.minimumValue) * 9.0f + 1.0f];
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
        [self updateProgressLabel: @"Creating charts" progress:0.0f];

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
    _labelStartEndTime.hidden  =YES;
    
    _outputImageView.hidden = YES;

    _labelFooter.hidden = YES;
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [_recorder record];

    [self deleteAudioFileIfExists];
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
    
    //title / subtitle
    [APPlotUtils addLabelToView:_outputView withFrame:CGRectMake(0.0f, 10.0f, width, 26.0f) withText:[NSString stringWithFormat:@"TubeNoise: Sound & Vibration Recording"] withSize:18];
    _outputSubtitle = [APPlotUtils addLabelToView:_outputView withFrame:CGRectMake(0.0f, 40.0f, width, 20.0f) withText:@"Recorded at ..." withSize:12];
    
    //plots
    _plotSound = [[APPlotView alloc] initWithFrame:CGRectMake(0.0f, titleHeight, width, plotHeight)];
    [_outputView addSubview:_plotSound];
    _plotSound.backgroundColor = [UIColor whiteColor];
    
    //Add sound view
    CGFloat plotSoundY = titleHeight + plotHeight + plotGap;
    _plotAccelerometer = [[APPlotView alloc] initWithFrame:CGRectMake(0.0f, plotSoundY, width, plotHeight)];
    [_outputView addSubview:_plotAccelerometer];
    _plotAccelerometer.backgroundColor = [UIColor whiteColor];
    
    //Add sliders for start / end cropping of video
    UIImage *greenLine = [APPlotUtils imageFromColor:[UIColor greenColor] withRect:CGRectMake(0.0, 0.0, 4.0, 2 * (plotHeight - kChartInset) + plotGap)];
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
    
    //add explanation text
    _labelStartEndTime = [APPlotUtils addLabelToView:_outputView withFrame:CGRectMake(0.0f, titleHeight + plotHeight, width, plotGap) withText:@"Move green bars to set output start and end times" withSize:10.0f withAlignment:NSTextAlignmentCenter withColor:[UIColor greenColor]];
    
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
    NSDate *startDate = [_timeData firstObject];
    NSDate *endDate = [_timeData lastObject];
    double duration = [endDate timeIntervalSinceDate:startDate];
    _sliderStartTime.hidden = NO;
    _sliderEndTime.hidden = NO;
    _labelStartEndTime.hidden = NO;
    
    _sliderStartTime.minimumValue = 0.0f;
    _sliderStartTime.maximumValue = duration / 2.0f;
    _sliderStartTime.value = 0.0f;
    _sliderEndTime.minimumValue = duration / 2.0f;
    _sliderEndTime.maximumValue = duration;
    _sliderEndTime.value = duration;
}

- (NSDate *)segmentStartDate {
    //adjusts the start date for the slider start
    return [_startDate dateByAddingTimeInterval:_sliderStartTime.value];
}

- (double)segmentDuration {
    return _sliderEndTime.value - _sliderStartTime.value;
}

- (void)buildOutputView {

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    _outputSubtitle.text = [NSString stringWithFormat:@"Recorded at %@", [dateFormatter stringFromDate:[self segmentStartDate]]];

    //process the data based on the current slider settings
    _processedData = [NSMutableDictionary dictionaryWithObjectsAndKeys:_accelerometerData, @"accelerometerVals", _timeData, @"accelerometerTime", _soundData, @"soundVals", _timeData, @"soundTime", nil];
    [[APDataProcessor alloc] processData:_processedData startTime:_sliderStartTime.value endTime:_sliderEndTime.value];
    
    //Create the charts
    [self createAccelerometerChart:[_processedData objectForKey:@"processedAccelerometerVals"] time:[_processedData objectForKey:@"processedAccelerometerTime"]];
    [self createSoundChart:[_processedData objectForKey:@"processedSoundVals"] time:[_processedData objectForKey:@"processedSoundTime"]];
    
    _outputView.hidden = NO;
}

- (void)createSoundChart:(NSArray *)vals time:(NSArray *)time {
    
    [_plotSound clear];
    [APPlotUtils removeAllSubviews:_plotSound];
    [APPlotUtils addLabelToView:_plotSound withFrame:CGRectMake(0.0f, 0.0f, _plotSound.frame.size.width, kChartInset) withText:@"Sound Level, dBFS max fast" withFont:[UIFont fontWithName:@"HelveticaNeue-Medium" size:12] withAlignment:NSTextAlignmentCenter withColor:[UIColor blackColor]];
    
    if ([vals count] == 0)
        return;
    [APPlotUtils createChart:_plotSound withData:vals withTimeData:time withInset:kChartInset withLineColor:[UIColor blueColor]];
}

- (void)createAccelerometerChart:(NSArray *)vals time:(NSArray *)time {
    
    [_plotAccelerometer clear];
    [APPlotUtils removeAllSubviews:_plotAccelerometer];
        
    UILabel *label = [APPlotUtils addLabelToView:_plotAccelerometer withFrame:CGRectMake(0.0f, 0.0f, _plotAccelerometer.frame.size.width, kChartInset) withText:@"Acceleration, mm/s  max fast" withFont:[UIFont fontWithName:@"HelveticaNeue-Medium" size:12] withAlignment:NSTextAlignmentCenter withColor:[UIColor blackColor]];
    [APPlotUtils addLabelToView:label withFrame:CGRectMake(182.0f, 5.0f, 10.0f, 8.0f) withText:@"2" withSize:8];
    if ([vals count] == 0)
        return;
    [APPlotUtils createChart:_plotAccelerometer withData:vals withTimeData:time withInset:kChartInset withLineColor:[UIColor redColor]];
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
    
    BOOL includeAccelerometerVideo = [[[NSUserDefaults standardUserDefaults] objectForKey:@"includeAccelerometerVideo"] boolValue];
    CGSize movieSize = CGSizeMake(640.0f, includeAccelerometerVideo ? 880.0f : 520.0f);
    APEncodeMovie *movie = [[APEncodeMovie alloc] initWithSize:movieSize url:_videoUrl];
    
    CGFloat outputImageViewWidth = _outputImageView.frame.size.width;
    
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
        
        x = kChartInset + (outputImageViewWidth - 2.0f * kChartInset) * (((CGFloat)i + 0.5f) / (CGFloat)frames);

        //Move lines
        frame = _viewLine1.frame;
        frame.origin.x = x;
        _viewLine1.frame = frame;
        frame = _viewLine2.frame;
        frame.origin.x = x;
        _viewLine2.frame = frame;

        //Update progress
        [self updateProgressLabel:[NSString stringWithFormat:@"Creating frame %d of %ld", i + 1, (long)frames] progress:((CGFloat)i / (CGFloat)frames) * 0.95f];

        //Create image and add to movie. Use autorelease pool to ensure the image is freed up quickly.
        @autoreleasepool {
            UIImage *image = [self imageWithView:_outputImageView withFrame:CGRectMake(0.0f, 0.0f, outputImageViewWidth, includeAccelerometerVideo ? 440.0f : 260.0f)];
            //UIImage *image = [self imageWithView:_outputImageView];
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

//Crops the image to the frame size (height) to exclude the acceleration view
- (UIImage *)imageWithView:(UIView *)view withFrame:(CGRect)frame {
    UIGraphicsBeginImageContextWithOptions(frame.size, view.opaque, 2.0f);    //request at retina scale
    [view drawViewHierarchyInRect:view.frame afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)imageWithView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 2.0f);    //request at retina scale
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)updateProgressLabel:(NSString *)text progress:(CGFloat)progress {
    _labelProgress.text = text;
    _progressView.progress = progress;
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate date]];
}

- (IBAction)buttonProcessClick:(UIButton *)sender {
    _buttonStartStop.enabled = NO;
    _buttonReset.enabled = NO;
    _buttonProcess.enabled = NO;
    _buttonEmail.enabled = NO;
    
    //rebuild the output view taking into account start / end time settings
    _sliderStartTime.hidden = YES;
    _sliderEndTime.hidden = YES;
    _labelStartEndTime.hidden = YES;
    [self updateProgressLabel: @"Creating charts" progress:0.0f];
    [self buildOutputView];

    //Create pdfs
    [self updateProgressLabel: @"Creating pdf" progress:0.0f];
    [[APPDFRenderer alloc] createPDF:_processedData url:_pdfUrl];

    //Create csv
    [self updateProgressLabel: @"Creating csv files" progress:0.0f];
    [[APCSVUtils alloc] createCSVFiles:_processedData rebasedUrl:_csvRebasedUrl processedUrl:_csvProcessedUrl];
    
    //Create audio file with correct duration
    [self updateProgressLabel: @"Creating audio file" progress:0.0f];
    [[APMovieProcessor alloc] trimCAFAudio:_audioUrl startTime:_sliderStartTime.value endTime:_sliderEndTime.value block:^(NSNumber *status) {
        
        //Create video images
        dispatch_async(dispatch_get_main_queue(), ^{

            [self updateProgressLabel: @"Creating video frames" progress:0.0f];
            [self createVideo:^(NSNumber *status) {
                
                //Now create the movie
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self updateProgressLabel: @"Creating combined video and audio movie" progress:0.97f];
                    [[APMovieProcessor alloc] createMovieWithVideo:_videoUrl audio:_audioUrl output:_movieUrl block:^(NSNumber *status) {
                        
                        //Update button status
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateProgressLabel: @"Processing completed" progress:1.0f];
                            _buttonStartStop.enabled = NO;
                            _buttonReset.enabled = YES;
                            _buttonProcess.enabled = NO;
                            _buttonEmail.enabled = YES;
                            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate date]];
                        });
                    }];
                });
            }];
        });
    }];
}

- (IBAction)buttonEmailClick:(UIButton *)sender {
    NSString *emailTitle = @"Sound & Vibration Recording";
    NSDate *start = [[_processedData objectForKey:@"rebasedAccelerometerTime"] firstObject];
    NSDate *end = [[_processedData objectForKey:@"rebasedAccelerometerTime"] lastObject];
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH.mm.ss";
    double duration = [end timeIntervalSinceDate:start];
    NSString *messageBody = [NSString stringWithFormat:@"Recorded at %@, duration %.1f seconds", [dateFormatter stringFromDate:start], duration];

    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:NO];
    
    //add default email address if set
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"defaultEmailAddress"] length]) {
        [mc setToRecipients:[NSArray arrayWithObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"defaultEmailAddress"]]];
    }
    
    //add attachments
    NSData *fileData = [NSData dataWithContentsOfURL:_movieUrl];
    [mc addAttachmentData:fileData mimeType:@"video/mp4" fileName:[NSString stringWithFormat:@"recording%@.mp4", [dateFormatter stringFromDate:start]]];

    fileData = [NSData dataWithContentsOfURL:_pdfUrl];
    [mc addAttachmentData:fileData mimeType:@"application/pdf" fileName:[NSString stringWithFormat:@"page%@.pdf", [dateFormatter stringFromDate:start]]];

    fileData = [NSData dataWithContentsOfURL:_audioUrl];
    [mc addAttachmentData:fileData mimeType:@"audio/x-caf" fileName:[NSString stringWithFormat:@"audio%@.caf", [dateFormatter stringFromDate:start]]];

    fileData = [NSData dataWithContentsOfURL:_csvRebasedUrl];
    [mc addAttachmentData:fileData mimeType:@"text/csv" fileName:[NSString stringWithFormat:@"rawdata%@.csv", [dateFormatter stringFromDate:start]]];
    
    fileData = [NSData dataWithContentsOfURL:_csvProcessedUrl];
    [mc addAttachmentData:fileData mimeType:@"text/csv" fileName:[NSString stringWithFormat:@"processeddata%@.csv", [dateFormatter stringFromDate:start]]];

    // Present mail view controller on screen
    _isShowingEmail = YES;
    [self presentViewController:mc animated:YES completion:NULL];
}

#pragma mark - mailComposeController delegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self dismissViewControllerAnimated:YES completion:NULL];
    _labelProgress.text = @"Email sent";
    _isShowingEmail = NO;
}

- (void)deleteAudioFileIfExists {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[_audioUrl path]]) {
        [[NSFileManager defaultManager] removeItemAtPath:[_audioUrl path] error:nil];
    }
}


@end
