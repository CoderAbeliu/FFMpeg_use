//
//  RootViewController.m
//  FFMpeg_Avfilter
//
//  Created by hollyland－Apple on 2020/8/11.
//  Copyright © 2020 hollyland－Apple. All rights reserved.
//

#import "RootViewController.h"
#import "DecodeViewController.h"
#import "EncodeViewController.h"

@interface RootViewController ()

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

#pragma mark delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0:{
            DecodeViewController *decodeVC = [[DecodeViewController alloc] init];
            [self.navigationController pushViewController:decodeVC animated:YES];
        }
            break;
        case 1:{
            EncodeViewController *encodeVC = [[EncodeViewController alloc] init];
            [self.navigationController pushViewController:encodeVC animated:YES];
        }
            
        default:
            break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"reuseCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"reuseCell"];
    }
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"解码操作";
            break;
        case 1:
            cell.textLabel.text = @"编码操作";
            break;
        default:
            break;
    }
    return cell;
}



@end
