/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Photo capture delegate.
*/

#import "AVCamPhotoCaptureDelegate.h"

@import Photos;

@interface AVCamPhotoCaptureDelegate ()

@property (nonatomic, readwrite) AVCapturePhotoSettings *requestedPhotoSettings;
@property (nonatomic) void (^willCapturePhotoAnimation)();
@property (nonatomic) void (^capturingLivePhoto)(BOOL capturing);
@property (nonatomic) void (^completed)(AVCamPhotoCaptureDelegate *photoCaptureDelegate);

@property (nonatomic) UIViewController *controllerToShare;

@property (nonatomic) UIPopoverPresentationController *popController;

@property (nonatomic) NSData *photoData;
@property (nonatomic) NSURL *livePhotoCompanionMovieURL;

@end

@implementation AVCamPhotoCaptureDelegate

- (instancetype)initWithRequestedPhotoSettings:(AVCapturePhotoSettings *)requestedPhotoSettings willCapturePhotoAnimation:(void (^)())willCapturePhotoAnimation capturingLivePhoto:(void (^)(BOOL))capturingLivePhoto completed:(void (^)(AVCamPhotoCaptureDelegate *))completed controller:(UIViewController *)controller
{
	self = [super init];
	if ( self ) {
		self.requestedPhotoSettings = requestedPhotoSettings;
		self.willCapturePhotoAnimation = willCapturePhotoAnimation;
		self.capturingLivePhoto = capturingLivePhoto;
		self.completed = completed;
        self.controllerToShare = controller;
	}
	return self;
}

- (void)didFinish
{
	if ( [[NSFileManager defaultManager] fileExistsAtPath:self.livePhotoCompanionMovieURL.path] ) {
		NSError *error = nil;
		[[NSFileManager defaultManager] removeItemAtPath:self.livePhotoCompanionMovieURL.path error:&error];
		
		if ( error ) {
			NSLog( @"Could not remove file at url: %@", self.livePhotoCompanionMovieURL.path );
		}
	}
	
	self.completed( self );
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	if ( ( resolvedSettings.livePhotoMovieDimensions.width > 0 ) && ( resolvedSettings.livePhotoMovieDimensions.height > 0 ) ) {
		self.capturingLivePhoto( YES );
	}
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	self.willCapturePhotoAnimation();
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error
{
	if ( error != nil ) {
		NSLog( @"Error capturing photo: %@", error );
		return;
	}
	
	self.photoData = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer previewPhotoSampleBuffer:previewPhotoSampleBuffer];
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishRecordingLivePhotoMovieForEventualFileAtURL:(NSURL *)outputFileURL resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
	self.capturingLivePhoto(NO);
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingLivePhotoToMovieFileAtURL:(NSURL *)outputFileURL duration:(CMTime)duration photoDisplayTime:(CMTime)photoDisplayTime resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
	if ( error != nil ) {
		NSLog( @"Error processing live photo companion movie: %@", error );
		return;
	}
	
	self.livePhotoCompanionMovieURL = outputFileURL;
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings error:(NSError *)error
{
	if ( error != nil ) {
		NSLog( @"Error capturing photo: %@", error );
		[self didFinish];
		return;
	}
	
	if ( self.photoData == nil ) {
		NSLog( @"No photo data resource" );
		[self didFinish];
		return;
	}
	
	[PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
		if ( status == PHAuthorizationStatusAuthorized ) {
			[[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
				PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAsset];
				[creationRequest addResourceWithType:PHAssetResourceTypePhoto data:self.photoData options:nil];
				
				if ( self.livePhotoCompanionMovieURL ) {
					PHAssetResourceCreationOptions *livePhotoCompanionMovieResourceOptions = [[PHAssetResourceCreationOptions alloc] init];
					livePhotoCompanionMovieResourceOptions.shouldMoveFile = YES;
					[creationRequest addResourceWithType:PHAssetResourceTypePairedVideo fileURL:self.livePhotoCompanionMovieURL options:livePhotoCompanionMovieResourceOptions];
				}
			} completionHandler:^( BOOL success, NSError * _Nullable error ) {
				if ( ! success ) {
					NSLog( @"Error occurred while saving photo to photo library: %@", error );
				}
				
				[self didFinish];
			}];
		}
		else {
			NSLog( @"Not authorized to save photo" );
			[self didFinish];
		}
	}];
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




@end
