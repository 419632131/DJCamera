//
//  ViewController.m
//  照相机demo
//
//  Created by Jason on 12/1/16.
//  Copyright © 2016年 Jason. All rights reserved.
//

#import "ViewController.h"
#import "DJCameraViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
- (IBAction)show:(id)sender {
    DJCameraViewController *VC = [DJCameraViewController new];
    
    [self presentViewController:VC animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
