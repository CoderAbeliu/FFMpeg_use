//
//  YJFileParseHandler.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/3.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "YJFileParseHandler.h"

@implementation YJFileParseHandler
{
    AVFormatContext *pFormatContext;
    BOOL pStopParse;
    int pVideoIndex;
}


- (instancetype)initWithFilePath:(NSString *)path {
    self = [super init];
    if (self) {
        av_register_all();
        pFormatContext = avformat_alloc_context();
        int ret = avformat_open_input(&pFormatContext, path.UTF8String, NULL, NULL);
        if (ret < 0) {
            av_log(NULL, AV_LOG_DEBUG, "avformat_open_input失败");
        }
        if (avformat_find_stream_info(pFormatContext, NULL) < 0) {
            av_log(NULL, AV_LOG_DEBUG, "没找到数据流信息\n");
        }
        for (int i = 0; i < pFormatContext->nb_streams; i++) {
            if (pFormatContext->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
                pVideoIndex = i;
                break;
            }
        }
        if (pVideoIndex == -1) {
            av_log(NULL, AV_LOG_ERROR, "数据中不存在视频流\n");
        }
    }
    return self;
}

- (void)startGetAVPacketBlock:(AVPacketBlock)packet {
    pStopParse = NO;
    dispatch_queue_t readQueue = dispatch_queue_create("read_pkt_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(readQueue, ^{
        while (!self->pStopParse) {
            if (!self->pFormatContext) {
                break;
            }
            AVPacket pkt;
            av_init_packet(&pkt);
            int ret = av_read_frame(self->pFormatContext, &pkt);
            if (ret < 0 || pkt.size < 0) {
                av_log(NULL, AV_LOG_ERROR, "读取数据失败\n");
                self->pStopParse = YES;
                break;
            }
            if (pkt.stream_index == self->pVideoIndex) {
                // 视频数据传递
                if (packet) {
                    packet(pkt);
                }
            }
            av_packet_unref(&pkt);
        }
//        avformat_close_input(&self->pFormatContext);
//        self->pFormatContext = NULL;
    });
    
}


- (void)setParseStatus:(BOOL)parseStatus {
    pStopParse = parseStatus;
}

- (BOOL)parseStatus {
    return pStopParse;
}

- (int)videoIndex {
    return pVideoIndex;
}

- (AVFormatContext *)formatContext {
    return pFormatContext;
}
@end
