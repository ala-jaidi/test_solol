import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraOverlay extends StatelessWidget {
  final CameraController controller;
  final bool detected;

  const CameraOverlay({super.key, required this.controller, required this.detected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          border: Border.all(
            color: detected ? Colors.green : Colors.blue,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: detected ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CameraPreview(controller),
            ),
            Positioned(
              top: 12,
              child: Text(
                detected ? 'Pied détecté!' : 'Alignez votre pied ici',
                style: TextStyle(
                  color: detected ? Colors.green : Colors.blue,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!detected)
              const Positioned(
                bottom: 20,
                child: Icon(
                  Icons.photo_camera,
                  color: Colors.white70,
                  size: 50,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
