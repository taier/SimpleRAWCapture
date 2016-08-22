//
//  DKPermissonManager.h
//  SimpleRAWCapture
//
//  Created by Deniss Kaibagarovs on 22/08/16.
//  Copyright © 2016 Deniss Kaibagarovs. All rights reserved.
//

#import <Foundation/Foundation.h>

@import Photos;

typedef NS_ENUM(NSInteger, DKAccess) {
    DKAcessGranted,
    DKAcessDenided,
    DKAcessAsking
};

typedef NS_ENUM(NSInteger, DKPermisson) {
    DKPermissonCamer,
    DKPermissonPhotoLibrary
};


@interface DKPermissonManager : NSObject

+ (DKAccess)hasCameraAcess;
+ (void)askForCameraAcess:(void (^)(BOOL granted))handler;
+ (DKAccess)hasPhotoLibraryAcess;
+ (void)askForPhotoLibraryAcess:(void(^)(PHAuthorizationStatus status))handler;

+ (void)showPermissionDeniedAlert:(DKPermisson) permisson viewController:(UIViewController *)viewController;

@end
