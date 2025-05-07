import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

class OpenCVService {
  late DynamicLibrary _opencvLib;

  Future<void> loadOpenCV() async {
    final libPath = Platform.isAndroid
        ? 'libopencv_java4.so'
        : 'libopencv_java4.dylib';
    _opencvLib = DynamicLibrary.open(libPath);
  }

// Exemple : ajouter ici vos méthodes OpenCV spécifiques
}
