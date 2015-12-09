//
//  LocationDetails.h
//  UpdateLoc
//
//  Created by Kundan Kumar on 18/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocationDetails : NSObject <NSCoding>

@property (nonatomic) float latitudeVal;
@property (nonatomic) float longitudeVal;
@property (nonatomic) float accuracyVal;
@property (nonatomic,strong) NSString *timeStamp;
@property (nonatomic,strong) NSString *activityVal;
@property (nonatomic) float speedVal;

@end
