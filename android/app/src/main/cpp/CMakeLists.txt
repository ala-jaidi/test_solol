cmake_minimum_required(VERSION 3.10.2)

project("native_opencv")

# Configuration OpenCV pour Android
set(OpenCV_DIR "C:/Users/alaja/OpenCV-android-sdk/sdk/native/jni")

# Trouver OpenCV
find_package(OpenCV REQUIRED)

# Afficher les informations OpenCV pour debug
message(STATUS "OpenCV library status:")
message(STATUS "    config: ${OpenCV_DIR}")
message(STATUS "    version: ${OpenCV_VERSION}")
message(STATUS "    libraries: ${OpenCV_LIBS}")
message(STATUS "    include path: ${OpenCV_INCLUDE_DIRS}")

# Créer la bibliothèque native
add_library(
    native_opencv
    SHARED
    native_opencv.cpp
)

# Inclure les headers OpenCV
target_include_directories(native_opencv PRIVATE 
    ${OpenCV_INCLUDE_DIRS}
)

# Configuration des flags de compilation
target_compile_options(native_opencv PRIVATE
    -std=c++14
    -fvisibility=hidden
    -fPIC
)

# Trouver les bibliothèques Android
find_library(log-lib log)
find_library(android-lib android)

# Lier les bibliothèques
target_link_libraries(
    native_opencv
    ${OpenCV_LIBS}
    ${log-lib}
    ${android-lib}
)

# Définir les propriétés de la bibliothèque
set_target_properties(native_opencv PROPERTIES
    LIBRARY_OUTPUT_NAME "native_opencv"
    POSITION_INDEPENDENT_CODE ON
)