import 'package:flutter/material.dart';
import 'features/foot_measurement/presentation/screens/camera_screen.dart';
import 'config/theme.dart';

void main() {
  runApp(const FootMeasurementApp());
}

class FootMeasurementApp extends StatelessWidget {
  const FootMeasurementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOLOL Foot Measurement',
      theme: AppTheme.lightTheme,
      home: const CameraScreen(),
    );
  }
}
