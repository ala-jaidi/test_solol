import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'features/foot_measurement/presentation/screens/camera_screen.dart';
import 'config/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception("Aucune caméra disponible");
    }

    runApp(FootMeasurementApp(camera: cameras.first));

  } catch (e) {
    print("❌ Erreur critique: $e");
  }
}

class FootMeasurementApp extends StatelessWidget {
  final CameraDescription camera;

  const FootMeasurementApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOLOL Foot Measurement',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: CameraScreen(camera: camera), // Passage de la caméra
    );
  }
}