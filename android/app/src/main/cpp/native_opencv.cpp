#include <opencv2/opencv.hpp>
#include <opencv2/objdetect.hpp>
#include <cstring>
#include <vector>
#include <algorithm>
#include <android/log.h>

#define LOG_TAG "NativeOpenCV"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

// Structure pour stocker les points extrêmes
struct ExtremePoints {
    cv::Point top;
    cv::Point bottom;
    cv::Point left;
    cv::Point right;
};

// Structure robuste pour les données de calibration QR
struct RobustCalibrationData {
    double pixels_per_cm;
    cv::Point2f qr_center;
    double qr_size_pixels_corrected;
    double qr_size_pixels_raw;
    bool is_calibrated;
    int qr_modules;
    double perspective_ratio;
    std::string qr_content;
};

// Structure pour les mesures détaillées du pied
struct FootMeasurements {
    double length_cm;
    double width_cm;
    double heel_to_arch_cm;
    double arch_to_toe_cm;
    double big_toe_length_cm;
    bool is_calibrated;
    cv::Point2f heel_point;
    cv::Point2f toe_point;
    cv::Point2f left_point;
    cv::Point2f right_point;
};

// Structure pour paramètres adaptatifs
struct AdaptiveParams {
    cv::Size kernel_size;
    double min_contour_area_ratio;
    double max_contour_area_ratio;
    int border_width;
    
    AdaptiveParams(const cv::Size& image_size) {
        int base_kernel = std::max(3, std::min(image_size.width, image_size.height) / 200);
        kernel_size = cv::Size(base_kernel, base_kernel);
        
        double total_pixels = image_size.width * image_size.height;
        min_contour_area_ratio = total_pixels > 1000000 ? 0.005 : 0.01;
        max_contour_area_ratio = 0.8;
        
        border_width = std::min(image_size.width, image_size.height) / 15;
        
        LOGI("📐 Paramètres adaptatifs: K=%dx%d, Aire=%.3f%%-%.1f%%, Border=%d", 
             kernel_size.width, kernel_size.height, 
             min_contour_area_ratio*100, max_contour_area_ratio*100, border_width);
    }
};

// Fonction de test
__attribute__((visibility("default")))
int testFunction() {
    LOGI("testFunction appelée avec succès");
    return 42;
}

// Estimation du nombre de modules QR
int estimateQRModules(const cv::Mat& straight_qrcode) {
    if (straight_qrcode.empty()) return 0;
    
    try {
        cv::Mat binary;
        if (straight_qrcode.channels() == 3) {
            cv::Mat gray;
            cv::cvtColor(straight_qrcode, gray, cv::COLOR_BGR2GRAY);
            cv::threshold(gray, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        } else {
            cv::threshold(straight_qrcode, binary, 127, 255, cv::THRESH_BINARY);
        }
        
        int transitions = 0;
        bool last_pixel = binary.at<uchar>(binary.rows/2, 0) > 127;
        
        for (int x = 1; x < binary.cols; x++) {
            bool current_pixel = binary.at<uchar>(binary.rows/2, x) > 127;
            if (current_pixel != last_pixel) {
                transitions++;
                last_pixel = current_pixel;
            }
        }
        
        int estimated_modules = (transitions + 1) / 2;
        std::vector<int> standard_sizes = {21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73, 77};
        
        for (int size : standard_sizes) {
            if (abs(estimated_modules - size) <= 2) {
                return size;
            }
        }
        
        return estimated_modules;
    } catch (const std::exception& e) {
        LOGE("Erreur estimation modules QR: %s", e.what());
        return 0;
    }
}

// Détection QR robuste avec gestion perspective
RobustCalibrationData detectRobustQRCalibration(const cv::Mat& image, double qr_real_size_cm) {
    RobustCalibrationData calibration;
    calibration.is_calibrated = false;
    calibration.pixels_per_cm = 0.0;
    calibration.qr_modules = 0;
    calibration.perspective_ratio = 1.0;
    
    try {
        cv::QRCodeDetector qr_detector;
        std::vector<cv::Point2f> points;
        cv::Mat straight_qrcode;
        std::string decoded_info;
        
        decoded_info = qr_detector.detectAndDecode(image, points, straight_qrcode);
        
        if (decoded_info.empty() || points.size() != 4) {
            LOGI("❌ QR non détecté");
            return calibration;
        }
        
        calibration.qr_content = decoded_info;
        LOGI("🎯 QR détecté: %s", decoded_info.substr(0, 50).c_str());
        
        // Validation modules
        calibration.qr_modules = estimateQRModules(straight_qrcode);
        if (calibration.qr_modules < 21 || calibration.qr_modules > 177) {
            LOGE("❌ Modules QR invalides: %d", calibration.qr_modules);
            return calibration;
        }
        LOGI("✅ Modules validés: %d", calibration.qr_modules);
        
        // Centre géométrique
        calibration.qr_center = cv::Point2f(0, 0);
        for (const auto& point : points) {
            calibration.qr_center += point;
        }
        calibration.qr_center /= 4.0f;
        
        // Taille brute dans l'image
        double side1 = cv::norm(points[0] - points[1]);
        double side2 = cv::norm(points[1] - points[2]);
        double side3 = cv::norm(points[2] - points[3]);
        double side4 = cv::norm(points[3] - points[0]);
        calibration.qr_size_pixels_raw = (side1 + side2 + side3 + side4) / 4.0;
        
        // Gestion perspective avec straight_qrcode
        if (!straight_qrcode.empty()) {
            double corrected_size = std::min(straight_qrcode.rows, straight_qrcode.cols);
            calibration.qr_size_pixels_corrected = corrected_size;
            calibration.perspective_ratio = calibration.qr_size_pixels_corrected / calibration.qr_size_pixels_raw;
            
            LOGI("📐 Perspective: brute=%.2f, corrigée=%.2f, ratio=%.3f", 
                 calibration.qr_size_pixels_raw, calibration.qr_size_pixels_corrected, calibration.perspective_ratio);
            
            if (calibration.perspective_ratio < 0.5 || calibration.perspective_ratio > 2.0) {
                LOGE("❌ Déformation excessive: %.3f", calibration.perspective_ratio);
                return calibration;
            }
            
            calibration.pixels_per_cm = calibration.qr_size_pixels_corrected / qr_real_size_cm;
        } else {
            LOGI("⚠️ straight_qrcode vide");
            calibration.qr_size_pixels_corrected = calibration.qr_size_pixels_raw;
            calibration.pixels_per_cm = calibration.qr_size_pixels_raw / qr_real_size_cm;
        }
        
        if (calibration.pixels_per_cm > 30.0 && calibration.pixels_per_cm < 800.0) {
            calibration.is_calibrated = true;
            LOGI("✅ CALIBRATION RÉUSSIE: %.3f pixels/cm", calibration.pixels_per_cm);
        } else {
            LOGE("❌ Ratio invalide: %.2f", calibration.pixels_per_cm);
        }
        
    } catch (const std::exception& e) {
        LOGE("❌ Exception QR: %s", e.what());
    }
    
    return calibration;
}

// Points extrêmes d'un contour
ExtremePoints getExtremePoints(const std::vector<cv::Point>& contour) {
    ExtremePoints extremes;
    if (contour.empty()) return extremes;
    
    extremes.left = extremes.right = extremes.top = extremes.bottom = contour[0];
    
    for (const auto& point : contour) {
        if (point.x < extremes.left.x) extremes.left = point;
        if (point.x > extremes.right.x) extremes.right = point;
        if (point.y < extremes.top.y) extremes.top = point;
        if (point.y > extremes.bottom.y) extremes.bottom = point;
    }
    
    return extremes;
}

// Analyse adaptative du pied
FootMeasurements analyzeFootShapeAdaptive(const std::vector<cv::Point>& foot_contour, 
                                          const RobustCalibrationData& calibration,
                                          const cv::Size& image_size) {
    FootMeasurements measurements;
    measurements.is_calibrated = calibration.is_calibrated;
    
    if (foot_contour.empty()) {
        LOGE("Contour vide");
        measurements.length_cm = 0.0;
        measurements.width_cm = 0.0;
        measurements.heel_to_arch_cm = 0.0;
        measurements.arch_to_toe_cm = 0.0;
        measurements.big_toe_length_cm = 0.0;
        return measurements;
    }
    
    // Points extrêmes
    measurements.heel_point = foot_contour[0];
    measurements.toe_point = foot_contour[0];
    measurements.left_point = foot_contour[0];
    measurements.right_point = foot_contour[0];
    
    for (const auto& point : foot_contour) {
        if (point.y > measurements.heel_point.y) measurements.heel_point = point;
        if (point.y < measurements.toe_point.y) measurements.toe_point = point;
        if (point.x < measurements.left_point.x) measurements.left_point = point;
        if (point.x > measurements.right_point.x) measurements.right_point = point;
    }
    
    // Distances en pixels
    double length_pixels = cv::norm(measurements.heel_point - measurements.toe_point);
    double width_pixels = cv::norm(measurements.left_point - measurements.right_point);
    
    LOGI("📏 Pixels: L=%.2f, W=%.2f", length_pixels, width_pixels);
    
    // Conversion en centimètres
    if (calibration.is_calibrated && calibration.pixels_per_cm > 0) {
        double effective_ratio = calibration.pixels_per_cm;
        
        // Correction perspective si nécessaire
        if (calibration.perspective_ratio != 1.0) {
            double distance_factor = cv::norm(measurements.heel_point - calibration.qr_center) / 
                                   std::max(image_size.width, image_size.height);
            if (distance_factor > 0.3) {
                effective_ratio *= (1.0 + (distance_factor - 0.3) * 0.1);
                LOGI("🔧 Correction distance: %.3f", effective_ratio);
            }
        }
        
        measurements.length_cm = length_pixels / effective_ratio;
        measurements.width_cm = width_pixels / effective_ratio;
        measurements.heel_to_arch_cm = measurements.length_cm * 0.60;
        measurements.arch_to_toe_cm = measurements.length_cm * 0.40;
        measurements.big_toe_length_cm = measurements.length_cm * 0.15;
        
        LOGI("✅ CALIBRÉ QR: %.3f pixels/cm", effective_ratio);
        
    } else {
        // Estimation adaptative
        double total_pixels = image_size.width * image_size.height;
        double estimated_pixels_per_cm;
        
        if (total_pixels > 2000000) {
            estimated_pixels_per_cm = 150.0;
        } else if (total_pixels > 1000000) {
            estimated_pixels_per_cm = 120.0;
        } else {
            estimated_pixels_per_cm = 90.0;
        }
        
        measurements.length_cm = length_pixels / estimated_pixels_per_cm;
        measurements.width_cm = width_pixels / estimated_pixels_per_cm;
        measurements.heel_to_arch_cm = measurements.length_cm * 0.60;
        measurements.arch_to_toe_cm = measurements.length_cm * 0.40;
        measurements.big_toe_length_cm = measurements.length_cm * 0.15;
        
        LOGI("⚠️ ESTIMATION: %.0f pixels/cm (%.1fMP)", estimated_pixels_per_cm, total_pixels/1000000.0);
    }
    
    LOGI("📏 FINAL: L=%.2fcm, W=%.2fcm", measurements.length_cm, measurements.width_cm);
    
    return measurements;
}

// FONCTION PRINCIPALE ROBUSTE
__attribute__((visibility("default")))
uint8_t* measureFootWithQR(const char* path, int* outSize, double qr_size_cm) {
    LOGI("🔍 measureFootWithQR robuste (QR: %.1f cm)", qr_size_cm);
    
    if (path == nullptr || outSize == nullptr) {
        LOGE("Paramètres invalides");
        *outSize = 0;
        return nullptr;
    }
    
    try {
        cv::Mat img_bgr = cv::imread(path, cv::IMREAD_COLOR);
        if (img_bgr.empty()) {
            LOGE("Image vide");
            *outSize = 0;
            return nullptr;
        }
        
        LOGI("📸 Image: %dx%d (%.1fMP)", img_bgr.cols, img_bgr.rows, 
             (img_bgr.cols * img_bgr.rows) / 1000000.0);
        
        // ÉTAPE 1: Calibration QR robuste
        RobustCalibrationData calibration = detectRobustQRCalibration(img_bgr, qr_size_cm);
        
        // ÉTAPE 2: Paramètres adaptatifs
        AdaptiveParams params(img_bgr.size());
        
        // ÉTAPE 3: Détection adaptative du pied
        cv::Mat img_gray;
        cv::cvtColor(img_bgr, img_gray, cv::COLOR_BGR2GRAY);
        
        cv::Mat img_blurred;
        cv::GaussianBlur(img_gray, img_blurred, cv::Size(5, 5), 0);
        
        // Détection du fond
        cv::Mat border_mask = cv::Mat::zeros(img_gray.size(), CV_8UC1);
        cv::rectangle(border_mask, cv::Point(0, 0), 
                     cv::Point(img_gray.cols, params.border_width), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(0, img_gray.rows - params.border_width), 
                     cv::Point(img_gray.cols, img_gray.rows), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(0, 0), 
                     cv::Point(params.border_width, img_gray.rows), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(img_gray.cols - params.border_width, 0), 
                     cv::Point(img_gray.cols, img_gray.rows), cv::Scalar(255), -1);
        
        cv::Scalar border_mean = cv::mean(img_blurred, border_mask);
        double background_intensity = border_mean[0];
        
        cv::Mat img_thresh;
        double otsu_threshold = cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        
        if (background_intensity > 128 && otsu_threshold > background_intensity * 0.7) {
            cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
            LOGI("Fond clair détecté");
        } else {
            LOGI("Fond sombre détecté");
        }
        
        // Morphologie adaptative
        cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, params.kernel_size);
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_CLOSE, kernel);
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_OPEN, kernel);
        
        // Contours avec filtrage adaptatif
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(img_thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        
        if (contours.empty()) {
            LOGE("Aucun contour");
            *outSize = 0;
            return nullptr;
        }
        
        // Filtrage adaptatif
        std::vector<std::pair<double, size_t>> valid_contours;
        double total_area = img_gray.rows * img_gray.cols;
        double min_area = total_area * params.min_contour_area_ratio;
        double max_area = total_area * params.max_contour_area_ratio;
        
        for (size_t i = 0; i < contours.size(); i++) {
            double area = cv::contourArea(contours[i]);
            if (area > min_area && area < max_area) {
                cv::Rect bbox = cv::boundingRect(contours[i]);
                bool near_border = (bbox.x < params.border_width || 
                                   bbox.y < params.border_width ||
                                   bbox.x + bbox.width > img_gray.cols - params.border_width ||
                                   bbox.y + bbox.height > img_gray.rows - params.border_width);
                
                if (!near_border || area > total_area * 0.3) {
                    valid_contours.push_back(std::make_pair(area, i));
                }
            }
        }
        
        std::sort(valid_contours.begin(), valid_contours.end(), 
                  [](const auto& a, const auto& b) { return a.first > b.first; });
        
        if (valid_contours.empty()) {
            LOGE("Aucun contour valide");
            *outSize = 0;
            return nullptr;
        }
        
        // ÉTAPE 4: Analyse mesures
        size_t best_contour_idx = valid_contours[0].second;
        FootMeasurements foot_measurements = analyzeFootShapeAdaptive(
            contours[best_contour_idx], calibration, img_bgr.size()
        );
        
        // ÉTAPE 5: Image résultat
        cv::Mat result = img_bgr.clone();
        
        // QR info
        if (calibration.is_calibrated) {
            cv::circle(result, calibration.qr_center, 15, cv::Scalar(0, 255, 0), -1);
            std::string qr_info = "QR: " + std::to_string(calibration.qr_modules) + "M";
            cv::putText(result, qr_info, 
                       cv::Point(calibration.qr_center.x + 20, calibration.qr_center.y), 
                       cv::FONT_HERSHEY_SIMPLEX, 0.6, cv::Scalar(0, 255, 0), 1);
        }
        
        // Contour et points
        cv::drawContours(result, contours, best_contour_idx, cv::Scalar(255, 0, 0), 3);
        cv::circle(result, foot_measurements.heel_point, 12, cv::Scalar(0, 255, 255), -1);
        cv::circle(result, foot_measurements.toe_point, 12, cv::Scalar(0, 50, 255), -1);
        cv::circle(result, foot_measurements.left_point, 12, cv::Scalar(255, 50, 0), -1);
        cv::circle(result, foot_measurements.right_point, 12, cv::Scalar(255, 255, 0), -1);
        
        cv::line(result, foot_measurements.heel_point, foot_measurements.toe_point, cv::Scalar(255, 255, 255), 3);
        cv::line(result, foot_measurements.left_point, foot_measurements.right_point, cv::Scalar(255, 255, 255), 3);
        
        // Texte info
        int y = 40;
        std::string length_text = "L: " + std::to_string(foot_measurements.length_cm).substr(0, 4) + "cm";
        std::string width_text = "W: " + std::to_string(foot_measurements.width_cm).substr(0, 4) + "cm";
        std::string method = foot_measurements.is_calibrated ? "QR ROBUSTE" : "ADAPTATIF";
        
        cv::putText(result, length_text, cv::Point(30, y), cv::FONT_HERSHEY_SIMPLEX, 0.8, cv::Scalar(255, 255, 255), 2);
        cv::putText(result, width_text, cv::Point(30, y+35), cv::FONT_HERSHEY_SIMPLEX, 0.8, cv::Scalar(255, 255, 255), 2);
        cv::putText(result, method, cv::Point(30, y+70), cv::FONT_HERSHEY_SIMPLEX, 0.6, 
                   foot_measurements.is_calibrated ? cv::Scalar(0, 255, 0) : cv::Scalar(0, 150, 255), 2);
        
        // Encoder
        std::vector<uchar> buf;
        cv::imencode(".png", result, buf);
        *outSize = static_cast<int>(buf.size());
        
        uint8_t* result_ptr = new uint8_t[*outSize];
        std::memcpy(result_ptr, buf.data(), *outSize);
        
        LOGI("✅ measureFootWithQR terminée");
        return result_ptr;
        
    } catch (const std::exception& e) {
        LOGE("❌ Exception: %s", e.what());
        *outSize = 0;
        return nullptr;
    }
}

// FONCTION D'EXTRACTION DE MESURES
__attribute__((visibility("default")))
double* extractFootMeasurements(const char* path, double qr_size_cm) {
    LOGI("🔍 extractFootMeasurements (QR: %.1f cm)", qr_size_cm);
    
    double* measurements = new double[6];
    for (int i = 0; i < 6; i++) measurements[i] = 0.0;
    
    try {
        cv::Mat img_bgr = cv::imread(path, cv::IMREAD_COLOR);
        if (img_bgr.empty()) {
            LOGE("Image vide");
            return measurements;
        }
        
        // Calibration QR
        RobustCalibrationData calibration = detectRobustQRCalibration(img_bgr, qr_size_cm);
        
        // Détection simple du pied
        cv::Mat img_gray;
        cv::cvtColor(img_bgr, img_gray, cv::COLOR_BGR2GRAY);
        cv::Mat img_blurred;
        cv::GaussianBlur(img_gray, img_blurred, cv::Size(5, 5), 0);
        
        cv::Mat img_thresh;
        cv::Scalar border_mean = cv::mean(img_blurred);
        double background_intensity = border_mean[0];
        
        if (background_intensity > 128) {
            cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        } else {
            cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        }
        
        cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5));
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_CLOSE, kernel);
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_OPEN, kernel);
        
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(img_thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        
        if (!contours.empty()) {
            auto max_contour = std::max_element(contours.begin(), contours.end(),
                [](const auto& a, const auto& b) { return cv::contourArea(a) < cv::contourArea(b); });
            
            FootMeasurements foot_measurements = analyzeFootShapeAdaptive(*max_contour, calibration, img_bgr.size());
            
            measurements[0] = foot_measurements.length_cm;
            measurements[1] = foot_measurements.width_cm;
            measurements[2] = foot_measurements.heel_to_arch_cm;
            measurements[3] = foot_measurements.arch_to_toe_cm;
            measurements[4] = foot_measurements.big_toe_length_cm;
            measurements[5] = foot_measurements.is_calibrated ? 1.0 : 0.0;
            
            LOGI("✅ Extraction réussie");
        } else {
            LOGE("Aucun contour détecté");
        }
        
        return measurements;
    } catch (const std::exception& e) {
        LOGE("Exception extractFootMeasurements: %s", e.what());
        return measurements;
    }
}

// FONCTIONS EXISTANTES (inchangées)
__attribute__((visibility("default")))
uint8_t* processImage(const char* path, int* outSize) {
    LOGI("processImage appelée");
    
    if (path == nullptr || outSize == nullptr) {
        LOGE("Paramètres invalides");
        *outSize = 0;
        return nullptr;
    }
    
    try {
        cv::Mat image = cv::imread(path, cv::IMREAD_COLOR);
        if (image.empty()) {
            LOGE("Impossible de charger l'image: %s", path);
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
    } catch (const std::exception& e) {
        LOGE("Exception processImage: %s", e.what());
        *outSize = 0;
        return nullptr;
    }
}

__attribute__((visibility("default")))
uint8_t* removeBackground(const char* path, int* outSize) {
    LOGI("removeBackground appelée");
    
    if (path == nullptr || outSize == nullptr) {
        LOGE("Paramètres invalides");
        *outSize = 0;
        return nullptr;
    }
    
    try {
        cv::Mat img_bgr = cv::imread(path, cv::IMREAD_COLOR);
        if (img_bgr.empty()) {
            LOGE("Image vide");
            *outSize = 0;
            return nullptr;
        }
        
        cv::Mat img_gray;
        cv::cvtColor(img_bgr, img_gray, cv::COLOR_BGR2GRAY);
        cv::Mat img_blurred;
        cv::GaussianBlur(img_gray, img_blurred, cv::Size(5, 5), 0);
        
        cv::Mat border_mask = cv::Mat::zeros(img_gray.size(), CV_8UC1);
        int border_width = std::min(img_gray.rows, img_gray.cols) / 10;
        
        cv::rectangle(border_mask, cv::Point(0, 0), cv::Point(img_gray.cols, border_width), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(0, img_gray.rows - border_width), cv::Point(img_gray.cols, img_gray.rows), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(0, 0), cv::Point(border_width, img_gray.rows), cv::Scalar(255), -1);
        cv::rectangle(border_mask, cv::Point(img_gray.cols - border_width, 0), cv::Point(img_gray.cols, img_gray.rows), cv::Scalar(255), -1);
        
        cv::Scalar border_mean = cv::mean(img_blurred, border_mask);
        double background_intensity = border_mean[0];
        
        cv::Mat img_thresh;
        double otsu_threshold = cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        
        if (background_intensity > 128 && otsu_threshold > background_intensity * 0.7) {
            cv::threshold(img_blurred, img_thresh, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);
        }
        
        cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5));
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_CLOSE, kernel);
        cv::morphologyEx(img_thresh, img_thresh, cv::MORPH_OPEN, kernel);
        
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(img_thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        
        if (contours.empty()) {
            *outSize = 0;
            return nullptr;
        }

        std::vector<std::pair<double, size_t>> valid_contours;
        double total_area = img_gray.rows * img_gray.cols;
        
        for (size_t i = 0; i < contours.size(); i++) {
            double area = cv::contourArea(contours[i]);
            if (area > total_area * 0.01 && area < total_area * 0.8) {
                cv::Rect bbox = cv::boundingRect(contours[i]);
                bool near_border = (bbox.x < border_width || bbox.y < border_width ||
                                   bbox.x + bbox.width > img_gray.cols - border_width ||
                                   bbox.y + bbox.height > img_gray.rows - border_width);
                
                if (!near_border || area > total_area * 0.3) {
                    valid_contours.push_back(std::make_pair(area, i));
                }
            }
        }
        
        std::sort(valid_contours.begin(), valid_contours.end(), 
                  [](const auto& a, const auto& b) { return a.first > b.first; });

        if (valid_contours.empty()) {
            *outSize = 0;
            return nullptr;
        }

        cv::Mat mask = cv::Mat::zeros(img_gray.size(), CV_8UC1);
        size_t num_contours = std::min(size_t(2), valid_contours.size());
        
        for (size_t i = 0; i < num_contours; i++) {
            size_t idx = valid_contours[i].second;
            cv::fillPoly(mask, std::vector<std::vector<cv::Point>>{contours[idx]}, cv::Scalar(255));
        }

        cv::Mat result;
        cv::Scalar bg_color = (background_intensity > 128) ? cv::Scalar(255, 255, 255) : cv::Scalar(0, 0, 0);
        
        cv::Mat colored_bg = cv::Mat::ones(img_bgr.size(), img_bgr.type());
        colored_bg = colored_bg.mul(cv::Scalar(bg_color[0], bg_color[1], bg_color[2]));
        
        img_bgr.copyTo(colored_bg, mask);
        result = colored_bg;

        for (size_t i = 0; i < num_contours; i++) {
            size_t idx = valid_contours[i].second;
            cv::drawContours(result, contours, idx, cv::Scalar(255, 0, 0), 3);
            
            ExtremePoints extremes = getExtremePoints(contours[idx]);
            cv::circle(result, extremes.left, 8, cv::Scalar(255, 50, 0), -1);
            cv::circle(result, extremes.right, 8, cv::Scalar(255, 255, 0), -1);
            cv::circle(result, extremes.top, 8, cv::Scalar(0, 50, 255), -1);
            cv::circle(result, extremes.bottom, 8, cv::Scalar(0, 255, 255), -1);
        }

        std::vector<uchar> buf;
        cv::imencode(".png", result, buf);
        *outSize = static_cast<int>(buf.size());

        uint8_t* result_ptr = new uint8_t[*outSize];
        std::memcpy(result_ptr, buf.data(), *outSize);
        
        return result_ptr;
    } catch (const std::exception& e) {
        LOGE("Exception removeBackground: %s", e.what());
        *outSize = 0;
        return nullptr;
    }
}

__attribute__((visibility("default")))
void freeMemory(uint8_t* ptr) {
    if (ptr != nullptr) {
        delete[] ptr;
    }
}

}