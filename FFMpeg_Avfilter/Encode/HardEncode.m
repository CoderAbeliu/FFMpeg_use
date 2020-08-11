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
    if (status != noErr) {
        NSLog(@"编码出错");
        return;
    }
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;
    
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)sourceFrameRefCon) longLongValue];
    HardEncode *encode = (__bridge HardEncode *)outputCallbackRefCon;
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                NSMutableData *data = [[NSMutableData alloc] init];
                uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                [data appendBytes:header length:4];
                [data appendData:sps];
                [data appendBytes:header length:4];
                [data appendData:pps];
                // TODO:写入文件

            }
        }
        
    }
    
    
    
    
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
