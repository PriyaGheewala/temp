//
//  LocScreenEndModel.m
//  UpdateLoc
//
//  Created by Kundan Kumar on 22/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import "LocScreenEndModel.h"

@implementation LocScreenEndModel

@synthesize screen_name,data_type,end_time;

//Decode to get values from NSUserDefaults.

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.screen_name = [decoder decodeObjectForKey:@"screen_NameVal1"];
        self.data_type = [decoder decodeObjectForKey:@"data_TypeVal1"];
        self.end_time = [decoder decodeObjectForKey:@"end_TimeVal"];
    }
    return self;
}

//Encode to save values in NSUserDefaults.

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:screen_name forKey:@"screen_NameVal1"];
    [encoder encodeObject:data_type forKey:@"data_TypeVal1"];
    [encoder encodeObject:end_time forKey:@"end_TimeVal"];
}

@end
