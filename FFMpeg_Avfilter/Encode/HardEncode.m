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
    /** 视频编码配置参数*/
    VideoEncodeConfig *pvideoConfig;
    /** 本地文件*/
    FILE *fp;
    /** 是否需要设置sps等头信息*/
    BOOL needSetVideoParam;
}



@end


@implementation HardEncode

#pragma mark Public Method

- (instancetype)initWithConfig:(VideoEncodeConfig *)config {
    if (self = [super init]) {
        pvideoConfig = config;
        [self initForFilePath];
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
    pFrameIndex++;
    CMTime presentationTimeStamp = CMTimeMake(pFrameIndex,(int32_t)pvideoConfig.videoFrameRate);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)pvideoConfig.videoFrameRate);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(samplerBuffer);
    NSDictionary *properties = nil;
    // 将指定帧作为i帧
    if (pFrameIndex % (int32_t)pvideoConfig.videoMaxKeyframeInterval == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    // 编码操作
    OSStatus status = VTCompressionSessionEncodeFrame(pCompressionSession, imageBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, NULL, &flags);
    if(status != noErr){
        
    }
}

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
    HardEncode *encode = (__bridge HardEncode *)outputCallbackRefCon;
    if (keyframe) {
        static size_t  keyParameterSetBufferSize = 0;
        if (keyParameterSetBufferSize == 0 && encode->needSetVideoParam == YES) {
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
                    // 写入文件
                    fwrite(data.bytes, 1, data.length, encode->fp);
                    NSLog(@"首次写入，配置SPS/PPS 信息");
                    
                    encode->needSetVideoParam = NO;
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            NSMutableData *tempData = [[NSMutableData alloc] init];
            uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
            [tempData appendBytes:header length:4];
            [tempData appendData:data];
            
            fwrite(tempData.bytes, 1, tempData.length, encode->fp);
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
# pragma mark private Method


- (void)createSessionWithConfig:(VideoEncodeConfig *)config {
    needSetVideoParam = YES;
    // 创建session，指定回调方法
    VTCompressionSessionCreate(NULL, config.size.width, config.size.height, kCMVideoCodecType_H264, NULL, NULL, NULL, outputCallback, (__bridge void *)self, &pCompressionSession);
    // 配置session 属性
    // 是否实时
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    // gop数值
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(config.videoMaxKeyframeInterval));
    // 期望帧率
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(config.videoFrameRate));
    // 关键帧采样间隔时间
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,( __bridge CFTypeRef)@(config.videoMaxKeyframeInterval / config.videoFrameRate));
    // 比特率
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_AverageBitRate, ( __bridge CFTypeRef)@(config.videoBitRate));
    NSArray *limit = @[@(config.videoBitRate * 1.5/8), @(1)];
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    // 编码登记
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
    // 编码类型
    VTSessionSetProperty(pCompressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    VTCompressionSessionPrepareToEncodeFrames(pCompressionSession);
    
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo.h264"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb+");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}






@end


@implementation VideoEncodeConfig

@end
