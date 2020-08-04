//
//  YJFFMpegDecode.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "YJFFMpegDecode.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreMedia/CoreMedia.h>

static AVBufferRef *hw_device_ctx = NULL;

@implementation YJFFMpegDecode
{
    AVFormatContext *pFormatContext;
    int pVideoIndex;
    AVCodecContext *pCodecContext;
    AVFrame *pFrame;
    int64_t pBaseTime;
    BOOL isFirstI;
}

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoIndex:(int)videoIndex {
    if (self = [super init]) {
        pVideoIndex = videoIndex;
        pFormatContext = formatContext;
        pBaseTime = 0;
        AVCodecParameters *parameters = pFormatContext->streams[pVideoIndex]->codecpar;
        // 指定成像的数据格式类型，目前的mp4文件解码出来默认是yuv420p 的格式，那图像数据yuv就是在avpacket 的data012上,解析成videotoolbox数据在第3个元素
        AVCodec *codec = NULL;
        const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
        enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
        int ret = av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
        pCodecContext = avcodec_alloc_context3(NULL);
        ret = avcodec_parameters_to_context(pCodecContext, parameters);
        if (ret < 0) {
            NSLog(@"解码器配置失败");
        }
    
        // 硬件设备支持的赋值,sws_getcontext 这个类似,但sws——getcontext是成像
        ret = av_hwdevice_ctx_create(&hw_device_ctx, type, NULL, NULL, 0);
        if (ret < 0) {
            NSLog(@"创建硬件解码失败");
        }
        pCodecContext->hw_device_ctx = av_buffer_ref(hw_device_ctx);
        
        AVCodec *codeC = avcodec_find_decoder(parameters->codec_id);
        if (codeC == NULL) {
            NSLog(@"没有对应的解码器");
        }
        if (avcodec_open2(pCodecContext, codeC, NULL) < 0 ) {
            NSLog(@"创建解码器上下文失败");
        }
        pFrame = av_frame_alloc();
        if (!pFrame) {
            avcodec_close(pCodecContext);
        }
    }
    return self;
}

- (void)startDecodeVideoDataWithPkt:(AVPacket)pkt {
    if (pkt.flags == 1 && isFirstI == false) {
        isFirstI = YES;
        pBaseTime = pFrame->pts;
    }
    if (isFirstI == YES) {
        CMClockRef hostClockRef = CMClockGetHostTimeClock();
        CMTime hostTime = CMClockGetTime(hostClockRef);
        Float64 current_timestamp =  CMTimeGetSeconds(hostTime);
        
        AVStream *videoStream = pFormatContext->streams[pVideoIndex];
        // send_packet 和receive_frame 是一套组合，在ffmpeg3.0以下的版本时可以用avcodec_decode_video2
        
        avcodec_send_packet(pCodecContext, &pkt);
        while (0 == avcodec_receive_frame(pCodecContext, pFrame)) {
            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pFrame->data[3];
            // 解码出来的pixelbuffer 在时间上会存在差异，但使用opengl 渲染可以直接送入，不用加时间
            CMTime presentationTimeStamp = kCMTimeInvalid;
            int64_t originPTS = pFrame->pts;
            int64_t newPTS    = originPTS - pBaseTime;
            presentationTimeStamp = CMTimeMakeWithSeconds(current_timestamp + newPTS * av_q2d(videoStream->time_base) , 30);
            CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:(CVPixelBufferRef)pixelBuffer
                                                                       withPresentationTimeStamp:presentationTimeStamp];
            if (sampleBufferRef) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(getVideoBufferByFFMpeg:)]) {
                    [self.delegate getVideoBufferByFFMpeg:sampleBufferRef];
                }
                CFRelease(sampleBufferRef);
            }
        }
    }
}

- (CMSampleBufferRef)convertCVImageBufferRefToCMSampleBufferRef:(CVImageBufferRef)pixelBuffer withPresentationTimeStamp:(CMTime)presentationTimeStamp {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus res = 0;
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = presentationTimeStamp;
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    res = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (res != 0) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
    }
    
    res = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo, &newSampleBuffer);
    
    CFRelease(videoInfo);
    if (res != 0) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
        
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return newSampleBuffer;
}


@end
