//
//  YJGLView.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/9/10.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "YJGLView.h"
#import <OpenGLES/ES2/glext.h>
#import <AVFoundation/AVUtilities.h>

@interface YJGLView()
/** 上下文*/
@property (nonatomic, strong) EAGLContext *context;

@end

enum
{
    YUNIFORM_Y,
    YUNIFORM_UV,
    YUNIFORM_COLOR_CONVERSION_MATRIX,
    YNUM_UNIFORMS
};

// BT.709, which is the standard for HDTV.
static const GLfloat g_bt709[] = {
    1.164,  1.164,  1.164,
    0.0,   -0.213,  2.112,
    1.793, -0.533,  0.0,
};
const GLfloat *IJK_GLES2_getColorMatrix_bt709()
{
    return g_bt709;
}

static const GLfloat g_bt601[] = {
    1.164,  1.164, 1.164,
    0.0,   -0.392, 2.017,
    1.596, -0.813, 0.0,
};
const GLfloat *IJK_GLES2_getColorMatrix_bt601()
{
    return g_bt601;
}


GLint uniforms2[YNUM_UNIFORMS];

@implementation YJGLView {
    GLuint _program;
    // 片元着色器
    GLuint _fragamentShader;
    // 顶点着色器
    GLuint _verShader;
    /// opengl缓存
    CVOpenGLESTextureCacheRef _glesCacheRef;
    /// 宽
    GLint _backingWidth;
    /// 高
    GLint _backingHeight;
    
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _context = [self createEAGLContextWithFrame:frame];
    }
    return self;
}



#pragma mark 显示

- (void)displayBuffer:(CVPixelBufferRef)pixelBuffer {
    // 获取解码后数据的宽高
    int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    if (!_glesCacheRef) {
        NSLog(@"纹理缓存器不存在");
        return;
    }
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    CVOpenGLESTextureRef lumaTexture,chromaTexture;
    CVOpenGLESTextureCacheFlush(_glesCacheRef, NULL);
    
    // Y
    glActiveTexture(GL_TEXTURE0);
    CVReturn error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _glesCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, frameWidth, frameHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &lumaTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture), CVOpenGLESTextureGetName(lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // UV
    glActiveTexture(GL_TEXTURE1);
    error = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _glesCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RG_EXT, frameWidth, frameHeight, GL_RG_EXT, GL_RG_EXT, GL_UNSIGNED_BYTE, &chromaTexture);
    glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture), CVOpenGLESTextureGetName(chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    // 视口
    glViewport(0, 0, _backingWidth, _backingHeight);
    // 清除颜色
    glClearColor(0.1f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glUseProgram(_program);
    glUniform1i(uniforms2[YUNIFORM_Y], 0);
    glUniform1i(uniforms2[YUNIFORM_UV], 1);
    glUniformMatrix3fv(uniforms2[YUNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, IJK_GLES2_getColorMatrix_bt709());
    
    
}
#pragma mark 创建上下文

- (EAGLContext *)createEAGLContextWithFrame:(CGRect)frame {
   
    // 创建layer图层，用来加载opengl图层
    CAEAGLLayer *eaglLayer       = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking   : [NSNumber numberWithBool:NO],
                                     kEAGLDrawablePropertyColorFormat       : kEAGLColorFormatRGBA8};
    // iOS提供给openglES 的接口
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:context];
 
    [self creatFBOWithContext:context width:frame.size.width height:frame.size.height];
    [self loadShader];
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &_glesCacheRef);
    if (err != noErr) {
        NSLog(@"创建纹理缓存区失败");
        return nil;
    }
    return context;
}

#pragma mark 创建FBO/VBO

- (void)creatFBOWithContext:(EAGLContext *)context width:(CGFloat)width height:(CGFloat)height {
    // glVertexAttribPointer 和 glEnableVertexAttribArray 没有顺序，需要在draw之前完成
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    glEnableVertexAttribArray(1);
    
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(GLfloat), 0);
    glEnableVertexAttribArray(0);
    
    // 设置framebuffer，帧缓冲区
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    // 设置renderbuffer，渲染缓冲区
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    // 将可绘制对象的存储绑定到opengles 的renderbuffer上
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH , &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    // 将渲染缓冲区挂载到当前帧缓冲区上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
}

#pragma mark 着色器加载

/** 加载着色器 */
- (BOOL)loadShader {
    // 程序
    _program = glCreateProgram();
    NSURL *verShaderUrl = [[NSBundle mainBundle] URLForResource:@"XDXPreviewNV12Shader" withExtension:@"vsh"];
    NSURL *fragmentShaderUrl = [[NSBundle mainBundle] URLForResource:@"XDXPreviewNV12Shader" withExtension:@"fsh"];
    BOOL status = [self loadAndCompileShader:&_verShader url:verShaderUrl type:GL_VERTEX_SHADER];
    if (!status) {
        NSLog(@"加载顶点着色器失败");
        return NO;
    }
    status = [self loadAndCompileShader:&_fragamentShader url:fragmentShaderUrl type:GL_FRAGMENT_SHADER];
    if (!status) {
        NSLog(@"加载顶点着色器失败");
        return NO;
    }
    // 绑定项目和着色器
    glAttachShader(_program, _verShader);
    glAttachShader(_program, _fragamentShader);
    // 绑定着色器程序对象, 对应glVertexAttribPointer里面绑定的值, 对应shader里面的属性); 顶点坐标，uv，颜色对应到shader属性 必须在glLinkProgram之前使用
    glBindAttribLocation(_program, 0 , "position");
    glBindAttribLocation(_program, 1, "inputTextureCoordinate");
    // 连接项目
    GLint linkStatus;
    glLinkProgram(_program);
    glGetProgramiv(_program, GL_LINK_STATUS, &linkStatus);
    
    uniforms2[YUNIFORM_Y] = glGetUniformLocation(_program , "luminanceTexture");
    uniforms2[YUNIFORM_UV] = glGetUniformLocation(_program, "chrominanceTexture");
    uniforms2[YUNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(_program, "colorConversionMatrix");
    if (!linkStatus) {
        NSLog(@"链接项目失败");
    }
    // 移除shader 是不会马上生效的
    if (_verShader) {
        glDetachShader(_program, _verShader);
        glDeleteShader(_verShader);
    }
    if (_fragamentShader) {
        glDetachShader(_program, _fragamentShader);
        glDeleteShader(_fragamentShader);
    }
    return YES;
}


- (BOOL)loadAndCompileShader:(GLuint *)shader url:(NSURL *)url type:(GLenum)type {
    NSString *sourceString = [[NSString alloc] initWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    GLint status;
    const GLchar *source =(GLchar *) [sourceString UTF8String];
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    return YES;
}

#pragma mark layer

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (CAEAGLLayer *)eglLayer {
    return (CAEAGLLayer *)self.layer;
}
@end
