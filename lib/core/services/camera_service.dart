import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class CameraService {
  late CameraController _controller;
  bool _isInitialized = false;

  CameraController get controller => _controller;
  bool get isInitialized => _isInitialized;

  /// Initialise la caméra arrière
  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller.initialize();
    _isInitialized = true;
  }

  /// Capture une image et retourne le chemin du fichier image
  Future<String?> takePicture() async {
    if (!_controller.value.isInitialized || _controller.value.isTakingPicture) {
      return null;
    }

    try {
      final directory = await getTemporaryDirectory();
      final imagePath = join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final file = await _controller.takePicture();
      final savedFile = await File(file.path).copy(imagePath);
      return savedFile.path;
    } catch (e) {
      debugPrint('❌ Erreur lors de la capture : $e');
      return null;
    }
  }

  void dispose() {
    _controller.dispose();
    _isInitialized = false;
  }
}
