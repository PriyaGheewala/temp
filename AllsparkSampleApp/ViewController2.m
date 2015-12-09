//
//  ViewController2.m
//  AllsparkSampleApp
//
//  Created by Apple on 09/12/15.
//  Copyright © 2015 Allspark. All rights reserved.
//

#import "ViewController2.h"
#import <AllsparkSDK/AllSpark.h>

@interface ViewController2 ()

@end

@implementation ViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:YES];
    
    // Starts api calls to send data to Allspark
    //Compulsory call to start SDK API calls
    [AllSpark startSDK:self];
}

-(void) viewDidDisappear:(BOOL)animated
{
    // Stops api calls to send data to Allspark
    [AllSpark stopSDK:self];
    [super viewDidDisappear:YES];
}

#pragma mark- IBAction methods
-(IBAction)btnBackClicked:(id)sender
{
    //Sends event name and value to Allspark
    [AllSpark sendEvent:@"BackClicked" withValue:@"Moving back to VC1 "];
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
