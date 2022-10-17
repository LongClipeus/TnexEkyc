//
//  FaceDetector.h
//  LivenessDetection
//
//  Created by Tnex on 22/08/2022.
//

#ifndef FaceDetector_h
#define FaceDetector_h

#include <string>
#include <opencv2/core/core.hpp>
#include "definition.h"


int LoadFaceModel(std::string paramPath, std::string binPath);
std::vector<FaceBox> GetFace(cv::Mat &src);
void unInitFace();

#endif /* FaceDetector_h */
