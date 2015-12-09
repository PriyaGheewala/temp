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
/*!
  * Starts api calls to send data to Allspark
 */
+(void)startSDK:(UIViewController *)viewControllerName;
/*!
 * Stops api calls to send data to Allspark
 */
+(void)stopSDK:(UIViewController *)viewControllerName;
/*!
 * Sets the ApplicationID,APIKey and PublisherID.
 */
+(void)setApplicationId:(NSString *)setApplicationId api:(NSString *) APIKey pub:(NSString *) PubID;
/*!
 * Sets the age of the user
 */
+(void)setAge:(int)age;
/*!
 * Sets the Custom Data
 */
+(void)setCustomData:(NSString *)customDataName withValue:(NSString *)customDataValue;
/*!
 * Sets the gender of the user
 */
+(void)setGender:(BOOL)gender;
/*!
 * Sends event name and value to Allspark
 */
+(void)sendEvent:(NSString *)eventName withValue:(NSString *)eventValue;

@end
