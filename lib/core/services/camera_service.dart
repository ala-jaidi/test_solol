import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;
    _controller = CameraController(camera, ResolutionPreset.high);
    await _controller!.initialize();
  }

  CameraController get controller => _controller!;

  void dispose() {
    _controller?.dispose();
  }
}
