//
//  APHomeViewController.h
//  tubenoise
//
//  Created by Charles Allen on 23/05/2014.
//  Copyright (c) 2014 Charles Allen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MessageUI/MessageUI.h>

@interface APHomeViewController : UIViewController <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *labelAccelerometerSensitivity;
@property (strong, nonatomic) IBOutlet UILabel *labelSoundSensitivity;

@property (strong, nonatomic) IBOutlet UISlider *sliderAccelerometerSensitivity;
@property (strong, nonatomic) IBOutlet UISlider *sliderSoundSensitivity;

- (IBAction)sliderAccelerometerValueChanged:(id)sender;
- (IBAction)sliderSoundValueChanged:(id)sender;

@property (strong, nonatomic) IBOutlet UILabel *labelStartTime;
@property (strong, nonatomic) IBOutlet UILabel *labelElapsedTime;


@property (strong, nonatomic) IBOutlet UIButton *buttonStartStop;
@property (strong, nonatomic) IBOutlet UIButton *buttonReset;
@property (strong, nonatomic) IBOutlet UIButton *buttonProcess;
@property (strong, nonatomic) IBOutlet UIButton *buttonEmail;

- (IBAction)buttonStartStopClick:(UIButton *)sender;
- (IBAction)buttonResetClick:(UIButton *)sender;
- (IBAction)buttonProcessClick:(UIButton *)sender;
- (IBAction)buttonEmailClick:(UIButton *)sender;

@property (strong, nonatomic) IBOutlet UIProgressView *progressView;
@property (strong, nonatomic) IBOutlet UILabel *labelProgress;

@property (strong, nonatomic) IBOutlet UILabel *labelFooter;

@end
