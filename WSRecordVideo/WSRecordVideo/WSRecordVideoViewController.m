//
//  WSRecordVideoViewController.m
//  WSRecordVideo
//
//  Created by WangS on 16/9/28.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import "WSRecordVideoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#include <CommonCrypto/CommonDigest.h>
#import <AVFoundation/AVFoundation.h>
#import "WSPlayVideoViewController.h"
#import "UIView+Tools.h"

#define ScreenW [UIScreen mainScreen].bounds.size.width
#define ScreenH [UIScreen mainScreen].bounds.size.height
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define TIMER_INTERVAL 0.05
#define VIDEO_FOLDER @"videoFolder"
#define MINTIME 5.0

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface WSRecordVideoViewController ()<AVCaptureFileOutputRecordingDelegate>//视频文件输出代理
@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层

@property (strong,nonatomic) UIView *viewContainer;//视频容器
@property (strong,nonatomic) UIImageView *focusCursor; //聚焦光标
@property (strong,nonatomic) NSURL *outputFileURL;

@property (strong,nonatomic) UIImageView * videoRemindImg;//提示框
@property (strong,nonatomic) UILabel * videoRemindLab;//提示语
@end

@implementation WSRecordVideoViewController{
    float currentTime; //当前视频长度
    NSTimer *countTimer; //计时器
    UIView* progressPreView; //进度条
    float progressStep; //进度条每次变长的最小单位
    float preLayerWidth;//镜头宽
    float preLayerHeight;//镜头高
    float preLayerHWRate; //高，宽比
    UIButton *shootBt;//录制按钮
    UIButton *flashBt;//闪光灯
    UIButton *cameraBt;//切换摄像头
    float totalTime; //视频总长度 默认15秒
    BOOL isPauseBtnClick;//停止录制按钮被点击
}

- (UIImageView *) videoRemindImg{
    if (!_videoRemindImg) {
        _videoRemindImg = [[UIImageView alloc] initWithFrame:CGRectMake(ScreenW/3.0-40, 44+preLayerHeight-35, 80, 25)];
        _videoRemindImg.image = [UIImage imageNamed:@"videoRemindImg"];
        [self.view addSubview:self.videoRemindImg];
    }
    return _videoRemindImg;
}
- (UILabel *) videoRemindLab{
    if (!_videoRemindLab) {
        _videoRemindLab = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
        _videoRemindLab.text = @"至少录到这里";
        _videoRemindLab.textColor = [UIColor whiteColor];
        _videoRemindLab.font = [UIFont systemFontOfSize:12];
        _videoRemindLab.textAlignment = NSTextAlignmentCenter;
        [self.videoRemindImg addSubview:self.videoRemindLab];
    }
    return _videoRemindLab;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    //视频最大时长 默认15秒
    if (totalTime==0) {
        totalTime = 15;
    }
    
    preLayerWidth = ScreenW;
    preLayerHeight = ceilf(3/4.0 * ScreenW);
    preLayerHWRate =preLayerHeight/preLayerWidth;
    progressStep = ScreenW*TIMER_INTERVAL/totalTime;
    
    [self setUpNav];
    [self createVideoFolderIfNotExist];
    [self initCapture];
    
}
-(BOOL)prefersStatusBarHidden{
    return true;
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
    
    UILabel *nameLab=[[UILabel alloc] initWithFrame:CGRectMake(90, 7, ScreenW-180, 30)];
    nameLab.textAlignment=NSTextAlignmentCenter;
    nameLab.text=@"视频录制";
    nameLab.font=[UIFont systemFontOfSize:18];
    nameLab.textColor=[UIColor whiteColor];
    [navView addSubview:nameLab];
    
    flashBt = [[UIButton alloc]initWithFrame:CGRectMake(ScreenW-90, 0, 44, 44)];
    flashBt.hidden = YES;
    [flashBt addTarget:self action:@selector(flashBtTap:) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:flashBt];
    
    cameraBt = [[UIButton alloc]initWithFrame:CGRectMake(ScreenW-44, 0, 44, 44)];
    cameraBt.imageEdgeInsets = UIEdgeInsetsMake(3, 0, 0, 0);
    [cameraBt setImage:[UIImage imageNamed:@"changeCamer"] forState:UIControlStateNormal];
    [cameraBt addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:cameraBt];
    
}
-(void)backBtnClick{
    [self dismissViewControllerAnimated:YES completion:nil];
}
-(void)initCapture{
    
    //视频高度加进度条（10）高度
    self.viewContainer = [[UIView alloc]initWithFrame:CGRectMake(0, 44, preLayerWidth, preLayerHeight)];
    [self.view addSubview:self.viewContainer];
    
    self.focusCursor = [[UIImageView alloc]initWithFrame:CGRectMake(100, 100, 50, 50)];
    [self.focusCursor setImage:[UIImage imageNamed:@"focusImg"]];
    self.focusCursor.alpha = 0;
    [self.viewContainer addSubview:self.focusCursor];
    
    shootBt = [UIButton buttonWithType:UIButtonTypeCustom];
    shootBt.frame = CGRectMake(0, 0, 152, 152);
    shootBt.center = CGPointMake(ScreenW/2, 44+preLayerHeight+47+76);
    [shootBt makeCornerRadius:76 borderColor:UIColorFromRGB(0x17ae98) borderWidth:1];
    [shootBt setTitle:@"按住录" forState:UIControlStateNormal];
    [shootBt setTitleColor:UIColorFromRGB(0x17ae98) forState:UIControlStateNormal];
    [shootBt addTarget:self action:@selector(stopShootButtonClick) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [shootBt addTarget:self action:@selector(shootButtonClick) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:shootBt];
    
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset640x480;
    }
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];//取得前置摄像头
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer= self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=  CGRectMake(0, 0, preLayerWidth, preLayerHeight);
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
    
    [self addGenstureRecognizer];
    
    //进度条
    //    progressPreView = [[UIView alloc]initWithFrame:CGRectMake(0, preLayerHeight, 0, 4)];
    //    progressPreView.backgroundColor = UIColorFromRGB(0x17ae98);
    //    [progressPreView makeCornerRadius:2 borderColor:nil borderWidth:0];
    //    [self.viewContainer addSubview:progressPreView];
    
    UIView * progressBackView = [[UIView alloc] initWithFrame:CGRectMake(0, 44+preLayerHeight,ScreenW, 4)];
    progressBackView.backgroundColor = UIColorFromRGB(0x1d1e20);
    //    [self.viewContainer addSubview:progressBackView];
    [self.view addSubview:progressBackView];
    
    
    progressPreView = [[UIView alloc]initWithFrame:CGRectMake(0, 44+preLayerHeight, 0, 4)];
    progressPreView.backgroundColor = UIColorFromRGB(0x17ae98);
    [progressPreView makeCornerRadius:2 borderColor:nil borderWidth:0];
    //    [self.viewContainer addSubview:progressPreView];
    [self.view addSubview:progressPreView];
    
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(ScreenW/3.0, 0, 1, 4)];
    imgView.backgroundColor = UIColorFromRGB(0x17ae98);
    [progressBackView addSubview:imgView];
    
}

-(void)flashBtTap:(UIButton*)bt{
    if (bt.selected == YES) {
        bt.selected = NO;
        
        [flashBt setImage:[UIImage imageNamed:@"flashOn"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOff];
    }else{
        bt.selected = YES;
        
        [flashBt setImage:[UIImage imageNamed:@"flashOff"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOn];
    }
}

-(void)startTimer{
    
    countTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
    // [[NSRunLoop currentRunLoop] addTimer:countTimer forMode:NSRunLoopCommonModes];
    [countTimer fire];
}

-(void)stopTimer{
    [countTimer invalidate];
    countTimer = nil;
    
}
- (void)onTimer:(NSTimer *)timer{
    currentTime += TIMER_INTERVAL;
    float progressWidth = progressPreView.frame.size.width+progressStep;
    [progressPreView setFrame:CGRectMake(0, 44+preLayerHeight, progressWidth, 4)];
    
    //时间到了停止录制视频
    if (currentTime>=totalTime) {
        [countTimer invalidate];
        countTimer = nil;
        [_captureMovieFileOutput stopRecording];
    }
}


-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
    
    //还原数据-----------
    [self deleteAllVideos];
    currentTime = 0;
    [progressPreView setFrame:CGRectMake(0, 44+preLayerHeight, 0, 4)];
    
}

#pragma mark 视频录制
- (void)shootButtonClick{
    isPauseBtnClick = NO;
    self.videoRemindImg.hidden = YES;
    self.videoRemindLab.hidden = YES;
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        //还原数据-----------
        [self deleteAllVideos];
        currentTime = 0;
        [progressPreView setFrame:CGRectMake(0, 44+preLayerHeight, 0, 4)];
        //shootBt.backgroundColor = UIColorFromRGB(0xfa5f66);
        //预览图层和视频方向保持一致
        captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
        
        [self.captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoSaveFilePathString]] recordingDelegate:self];
    }
    else{
        [self stopTimer];
        [self.captureMovieFileOutput stopRecording];//停止录制
    }
}
- (void)stopShootButtonClick{
    isPauseBtnClick = YES;
    [self stopTimer];
    [_captureMovieFileOutput stopRecording];//停止录制
}
#pragma mark 切换前后摄像头
- (void)changeCamera:(UIButton*)bt {
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
        flashBt.hidden = NO;
    }else{
        flashBt.hidden = YES;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    //关闭闪光灯
    flashBt.selected = NO;
    [flashBt setImage:[UIImage imageNamed:@"flashOn"] forState:UIControlStateNormal];
    [self setTorchMode:AVCaptureTorchModeOff];
    
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
    if (!isPauseBtnClick) {
        [self startTimer];
    }else{
        [self stopTimer];
    }
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    
    self.outputFileURL = outputFileURL;
    NSLog(@"outputFileURL -------  %@",outputFileURL);
    //时间到了
    //    if (currentTime>=totalTime) {
    //        [self enableBtn];
    //    }
    if (error) {
        //[HUDManager showWarningWithText:@"请长按5秒录制视频"];
        self.videoRemindImg.hidden = NO;
        self.videoRemindLab.hidden = NO;
        [self animationRemind];
    }else{
        if (currentTime<MINTIME) {
            //[HUDManager showWarningWithText:@"请长按5秒录制视频"];
            self.videoRemindImg.hidden = NO;
            self.videoRemindLab.hidden = NO;
            [self animationRemind];
        }else{
            currentTime = totalTime +15;
            [self save];
        }
    }
}
- (void)animationRemind{
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.8]; //动画时长
    [UIView setAnimationDelegate:self]; //设置代理
    [UIView setAnimationDidStopSelector:@selector(animationDidStop)]; //动画已经结束
    //[UIView setAnimationRepeatAutoreverses:YES]; //自动反向执行动画
    [UIView setAnimationRepeatCount:3]; //重复次数
    //动画执行代码
    self.videoRemindImg.frame = CGRectMake(ScreenW/3.0-40, 44+preLayerHeight-30, 80, 25);
    [UIView commitAnimations];
}
//动画已经结束
-(void)animationDidStop{
    self.videoRemindImg.frame = CGRectMake(ScreenW/3.0-40, 44+preLayerHeight-35, 80, 25);
}
//保存到相册，需修改
- (void)save{
    
    NSError *error = nil;
    
    CGSize renderSize = CGSizeMake(0, 0);
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    CMTime totalDuration = kCMTimeZero;
    
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    
    AVAsset *asset = [AVAsset assetWithURL:self.outputFileURL];
    [assetArray addObject:asset];
    NSArray* tmpAry =[asset tracksWithMediaType:AVMediaTypeVideo];
    if (tmpAry.count>0) {
        AVAssetTrack *assetTrack = [tmpAry objectAtIndex:0];
        [assetTrackArray addObject:assetTrack];
        renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
        renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        NSArray*dataSourceArray= [asset tracksWithMediaType:AVMediaTypeAudio];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:([dataSourceArray count]>0)?[dataSourceArray objectAtIndex:0]:nil
                             atTime:totalDuration
                              error:nil];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0+preLayerHWRate*(preLayerHeight-preLayerWidth)/2));
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        
        [layerInstructionArray addObject:layerInstruciton];
    }
    
    NSString *path = [self getVideoSaveFilePathString];
    NSURL *mergeFileURL = [NSURL fileURLWithPath:path];
    
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 100);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW*preLayerHWRate);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            WSPlayVideoViewController *playVideo = [[WSPlayVideoViewController alloc] init];
            playVideo.videoURL =mergeFileURL;
            [self.navigationController pushViewController:playVideo animated:YES];
        });
    }];
    
}
//录制保存的时候要保存为 mov
- (NSString *)getVideoSaveFilePathString{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    
    return fileName;
}
- (void)createVideoFolderIfNotExist{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    NSString *folderPath = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir)){
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建保存视频文件夹失败");
        }
    }
}
- (void)deleteAllVideos{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = [[self.outputFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath]) {
            NSError *error = nil;
            [fileManager removeItemAtPath:filePath error:&error];
            
            if (error) {
                NSLog(@"delete All Video 删除视频文件出错:%@", error);
            }
        }
    });
}

#pragma mark - 私有方法
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

-(void)setTorchMode:(AVCaptureTorchMode )torchMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isTorchModeSupported:torchMode]) {
            [captureDevice setTorchMode:torchMode];
        }
    }];
}

-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}
- (CGFloat)getfileSize:(NSString *)path{
    NSDictionary *outputFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSLog (@"file size: %f", (unsigned long long)[outputFileAttributes fileSize]/1024.00 /1024.00);
    return (CGFloat)[outputFileAttributes fileSize]/1024.00 /1024.00;
}



@end
