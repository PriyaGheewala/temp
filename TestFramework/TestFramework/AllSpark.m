//
//  AllSpark.m
//  AllSpark
//
//  Created by Kundan Kumar on 14/05/15.
//  Copyright (c) 2015 Kundan Kumar. All rights reserved.
//

#import "AllSpark.h"
#import "LocationDetails.h"
#import "LocEventModel.h"
#import "LocScreenModel.h"
#import "LocScreenEndModel.h"
#import <sys/utsname.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <AdSupport/AdSupport.h>
#import <sys/sysctl.h>

#define IS_OS_8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
#define ONE_MIN 1
#define TEN_MIN 10

@interface AllSpark()

@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic,strong) NSDate *lastTimestamp;
@property (nonatomic, strong) NSMutableArray *analyticsArray,*prevLocationArray; //Global array
@property (nonatomic, strong) CLLocation *locationLatLong;
@property (nonatomic, strong) CLLocation *locationLatLongTemp;
@property (nonatomic, strong) NSTimer *timerForInterval;
@property (nonatomic, strong) NSString *stateChanged;
@property (nonatomic, assign) NSInteger timerIndex;
@property BOOL isFiredAPI;

@end
@implementation AllSpark
static id lockingKey=@"lock";
@synthesize locationManager,locationLatLong,analyticsArray,prevLocationArray,timerForInterval,stateChanged,timerIndex,isFiredAPI,locationLatLongTemp;

// Initializing

- (id)init {
    self = [super init];
    
    if(self) {
        analyticsArray = [[NSMutableArray alloc] init];
        prevLocationArray = [[NSMutableArray alloc] init];
        
        //Creating instance of CLLocationManager
        self.locationManager = [CLLocationManager new];
        
        timerIndex=0;
        isFiredAPI=NO;
        [self.locationManager setDelegate:self];
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.pausesLocationUpdatesAutomatically = NO;
        self.locationManager.distanceFilter = 100;
        
        //To get user permission for location access.
        if(IS_OS_8_OR_LATER)
        {
            NSUInteger code = [CLLocationManager authorizationStatus];
            if (code == kCLAuthorizationStatusNotDetermined && ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)] || [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])) {
                if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"]){
                    [self.locationManager requestAlwaysAuthorization];
                } else if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
                    [self.locationManager  requestWhenInUseAuthorization];
                } else {
                    NSException *exception =[NSException exceptionWithName:@"NSLocationAlwaysUsageDescriptionException" reason:@"Info.plist does not contain NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription" userInfo:nil];
                    @throw exception;
                }
            }
        }
        [self.locationManager startUpdatingLocation];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:[AllSpark class] selector:@selector(activateTimer)
                                                     name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}
+(void)activateTimer{
    NSLog(@"From activate timer");
    if(![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] && ![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"])
    {
        
        NSException *exception =[NSException exceptionWithName:@"NSLocationAlwaysUsageDescriptionException" reason:@"Info.plist does not contain NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription" userInfo:nil];
        @throw exception;
    }
    if([[NSUserDefaults standardUserDefaults]
        stringForKey:@"AppID"].length==0 || [[NSUserDefaults standardUserDefaults]
                                             stringForKey:@"PubID"].length==0 || [[NSUserDefaults standardUserDefaults]
                                                                                  stringForKey:@"APIKey"].length==0)
    {
        NSException *exception =[NSException exceptionWithName:@"AppSpecificDataException" reason:@"Application Specific Data is not set" userInfo:nil];
        @throw exception;
    }
    
    if([AllSpark sharedSingleton].timerForInterval==nil || ![[AllSpark sharedSingleton].timerForInterval isValid])
    {
        @try {
            
           // [AllSpark sharedSingleton].timerForInterval = [NSTimer scheduledTimerWithTimeInterval:ONE_MIN * 60 target:self selector:@selector(handleTimer) userInfo:@"yes" repeats:YES];
               [AllSpark sharedSingleton].timerForInterval = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(handleTimer) userInfo:@"yes" repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:[AllSpark sharedSingleton].timerForInterval forMode:NSRunLoopCommonModes];
        }
        @catch (NSException *exception) {
            // NSLog(@"From activateTimer- %@",exception.description);
        }
    }
    [[AllSpark sharedSingleton].locationManager startUpdatingLocation]; //location updates were stopped as app was in background. Start it again.
    // NSLog(@"Activate Timer");
    
}

#pragma mark - CLLocationManager Delegate Methods
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"didChangeAuthorizationStatus");
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status==kCLAuthorizationStatusAuthorized || status==kCLAuthorizationStatusAuthorizedAlways)
    {
        [self.locationManager startUpdatingLocation];
    }
    else if(status==kCLAuthorizationStatusDenied || status==kCLAuthorizationStatusNotDetermined || status==kCLAuthorizationStatusRestricted)
    {
        //Save location data to prev loc array and set locationlatlong to nil, if user revokes permission of loc tracking in the middle of app execution. o/w same location lat long will be sent forever as current location.
        [self.locationManager stopUpdatingLocation];
        if(locationLatLong!=nil){
            NSLog(@"Revoked location permission Saving location data to prevLoc array");
            [self addLocationToPreviousLocationArray:locationLatLong];
            locationLatLong=nil;
        }
        if(locationLatLongTemp!=nil){
            [self addLocationToPreviousLocationArray:locationLatLongTemp];
            locationLatLongTemp=nil;
        }
    }
}

// Delegate method for CLLocationManager, which get call when location update occurs.
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"From didUpdateLocations started");
    // @synchronized([NSUserDefaults standardUserDefaults])
    @synchronized(lockingKey)
    {
        if(! isFiredAPI)  //To prevent main thread to call this method while executing handleTimer and lost location data and create inconsistency.
        {
            NSLog(@"didUpdateLocations Current thread is %@",[NSThread currentThread]);
            @try {
               
                if(locationLatLong!=nil){
                    NSLog(@"locationLatLong is not nil");
                    [self addLocationToPreviousLocationArray:locationLatLong];

                }
                if(locationLatLongTemp!=nil){
                    NSLog(@"locationLatLongtemp is not nil");

                    [self addLocationToPreviousLocationArray:locationLatLongTemp];
                    locationLatLongTemp=nil;
                    
                }
                locationLatLong =[locations lastObject];
                [AllSpark sharedSingleton].stateChanged=@"yes";
                NSLog(@"State Change from didUpdateLocations");
                NSLog(@"From didUpdateLocations ended");
                
            }
            @catch (NSException *exception) {
            }
        }
        else
        {
            locationLatLongTemp=[locations lastObject];
        }
    }
}
-(void)addLocationToPreviousLocationArray:(CLLocation *)locationData
{
    NSMutableArray *prevLocArray;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"prevLocationArrayVal"]) {
        NSData *notesData1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"prevLocationArrayVal"];
        prevLocArray = [[NSKeyedUnarchiver unarchiveObjectWithData:notesData1]mutableCopy];
    }
    if (prevLocArray == nil) {
        prevLocArray = [[NSMutableArray alloc]init];
    }
    LocationDetails *locationElements = [[LocationDetails alloc]init];
    locationElements.latitudeVal = locationData.coordinate.latitude;
    locationElements.longitudeVal = locationData.coordinate.longitude;
    locationElements.accuracyVal = locationData.horizontalAccuracy;
    NSDate *nowVal = locationData.timestamp;
    NSString *currentTimeValEventTimer = [NSString stringWithFormat:@"%lli",[@(floor([nowVal timeIntervalSince1970])) longLongValue]];
    locationElements.timeStamp = currentTimeValEventTimer;
    [prevLocArray addObject:locationElements];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:prevLocArray];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"prevLocationArrayVal"];

}
#pragma mark -Class level methods

// Created singleton class to start location tracking.
+ (AllSpark *)sharedSingleton {
    static AllSpark* sharedSingleton;
    if(!sharedSingleton) {
        @synchronized(self) {
            sharedSingleton = [AllSpark new];
        }
    }
    return sharedSingleton;
}
// Method getting called to set AppID, APIKey and PubID.
+ (void)setApplicationId:(NSString *)setApplicationId api:(NSString *) APIKey pub:(NSString *) PubID
{
    // @synchronized([NSUserDefaults standardUserDefaults])
    @synchronized(lockingKey)
    {
        @try {
            [[NSUserDefaults standardUserDefaults] setObject:setApplicationId forKey:@"AppID"];
            [[NSUserDefaults standardUserDefaults] setObject:APIKey forKey:@"APIKey"];
            [[NSUserDefaults standardUserDefaults] setObject:PubID forKey:@"PubID"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [AllSpark sharedSingleton].stateChanged=@"yes";
            NSLog(@"State Changed From setApplicationId");
            
        }
        @catch (NSException *exception) {
        }
    }
    
}
// Method getting called to set age.
+(void)setAge:(int)age
{
    // @synchronized([NSUserDefaults standardUserDefaults])
    @synchronized(lockingKey)
    {
        @try {
            if(age>120 || age <= 0)
            {
                NSException *exception =[NSException exceptionWithName:@"InvalidAgeException" reason:@"Invalid Age" userInfo:nil];
                @throw exception;
                //  NSLog(@"Invalid Age");
            }
            else
            {
                [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d",age] forKey:@"ageVal"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [AllSpark sharedSingleton].stateChanged=@"yes";
                NSLog(@"State Changed  From setAge");
            }
        }
        @catch (NSException *exception) {
            //   NSLog(@"%@",exception.description);
            if([exception.name isEqualToString:@"InvalidAgeException"])
            {
                @throw exception;
            }
        }
    }
}

// Method getting called to set gender.
+(void)setGender:(BOOL)gender
{
    //@synchronized([NSUserDefaults standardUserDefaults])
    @synchronized(lockingKey)
    {
        @try {
            NSString *genderValue;
            if(gender)
            {
                genderValue=@"male";
            }
            else
            {
                genderValue=@"female";
            }
            [[NSUserDefaults standardUserDefaults] setObject:genderValue forKey:@"genderVal"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [AllSpark sharedSingleton].stateChanged=@"yes";
            NSLog(@"State Changed  From setGender");
            
        }
        @catch (NSException *exception) {
        }
    }
}

// Method getting called to set EventName and EventValue.
+(void)sendEvent:(NSString *)eventName withValue:(NSString *)eventValue
{
    @try {
        NSDate *nowVal = [NSDate date];
        NSString *currentTimeValEvent = [NSString stringWithFormat:@"%lli",[@(floor([nowVal timeIntervalSince1970])) longLongValue]];
        
        LocEventModel *locEModel = [[LocEventModel alloc]init];
        locEModel.event_type = eventValue;
        locEModel.event_name = eventName;
        locEModel.time = currentTimeValEvent;
        
        //@synchronized([NSUserDefaults standardUserDefaults])
        @synchronized(lockingKey)
        {
            @try {
                //getEventArray from NSUserDefaults, append new event to array and store it back to NSUserDefaults
                NSMutableArray *eventArrayDesc;
                if ([[NSUserDefaults standardUserDefaults] objectForKey:@"eventArrayVal"]) {
                    NSData *notesData1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"eventArrayVal"];
                    eventArrayDesc = [[NSKeyedUnarchiver unarchiveObjectWithData:notesData1]mutableCopy];
                }
                if (eventArrayDesc == nil) {
                    eventArrayDesc = [[NSMutableArray alloc]init];
                }
                [eventArrayDesc addObject:locEModel];
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:eventArrayDesc];
                [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"eventArrayVal"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            @catch (NSException *exception) {
                
            }
        }
        [AllSpark sharedSingleton].stateChanged=@"yes";
        NSLog(@"State Changed  From sendEvent");
    }
    @catch (NSException *exception) {
        
    }
}

// Method getting called to start SDK.
+(void)startSDK:(UIViewController *)viewControllerName
{
    @try {
        
        if(![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] && ![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"])
        {
            
            NSException *exception =[NSException exceptionWithName:@"NSLocationAlwaysUsageDescriptionException" reason:@"Info.plist does not contain NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription" userInfo:nil];
            @throw exception;
        }
        if([[NSUserDefaults standardUserDefaults]
            stringForKey:@"AppID"].length==0 || [[NSUserDefaults standardUserDefaults]
                                                 stringForKey:@"PubID"].length==0 || [[NSUserDefaults standardUserDefaults]
                                                                                      stringForKey:@"APIKey"].length==0)
        {
            NSException *exception =[NSException exceptionWithName:@"AppSpecificDataException" reason:@"Application Specific Data is not set" userInfo:nil];
            @throw exception;
        }
        
        NSString *viewControllerClassName = NSStringFromClass([viewControllerName class]);
        NSDate *nowVal = [NSDate date];
        // NSLog(@"nowVal is %@",nowVal);
        NSString *currentTimeValStart = [NSString stringWithFormat:@"%lli",[@(floor([nowVal timeIntervalSince1970])) longLongValue]];
        // NSLog(@"currentTimeValStart is %@",currentTimeValStart);
        
        LocScreenModel *locScreenMdl = [[LocScreenModel alloc]init];
        locScreenMdl.start_time = currentTimeValStart;
        locScreenMdl.data_type = @"session_start";
        locScreenMdl.screen_name = viewControllerClassName;
        //@synchronized([NSUserDefaults standardUserDefaults])
        @synchronized(lockingKey)
        {
            @try {
                NSMutableArray *screenNameArrayStart;
                if ([[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal"]) {
                    NSData *notesData1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal"];
                    screenNameArrayStart = [[NSKeyedUnarchiver unarchiveObjectWithData:notesData1]mutableCopy];
                }
                if (screenNameArrayStart == nil) {
                    screenNameArrayStart = [[NSMutableArray alloc]init];
                }
                [screenNameArrayStart addObject:locScreenMdl];
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:screenNameArrayStart];
                [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"screenNameArrayVal"];
            }
            @catch (NSException *exception) {
            }
        }
        //   NSLog(@"Time isValid %d",[[AllSpark sharedSingleton].timerForInterval isValid]);
        if([AllSpark sharedSingleton].timerForInterval==nil || ![[AllSpark sharedSingleton].timerForInterval isValid]){
            @try {
                // [AllSpark sharedSingleton].timerForInterval = [NSTimer scheduledTimerWithTimeInterval:ONE_MIN * 60 target:self selector:@selector(handleTimer) userInfo:@"yes" repeats:YES];
                
                [AllSpark sharedSingleton].timerForInterval = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(handleTimer) userInfo:@"yes" repeats:YES];
                [[NSRunLoop currentRunLoop] addTimer:[AllSpark sharedSingleton].timerForInterval forMode:NSRunLoopCommonModes];
            }
            @catch (NSException *exception) {
            }
        }
        [AllSpark sharedSingleton].stateChanged=@"yes";
        NSLog(@"State Changed From start SDK");
    }
    @catch (NSException *exception) {
        if([exception.name isEqualToString:@"NSLocationAlwaysUsageDescriptionException"] || [exception.name isEqualToString:@"AppSpecificDataException"])
        {
            @throw exception;
        }
    }
}

// Method getting called to stop SDK.
+(void)stopSDK:(UIViewController *)viewControllerName
{
    @try {
        
        
        NSString *viewControllerClassName = NSStringFromClass([viewControllerName class]);
        
        NSDate *nowVal = [NSDate date];
        NSString *currentTimeValEnd = [NSString stringWithFormat:@"%lli",[@(floor([nowVal timeIntervalSince1970])) longLongValue]];
        
        LocScreenEndModel *locScreenMdl = [[LocScreenEndModel alloc]init];
        locScreenMdl.end_time = currentTimeValEnd;
        locScreenMdl.data_type = @"session_end";
        locScreenMdl.screen_name = viewControllerClassName;
        
        //@synchronized([NSUserDefaults standardUserDefaults])
        @synchronized(lockingKey)
        {
            @try {
                NSMutableArray *screenNameArray1;
                if ([[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal1"]) {
                    NSData *notesData1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal1"];
                    screenNameArray1 = [[NSKeyedUnarchiver unarchiveObjectWithData:notesData1]mutableCopy];
                }
                if (screenNameArray1 == nil) {
                    screenNameArray1 = [[NSMutableArray alloc]init];
                }
                [screenNameArray1 addObject:locScreenMdl];
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:screenNameArray1];
                [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"screenNameArrayVal1"];
            }
            @catch (NSException *exception) {
            }
        }
        [AllSpark sharedSingleton].stateChanged=@"yes";
        NSLog(@"State Changed From stop SDK");
    }
    @catch (NSException *exception) {
        
    }
    
}
+(NSString *)getCurrentNetworkType
{
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    if ([netinfo.currentRadioAccessTechnology length] == 0) {
        return @"WIFI";
    }
    else
    {
        //       get carrier Network Type.
        return  netinfo.currentRadioAccessTechnology;
    }
}
+(NSString *)getCarrierOperatorName
{
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    if ([[carrier carrierName] length] == 0) {
        return @"No Carrier";
    }
    else
    {
        //       get carrier operator name.
        return [carrier carrierName];
    }
}
+(NSString *)getIsLatValue
{
    ASIdentifierManager *adIdentManager = [ASIdentifierManager sharedManager];
    if (adIdentManager.advertisingTrackingEnabled) {
        // do ad tracking/targeting stuff
        //User has disabled limited Ad tracking
        return @"false";
    } else {
        // throw away any tracking info you may have saved before
        //User has opted for limitd Ad tracking
        return  @"true";
    }
}
+(NSString *)getDeviceType
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    
    NSString *deviceType = [NSString stringWithFormat:@"%@",[self platformType:platform]];
    return deviceType;
    
}
+(void)fillPreviousLocationArray
{
    @try {
        NSArray *prevLocationArrayNotes;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"prevLocationArrayVal"]) {
            NSData *locationData = [[NSUserDefaults standardUserDefaults] objectForKey:@"prevLocationArrayVal"];
            prevLocationArrayNotes = [[NSKeyedUnarchiver unarchiveObjectWithData:locationData]mutableCopy];
        }
        
        if (prevLocationArrayNotes != nil) {
            for(int i=0;i<prevLocationArrayNotes.count;i++)
            {
                LocationDetails *locationElements = [prevLocationArrayNotes objectAtIndex:i];
                NSMutableDictionary *prevLocationDic = [NSMutableDictionary dictionaryWithDictionary:@{@"lon": [NSNumber numberWithFloat:locationElements.longitudeVal],@"time" : locationElements.timeStamp, @"lat":[NSNumber numberWithFloat:locationElements.latitudeVal], @"acc":[NSNumber numberWithFloat:locationElements.accuracyVal]}];
                [[AllSpark sharedSingleton].prevLocationArray addObject:prevLocationDic];
            }
            //    NSLog(@"prevLocationArray has data");
        }
    }
    @catch (NSException *exception) {
    }
}
+(void)fillAnalyticsArray
{
    @try {
        
        NSArray *screenNameNotes;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal"]) {
            NSData *screenNameData = [[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal"];
            screenNameNotes = [[NSKeyedUnarchiver unarchiveObjectWithData:screenNameData]mutableCopy];
        }
        NSDictionary *analyticsDic;
        if (screenNameNotes != nil) {
            
            for(int i=0;i<screenNameNotes.count;i++)
            {
                LocScreenModel *locScrMdl = [screenNameNotes objectAtIndex:i];
                analyticsDic = @{@"start_time": locScrMdl.start_time,@"data_type" : @"session_start",@"screen_name" : locScrMdl.screen_name};
                [[AllSpark sharedSingleton].analyticsArray addObject:analyticsDic];
            }
        }
        
        NSArray *screenNameEndNotes;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal1"]) {
            NSData *screenNameEndData = [[NSUserDefaults standardUserDefaults] objectForKey:@"screenNameArrayVal1"];
            screenNameEndNotes = [[NSKeyedUnarchiver unarchiveObjectWithData:screenNameEndData]mutableCopy];
        }
        NSDictionary *endDic;
        if (screenNameEndNotes != nil) {
            for(int i=0;i<screenNameEndNotes.count;i++)
            {
                LocScreenEndModel *locScrEndMdl = [screenNameEndNotes objectAtIndex:i];
                endDic = @{@"end_time": locScrEndMdl.end_time,@"data_type" : @"session_end",@"screen_name" : locScrEndMdl.screen_name};
                [[AllSpark sharedSingleton].analyticsArray addObject:endDic];
            }
        }
        
        NSArray *eventArrayNotes;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"eventArrayVal"])
        {
            NSData *eventArrayData = [[NSUserDefaults standardUserDefaults] objectForKey:@"eventArrayVal"];
            eventArrayNotes = [[NSKeyedUnarchiver unarchiveObjectWithData:eventArrayData]mutableCopy];
        }
        
        if (eventArrayNotes != nil)
        {
            for(int i=0;i<eventArrayNotes.count;i++)
            {
                LocEventModel *locEvntMdl = [eventArrayNotes objectAtIndex:i];
                NSDictionary *eventDic = @{@"event_type": locEvntMdl.event_type,@"time" : locEvntMdl.time,@"event_name" : locEvntMdl.event_name};
                [[AllSpark sharedSingleton].analyticsArray addObject:eventDic];
            }
        }
    }
    @catch (NSException *exception) {
    }
}

+(NSMutableDictionary *)getCurrentLocationDictionary
{
    //current Location
    
    LocationDetails *locationElements = [[LocationDetails alloc]init];
    @try {
        locationElements.latitudeVal = [AllSpark sharedSingleton].locationLatLong.coordinate.latitude;;
        locationElements.longitudeVal = [AllSpark sharedSingleton].locationLatLong.coordinate.longitude;
        locationElements.accuracyVal = [AllSpark sharedSingleton].locationLatLong.horizontalAccuracy;
        NSDate *locationTimeVal = [AllSpark sharedSingleton].locationLatLong.timestamp;
        
        NSString *locationCaptureTime = [NSString stringWithFormat:@"%lli",[@(floor([locationTimeVal timeIntervalSince1970])) longLongValue]];
        
        locationElements.timeStamp = locationCaptureTime;
    }
    @catch (NSException *exception) {
        
    }
    
    NSMutableDictionary *dic;
    if(locationElements.latitudeVal!=0 && locationElements.longitudeVal!=0){
        dic = [NSMutableDictionary dictionaryWithDictionary:@{@"lon": [NSNumber numberWithFloat:locationElements.longitudeVal],@"time" : locationElements.timeStamp, @"lat":[NSNumber numberWithFloat:locationElements.latitudeVal], @"acc":[NSNumber numberWithFloat:locationElements.accuracyVal]}];
    }
    return dic;
}
+(void) handleTimer
{
    //  NSLog(@"From handle Timer");
    @try {
        [AllSpark sharedSingleton].timerIndex++;
        NSLog(@"TimerIndex is %ld",(long)[AllSpark sharedSingleton].timerIndex);
        NSLog(@"isFiredAPI is %d",[AllSpark sharedSingleton].isFiredAPI);
        
        
        
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        if(state==UIApplicationStateBackground)
        {
            [self clearArrays];
            [[AllSpark sharedSingleton].locationManager stopUpdatingLocation];
            
            [[AllSpark sharedSingleton].timerForInterval invalidate];
            return;
        }
        
        NSLog(@"From Handle Timer: stateChanged is %@",[AllSpark sharedSingleton].stateChanged);
        // if(([AllSpark sharedSingleton].stateChanged==nil || [[AllSpark sharedSingleton].stateChanged isEqualToString:@"no"]) && [AllSpark sharedSingleton].timerIndex<=TEN_MIN)
        if([[AllSpark sharedSingleton].stateChanged isEqualToString:@"no"] && [AllSpark sharedSingleton].timerIndex<=TEN_MIN)
            
        {
            //  NSLog(@"Timer index is%ld",(long)[AllSpark sharedSingleton].timerIndex);
            //  NSLog(@"StateChanged is %@",[AllSpark sharedSingleton].stateChanged);
            //  NSLog(@"No Statechange or time is <10");
            return;
        }
        
        NSDate *nowVal = [NSDate date];
        NSString *currentTimeValEventTimer = [NSString stringWithFormat:@"%lli",[@(floor([nowVal timeIntervalSince1970])) longLongValue]];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        //       get version number.
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *carrierOperatorName=[self getCarrierOperatorName];
        NSString *currentNetworkType =[self getCurrentNetworkType];
        if(! [AllSpark sharedSingleton].isFiredAPI)
        {
            [AllSpark sharedSingleton].isFiredAPI=YES;
            //@synchronized([NSUserDefaults standardUserDefaults])
            @synchronized(lockingKey)
            {
                NSLog(@"handleTimer Current thread is %@",[NSThread currentThread]);
                
                @try {
                    //           get appID value.
                    NSString *appIDValue = [[NSUserDefaults standardUserDefaults]
                                            stringForKey:@"AppID"];
                    //  NSLog(@"AppID %@",appIDValue);
                    //           get PubID Value.
                    NSString *pubIDValue = [[NSUserDefaults standardUserDefaults]
                                            stringForKey:@"PubID"];
                    //    NSLog(@"pubIDValue %@",pubIDValue);
                    
                    NSMutableDictionary *userDic=[[NSMutableDictionary alloc]init];
                    
                    if([[NSUserDefaults standardUserDefaults] objectForKey:@"genderVal"])
                    {
                        [userDic setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"genderVal"] forKey:@"gender"];
                    }
                    
                    if([[NSUserDefaults standardUserDefaults]objectForKey:@"ageVal"])
                    {
                        [userDic setObject:[[NSUserDefaults standardUserDefaults]objectForKey:@"ageVal"] forKey:@"age"];
                    }
                    
                    NSString *isLat=[self getIsLatValue];
                    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString]; //To get Ad Identifier of device
                    NSString *deviceType = [self getDeviceType];
                    
                    //               Creating Dictionaries to pass the values for post method.
                    NSDictionary *deviceDic = @{@"islat": isLat,@"idfa" : idfa,@"make" : @"Apple",@"os" : [UIDevice currentDevice].systemName,@"model" : deviceType,@"version" : [UIDevice currentDevice].systemVersion};
                    [self fillAnalyticsArray];
                    [self fillPreviousLocationArray];
                    
                    NSMutableDictionary *locationDic=[self getCurrentLocationDictionary];
                    NSDictionary *networkInfoDic = @{@"networkSubType": @"",@"networkType" : currentNetworkType,@"carrierName" : carrierOperatorName};
                    
                    NSDictionary *jsonSignUpDictionaryTemp = @{@"app_package":bundleIdentifier, @"appid":appIDValue, @"pubid":pubIDValue, @"device":deviceDic, @"timestamp":currentTimeValEventTimer,@"sdk_ver":version, @"networkInfo":networkInfoDic};
                    
                    NSMutableDictionary *jsonSignUpDictionary = [[NSMutableDictionary alloc]initWithDictionary:jsonSignUpDictionaryTemp];
                    
                    if([userDic count]>0)
                    {
                        [jsonSignUpDictionary setObject:userDic forKey:@"user"];
                        
                    }
                    if(locationDic!=nil && [CLLocationManager locationServicesEnabled])
                        [jsonSignUpDictionary setObject:locationDic forKey:@"location"];
                    
                    if([AllSpark sharedSingleton].analyticsArray!=nil && [AllSpark sharedSingleton].analyticsArray.count!=0)
                        [jsonSignUpDictionary setObject:[AllSpark sharedSingleton].analyticsArray forKey: @"analytics"];
                   
                    NSLog(@"prevLocationArray count is %lu",(unsigned long)[AllSpark sharedSingleton].prevLocationArray.count);
                    if([AllSpark sharedSingleton].prevLocationArray!=nil && [AllSpark sharedSingleton].prevLocationArray.count!=0)
                    {
                         NSLog(@"prevLocationArray added to jsonSignUpDictionary");
                        [jsonSignUpDictionary setObject:[AllSpark sharedSingleton].prevLocationArray forKey: @"prev_locations"];
                    }
                    
                    NSData *json = [NSJSONSerialization dataWithJSONObject:jsonSignUpDictionary options:0 error:nil];
                    NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSASCIIStringEncoding];
                    
                    [self makeNetworkCall:jsonString];
                    
                    NSLog(@"%@",jsonString);
                }
                @catch (NSException *exception) {
                    // NSLog(@"From HandleTimer- %@",exception.description);
                }
                
            }
            
        }
    }
    @catch (NSException *exception) {
        // NSLog(@"From HandleTimer- %@",exception.description);
    }
}

+(void)makeNetworkCall:(NSString *)jsonString
{
    @try {
        NSLog(@"Make Network Call");
        NSLog(@"Network Call Current thread is %@",[NSThread currentThread]);
        //get APIKey Value.
        NSString *savedAPIKeyValue = [[NSUserDefaults standardUserDefaults]
                                      stringForKey:@"APIKey"];
        //               Url to Post Values.
        //NSString *url = @"http://polar-wave-4368.herokuapp.com/";
        NSString *url = [NSString stringWithFormat:@"https://api.zprk.io/v1/push.json?key=%@",savedAPIKeyValue];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        
        NSData *myRequestData = [jsonString dataUsingEncoding:NSASCIIStringEncoding];
        
        [request setHTTPBody:myRequestData];
        
        /*
         get a few seconds window to finish network operation if app moves to background at this stage.
         
         */
        UIBackgroundTaskIdentifier bgTask;
        
        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            //   bgTask=UIBackgroundTaskInvalid;
        }];
        
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:
         ^(NSURLResponse *response, NSData *data, NSError *error)
         {
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
             int code = (int)[httpResponse statusCode];
             if(error)
             {
                 //   NSLog(@"%@",error.description);
             }
             if (code == 200)
             {
                 //NSLog(@"clearing values");
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"prevLocationArrayVal"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"eventArrayVal"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"screenNameArrayVal"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"screenNameArrayVal1"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"genderVal"];
                 [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ageVal"];
                 [[NSUserDefaults standardUserDefaults] synchronize];
                 [self clearArrays];
                 [AllSpark sharedSingleton].stateChanged=@"no"; //becomes no when data is sent successfully on server and there are no new changes left to send.
                 NSLog(@"State Changed From handle timer");
                 [AllSpark sharedSingleton].timerIndex=0;
                 //  NSLog(@"Data successfully sent");
                 NSLog(@"Network Call-completion Handler Current thread is %@",[NSThread currentThread]);
                 
             }else{
                 
                 [self clearArrays];
             }
             [AllSpark sharedSingleton].isFiredAPI=NO;
         }];
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        
    }
    @catch (NSException *exception) {
        
    }
    
}
+(void)clearArrays
{
    [AllSpark sharedSingleton].prevLocationArray = [[NSMutableArray alloc]init];
    [AllSpark sharedSingleton].analyticsArray = [[NSMutableArray alloc]init];
}

+ (NSString *) platformType:(NSString *)platform
{
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM)";
    if ([platform isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM)";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini (WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 (GSM)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad4,1"])      return @"iPad Air (WiFi)";
    if ([platform isEqualToString:@"iPad4,2"])      return @"iPad Air (Cellular)";
    if ([platform isEqualToString:@"iPad4,3"])      return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,4"])      return @"iPad Mini 2G (WiFi)";
    if ([platform isEqualToString:@"iPad4,5"])      return @"iPad Mini 2G (Cellular)";
    if ([platform isEqualToString:@"iPad4,6"])      return @"iPad Mini 2G";
    if ([platform isEqualToString:@"iPad4,7"])      return @"iPad Mini 3 (WiFi)";
    if ([platform isEqualToString:@"iPad4,8"])      return @"iPad Mini 3 (Cellular)";
    if ([platform isEqualToString:@"iPad4,9"])      return @"iPad Mini 3 (China)";
    if ([platform isEqualToString:@"iPad5,3"])      return @"iPad Air 2 (WiFi)";
    if ([platform isEqualToString:@"iPad5,4"])      return @"iPad Air 2 (Cellular)";
    if ([platform isEqualToString:@"AppleTV2,1"])   return @"Apple TV 2G";
    if ([platform isEqualToString:@"AppleTV3,1"])   return @"Apple TV 3";
    if ([platform isEqualToString:@"AppleTV3,2"])   return @"Apple TV 3 (2013)";
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    return platform;
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:[AllSpark class]];
}
@end
