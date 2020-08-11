//
//  EncodeViewController.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/11.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "EncodeViewController.h"
#import "HardEncode.h"
#import <AVFoundation/AVFoundation.h>

@interface EncodeViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
/** 预览图层*/
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preViewLayer;
/** 编码工具*/
@property (nonatomic, strong) HardEncode *encode;

@end

@implementation EncodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    UIView *preView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame) - 100)];
    [self.view addSubview:preView];
    
    [self initCaptureSessionWithView:preView];
    [self initEncode];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.backgroundColor = [UIColor redColor];
    [btn setTitle:@"采集" forState:UIControlStateNormal];
    btn.frame = CGRectMake(0, CGRectGetHeight(self.view.frame) - 120, 80, 30);
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(capture:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.preViewLayer) {
        [self.preViewLayer removeFromSuperlayer];
        self.preViewLayer = nil;
    }
    [self.captureSession startRunning];
    self.captureSession = nil;
}


#pragma mark private method

- (void)initCaptureSessionWithView:(UIView *)preView {
    
    // 管理session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    self.captureSession = session;
    
    // 设备初始化
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    // 输入设备添加
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (!error) {
        [session addInput:input];
    }

    // 输出数据配置
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:videoDataOutput];
    videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    dispatch_queue_t videoQueue = dispatch_queue_create("VideoQueue", NULL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoQueue];
    // 设置采集的方向
    AVCaptureConnection *connection = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    // session对应的渲染图层
    AVCaptureVideoPreviewLayer *preViewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    preViewLayer.frame = preView.frame;
    [preView.layer insertSublayer:preViewLayer atIndex:0];
    self.preViewLayer = preViewLayer;
}

- (void)initEncode {
    VideoEncodeConfig *config = [[VideoEncodeConfig alloc] init];
    config.size = CGSizeMake(1920, 1080);
    config.frameRate = 30;
    config.bitRate = 2048;
    config.gopRate = 30;
    self.encode = [[HardEncode alloc] initWithConfig:config];
}

- (void)capture:(UIButton *)senderBtn {
    if (self.captureSession.isRunning) {
        [self.captureSession stopRunning];
    } else {
        [self.captureSession startRunning];
    }
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"%s", __func__);
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self.encode startEncodeWithCMSampleBufferRef:sampleBuffer];
}


@end
