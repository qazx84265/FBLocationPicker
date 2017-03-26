//
//  FBLocationPickerVC.h
//  FBLocationPicker
//
//  Created by FB on 2017/3/25.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

typedef void (^pickerCallback)(CLLocationCoordinate2D coor, NSString* formatLocation);

typedef NS_ENUM(NSInteger, pickerType) {
    pickerType_done_with_sendButton,
    pickerType_done_with_select
};

@interface FBLocationPickerVC : UIViewController
+ (void)showInViewController:(UIViewController*)viewController type:(pickerType)type pickerCallback:(pickerCallback)pickerCallback;
@end
