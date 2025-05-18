import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service qui utilise MediaPipe et ML Kit pour la détection et mesure précise des pieds.
/// Conçu pour des applications médicales et sanitaires nécessitant des mesures fiables.
class MediaPipeService {
  /// Constantes pour la détection et la validation
  static const double _boundingBoxMargin = 20.0;
  static const double _requiredConfidenceThreshold = 0.90; // Confiance élevée pour usage médical
  static const double _minFootLengthCm = 15.0; // Taille minimale pour un pied adulte
  static const double _maxFootLengthCm = 35.0; // Taille maximale pour un pied adulte
  static const double _maxAspectRatio = 3.0;
  static const double _defaultPixelToCmRatio = 0.026458; // Ratio par défaut

  /// Options de détection optimisées pour la précision médicale
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.accurate,
    ),
  );

  /// Ratio de conversion pixels vers centimètres (calibrable)
  double _pixelToCmRatio = _defaultPixelToCmRatio;

  /// Historique des mesures récentes pour le filtrage
  final List<double> _recentMeasurements = [];
  static const int _maxMeasurementsHistory = 5;

  /// Calibre le système avec une distance connue en centimètres
  /// entre deux points de référence sur l'image
  ///
  /// [realLengthCm] est la mesure réelle en centimètres entre les points de calibration
  /// [calibrationPoints] est une liste de deux points de calibration, chacun représenté par [x, y]
  Future<void> calibrate(double realLengthCm, List<List<double>> calibrationPoints) async {
    if (calibrationPoints.length != 2 ||
        calibrationPoints[0].length < 2 ||
        calibrationPoints[1].length < 2) {
      throw ArgumentError('La calibration nécessite exactement deux points valides');
    }

    final dx = (calibrationPoints[0][0] - calibrationPoints[1][0]).abs();
    final dy = (calibrationPoints[0][1] - calibrationPoints[1][1]).abs();
    final distancePx = sqrt(dx * dx + dy * dy);

    if (distancePx <= 0) {
      throw ArgumentError('Les points de calibration doivent être distincts');
    }

    _pixelToCmRatio = realLengthCm / distancePx;
    debugPrint('✅ Calibration réussie: $_pixelToCmRatio cm/px');
  }

  /// Traite une image pour détecter et mesurer un pied
  ///
  /// [inputImage] est l'image à analyser
  /// [width] est la largeur de l'image en pixels
  /// [height] est la hauteur de l'image en pixels
  ///
  /// Retourne les mesures du pied ou null si aucun pied n'est détecté avec confiance
  Future<FootMeasurement?> processInputImage(InputImage inputImage, int width, int height) async {
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) return null;

      return _processPose(poses.first, width, height);
    } catch (e) {
      debugPrint('❌ Erreur de traitement: $e');
      return null;
    }
  }

  /// Traite une pose détectée pour extraire les mesures du pied
  FootMeasurement? _processPose(Pose pose, int width, int height) {
    // Recherche une paire talon/orteil valide (droite ou gauche)
    final footPair = _findValidFootPair(pose.landmarks);
    if (footPair == null) return null;

    final (heel, toe) = footPair;
    final lengthCm = _calculateDistance(heel, toe, width, height);
    final widthCm = _estimateFootWidth(lengthCm);

    // Validation des mesures pour usage médical
    if (!_validateMeasurements(heel, toe, width, height, lengthCm)) return null;

    // Appliquer un filtre pour stabiliser les mesures
    final smoothedLengthCm = _applyMeasurementFilter(lengthCm);

    // Créer la zone englobante avec une marge adéquate
    final boundingBox = _createBoundingBox(heel, toe, width, height);

    return FootMeasurement(
      landmarks: [
        [heel.x, heel.y, heel.likelihood],
        [toe.x, toe.y, toe.likelihood],
      ],
      lengthCm: smoothedLengthCm,
      widthCm: widthCm,
      boundingBox: boundingBox,
      footSide: _determineFootSide(heel, toe),
    );
  }

  /// Valide les mesures obtenues selon des critères médicaux
  bool _validateMeasurements(PoseLandmark heel, PoseLandmark toe, int w, int h, double lengthCm) {
    // Vérification de la plage de taille anatomiquement plausible
    if (lengthCm < _minFootLengthCm || lengthCm > _maxFootLengthCm) {
      debugPrint('⚠️ Mesure hors plage anatomique: ${lengthCm.toStringAsFixed(1)}cm');
      return false;
    }

    // Vérification de la proportion (rapport largeur/longueur)
    final dx = (heel.x - toe.x).abs() * w;
    final dy = (heel.y - toe.y).abs() * h;
    if (dx == 0) return false;

    final aspectRatio = dy / dx;
    if (aspectRatio > _maxAspectRatio) {
      debugPrint('⚠️ Proportion anatomique incorrecte: ${aspectRatio.toStringAsFixed(2)}');
      return false;
    }

    // Vérification de l'orientation (talon doit être plus bas que l'orteil dans l'image)
    if (heel.y < toe.y) {
      debugPrint('⚠️ Orientation anatomique incorrecte');
      return false;
    }

    return true;
  }

  /// Identifie une paire talon/orteil valide parmi les points détectés
  (PoseLandmark, PoseLandmark)? _findValidFootPair(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    const pairs = [
      [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
      [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
    ];

    (PoseLandmark, PoseLandmark)? bestPair;
    double highestConfidence = 0;

    for (final pair in pairs) {
      final heel = landmarks[pair[0]];
      final toe = landmarks[pair[1]];

      if (heel != null && toe != null &&
          heel.likelihood >= _requiredConfidenceThreshold &&
          toe.likelihood >= _requiredConfidenceThreshold) {

        // Calcul de la confiance moyenne de la paire
        final pairConfidence = (heel.likelihood + toe.likelihood) / 2;

        // Sélectionner la paire avec la confiance la plus élevée
        if (pairConfidence > highestConfidence) {
          highestConfidence = pairConfidence;
          bestPair = (heel, toe);
        }
      }
    }

    return bestPair;
  }

  /// Calcule la distance réelle en centimètres entre deux points
  double _calculateDistance(PoseLandmark p1, PoseLandmark p2, int w, int h) {
    final dx = (p1.x - p2.x) * w;
    final dy = (p1.y - p2.y) * h;
    return sqrt(dx * dx + dy * dy) * _pixelToCmRatio;
  }

  /// Crée un rectangle englobant autour du pied détecté
  Rect _createBoundingBox(PoseLandmark heel, PoseLandmark toe, int w, int h) {
    // Calcul de la largeur estimée du pied pour ajuster le rectangle
    final footLengthPx = (heel.x - toe.x).abs() * w;
    final estimatedWidthPx = footLengthPx * 0.4; // Ratio anatomique approximatif

    final centerX = (heel.x + toe.x) / 2;

    final left = min(heel.x, toe.x) * w - _boundingBoxMargin;
    final right = max(heel.x, toe.x) * w + _boundingBoxMargin;
    final top = min(heel.y, toe.y) * h - _boundingBoxMargin - estimatedWidthPx/2;
    final bottom = max(heel.y, toe.y) * h + _boundingBoxMargin;

    return Rect.fromLTRB(
      left.clamp(0, w.toDouble()),
      top.clamp(0, h.toDouble()),
      right.clamp(0, w.toDouble()),
      bottom.clamp(0, h.toDouble()),
    );
  }

  /// Estime la largeur du pied en centimètres basée sur la longueur
  /// en utilisant des ratios anatomiques standards
  double _estimateFootWidth(double lengthCm) {
    // Ratio anatomique moyen: largeur ≈ 40% de la longueur
    return lengthCm * 0.4;
  }

  /// Applique un filtre de moyenne mobile pour stabiliser les mesures
  double _applyMeasurementFilter(double newMeasurement) {
    _recentMeasurements.add(newMeasurement);

    // Limiter la taille de l'historique
    if (_recentMeasurements.length > _maxMeasurementsHistory) {
      _recentMeasurements.removeAt(0);
    }

    // Calculer la moyenne des mesures récentes
    return _recentMeasurements.reduce((a, b) => a + b) / _recentMeasurements.length;
  }

  /// Détermine s'il s'agit du pied gauche ou droit
  FootSide _determineFootSide(PoseLandmark heel, PoseLandmark toe) {
    // Cette logique est simplifiée et pourrait être améliorée avec d'autres points de référence
    if (heel.type == PoseLandmarkType.leftHeel || toe.type == PoseLandmarkType.leftFootIndex) {
      return FootSide.left;
    } else {
      return FootSide.right;
    }
  }

  /// Libère les ressources utilisées par le détecteur
  void dispose() {
    _poseDetector.close();
    _recentMeasurements.clear();
    debugPrint('MediaPipeService libéré');
  }
}

/// Énumération des côtés du pied
enum FootSide { left, right }

/// Classe contenant les mesures détaillées du pied
class FootMeasurement {
  /// Points clés détectés [x, y, confiance]
  final List<List<double>> landmarks;

  /// Longueur du pied en centimètres
  final double lengthCm;

  /// Largeur estimée du pied en centimètres
  final double widthCm;

  /// Rectangle englobant le pied sur l'image
  final Rect boundingBox;

  /// Côté du pied (gauche ou droit)
  final FootSide footSide;

  /// Crée une instance des mesures du pied
  FootMeasurement({
    required this.landmarks,
    required this.lengthCm,
    required this.widthCm,
    required this.boundingBox,
    this.footSide = FootSide.right,
  });

  /// Convertit les mesures en pointure européenne standard
  double getEuropeanShoeSize() {
    // Formule approximative: EU size = (Foot length in cm * 1.5) + 2
    return (lengthCm * 1.5) + 2;
  }

  /// Convertit les mesures en pointure UK standard
  double getUKShoeSize() {
    // Formule approximative: UK size = (Foot length in cm - 23) * 3
    return (lengthCm - 23) * 3;
  }

  /// Convertit les mesures en pointure US standard
  double getUSShoeSize(bool isMale) {
    // Formule approximative avec différenciation homme/femme
    if (isMale) {
      return (lengthCm - 24) * 3 + 4;
    } else {
      return (lengthCm - 22) * 3 + 5;
    }
  }
}