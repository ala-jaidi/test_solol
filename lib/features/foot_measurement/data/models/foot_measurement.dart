import 'package:flutter/material.dart';

class FootMeasurement {
  final double lengthCm;
  final double widthCm;
  final double heelToArchCm;
  final double archToToeCm;
  final double bigToeLengthCm;
  final bool isCalibrated;
  final String estimatedShoeSize;

  FootMeasurement({
    required this.lengthCm,
    required this.widthCm,
    this.heelToArchCm = 0.0,
    this.archToToeCm = 0.0,
    this.bigToeLengthCm = 0.0,
    this.isCalibrated = false,
    this.estimatedShoeSize = 'N/A',
  });

  // Calculer la pointure européenne approximative
  String get calculatedShoeSize {
    if (lengthCm <= 0) return 'Mesure invalide';
    if (!isCalibrated) return 'Estimation: ${_calculateSize()}';
    
    return 'Pointure: ${_calculateSize()}';
  }
  
  String _calculateSize() {
    // Formule pointure européenne: (Longueur en cm + 1.5) * 1.5
    double size = (lengthCm + 1.5) * 1.5;
    return size.toStringAsFixed(0);
  }

  // Obtenir le statut de calibration en texte
  String get calibrationStatus {
    if (lengthCm <= 0) return 'ÉCHEC MESURE';
    return isCalibrated ? 'CALIBRÉ QR' : 'ESTIMÉ';
  }

  // Obtenir la couleur pour l'affichage du statut
  Color get calibrationColor {
    if (lengthCm <= 0) return Colors.red;
    return isCalibrated ? Colors.green : Colors.orange;
  }

  // Vérifier si les mesures sont valides
  bool get isValid {
    return lengthCm > 15.0 && lengthCm < 35.0 && 
           widthCm > 5.0 && widthCm < 15.0;
  }

  // Obtenir un message d'avertissement si les mesures sont suspectes
  String? get warningMessage {
    if (lengthCm <= 0) return 'Aucune mesure détectée';
    if (lengthCm < 15.0) return 'Longueur très petite (< 15cm)';
    if (lengthCm > 35.0) return 'Longueur très grande (> 35cm)';
    if (widthCm < 5.0) return 'Largeur très petite (< 5cm)';
    if (widthCm > 15.0) return 'Largeur très grande (> 15cm)';
    return null;
  }

  // Obtenir un niveau de confiance
  String get confidenceLevel {
    if (!isValid) return 'Faible';
    if (isCalibrated) return 'Élevée';
    return 'Moyenne';
  }

  // Obtenir une description de la méthode de mesure
  String get measurementMethod {
    if (lengthCm <= 0) return 'Échec de détection';
    if (isCalibrated) return 'QR Code de référence';
    return 'Estimation adaptative';
  }

  Map<String, dynamic> toJson() => {
    'lengthCm': lengthCm,
    'widthCm': widthCm,
    'heelToArchCm': heelToArchCm,
    'archToToeCm': archToToeCm,
    'bigToeLengthCm': bigToeLengthCm,
    'isCalibrated': isCalibrated,
    'estimatedShoeSize': estimatedShoeSize,
  };

  factory FootMeasurement.fromJson(Map<String, dynamic> json) {
    return FootMeasurement(
      lengthCm: json['lengthCm']?.toDouble() ?? 0.0,
      widthCm: json['widthCm']?.toDouble() ?? 0.0,
      heelToArchCm: json['heelToArchCm']?.toDouble() ?? 0.0,
      archToToeCm: json['archToToeCm']?.toDouble() ?? 0.0,
      bigToeLengthCm: json['bigToeLengthCm']?.toDouble() ?? 0.0,
      isCalibrated: json['isCalibrated'] ?? false,
      estimatedShoeSize: json['estimatedShoeSize'] ?? 'N/A',
    );
  }

  // Factory pour créer une mesure d'échec
  factory FootMeasurement.failed() {
    return FootMeasurement(
      lengthCm: 0.0,
      widthCm: 0.0,
      heelToArchCm: 0.0,
      archToToeCm: 0.0,
      bigToeLengthCm: 0.0,
      isCalibrated: false,
      estimatedShoeSize: 'Échec',
    );
  }

  // Factory pour mesure sans calibration (estimation uniquement)
  factory FootMeasurement.estimated(double length, double width) {
    return FootMeasurement(
      lengthCm: length,
      widthCm: width,
      heelToArchCm: length * 0.60,
      archToToeCm: length * 0.40,
      bigToeLengthCm: length * 0.15,
      isCalibrated: false,
      estimatedShoeSize: 'Estimation',
    );
  }

  // Factory pour compatibilité avec l'ancien code
  factory FootMeasurement.uncalibrated() {
    return FootMeasurement(
      lengthCm: 25.5,
      widthCm: 9.2,
      heelToArchCm: 15.3,
      archToToeCm: 10.2,
      bigToeLengthCm: 3.8,
      isCalibrated: false,
      estimatedShoeSize: 'Environ 41',
    );
  }

  // Copier avec modifications
  FootMeasurement copyWith({
    double? lengthCm,
    double? widthCm,
    double? heelToArchCm,
    double? archToToeCm,
    double? bigToeLengthCm,
    bool? isCalibrated,
    String? estimatedShoeSize,
  }) {
    return FootMeasurement(
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heelToArchCm: heelToArchCm ?? this.heelToArchCm,
      archToToeCm: archToToeCm ?? this.archToToeCm,
      bigToeLengthCm: bigToeLengthCm ?? this.bigToeLengthCm,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      estimatedShoeSize: estimatedShoeSize ?? this.estimatedShoeSize,
    );
  }

  @override
  String toString() {
    return 'FootMeasurement(L: ${lengthCm.toStringAsFixed(1)}cm, '
           'W: ${widthCm.toStringAsFixed(1)}cm, '
           'Calibré: $isCalibrated, '
           'Valide: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FootMeasurement &&
        other.lengthCm == lengthCm &&
        other.widthCm == widthCm &&
        other.isCalibrated == isCalibrated;
  }

  @override
  int get hashCode {
    return lengthCm.hashCode ^ widthCm.hashCode ^ isCalibrated.hashCode;
  }
}