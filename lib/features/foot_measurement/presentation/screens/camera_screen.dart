import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/services/yolo_service.dart';
import '../widgets/camera_overlay.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}


class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  final TFLiteYoloService _yoloService = TFLiteYoloService();

  ui.Image? _segmentationImage;
  FootMeasurement? _measurement;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.medium);
    await _controller.initialize();
    await _yoloService.initialize();
    setState(() {});
  }

  Future<void> _captureAndDetect() async {
    if (!_controller.value.isInitialized) return;

    final image = await _controller.takePicture();
    final imageBytes = await image.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) return;

    final measurement = await _yoloService.runOnImage(
      originalImage,
      originalImage.width,
      originalImage.height,
    );

    if (measurement != null) {
      final segmentationImage = await _yoloService.generateSegmentationMask(
        _yoloService.outputs!,
        _yoloService.bestIndex,
      );

      setState(() {
        _segmentationImage = segmentationImage;
        _measurement = measurement;
        _imageBytes = imageBytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _controller.value.isInitialized
          ? Stack(
        children: [
          CameraOverlay(
            controller: _controller,
            detected: _measurement != null,
          ),

          if (_imageBytes != null)
            Positioned.fill(
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          if (_segmentationImage != null)
            Positioned.fill(
              child: CustomPaint(
                painter: SegmentationPainter(_segmentationImage!),
              ),
            ),
          if (_measurement != null)
            Positioned(
              left: _measurement!.boundingBox.left,
              top: _measurement!.boundingBox.top,
              child: Container(
                width: _measurement!.boundingBox.width,
                height: _measurement!.boundingBox.height,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                ),
              ),
            ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureAndDetect,
        child: const Icon(Icons.camera),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _yoloService.dispose();
    super.dispose();
  }
}

class SegmentationPainter extends CustomPainter {
  final ui.Image maskImage;

  SegmentationPainter(this.maskImage);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      maskImage,
      Rect.fromLTWH(0, 0, maskImage.width.toDouble(), maskImage.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}