//
//  LocationDetails.m
//  UpdateLoc
//
//  Created by Kundan Kumar on 18/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import "LocationDetails.h"

@implementation LocationDetails

@synthesize accuracyVal,activityVal,latitudeVal,longitudeVal,speedVal,timeStamp;

//Decode to get values from NSUserDefaults.

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.accuracyVal = [decoder decodeFloatForKey:@"accVal"];
        self.timeStamp = [decoder decodeObjectForKey:@"timeStmp"];
        self.latitudeVal = [decoder decodeFloatForKey:@"latVal"];
        self.longitudeVal = [decoder decodeFloatForKey:@"longVal"];
    }
    return self;
}

//Encode to save values in NSUserDefaults.

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeFloat:accuracyVal forKey:@"accVal"];
    [encoder encodeFloat:latitudeVal forKey:@"latVal"];
    [encoder encodeFloat:longitudeVal forKey:@"longVal"];
    [encoder encodeObject:timeStamp forKey:@"timeStmp"];
}

@end
