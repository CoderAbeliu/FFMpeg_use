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
#import <libavfilter/avfilter.h>
#import <libavfilter/buffersrc.h>
#import <libavfilter/buffersink.h>


#define KVIDEOTOOLBOX 1

static AVBufferRef *hw_device_ctx = NULL;
AVFilterContext *buffersink_ctx;
AVFilterContext *buffersrc_ctx;
AVFilterGraph *filter_graph;

@implementation YJFFMpegDecode
{
    AVFormatContext *pFormatContext;
    int pVideoIndex;
    AVCodecContext *pCodecContext;
    AVFrame *pFrame;
    int64_t pBaseTime;
    BOOL isFirstI;
    FILE *fp_yuv;
}

- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoIndex:(int)videoIndex {
    if (self = [super init]) {
        pVideoIndex = videoIndex;
        pFormatContext = formatContext;
        pBaseTime = 0;
        [self initCodecContextWithContext:formatContext];
        if (!KVIDEOTOOLBOX) {
            [self initFilters];
        }
    }
    return self;
}

+ (void)initialize {
    [super initialize];
    avfilter_register_all();
}

- (void)initCodecContextWithContext:(AVFormatContext *)formatContext {
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
    if (KVIDEOTOOLBOX) {
        pCodecContext->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    }
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

- (BOOL)initFilters {
    char args[512];
    int ret;
    // 1.初始化滤波器结构体
    filter_graph = avfilter_graph_alloc();
    
    // 2.获取两个特殊的滤波器，输入和输出(buffer/buffersink)
    AVFilter *buffersrc = avfilter_get_by_name("buffer");
    AVFilter *buffersink = avfilter_get_by_name("buffersink");
    // 3.为滤波器添加像素等配置
    snprintf(args, sizeof(args),
               "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
               pCodecContext->width, pCodecContext->height, AV_PIX_FMT_YUV420P,
               1, 1,
             16, 9);
    // 4.创建输入滤波器
    ret = avfilter_graph_create_filter(&buffersrc_ctx, buffersrc, "in", args, NULL, filter_graph);
    
    if (ret < 0) {
        NSLog(@"创建滤镜输入失败");
        return NO;
    }

    // 5.创建输出滤波器的配置结构体
    AVBufferSinkParams *buffersink_params;
    enum AVPixelFormat pix_fmts[] = { AV_PIX_FMT_YUV420P, AV_PIX_FMT_NONE };
    buffersink_params = av_buffersink_params_alloc();
    buffersink_params->pixel_fmts = pix_fmts;
    ret = avfilter_graph_create_filter(&buffersink_ctx, buffersink, "out", NULL, buffersink_params, filter_graph);
    av_free(buffersink_params);
    if (ret < 0) {
        NSLog(@"创建buffersink失败");
        return false;
    }
    
    // 6.创建输入输出的列表(包含名称及下一个输入或者输出)
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs = avfilter_inout_alloc();
    outputs->name       = av_strdup("in");
    outputs->filter_ctx = buffersrc_ctx;
    outputs->pad_idx    = 0;
    outputs->next       = NULL;

    inputs->name       = av_strdup("out");
    inputs->filter_ctx = buffersink_ctx;
    inputs->pad_idx    = 0;
    inputs->next = NULL;
    
    // 7.解析字符串，构建滤波器
    const char *filter_descr = "lutyuv='u=128:v=128'";
    ret = avfilter_graph_parse(filter_graph, filter_descr, inputs, outputs, NULL);
    if (ret < 0) {
        NSLog(@"水印加载失败");
        return NO;
    }
    // 8.上传滤波器
    ret = avfilter_graph_config(filter_graph, NULL);
    if (ret < 0) {
        NSLog(@"水印连接存在错误显示");
        return NO;
    }
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    docPath = [docPath stringByAppendingPathComponent:@"test.yuv"];
    fp_yuv = fopen(docPath.UTF8String, "wb+");
    
    return YES;
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

            if (KVIDEOTOOLBOX) {
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
            } else {
                AVFrame *outFrame = av_frame_alloc();
                pFrame->pts = av_frame_get_best_effort_timestamp(pFrame);
                if (av_buffersrc_add_frame(buffersrc_ctx, pFrame) < 0) {
                    printf( "Error while feeding the filtergraph\n");
                    break;
                }
                int ret = av_buffersink_get_frame(buffersink_ctx, outFrame);
                if (ret < 0) {
                    NSLog(@"从滤镜获取avframe 数据失败");
                    break;
                }
                if (outFrame->format==AV_PIX_FMT_YUV420P) {
                    for (int i=0;i<outFrame->height;i++) {
                        fwrite(outFrame->data[0]+outFrame->linesize[0]*i,1,outFrame->width,fp_yuv);
                    }
                    for (int i=0;i<outFrame->height/2;i++) {
                        fwrite(outFrame->data[1]+outFrame->linesize[1]*i,1,outFrame->width/2,fp_yuv);
                    }
                    for (int i=0;i<outFrame->height/2;i++) {
                        fwrite(outFrame->data[2]+outFrame->linesize[2]*i,1,outFrame->width/2,fp_yuv);
                    }
                }
                av_frame_unref(outFrame);
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
