//
//  ViewController1.m
//  AllsparkSampleApp
//
//  Created by Apple on 09/12/15.
//  Copyright © 2015 Allspark. All rights reserved.
//

#import "ViewController1.h"
#import <AllsparkSDK/AllSpark.h>

@interface ViewController1 ()

@end

@implementation ViewController1

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Sets the Custom Data
    [AllSpark setCustomData:@"Country" withValue:@"India"];
    // Sets the age of the user
    [AllSpark setAge:43];
   // Sets the gender of the user
    [AllSpark setGender:YES]; // YES for male, NO for female
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

-(IBAction)btnNextPageClicked:(id)sender
{
    //Sends event name and value to Allspark

    [AllSpark sendEvent:@"btnNextPageClicked" withValue:@"VC2 will appear"];

    UIStoryboard *sb=[UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ViewController2 *vc2=[sb instantiateViewControllerWithIdentifier:@"VC2"];
    [self presentViewController:vc2 animated:YES completion:nil];
}
@end
