//
//  ViewController.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "DecodeViewController.h"
#import "YJFileParseHandler.h"
#import "YJFFMpegDecode.h"
#import "XDXPreviewView.h"
#import "YJGLView.h"

@interface DecodeViewController ()<YJFFMpegDelegate>
/** 读取工具类*/
@property (nonatomic, strong) YJFileParseHandler *fileHandle;

/** 解码工具*/
@property (nonatomic, strong) YJFFMpegDecode *decode;

/** 显示render*/
@property (nonatomic, strong) XDXPreviewView *preView;
@end

@implementation DecodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"normal1" ofType:@"mp4"];
    self.fileHandle = [[YJFileParseHandler alloc] initWithFilePath:videoPath];
    self.decode = [[YJFFMpegDecode alloc] initWithFormatContext:[self.fileHandle formatContext] videoIndex:[self.fileHandle videoIndex]];
    self.decode.delegate = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.fileHandle startGetAVPacketBlock:^(AVPacket packet) {
            // 读取速度很快，会出现快播,但在实际的数据流传输中，读取是可控的
            usleep(30 * 1000);
            [self.decode startDecodeVideoDataWithPkt:packet];
        }];
    });
    self.preView = [[XDXPreviewView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame))];
    [self.view addSubview:self.preView];
    self.preView.center = self.view.center;
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 100, 100, 100);
    btn.backgroundColor = [UIColor redColor];
    [btn addTarget:self action:@selector(stopParse:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    YJGLView *glView = [[YJGLView alloc] initWithFrame:self.view.frame];
    
}

- (void)stopParse:(UIButton *)sender {
    if (self.fileHandle.parseStatus) {
        NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"normal1" ofType:@"mp4"];
        self.fileHandle = [[YJFileParseHandler alloc] initWithFilePath:videoPath];
        [self.fileHandle startGetAVPacketBlock:^(AVPacket packet) {
            // 读取速度很快，会出现快播,但在实际的数据流传输中，读取是可控的
            usleep(30 * 1000);
            [self.decode startDecodeVideoDataWithPkt:packet];
        }];
    } else {
        self.fileHandle.parseStatus = YES;
    }
        
    
}

#pragma mark YJFFMpegDelegate

- (void)getVideoBufferByFFMpeg:(CMSampleBufferRef)samplerBuffer {
    CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(samplerBuffer);
    [self.preView displayPixelBuffer:pix];
}


@end
