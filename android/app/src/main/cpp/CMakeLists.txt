cmake_minimum_required(VERSION 3.10.2)

project("native-lib")

# 👇 Spécifie ici le chemin vers le dossier qui contient OpenCVConfig.cmake
set(OpenCV_DIR "C:/Users/alaja/OpenCV-android-sdk/sdk/native/jni")

# 🔍 CMake trouvera maintenant OpenCV
find_package(OpenCV REQUIRED)

add_library(
        native-lib
        SHARED
        native_opencv.cpp
)

include_directories(${OpenCV_INCLUDE_DIRS})

find_library(log-lib log)

target_link_libraries(
        native-lib
        ${OpenCV_LIBS}
        ${log-lib}
)
