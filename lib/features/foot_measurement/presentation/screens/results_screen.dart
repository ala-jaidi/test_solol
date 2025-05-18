import 'package:flutter/material.dart';
import 'dart:io';

class ResultsScreen extends StatelessWidget {
  final String imagePath;
  final List<List<double>> landmarks;
  final double measurement;

  const ResultsScreen({
    Key? key,
    required this.imagePath,
    required this.landmarks,
    required this.measurement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du Scan'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mesure estimée du pied :',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${measurement.toStringAsFixed(2)} cm',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: landmarks.length,
                itemBuilder: (context, index) {
                  final point = landmarks[index];
                  return ListTile(
                    title: Text('Point $index'),
                    subtitle: Text('x: ${point[0].toStringAsFixed(2)}, y: ${point[1].toStringAsFixed(2)}, z: ${point[2].toStringAsFixed(2)}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
