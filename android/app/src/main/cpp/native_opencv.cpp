#include <opencv2/opencv.hpp>
#include <cstring>

extern "C" {

// Traitement d'image avec Canny
uint8_t* processImage(const char* path, int* outSize) {
    cv::Mat image = cv::imread(path, cv::IMREAD_COLOR);
    if (image.empty()) {
        *outSize = 0;
        return nullptr;
    }

    cv::Mat gray, edges;
    cv::cvtColor(image, gray, cv::COLOR_BGR2GRAY);
    cv::Canny(gray, edges, 100, 200);

    std::vector<uchar> buf;
    cv::imencode(".png", edges, buf);
    *outSize = static_cast<int>(buf.size());

    uint8_t* result = new uint8_t[*outSize];
    std::memcpy(result, buf.data(), *outSize);
    return result;
}

// Libération mémoire
void freeMemory(uint8_t* ptr) {
    delete[] ptr;
}

}
