//
// Created by yuanhao on 20-6-9.
//

#ifndef LIVEBODYEXAMPLE_DEFINITION_H
#define LIVEBODYEXAMPLE_DEFINITION_H

#include <string>

struct FaceBox {
    float confidence;
    float x1;
    float y1;
    float x2;
    float y2;
};

struct ModelConfig {
    float scale;
    float shift_x;
    float shift_y;
    int height;
    int width;
    std::string param;
    std::string bin;
    bool org_resize;
};

#endif //LIVEBODYEXAMPLE_DEFINITION_H
