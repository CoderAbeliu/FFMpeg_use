//
//  YJFFMpegDecode.h
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"


@protocol YJFFMpegDelegate <NSObject>

- (void)getVideoBufferByFFMpeg:(CMSampleBufferRef)samplerBuffer;

@end
NS_ASSUME_NONNULL_BEGIN

@interface YJFFMpegDecode : NSObject

/** 解码数据代理*/
@property (nonatomic, weak) id <YJFFMpegDelegate>delegate;

/// 使用context 初始化解码器
/// @param formatContext 数据上下文
/// @param videoIndex 视频下标
- (instancetype)initWithFormatContext:(AVFormatContext *)formatContext videoIndex:(int)videoIndex;


/// 使用ffmpeg 进行解码
/// @param pkt AVPacket 数据
- (void)startDecodeVideoDataWithPkt:(AVPacket)pkt;
@end

NS_ASSUME_NONNULL_END
