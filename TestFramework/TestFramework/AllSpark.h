//
//  AllSpark.h
//  AllSpark
//
//  Created by Kundan Kumar on 14/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>


@interface AllSpark : NSObject<CLLocationManagerDelegate>

+(void)startSDK:(UIViewController *)viewControllerName;
+(void)stopSDK:(UIViewController *)viewControllerName;
+(void)setApplicationId:(NSString *)setApplicationId api:(NSString *) APIKey pub:(NSString *) PubID;
+(void)setAge:(int)age;
+(void)setGender:(BOOL)gender;
+(void)sendEvent:(NSString *)eventName withValue:(NSString *)eventValue;

@end
