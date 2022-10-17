//
//  Reco.m
//  ncnn-example
//
//  Created by 肖楚🐑 on 2022/1/9.
//

#import "Live.h"
#import "LiveInterface.h"
#include "FaceDetector.h"
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>

@implementation LiveInterface

- (int)loadModel {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *model1Param = [bundle URLForResource:@"model_1" withExtension:@"param"].path;
    NSString *model1Bin = [bundle URLForResource:@"model_1" withExtension:@"bin"].path;
    NSString *model2Bin = [bundle URLForResource:@"model_2" withExtension:@"bin"].path;
    NSString *model2Param = [bundle URLForResource:@"model_2" withExtension:@"param"].path;
    
    std::string param_1 = std::string([model1Param UTF8String]);
    std::string bin_1 = std::string([model1Bin UTF8String]);
    std::string param_2 = std::string([model2Param UTF8String]);
    std::string bin_2 = std::string([model2Bin UTF8String]);
    
    __block std::vector<ModelConfig> vectorList;
    vectorList.reserve(2);
    vectorList.push_back({
        2.7,
        0,
        0,
        80,
        80,
        param_1,
        bin_1,
        false,
    });
    vectorList.push_back({
        4,
        0,
        0,
        80,
        80,
        param_2,
        bin_2,
        false,
    });
    
    return LoadModel(vectorList);
}

- (int) loadAllModel {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"detection" ofType:@"param"];
    NSLog(@"BienNTPATH: %@",filePath);


    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSLog(@"BienNTPATH: %@",bundle.description);
    NSString *model1Param = [bundle URLForResource:@"detection" withExtension:@"param"].path;
    NSLog(@"BienNTPATH: %@",model1Param);

    NSString *model1Bin = [bundle URLForResource:@"detection" withExtension:@"bin"].path;
    NSLog(@"BienNTPATH: %@",model1Bin);

    std::string param_1 = std::string([model1Param UTF8String]);
    std::string bin_1 = std::string([model1Bin UTF8String]);

    LoadFaceModel(param_1, bin_1);
    int load = [self loadModel];
    return load;
    
    return -1;
}

- (float)detectLiveFromImage:(UIImage *)image{
    cv::Mat input = [self image2Mat:image];
    std::vector<FaceBox> vectorList = GetFace(input);
    
    if(vectorList.size() > 1 || vectorList.size() <= 0){
        return 0;
    }
    
    FaceBox box = vectorList[0];
    return Detect(input, box);
}

- (NSString *)getFace:(UIImage *)image{
    cv::Mat input = [self image2Mat:image];
    std::vector<FaceBox> vectorList = GetFace(input);
    if (vectorList.size() > 1 || vectorList.size() <= 0) {
        return @"";
    }
    
    NSString *str3 = [[NSString alloc] initWithFormat:@"{\"x1\":%f,\"y1\":%f,\"x2\":%f,\"y2\":%f}",vectorList[0].x1,vectorList[0].y1, vectorList[0].x2, vectorList[0].y2];
    return str3;
}

- (float)detectLive:(UIImage *)image x1:(float)x1 y1:(float)y1 x2:(float)x2 y2:(float)y2 {
    cv::Mat input = [self image2Mat:image];
    FaceBox box = {0, x1, y1, x2, y2};
    return Detect(input, box);
}


- (cv::Mat)image2Mat:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;

    cv::Mat cvMat(rows, cols, CV_8UC4);
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,
                                                cols,
                                                rows,
                                                8,
                                                cvMat.step[0],
                                                colorSpace,
                                                kCGImageAlphaNoneSkipLast |
                                                kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    cv::cvtColor(cvMat, cvMat, cv::COLOR_RGB2BGR);
    return cvMat;
}

- (void)deallocate{
    unInit();
}

@end
