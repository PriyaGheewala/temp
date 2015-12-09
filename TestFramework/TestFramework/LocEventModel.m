//
//  LocEventModel.m
//  UpdateLoc
//
//  Created by Kundan Kumar on 21/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import "LocEventModel.h"

@implementation LocEventModel

@synthesize event_name,event_type,time;

//Decode to get values from NSUserDefaults.

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.event_name = [decoder decodeObjectForKey:@"event_NameVal"];
        self.event_type = [decoder decodeObjectForKey:@"event_TypeVal"];
        self.time = [decoder decodeObjectForKey:@"timeVal"];
    }
    return self;
}

//Encode to save values in NSUserDefaults.

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:event_name forKey:@"event_NameVal"];
    [encoder encodeObject:event_type forKey:@"event_TypeVal"];
    [encoder encodeObject:time forKey:@"timeVal"];
}

@end
