/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Photo capture delegate.
*/

@import AVFoundation;
@import UIKit;

@interface AVCamPhotoCaptureDelegate : NSObject<AVCapturePhotoCaptureDelegate>

- (instancetype)initWithRequestedPhotoSettings:(AVCapturePhotoSettings *)requestedPhotoSettings willCapturePhotoAnimation:(void (^)())willCapturePhotoAnimation capturingLivePhoto:(void (^)(BOOL))capturingLivePhoto completed:(void (^)(AVCamPhotoCaptureDelegate *))completed controller:(UIViewController *)controller;

@property (nonatomic, readonly) AVCapturePhotoSettings *requestedPhotoSettings;
@property (nonatomic, strong) UIImage *previewImage;

@end
