//
//  DKPermissonManager.m
//  SimpleRAWCapture
//
//  Created by Deniss Kaibagarovs on 22/08/16.
//  Copyright © 2016 Deniss Kaibagarovs. All rights reserved.
//

#import "DKPermissonManager.h"

@import AVFoundation;

@implementation DKPermissonManager

+ (id)sharedManager {
    static DKPermissonManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (id)init {
    if (self = [super init]) {
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

+ (DKAccess)hasCameraAcess {
    
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    if(status == AVAuthorizationStatusAuthorized) {
        return DKAcessGranted;
    }
    else if(status == AVAuthorizationStatusDenied) {

    }
    else if(status == AVAuthorizationStatusRestricted) {
        
    }
    
    else if (status == AVAuthorizationStatusNotDetermined) {
        return DKAcessAsking;
    }
    
    return DKAcessDenided;
}

+ (void)askForCameraAcess:(void (^)(BOOL granted))handler {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:handler];
}

+ (DKAccess)hasPhotoLibraryAcess {
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if (status == PHAuthorizationStatusAuthorized) {
        return DKAcessGranted;
    }
    
    else if (status == PHAuthorizationStatusDenied) {
        
    }
    
    else if (status == PHAuthorizationStatusRestricted) {
    }
    
    else if (status == PHAuthorizationStatusNotDetermined) {
        return DKAcessAsking;
    }
    
    return DKAcessDenided;
}

+ (void)askForPhotoLibraryAcess:(void(^)(PHAuthorizationStatus status))handler {
    [PHPhotoLibrary requestAuthorization:handler];
}

+ (void)showPermissionDeniedAlert:(DKPermisson) permisson viewController:(UIViewController *)viewController {
    
    NSString *permissionRegion = permisson == DKPermissonCamer ? @"Camera" : @"Photos";
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Permission Denied"
                                 message:[NSString stringWithFormat:@"Please turn on '%@ Acess' in Settings > Privacy > %@ ", permissionRegion, permissionRegion]
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:@"Settings"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    NSURL *URL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                    [[UIApplication sharedApplication] openURL:URL options:NULL completionHandler:NULL];
                                }];
    
    UIAlertAction* noButton = [UIAlertAction
                               actionWithTitle:@"Cancel"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   //Handle no, thanks button
                               }];
    
    [alert addAction:noButton];
    [alert addAction:yesButton];
    
    
    [viewController presentViewController:alert animated:YES completion:nil];
}

@end
