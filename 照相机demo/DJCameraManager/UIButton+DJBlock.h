//
//  UIButton+DJBlock.h
//  TableViewCDemo
//
//  Created by Jason on 6/1/16.
//  Copyright © 2016年 Jason. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIButton (DJBlock)
- (void)addActionBlock:(void(^)(id sender))block forControlEvents:(UIControlEvents )event;
@end
