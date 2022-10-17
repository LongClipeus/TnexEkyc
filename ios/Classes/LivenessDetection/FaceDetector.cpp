//
//  FaceDetector.cpp
//  LivenessDetection
//
//  Created by Tnex on 22/08/2022.
//

#include "FaceDetector.h"
#include <cstdio>
#include <opencv2/highgui/highgui.hpp>
#include <ncnn/ncnn/platform.h>
#include <ncnn/ncnn/net.h>
#include <opencv2/imgproc.hpp>
#include <iostream>
    
ncnn::Net net_;
const std::string face_net_input_name_ = "data";
const std::string face_net_output_name_ = "detection_out";
int face_thread_num_;
int face_input_size_ = 192;
int min_face_size_;
ncnn::Option face_option_;
float face_threshold_;
const float mean_val_[3] = {104.f, 117.f, 123.f};

void unInitFace() {
    net_.clear();
}

static bool AreaComp(FaceBox& l, FaceBox& r) {
    return ((l.x2 - l.x1 + 1) * (l.y2 - l.y1 + 1)) > ((r.x2 - r.x1 + 1) * (r.y2 - r.y1 + 1));
}

int LoadFaceModel(std::string paramPath, std::string binPath) {
    unInitFace();
    min_face_size_ = 64;
    face_threshold_ = 0.6f;
    face_thread_num_ = 2;
    face_option_.lightmode = true;
    face_option_.num_threads = face_thread_num_;
    
    net_.opt = face_option_;
    int ret = net_.load_param(paramPath.c_str());
    if (ret != 0) {
        return - 1;
    }

    ret = net_.load_model(binPath.c_str());
    if (ret != 0) {
        return -2;
    }
    
    return 0;
}

std::vector<FaceBox> GetFace(cv::Mat &src) {
    int w = src.cols;
    int h = src.rows;

    float aspect_ratio = w / (float)h;

    int input_width = static_cast<int>(face_input_size_ * sqrt(aspect_ratio));
    int input_height = static_cast<int>(face_input_size_ / sqrt(aspect_ratio));

    ncnn::Mat in = ncnn::Mat::from_pixels_resize(src.data, ncnn::Mat::PIXEL_BGR, src.cols, src.rows,
                                                 input_width, input_height);

    in.substract_mean_normalize(mean_val_, nullptr);

    ncnn::Extractor extractor = net_.create_extractor();
    extractor.set_num_threads(face_thread_num_);
    extractor.input(face_net_input_name_.c_str(), in);

    ncnn::Mat out;
    extractor.extract(face_net_output_name_.c_str(), out);
    std::vector<FaceBox> boxes;
    for (int i = 0; i < out.h; ++i) {
        const float* values = out.row(i);
        float confidence = values[1];
        
        std::cout << "BienNT GetFace live confidence " << confidence << std::endl;

        if(confidence < face_threshold_) continue;

        FaceBox box;
        box.confidence = confidence;
        box.x1 = values[2] * w;
        box.y1 = values[3] * h;
        box.x2 = values[4] * w;
        box.y2 = values[5] * h;
        
        std::cout << "BienNT GetFace live box.x1 " << box.x1 << std::endl;
        std::cout << "BienNT GetFace live box.y1 " << box.y1 << std::endl;
        std::cout << "BienNT GetFace live box.x2 " << box.x2 << std::endl;
        std::cout << "BienNT GetFace live box.y2 " << box.y2 << std::endl;


        // square
        float box_width = box.x2 - box.x1 + 1;
        float box_height = box.y2 - box.y1 + 1;

        float size = (box_width + box_height) * 0.5f;

        if(size < min_face_size_) continue;

        float cx = box.x1 + box_width * 0.5f;
        float cy = box.y1 + box_height * 0.5f;

        box.x1 = cx - size * 0.5f;
        box.y1 = cy - size * 0.5f;
        box.x2 = cx + size * 0.5f - 1;
        box.y2 = cy + size * 0.5f - 1;
        
        std::cout << "BienNT GetFace live box.x1 " << box.x1 << std::endl;
        std::cout << "BienNT GetFace live box.y1 " << box.y1 << std::endl;
        std::cout << "BienNT GetFace live box.x2 " << box.x2 << std::endl;
        std::cout << "BienNT GetFace live box.y2 " << box.y2 << std::endl;

        boxes.emplace_back(box);
    }

    // sort
    std::sort(boxes.begin(), boxes.end(), AreaComp);
    return boxes;
}
