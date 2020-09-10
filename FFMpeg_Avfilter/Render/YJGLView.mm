//
//  YJGLView.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/9/10.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "YJGLView.h"



@interface YJGLView()
/** 上下文*/
@property (nonatomic, strong) EAGLContext *context;

@end

@implementation YJGLView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _context = [self createEAGLContextWithFrame:frame];
    }
    return self;
}


- (EAGLContext *)createEAGLContextWithFrame:(CGRect)frame {
    
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:context];
    CAEAGLLayer *eaglLayer       = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking   : [NSNumber numberWithBool:NO],
                                     kEAGLDrawablePropertyColorFormat       : kEAGLColorFormatRGBA8};
    return context;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}
@end
