//
//  HardEncode.h
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/10.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>


@class VideoEncodeConfig;

NS_ASSUME_NONNULL_BEGIN

@interface HardEncode : NSObject

/** 初始化编码配置*/
- (instancetype)initWithConfig:(VideoEncodeConfig *)config;

/** 编码入口*/
- (void)startEncodeWithCMSampleBufferRef:(CMSampleBufferRef)samplerBuffer;

/** 停止编码*/
- (void)stopEncode;

@end

@interface VideoEncodeConfig : NSObject
/** 编码图像大小*/
@property (nonatomic, assign) CGSize size;
/** 帧率*/
@property (nonatomic, assign) NSInteger videoFrameRate;
/** 比特率*/
@property (nonatomic, assign) NSInteger videoBitRate;

@property (nonatomic, assign) NSInteger videoMaxBitRate;

@property (nonatomic, assign) NSInteger videoMinBitRate;

@property (nonatomic, assign) NSInteger videoMaxKeyframeInterval;

/*
videoConfiguration.videoBitRate = 800*1024;
videoConfiguration.videoMaxBitRate = 1000*1024;
videoConfiguration.videoMinBitRate = 500*1024;
videoConfiguration.videoFrameRate = 24;
videoConfiguration.videoMaxKeyframeInterval = 48;
 */
@end

NS_ASSUME_NONNULL_END
