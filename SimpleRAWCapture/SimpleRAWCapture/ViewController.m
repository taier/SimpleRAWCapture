//
//  ViewController.m
//  SimpleRAWCapture
//
//  Created by Deniss Kaibagarovs on 21/08/16.
//  Copyright © 2016 Deniss Kaibagarovs. All rights reserved.
// https://github.com/mamaral/Onboard


@import AVFoundation;
@import Photos;
@import GoogleMobileAds;

#import "ViewController.h"
#import "AVCamPreviewView.h"
#import "AVCamPhotoCaptureDelegate.h"
#import "DKPermissonManager.h"

#import "OnboardingViewController.h"
#import "OnboardingContentViewController.h"

static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
    AVCamSetupResultCameraNotAuthorized,
    AVCamSetupResultSessionConfigurationFailed
};

@interface ViewController ()

// Outletts
@property (weak, nonatomic) IBOutlet AVCamPreviewView *previewView;
@property (weak, nonatomic) IBOutlet DFPBannerView *bannerView;

// Global variables
@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) bool flashEnabled;

@property (nonatomic) OnboardingViewController *onboardingVC;

@property (nonatomic) AVCapturePhotoOutput *photoOutput;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) NSMutableDictionary<NSNumber *, AVCamPhotoCaptureDelegate *> *inProgressPhotoCaptureDelegates;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

@property BOOL didLoad;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //self.bannerView.adUnitID = @"/6499/example/banner";
    self.bannerView.adUnitID = @"ca-app-pub-6795887346824199/1578371261";
    self.bannerView.rootViewController = self;
    
    DFPRequest *request = [DFPRequest request];
    request.testDevices = @[@"7266f9e7e2608e5526bdcc015fbd3de6" ];
    [self.bannerView loadRequest:request];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"Google Mobile Ads SDK version: %@", [DFPRequest sdkVersion]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    if(!self.didLoad) {
        if([DKPermissonManager hasCameraAcess] == DKAcessGranted &&
           [DKPermissonManager hasPhotoLibraryAcess] == DKAcessGranted) {
            [self setupCameraAfterPermission];
        } else {
            [self showOnboarding];
        }
        self.didLoad = true;
    }
    
    //[self.previewView setFrame:self.view.frame];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        self.previewView.videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}


 //MARK: Setup methods

- (void)setupCameraAfterPermission {
    [self initialSetup];
    [self showCamera];
    [self showRAWSupportingNotification];
}

- (void)showRAWSupportingNotification {
    int rawFormat = self.photoOutput.availableRawPhotoPixelFormatTypes.firstObject.intValue;
    
    if(rawFormat != 0) { // RAW supported!
        return;
    }
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"ATTENTION!"
                                 message:@"RAW image shooting supported on the iPhone 6s, iPhone 6s Plus, iPhone SE, 9.7-inch iPad Pro and newer devices. You can still capture JPEG images using this application!"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* closeButton = [UIAlertAction
                               actionWithTitle:@"Close"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   //Handle no, thanks button
                               }];
    
    [alert addAction:closeButton];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showOnboarding {
    OnboardingContentViewController *firstPage = [[OnboardingContentViewController alloc] initWithTitle:@"Let's start!" body:@"Application need camera to take pictures." image:NULL buttonText:@"Give Access" action:^{
        
        DKAccess cameraAccess = [DKPermissonManager hasCameraAcess];
        
        if (cameraAccess == DKAcessGranted) {
            [self.onboardingVC moveNextPage];
        } else if (cameraAccess == DKAcessDenided) {
            [DKPermissonManager showPermissionDeniedAlert:DKPermissonCamer viewController:self.onboardingVC];
        } else if (cameraAccess == DKAcessAsking) {
            [DKPermissonManager askForCameraAcess:^(BOOL granted) {
                if(granted){ // Access has been granted ..do something
                    [self.onboardingVC moveNextPage];
                } else { // Access denied ..do something
                    [DKPermissonManager showPermissionDeniedAlert:DKPermissonCamer viewController:self.onboardingVC];
                }
            }];
        }
        
    }];
    
    OnboardingContentViewController *secondPage = [[OnboardingContentViewController alloc] initWithTitle:@"Save photos" body:@"Application need photo library to save photos" image:NULL buttonText:@"Give Access!" action:^{
        
        DKAccess cameraAccess = [DKPermissonManager hasPhotoLibraryAcess];
        
        if (cameraAccess == DKAcessGranted) {
            [self.onboardingVC moveNextPage];
        } else if (cameraAccess == DKAcessDenided) {
            [DKPermissonManager showPermissionDeniedAlert:DKPermissonPhotoLibrary viewController:self.onboardingVC];
        } else if (cameraAccess == DKAcessAsking) {
            [DKPermissonManager askForPhotoLibraryAcess:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    // Access has been granted.
                    [self.onboardingVC moveNextPage];
                } else {
                    // Access has been denied.
                    [DKPermissonManager showPermissionDeniedAlert:DKPermissonPhotoLibrary viewController:self.onboardingVC];
                }
            }];
        }
    }];
    
    OnboardingContentViewController *thirdPage = [[OnboardingContentViewController alloc] initWithTitle:@"Done!" body:@"Let's take some photos!" image:NULL buttonText:@"Finish!" action:^{
        [self setupCameraAfterPermission];
        [self.onboardingVC dismissViewControllerAnimated:true completion:NULL];
    }];
    
    // Image
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *moviePath = [bundle pathForResource:@"background" ofType:@"mp4"];
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    self.onboardingVC = [[OnboardingViewController alloc] initWithBackgroundVideoURL:movieURL contents:@[firstPage, secondPage, thirdPage]];
    //self.onboardingVC = [[OnboardingViewController alloc] initWithBackgroundImage:[UIImage imageNamed:@"background.jpg"] contents:@[firstPage, secondPage, thirdPage]];
    //self.onboardingVC.shouldBlurBackground = true;
    //self.onboardingVC.shouldMaskBackground = false;
    self.onboardingVC.swipingEnabled = false;
    
    [self presentViewController:self.onboardingVC animated:YES completion:NULL];
}

- (void)initialSetup {
    
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
    
    // Set up the preview view.
    self.previewView.session = self.session;
    
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );

    self.setupResult = AVCamSetupResultSuccess;
    
    dispatch_async( self.sessionQueue, ^{
        [self configureSession];
    } );
}

- (void)configureSession {
    
    // Add photo output.
    [self.session beginConfiguration];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    NSError *error = nil;
    
    // Add video input.
    AVCaptureDevice *videoDevice = [ViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if ( ! videoDeviceInput ) {
        NSLog( @"Could not create video device input: %@", error );
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    if ( [self.session canAddInput:videoDeviceInput] ) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
    }
    else {
        NSLog( @"Could not add video device input to the session" );
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }

    
    AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
    if ( [self.session canAddOutput:photoOutput] ) {
        [self.session addOutput:photoOutput];
        self.photoOutput = photoOutput;
        
        self.photoOutput.highResolutionCaptureEnabled = YES;
        self.inProgressPhotoCaptureDelegates = [NSMutableDictionary dictionary];
    } else {
        NSLog( @"Could not add photo output to the session" );
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    self.backgroundRecordingID = UIBackgroundTaskInvalid;
    
    [self.session commitConfiguration];
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}

- (void)showCamera {
    dispatch_async( self.sessionQueue, ^{
        switch ( self.setupResult )
        {
            case AVCamSetupResultSuccess:
            {
                // Only setup observers and start the session running if setup succeeded.
                [self addObservers];
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
                break;
            }
            case AVCamSetupResultCameraNotAuthorized:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    // Provide quick access to Settings.
                    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    }];
                    [alertController addAction:settingsAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
            case AVCamSetupResultSessionConfigurationFailed:
            {
                dispatch_async( dispatch_get_main_queue(), ^{
                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                    [alertController addAction:cancelAction];
                    [self presentViewController:alertController animated:YES completion:nil];
                } );
                break;
            }
        }
    } );
}

 //MARK: Buttons



- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint devicePoint = [self.previewView.videoPreviewLayer captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (IBAction)onFlashPress:(id)sender {
    
    
    self.flashEnabled = !self.flashEnabled;
    UIButton *button = sender;
    [button setTitle:self.flashEnabled ? @"Flash ON" : @"Flash OFF" forState:UIControlStateNormal];
    
    /*// We choose not to use flash when doing manual exposure
    if ( self.photoOutput.exposureMode == AVCaptureExposureModeCustom ) {
        photoSettings.flashMode = AVCaptureFlashModeOff;
    }
    else {
        photoSettings.flashMode = [self.photoOutput.supportedFlashModes containsObject:@(AVCaptureFlashModeAuto)] ? AVCaptureFlashModeAuto : AVCaptureFlashModeOff;
    }
     */

}

- (AVCapturePhotoSettings *)currentPhotoSettings
{
    
    AVCapturePhotoSettings *photoSettings = nil;
    
    if (self.photoOutput.isLensStabilizationDuringBracketedCaptureSupported ) {
        NSArray *bracketedSettings = nil;
        if (self.videoDeviceInput.device.exposureMode == AVCaptureExposureModeCustom) {
            bracketedSettings = @[[AVCaptureManualExposureBracketedStillImageSettings manualExposureSettingsWithExposureDuration:AVCaptureExposureDurationCurrent ISO:AVCaptureISOCurrent]];
        }
        else {
            bracketedSettings = @[[AVCaptureAutoExposureBracketedStillImageSettings autoExposureSettingsWithExposureTargetBias:AVCaptureExposureTargetBiasCurrent]];
        }
        
        if (self.photoOutput.availableRawPhotoPixelFormatTypes.count) {
            photoSettings = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:(OSType)(((NSNumber *)self.photoOutput.availableRawPhotoPixelFormatTypes[0]).unsignedLongValue) processedFormat:nil bracketedSettings:bracketedSettings];
        }
        else {
            photoSettings = [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:0 processedFormat:@{ AVVideoCodecKey : AVVideoCodecJPEG } bracketedSettings:bracketedSettings];
        }
        
        ((AVCapturePhotoBracketSettings *)photoSettings).lensStabilizationEnabled = YES;
    }
    else {
        if (self.photoOutput.availableRawPhotoPixelFormatTypes.count) {
            photoSettings = [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:(OSType)(((NSNumber *)self.photoOutput.availableRawPhotoPixelFormatTypes[0]).unsignedLongValue) processedFormat:nil];
        }
        else {
            photoSettings = [AVCapturePhotoSettings photoSettings];
        }
    }
    
    
    photoSettings.flashMode = self.flashEnabled ? AVCaptureFlashModeOn : AVCaptureFlashModeOff;
    
    photoSettings.autoStillImageStabilizationEnabled = YES;
    
    photoSettings.highResolutionPhotoEnabled = YES;
    
    return photoSettings;
}




- (IBAction)onCapturePress:(id)sender {
    /*
     Retrieve the video preview layer's video orientation on the main queue before
     entering the session queue. We do this to ensure UI elements are accessed on
     the main thread and session configuration is done on the session queue.
     */
    AVCaptureVideoOrientation videoPreviewLayerVideoOrientation = self.previewView.videoPreviewLayer.connection.videoOrientation;
    
    dispatch_async( self.sessionQueue, ^{
        
        // Update the photo output's connection to match the video orientation of the video preview layer.
        AVCaptureConnection *photoOutputConnection = [self.photoOutput connectionWithMediaType:AVMediaTypeVideo];
        photoOutputConnection.videoOrientation = videoPreviewLayerVideoOrientation;
        
        AVCapturePhotoSettings *photoSettings = [self currentPhotoSettings];
        // Use a separate object for the photo capture delegate to isolate each capture life cycle.
        AVCamPhotoCaptureDelegate *photoCaptureDelegate = [[AVCamPhotoCaptureDelegate alloc] initWithRequestedPhotoSettings:photoSettings willCapturePhotoAnimation:^{
            dispatch_async( dispatch_get_main_queue(), ^{
                self.previewView.videoPreviewLayer.opacity = 0.0;
                [UIView animateWithDuration:0.25 animations:^{
                    self.previewView.videoPreviewLayer.opacity = 1.0;
                }];
            } );
        } capturingLivePhoto:^( BOOL capturing ) {
        } completed:^( AVCamPhotoCaptureDelegate *photoCaptureDelegate ) {
            // When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
            dispatch_async( self.sessionQueue, ^{
                self.inProgressPhotoCaptureDelegates[@(photoCaptureDelegate.requestedPhotoSettings.uniqueID)] = nil;
            } );
        } controller:self];
        
        
        /*
         The Photo Output keeps a weak reference to the photo capture delegate so
         we store it in an array to maintain a strong reference to this object
         until the capture is completed.
         */
        self.inProgressPhotoCaptureDelegates[@(photoCaptureDelegate.requestedPhotoSettings.uniqueID)] = photoCaptureDelegate;
        [self.photoOutput capturePhotoWithSettings:photoSettings delegate:photoCaptureDelegate];
    } );

}


 //MARK: Delegates

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    
}


- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingRawPhotoSampleBuffer:(nullable CMSampleBufferRef)rawSampleBuffer previewPhotoSampleBuffer:(nullable CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(nullable AVCaptureBracketedStillImageSettings *)bracketSettings error:(nullable NSError *)error {
    if ( rawSampleBuffer ) {
        NSURL *temporaryDNGFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%lld.dng", resolvedSettings.uniqueID]]];
        NSData *imageData = [AVCapturePhotoOutput DNGPhotoDataRepresentationForRawSampleBuffer:rawSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
        [imageData writeToURL:temporaryDNGFileURL atomically:YES];
        
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if ( status == PHAuthorizationStatusAuthorized ) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    // In iOS 9 and later, it's possible to move the file into the photo library without duplicating the file data.
                    // This avoids using double the disk space during save, which can make a difference on devices with limited free disk space.
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    [[PHAssetCreationRequest creationRequestForAsset] addResourceWithType:PHAssetResourceTypePhoto fileURL:temporaryDNGFileURL options:options]; // Add move (not copy) option
                } completionHandler:^( BOOL success, NSError *error ) {
                    if ( ! success ) {
                        NSLog( @"Error occurred while saving raw photo to photo library: %@", error );
                    }
                    else {
                        NSLog( @"Raw photo was saved to photo library" );
                    }
                    
                    if ( [[NSFileManager defaultManager] fileExistsAtPath:temporaryDNGFileURL.path] ) {
                        [[NSFileManager defaultManager] removeItemAtURL:temporaryDNGFileURL error:nil];
                    }
                }];
            }
            else {
                NSLog( @"Not authorized to save photo" );
            }
        }];
    }
    else {
        NSLog( @"Error occurred while capturing photo: %@", error );
    }
}

// MARK: KVO

- (void)addObservers
{
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    
    /*
     A session can only run when the app is full screen. It will be interrupted
     in a multi-app layout, introduced in iOS 9, see also the documentation of
     AVCaptureSessionInterruptionReason. Add observers to handle these session
     interruptions and show a preview is paused message. See the documentation
     of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
     */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == SessionRunningContext ) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        BOOL livePhotoCaptureSupported = self.photoOutput.livePhotoCaptureSupported;
        BOOL livePhotoCaptureEnabled = self.photoOutput.livePhotoCaptureEnabled;
        
        dispatch_async( dispatch_get_main_queue(), ^{
            // Only enable the ability to change camera if the device has more than one camera.
            // self.cameraButton.enabled = isSessionRunning && ( [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1 );
            // self.recordButton.enabled = isSessionRunning && ( self.captureModeControl.selectedSegmentIndex == AVCamCaptureModeMovie );
            // self.photoButton.enabled = isSessionRunning;
            // self.captureModeControl.enabled = isSessionRunning;
            // self.livePhotoModeButton.enabled = isSessionRunning && livePhotoCaptureEnabled;
            // self.livePhotoModeButton.hidden = ! ( isSessionRunning && livePhotoCaptureSupported );
        } );
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog( @"Capture session runtime error: %@", error );
    
    /*
     Automatically try to restart the session running if media services were
     reset and the last start running succeeded. Otherwise, enable the user
     to try to resume the session running.
     */
    if ( error.code == AVErrorMediaServicesWereReset ) {
        dispatch_async( self.sessionQueue, ^{
            if ( self.isSessionRunning ) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
            else {
                dispatch_async( dispatch_get_main_queue(), ^{
                    // self.resumeButton.hidden = NO;
                } );
            }
        } );
    }
    else {
       //  self.resumeButton.hidden = NO;
    }
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
    /*
     In some scenarios we want to enable the user to resume the session running.
     For example, if music playback is initiated via control center while
     using AVMetadataRecordPlay, then the user can let AVMetadataRecordPlay resume
     the session running, which will stop music playback. Note that stopping
     music playback in control center will not automatically resume the session
     running. Also note that it is not always possible to resume, see -[resumeInterruptedSession:].
     */
    BOOL showResumeButton = NO;
    
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    NSLog( @"Capture session was interrupted with reason %ld", (long)reason );
    
    if ( reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
        reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient ) {
        showResumeButton = YES;
    }
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    NSLog( @"Capture session interruption ended" );
}


//MARK: Controls



- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ( [device lockForConfiguration:&error] ) {
            /*
             Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
             Call set(Focus/Exposure)Mode() to apply the new point of interest.
             */
            if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            
            if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog( @"Could not lock device for configuration: %@", error );
        }
    } );
}


@end
