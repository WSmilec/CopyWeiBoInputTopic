//
//  WSPlayVideoViewController.h
//  WSRecordVideo
//
//  Created by WangS on 16/9/28.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import <UIKit/UIKit.h>
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
@interface WSPlayVideoViewController : UIViewController

@property (nonatomic,strong) NSURL *videoURL;

@end
