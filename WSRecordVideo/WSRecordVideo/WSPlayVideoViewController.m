//
//  WSPlayVideoViewController.m
//  WSRecordVideo
//
//  Created by WangS on 16/9/28.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import "WSPlayVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIView+Tools.h"

#define ScreenW [UIScreen mainScreen].bounds.size.width
#define ScreenH [UIScreen mainScreen].bounds.size.height

@interface WSPlayVideoViewController ()
@property (nonatomic,strong) UIButton *uploadBtn;
@property (nonatomic,strong) NSData *data;
@end

@implementation WSPlayVideoViewController{
    AVPlayer *player;
    AVPlayerLayer *playerLayer;
    AVPlayerItem *playerItem;
    UIImageView* playImg;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}
-(BOOL)prefersStatusBarHidden{
    return true;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setUpNav];
    
    float videoWidth = ScreenW;
    float videoHeight = ceilf(3/4.0 * ScreenW);
    
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:self.videoURL options:nil];
    playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    player = [AVPlayer playerWithPlayerItem:playerItem];
    
    playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.frame = CGRectMake(0, 44, videoWidth, videoHeight);
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerLayer];
    
    UITapGestureRecognizer *playTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playOrPause)];
    [self.view addGestureRecognizer:playTap];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    playImg = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, 80, 80)];
    playImg.center = CGPointMake(videoWidth/2, 64+80);
    [playImg setImage:[UIImage imageNamed:@"videoPlay"]];
    [playerLayer addSublayer:playImg.layer];
}

- (void)setUpNav{
    UIView *navView=[[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenW, 44)];
    navView.backgroundColor=[UIColor blackColor];
    [self.view addSubview:navView];
    
    UIButton *backBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame=CGRectMake(0, 0, 60, 44);
    backBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 20);
    [backBtn setImage:[UIImage imageNamed:@"closeWindow"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:backBtn];
    
    UILabel *nameLab=[[UILabel alloc] initWithFrame:CGRectMake(60, 7, ScreenW-120, 30)];
    nameLab.textAlignment=NSTextAlignmentCenter;
    nameLab.text=@"视频预览";
    nameLab.font=[UIFont systemFontOfSize:18];
    nameLab.textColor=[UIColor whiteColor];
    [navView addSubview:nameLab];
    
//    UIButton *uploadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    uploadBtn.frame = CGRectMake(0, 0, 306, 56);
//    uploadBtn.center =CGPointMake(ScreenW/2.0, 44+ceilf(3/4.0 * ScreenW)+36+56);
//    [uploadBtn setTitle:@"上传" forState:UIControlStateNormal];
//    uploadBtn.titleLabel.font = [UIFont systemFontOfSize:17];
//    [uploadBtn setTitleColor:UIColorFromRGB(0x17ae98) forState:UIControlStateNormal];
//    [uploadBtn makeCornerRadius:5 borderColor:UIColorFromRGB(0x17ae98) borderWidth:1];
//    [uploadBtn addTarget:self action:@selector(uploadBtnClick) forControlEvents:UIControlEventTouchUpInside];
//    self.uploadBtn = uploadBtn;
//    [self.view addSubview:uploadBtn];
    
    UIButton *retryBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    retryBtn.frame = CGRectMake(0, 0, 306, 56);
    retryBtn.center =CGPointMake(ScreenW/2.0, 44+ceilf(3/4.0 * ScreenW)+36+56);
    [retryBtn setTitle:@"重拍" forState:UIControlStateNormal];
    retryBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    [retryBtn setTitleColor:UIColorFromRGB(0x17ae98) forState:UIControlStateNormal];
    [retryBtn makeCornerRadius:5 borderColor:UIColorFromRGB(0x17ae98) borderWidth:1];
    [retryBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:retryBtn];
    
}
-(void)backBtnClick{
    [self.navigationController popViewControllerAnimated:YES];
}
-(void)uploadBtnClick{
   
}
-(void)playOrPause{
    if (playImg.isHidden) {
        playImg.hidden = NO;
        [player pause];
        
    }else{
        playImg.hidden = YES;
        [player play];
    }
}

- (void)pressPlayButton{
    [playerItem seekToTime:kCMTimeZero];
    [player play];
}

- (void)playingEnd:(NSNotification *)notification{
    if (playImg.isHidden) {
        [self pressPlayButton];
    }
}
//保存到相册
- (void)saveRecordedFile:(NSURL *)recordedFile {
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:
         ^(NSURL *assetURL, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 
                 NSString *title;
                 NSString *message;
                 
                 if (error != nil) {
                     title = @"保存相册失败";
                     message = [error localizedDescription];
                 }
                 else {
                     title = @"保存相册成功";
                     message = nil;
                 }
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             });
         }];
    });
}
//获取视频任意帧
- (UIImage *) thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGenerator =[[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60)actualTime:NULL error:&thumbnailImageGenerationError];
    
    if(!thumbnailImageRef)
        NSLog(@"thumbnailImageGenerationError %@",thumbnailImageGenerationError);
    
    UIImage*thumbnailImage = thumbnailImageRef ? [[UIImage alloc]initWithCGImage: thumbnailImageRef] : nil;
    
    return thumbnailImage;
}
// 获取视频的第一帧
- (UIImage *)getVideoFirstPic:(NSURL *)url{
    //    // 获取资源类
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    
    // 视频中截图类
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    generator.appliesPreferredTrackTransform = YES;
    
    //设置时间为0秒
    CMTime time = CMTimeMakeWithSeconds(0, 10);
    
    // 取出视频在0秒时候的图片
    CGImageRef image = [generator copyCGImageAtTime:time actualTime:nil error:nil];
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    return thumb;
    
}
#pragma mark - 保存图片至沙盒
- (void) saveImage:(UIImage *)currentImage withName:(NSString *)imageName{
    
    NSData *imageData = UIImageJPEGRepresentation(currentImage, 0.01);
    
    // 获取沙盒目录
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:imageName];
    // 将图片写入文件
    [imageData writeToFile:fullPath atomically:NO];
    NSData *data = [NSData dataWithContentsOfFile:fullPath];
    
    self.data = data;
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [player pause]; //暂停
    player = nil; //置空
}



@end
