import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../data/models/foot_measurement.dart';

class ResultsScreen extends StatelessWidget {
  final Uint8List originalImage;
  final Uint8List processedImage;
  final FootMeasurement measurement;

  const ResultsScreen({
    super.key,
    required this.originalImage,
    required this.processedImage,
    required this.measurement,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat de mesure'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Statut de la mesure
              _buildStatusCard(),
              
              const SizedBox(height: 16),

              // Images
              _buildImagesSection(),
              
              const SizedBox(height: 24),

              // Mesures principales
              _buildMainMeasurementsCard(),
              
              const SizedBox(height: 16),

              // Mesures détaillées (si disponibles)
              if (measurement.heelToArchCm > 0) _buildDetailedMeasurementsCard(),
              
              const SizedBox(height: 16),

              // Estimation de pointure
              _buildShoeSizeCard(),
              
              const SizedBox(height: 24),

              // Boutons d'action
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasWarning = measurement.warningMessage != null;
    
    return Card(
      color: hasWarning ? Colors.orange.shade50 : measurement.calibrationColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              hasWarning ? Icons.warning : 
              (measurement.isCalibrated ? Icons.check_circle : Icons.info),
              color: hasWarning ? Colors.orange : measurement.calibrationColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasWarning ? 'Attention' : measurement.calibrationStatus,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasWarning ? Colors.orange.shade800 : measurement.calibrationColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasWarning ? measurement.warningMessage! : 
                    (measurement.isCalibrated 
                        ? 'Mesures calibrées avec QR code (précises)'
                        : 'Mesures estimées (moins précises)'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Image originale',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  originalImage, 
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Résultat analysé',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  processedImage, 
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainMeasurementsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Mesures principales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMeasurementItem(
                    'Longueur',
                    '${measurement.lengthCm.toStringAsFixed(1)} cm',
                    Icons.height,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMeasurementItem(
                    'Largeur',
                    '${measurement.widthCm.toStringAsFixed(1)} cm',
                    Icons.width_normal,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedMeasurementsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Mesures détaillées',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMeasurementItem(
              'Talon vers voûte plantaire',
              '${measurement.heelToArchCm.toStringAsFixed(1)} cm',
              Icons.straighten,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildMeasurementItem(
              'Voûte plantaire vers orteils',
              '${measurement.archToToeCm.toStringAsFixed(1)} cm',
              Icons.straighten,
              Colors.teal,
            ),
            const SizedBox(height: 12),
            _buildMeasurementItem(
              'Longueur gros orteil (estimation)',
              '${measurement.bigToeLengthCm.toStringAsFixed(1)} cm',
              Icons.straighten,
              Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShoeSizeCard() {
    return Card(
      elevation: 4,
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Changed from Icons.footprint to Icons.fitness_center which is available
                const Icon(Icons.fitness_center, color: Colors.indigo, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Estimation de pointure',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              measurement.calculatedShoeSize,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              measurement.isCalibrated 
                  ? 'Basé sur des mesures calibrées'
                  : 'Estimation approximative',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Nouvelle mesure'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share),
            label: const Text('Partager les résultats'),
            onPressed: () => _shareResults(context),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('À propos des mesures'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯 Mesures calibrées (QR):'),
            const Text('• Précision élevée grâce au QR code de référence'),
            const Text('• Recommandé pour des mesures exactes'),
            const SizedBox(height: 12),
            const Text('⚠️ Mesures estimées:'),
            const Text('• Basées sur une estimation de la résolution'),
            const Text('• Moins précises, à titre indicatif'),
            const SizedBox(height: 12),
            const Text('📏 Conseils:'),
            const Text('• Utilisez un QR code de 3cm pour plus de précision'),
            const Text('• Placez le pied bien à plat'),
            const Text('• Assurez-vous que tout le pied est visible'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _shareResults(BuildContext context) {
    // TODO: Implémenter le partage des résultats
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction de partage à implémenter'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}