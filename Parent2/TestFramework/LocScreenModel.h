//
//  LocScreenModel.h
//  UpdateLoc
//
//  Created by Kundan Kumar on 21/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LocScreenModel : NSObject<NSCoding>

@property (nonatomic, strong) NSString *start_time;
@property (nonatomic, strong) NSString *screen_name;
@property (nonatomic, strong) NSString *data_type;

@end
