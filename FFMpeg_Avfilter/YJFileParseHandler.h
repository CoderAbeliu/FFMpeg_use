//
//  YJFileParseHandler.h
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
NS_ASSUME_NONNULL_BEGIN

typedef void(^AVPacketBlock)(AVPacket packet);

@interface YJFileParseHandler : NSObject

@property (nonatomic, assign) BOOL parseStatus;

/// 初始化上下文
/// @param path 文件路径
- (instancetype)initWithFilePath:(NSString *)path;

/// 开始读取到AVPacket 数据
/// @param packet avpacket 数据
- (void)startGetAVPacketBlock:(AVPacketBlock)packet;

/** 上下文*/
- (AVFormatContext *)formatContext;
/** 视频流下标*/
- (int)videoIndex;
@end

NS_ASSUME_NONNULL_END
