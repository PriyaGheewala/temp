//
//  LocEventModel.h
//  UpdateLoc
//
//  Created by Kundan Kumar on 21/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocEventModel : NSObject<NSCoding>

@property (nonatomic, strong) NSString *event_type,*time,*event_name;

@end
