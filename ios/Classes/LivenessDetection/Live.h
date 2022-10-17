
#ifndef NCNN_EXMAPLE_LIVE_H
#define NCNN_EXMAPLE_LIVE_H
#include <string>
#include <opencv2/core/core.hpp>
#include "definition.h"


int LoadModel(std::vector<ModelConfig> &configs);
float Detect(cv::Mat &src, FaceBox &box);
void unInit();

#endif //NCNN_EXMAPLE_LIVE_H
