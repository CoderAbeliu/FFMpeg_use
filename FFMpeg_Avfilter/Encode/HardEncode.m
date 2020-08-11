//
//  HardEncode.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/10.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "HardEncode.h"
#import <VideoToolbox/VideoToolbox.h>


@interface HardEncode(){
    /** 压缩session */
    VTCompressionSessionRef pCompressionSession;
    /** 编码的帧数*/
    NSInteger pFrameIndex;
    VideoEncodeConfig *pvideoConfig;
}
@end

static void outputCallback(
                                    void * CM_NULLABLE outputCallbackRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                                    CM_NULLABLE CMSampleBufferRef sampleBuffer ) {
    
}

@implementation HardEncode

#pragma mark Public Method

- (instancetype)initWithConfig:(VideoEncodeConfig *)config {
    if (self = [super init]) {
        pvideoConfig = config;
        [self createSessionWithConfig:config];
    }
    return self;
}

- (void)stopEncode{
    if(pCompressionSession){
        VTCompressionSessionCompleteFrames(pCompressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(pCompressionSession);
        CFRelease(pCompressionSession);
        pCompressionSession = NULL;
    }
}

- (void)startEncodeWithCMSampleBufferRef:(CMSampleBufferRef)samplerBuffer {
    if (pCompressionSession == NULL) {
        return;
    }
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(samplerBuffer);
    pFrameIndex++;
    CMTime presentationTimeStamp = CMTimeMake(pFrameIndex, 1000);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)pvideoConfig.frameRate);
    OSStatus status = VTCompressionSessionEncodeFrame(pCompressionSession, imageBuffer, presentationTimeStamp, duration, NULL, (__bridge void *)self, &flags);
    if (status == noErr) {
        NSLog(@"编码数据%zdsuccess", pFrameIndex);
    }
}

# pragma mark private Method


- (void)createSessionWithConfig:(VideoEncodeConfig *)config {
    // 创建session，指定回调方法
    VTCompressionSessionCreate(NULL, config.size.width, config.size.height, kCMVideoCodecType_H264, NULL, NULL, NULL, outputCallback, (__bridge void *)self, &pCompressionSession);
    // 配置session 属性
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(config.frameRate));
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,( __bridge CFTypeRef)@(config.gopRate));
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_AverageBitRate, ( __bridge CFTypeRef)@(config.bitRate));
    NSArray *limit = @[@(config.bitRate * 1.5/8), @(1)];
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    // 是否编码B 帧
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    VTCompressionSessionPrepareToEncodeFrames(pCompressionSession);
}







@end


@implementation VideoEncodeConfig

@end
