//
//  Reco.h
//  ncnn-example
//
//  Created by 肖楚🐑 on 2022/1/9.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LiveInterface : NSObject

- (int)loadModel;

- (int)loadAllModel;


- (float)detectLive:(UIImage *)image x1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2;

- (float)detectLiveFromImage:(UIImage *)image;

- (float)detectLiveFromImage2:(UIImage *)image;

- (float)detectLiveFromImage3:(UIImage *)image;

- (void)deallocate;

@end

NS_ASSUME_NONNULL_END
