//
//  LocScreenModel.m
//  UpdateLoc
//
//  Created by Kundan Kumar on 21/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import "LocScreenModel.h"

@implementation LocScreenModel

@synthesize screen_name,start_time,data_type;

//Decode to get values from NSUserDefaults.

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.screen_name = [decoder decodeObjectForKey:@"screen_NameVal"];
        self.start_time = [decoder decodeObjectForKey:@"start_TimeVal"];
        self.data_type = [decoder decodeObjectForKey:@"data_TypeVal"];
    }
    return self;
}

//Encode to save values in NSUserDefaults.

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:screen_name forKey:@"screen_NameVal"];
    [encoder encodeObject:start_time forKey:@"start_TimeVal"];
    [encoder encodeObject:data_type forKey:@"data_TypeVal"];
}

@end
