import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Utilitaires pour la calibration de la mesure avec une feuille A4
class CalibrationUtils {
  /// Dimensions standards d'une feuille A4 en millimètres
  static const double a4Width = 210.0;  // mm
  static const double a4Height = 297.0; // mm
  static const double a4Ratio = a4Width / a4Height;

  /// Tolérance pour le ratio A4 (±10%)
  static const double ratioTolerance = 0.1;

  /// Vérifier si un rectangle correspond au ratio d'une feuille A4
  static bool isA4SheetRatio(double width, double height) {
    // S'assurer que width est toujours le côté le plus court
    if (width > height) {
      final temp = width;
      width = height;
      height = temp;
    }

    double ratio = width / height;
    double ratioDifference = (ratio - a4Ratio).abs();

    return ratioDifference < ratioTolerance;
  }

  /// Calculer le facteur de conversion pixels vers millimètres
  static double calculatePixelToMmFactor(
      double widthPx,
      double heightPx,
      {bool landscape = false}
      ) {
    // Si l'orientation est paysage, intervertir largeur et hauteur
    if (landscape) {
      final temp = widthPx;
      widthPx = heightPx;
      heightPx = temp;
    }

    // Calculer les facteurs de conversion
    double pxToMmFactorX = a4Width / widthPx;
    double pxToMmFactorY = a4Height / heightPx;

    // Moyenne des facteurs pour plus de précision
    return (pxToMmFactorX + pxToMmFactorY) / 2;
  }

  /// Déterminer si la feuille A4 est en orientation portrait ou paysage
  static bool isLandscapeOrientation(double width, double height) {
    return width > height;
  }

  /// Estimer le facteur de conversion en utilisant une référence connue (si disponible)
  static double estimatePixelToMmFactor(File imageFile) {
    try {
      // Cette fonction pourrait être améliorée avec des métadonnées EXIF ou
      // des caractéristiques de l'appareil photo

      // Facteur de conversion moyen basé sur des smartphones modernes
      // (approximativement 0.1mm par pixel à une distance de prise de vue d'environ 30cm)
      return 0.1;
    } catch (e) {
      debugPrint('Erreur lors de l\'estimation du facteur de conversion: $e');
      // Valeur par défaut
      return 0.1;
    }
  }

  /// Vérifier si les coins d'un rectangle forment approximativement un rectangle
  static bool isValidRectangle(List<Map<String, double>> corners) {
    if (corners.length != 4) return false;

    // Calculer les longueurs des côtés
    double side1 = _distance(corners[0], corners[1]);
    double side2 = _distance(corners[1], corners[2]);
    double side3 = _distance(corners[2], corners[3]);
    double side4 = _distance(corners[3], corners[0]);

    // Vérifier que les côtés opposés sont approximativement égaux
    bool oppositeSidesEqual =
        (_percentDifference(side1, side3) < 15) &&
            (_percentDifference(side2, side4) < 15);

    // Vérifier les angles (approximativement 90 degrés)
    // Pour un rectangle parfait, la somme des angles est 360 degrés
    // et chaque angle fait 90 degrés
    double angle1 = _calculateAngle(corners[0], corners[1], corners[2]);
    double angle2 = _calculateAngle(corners[1], corners[2], corners[3]);
    double angle3 = _calculateAngle(corners[2], corners[3], corners[0]);
    double angle4 = _calculateAngle(corners[3], corners[0], corners[1]);

    bool anglesValid =
        (angle1 > 75 && angle1 < 105) &&
            (angle2 > 75 && angle2 < 105) &&
            (angle3 > 75 && angle3 < 105) &&
            (angle4 > 75 && angle4 < 105);

    return oppositeSidesEqual && anglesValid;
  }

  // Calculer la distance entre deux points
  static double _distance(Map<String, double> p1, Map<String, double> p2) {
    double dx = p1['x']! - p2['x']!;
    double dy = p1['y']! - p2['y']!;
    return sqrt(dx * dx + dy * dy);
  }

  // Calculer le pourcentage de différence entre deux valeurs
  static double _percentDifference(double a, double b) {
    if (a == 0 && b == 0) return 0;
    return 100 * (a - b).abs() / ((a + b) / 2);
  }

  // Calculer l'angle entre trois points (en degrés)
  static double _calculateAngle(
      Map<String, double> p1,
      Map<String, double> p2,
      Map<String, double> p3
      ) {
    // Vecteur p1p2
    double v1x = p2['x']! - p1['x']!;
    double v1y = p2['y']! - p1['y']!;

    // Vecteur p3p2
    double v2x = p2['x']! - p3['x']!;
    double v2y = p2['y']! - p3['y']!;

    // Produit scalaire
    double dotProduct = v1x * v2x + v1y * v2y;

    // Normes des vecteurs
    double norm1 = sqrt(v1x * v1x + v1y * v1y);
    double norm2 = sqrt(v2x * v2x + v2y * v2y);

    // Angle en radians
    double angleRad = acos(dotProduct / (norm1 * norm2));

    // Conversion en degrés
    return angleRad * 180 / pi;
  }
}