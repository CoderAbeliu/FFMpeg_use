//
//  TestViewController.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/9/10.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "TestViewController.h"
#import "YJGLView.h"

@interface TestViewController ()
@property (nonatomic, strong) YJGLView *glView;
@end

@implementation TestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.glView = [[YJGLView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.glView];
}


@end
