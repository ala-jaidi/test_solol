import 'package:flutter/material.dart';
import '../../data/models/foot_measurement.dart';

class ResultsScreen extends StatelessWidget {
  final FootMeasurement measurement;

  const ResultsScreen({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Résultats')),
      body: Center(
        child: Text(
          'Longueur: ${measurement.lengthCm.toStringAsFixed(2)} cm\n'
              'Largeur: ${measurement.widthCm.toStringAsFixed(2)} cm',
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
