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
@property (nonatomic, assign) NSInteger frameRate;
/** 比特率*/
@property (nonatomic, assign) NSInteger bitRate;
/** 关键帧间隔 */
@property (nonatomic, assign) NSInteger gopRate;

@end

NS_ASSUME_NONNULL_END
