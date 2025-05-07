import 'dart:math';
import 'package:flutter/foundation.dart';

/// Classe utilitaire pour calculer les mesures du pied
class FootCalculator {
  /// Calculer la longueur du pied à partir des points clés
  static double calculateFootLength(
      List<Map<String, double>> keyPoints,
      double pixelToMmFactor
      ) {
    try {
      // Filtrer les points avec une confiance suffisante
      var validPoints = keyPoints.where((point) =>
      point['confidence'] != null && point['confidence']! > 0.5
      ).toList();

      if (validPoints.isEmpty) {
        throw Exception('Aucun point valide détecté');
      }

      // Trouver les points extrêmes sur l'axe Y (longueur)
      double minY = validPoints.map((p) => p['y']!).reduce(min);
      double maxY = validPoints.map((p) => p['y']!).reduce(max);

      // Calculer la longueur en pixels puis convertir en mm
      double lengthPx = maxY - minY;
      return lengthPx * pixelToMmFactor;
    } catch (e) {
      debugPrint('Erreur lors du calcul de la longueur du pied: $e');
      rethrow;
    }
  }

  /// Calculer la largeur du pied à partir des points clés
  static double calculateFootWidth(
      List<Map<String, double>> keyPoints,
      double pixelToMmFactor
      ) {
    try {
      // Filtrer les points avec une confiance suffisante
      var validPoints = keyPoints.where((point) =>
      point['confidence'] != null && point['confidence']! > 0.5
      ).toList();

      if (validPoints.isEmpty) {
        throw Exception('Aucun point valide détecté');
      }

      // Trouver les points extrêmes sur l'axe X (largeur)
      double minX = validPoints.map((p) => p['x']!).reduce(min);
      double maxX = validPoints.map((p) => p['x']!).reduce(max);

      // Calculer la largeur en pixels puis convertir en mm
      double widthPx = maxX - minX;
      return widthPx * pixelToMmFactor;
    } catch (e) {
      debugPrint('Erreur lors du calcul de la largeur du pied: $e');
      rethrow;
    }
  }

  /// Estimer la pointure de chaussure à partir de la longueur du pied
  static double estimateShoeSize(double footLengthMm, {String system = 'EU'}) {
    try {
      switch (system) {
        case 'EU': // Système européen
        // Formule approximative: pointure EU = (longueur en mm - 10) / 6.67
          return (footLengthMm - 10) / 6.67;

        case 'UK': // Système britannique
        // Formule approximative: pointure UK = (longueur en mm - 10) / 8.47 - 23
          return (footLengthMm - 10) / 8.47 - 23;

        case 'US_MEN': // Système américain hommes
        // Formule approximative: pointure US hommes = (longueur en mm - 10) / 8.47 - 22
          return (footLengthMm - 10) / 8.47 - 22;

        case 'US_WOMEN': // Système américain femmes
        // Formule approximative: pointure US femmes = (longueur en mm - 10) / 8.47 - 20.5
          return (footLengthMm - 10) / 8.47 - 20.5;

        default:
          return (footLengthMm - 10) / 6.67; // Par défaut, système EU
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'estimation de la pointure: $e');
      rethrow;
    }
  }

  /// Extraire les points spécifiques du pied (talon, pointe, etc.)
  static Map<String, Map<String, double>> extractSpecificFootPoints(
      List<Map<String, double>> keyPoints
      ) {
    try {
      var validPoints = keyPoints.where((point) =>
      point['confidence'] != null && point['confidence']! > 0.5
      ).toList();

      if (validPoints.isEmpty) {
        throw Exception('Aucun point valide détecté');
      }

      // Trouver les points extrêmes
      double minY = validPoints.map((p) => p['y']!).reduce(min);
      double maxY = validPoints.map((p) => p['y']!).reduce(max);
      double minX = validPoints.map((p) => p['x']!).reduce(min);
      double maxX = validPoints.map((p) => p['x']!).reduce(max);

      // Obtenir les points aux extrémités
      var heelPoint = validPoints.firstWhere((p) => p['y']! >= maxY * 0.95);
      var toePoint = validPoints.firstWhere((p) => p['y']! <= minY * 1.05);
      var innerPoint = validPoints.firstWhere((p) => p['x']! <= minX * 1.05);
      var outerPoint = validPoints.firstWhere((p) => p['x']! >= maxX * 0.95);

      return {
        'heel': heelPoint,
        'toe': toePoint,
        'inner': innerPoint,
        'outer': outerPoint,
      };
    } catch (e) {
      debugPrint('Erreur lors de l\'extraction des points spécifiques: $e');

      // En cas d'erreur, renvoyer un ensemble de points par défaut
      return {
        'heel': {'x': 0, 'y': 0, 'confidence': 0},
        'toe': {'x': 0, 'y': 0, 'confidence': 0},
        'inner': {'x': 0, 'y': 0, 'confidence': 0},
        'outer': {'x': 0, 'y': 0, 'confidence': 0},
      };
    }
  }

  /// Calculer l'indice de largeur du pied (ratio largeur/longueur)
  static double calculateFootWidthIndex(double width, double length) {
    return width / length;
  }

  /// Déterminer la catégorie de largeur du pied
  static String determineFootWidthCategory(double widthIndex) {
    if (widthIndex < 0.35) {
      return 'Étroit';
    } else if (widthIndex < 0.40) {
      return 'Normal';
    } else if (widthIndex < 0.45) {
      return 'Large';
    } else {
      return 'Très large';
    }
  }
}