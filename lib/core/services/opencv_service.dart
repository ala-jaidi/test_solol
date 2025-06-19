import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

import '../../features/foot_measurement/data/models/foot_measurement.dart';

// Typedefs pour les fonctions natives
typedef TestFunctionNative = Int32 Function();
typedef TestFunctionDart = int Function();

typedef ProcessImageNative = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize);
typedef ProcessImageDart = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize);

typedef RemoveBackgroundNative = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize);
typedef RemoveBackgroundDart = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize);

typedef MeasureFootWithQRNative = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize, Double qrSize);
typedef MeasureFootWithQRDart = Pointer<Uint8> Function(Pointer<Utf8> path, Pointer<Int32> outSize, double qrSize);

typedef ExtractFootMeasurementsNative = Pointer<Double> Function(Pointer<Utf8> path, Double qrSize);
typedef ExtractFootMeasurementsDart = Pointer<Double> Function(Pointer<Utf8> path, double qrSize);

typedef FreeMemoryNative = Void Function(Pointer<Uint8> ptr);
typedef FreeMemoryDart = void Function(Pointer<Uint8> ptr);

class OpenCVService {
  static DynamicLibrary? _lib;
  static TestFunctionDart? _testFunction;
  static ProcessImageDart? _processImage;
  static RemoveBackgroundDart? _removeBackground;
  static MeasureFootWithQRDart? _measureFootWithQR;
  static ExtractFootMeasurementsDart? _extractFootMeasurements;
  static FreeMemoryDart? _freeMemory;

  static bool _initialized = false;

  /// Initialise le service OpenCV
  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      print('🔧 Initialisation OpenCV Service...');

      // Chargement de la bibliothèque native
      if (Platform.isAndroid) {
        try {
          _lib = DynamicLibrary.open('libnative_opencv.so');
          print('✅ libnative_opencv.so chargée');
        } catch (e) {
          print('⚠️ Échec libnative_opencv.so: $e');
          try {
            _lib = DynamicLibrary.open('native_opencv.so');
            print('✅ native_opencv.so chargée');
          } catch (e2) {
            print('❌ Échec chargement bibliothèque: $e2');
            return false;
          }
        }
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
        print('✅ Bibliothèque iOS chargée');
      } else {
        print('❌ Plateforme non supportée: ${Platform.operatingSystem}');
        return false;
      }

      if (_lib == null) {
        print('❌ Bibliothèque native non chargée');
        return false;
      }

      // Liaison des fonctions
      try {
        // Test de base
        _testFunction = _lib!.lookupFunction<TestFunctionNative, TestFunctionDart>('testFunction');
        final testResult = _testFunction!();
        
        if (testResult != 42) {
          print('❌ Test function invalide: $testResult');
          return false;
        }
        print('🧪 Test function OK: $testResult');
        
        // Fonctions de base
        _processImage = _lib!.lookupFunction<ProcessImageNative, ProcessImageDart>('processImage');
        _removeBackground = _lib!.lookupFunction<RemoveBackgroundNative, RemoveBackgroundDart>('removeBackground');
        _freeMemory = _lib!.lookupFunction<FreeMemoryNative, FreeMemoryDart>('freeMemory');
        print('✅ Fonctions de base liées');
        
        // Nouvelles fonctions QR
        try {
          _measureFootWithQR = _lib!.lookupFunction<MeasureFootWithQRNative, MeasureFootWithQRDart>('measureFootWithQR');
          _extractFootMeasurements = _lib!.lookupFunction<ExtractFootMeasurementsNative, ExtractFootMeasurementsDart>('extractFootMeasurements');
          print('✅ Fonctions QR robustes liées');
        } catch (e) {
          print('⚠️ Fonctions QR non disponibles: $e');
        }
        
      } catch (e) {
        print('❌ Erreur liaison fonctions: $e');
        return false;
      }

      _initialized = true;
      print('🎉 OpenCV Service initialisé!');
      print('   QR disponible: ${isQRFunctionsAvailable ? "OUI" : "NON"}');
      return true;
    } catch (e) {
      print('❌ Erreur critique initialisation: $e');
      return false;
    }
  }

  /// Mesure du pied avec QR code robuste
  static Future<Uint8List?> measureFootWithQR(Uint8List imageBytes, {double qrSizeCm = 3.0}) async {
    print('🔍 measureFootWithQR robuste (QR: ${qrSizeCm}cm)');

    if (!_initialized) {
      await initialize();
    }

    if (_measureFootWithQR == null) {
      print('⚠️ measureFootWithQR non disponible, fallback');
      return await removeBackground(imageBytes);
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final pathPointer = tempFile.path.toNativeUtf8();
      final sizePointer = malloc<Int32>();
      
      final resultPointer = _measureFootWithQR!(pathPointer, sizePointer, qrSizeCm);
      final resultSize = sizePointer.value;

      if (resultSize == 0 || resultPointer == nullptr) {
        print('❌ Échec measureFootWithQR, fallback');
        malloc.free(pathPointer);
        malloc.free(sizePointer);
        await tempFile.delete();
        return await removeBackground(imageBytes);
      }

      final result = Uint8List.fromList(resultPointer.asTypedList(resultSize));

      _freeMemory!(resultPointer);
      malloc.free(pathPointer);
      malloc.free(sizePointer);
      await tempFile.delete();

      print('✅ Mesure QR réussie (${result.length} bytes)');
      return result;
    } catch (e) {
      print('❌ Erreur measureFootWithQR: $e');
      return await removeBackground(imageBytes);
    }
  }

  /// Extraction des mesures détaillées
  static Future<FootMeasurement> extractFootMeasurements(Uint8List imageBytes, {double qrSizeCm = 3.0}) async {
    print('📏 extractFootMeasurements (QR: ${qrSizeCm}cm)');

    if (!_initialized) {
      await initialize();
    }

    if (_extractFootMeasurements == null) {
      print('⚠️ extractFootMeasurements non disponible');
      return FootMeasurement.failed();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/extract_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final pathPointer = tempFile.path.toNativeUtf8();
      
      final resultPointer = _extractFootMeasurements!(pathPointer, qrSizeCm);

      if (resultPointer == nullptr) {
        print('❌ Échec extraction mesures');
        malloc.free(pathPointer);
        await tempFile.delete();
        return FootMeasurement.failed();
      }

      // Lecture des 6 valeurs: [length, width, heel_to_arch, arch_to_toe, big_toe, is_calibrated]
      final measurements = resultPointer.asTypedList(6);
      
      print('📊 Mesures extraites:');
      print('   Longueur: ${measurements[0].toStringAsFixed(2)}cm');
      print('   Largeur: ${measurements[1].toStringAsFixed(2)}cm');
      print('   Calibré: ${measurements[5] > 0.5 ? "OUI" : "NON"}');
      
      final footMeasurement = FootMeasurement(
        lengthCm: measurements[0],
        widthCm: measurements[1],
        heelToArchCm: measurements[2],
        archToToeCm: measurements[3],
        bigToeLengthCm: measurements[4],
        isCalibrated: measurements[5] > 0.5,
      );

      // Libération mémoire
      malloc.free(resultPointer.cast<Void>());
      malloc.free(pathPointer);
      await tempFile.delete();

      if (!footMeasurement.isValid) {
        print('⚠️ Mesures suspectes: ${footMeasurement.warningMessage}');
      }

      print('✅ Extraction terminée');
      return footMeasurement;
    } catch (e) {
      print('❌ Erreur extraction: $e');
      return FootMeasurement.failed();
    }
  }

  /// Traitement complet avec QR
  static Future<ProcessingResult?> processFootWithQR(Uint8List imageBytes, {double qrSizeCm = 3.0}) async {
    print('🚀 Traitement complet avec QR');

    try {
      // Traitement image
      final processedImage = await measureFootWithQR(imageBytes, qrSizeCm: qrSizeCm);
      if (processedImage == null) {
        print('❌ Échec traitement image');
        return null;
      }

      // Extraction mesures
      final measurements = await extractFootMeasurements(imageBytes, qrSizeCm: qrSizeCm);

      return ProcessingResult(
        processedImageBytes: processedImage,
        measurement: measurements,
        hasQRCalibration: measurements.isCalibrated,
      );
    } catch (e) {
      print('❌ Erreur traitement complet: $e');
      return null;
    }
  }

  /// Suppression d'arrière-plan (fallback)
  static Future<Uint8List?> removeBackground(Uint8List imageBytes) async {
    print('🔄 removeBackground');

    if (!_initialized) {
      await initialize();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final pathPointer = tempFile.path.toNativeUtf8();
      final sizePointer = malloc<Int32>();
      
      final resultPointer = _removeBackground!(pathPointer, sizePointer);
      final resultSize = sizePointer.value;

      if (resultSize == 0 || resultPointer == nullptr) {
        malloc.free(pathPointer);
        malloc.free(sizePointer);
        await tempFile.delete();
        return null;
      }

      final result = Uint8List.fromList(resultPointer.asTypedList(resultSize));

      _freeMemory!(resultPointer);
      malloc.free(pathPointer);
      malloc.free(sizePointer);
      await tempFile.delete();

      print('✅ removeBackground OK');
      return result;
    } catch (e) {
      print('❌ Erreur removeBackground: $e');
      return null;
    }
  }

  /// Traitement Canny
  static Future<Uint8List?> processImageCanny(Uint8List imageBytes) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/canny_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);

      final pathPointer = tempFile.path.toNativeUtf8();
      final sizePointer = malloc<Int32>();
      
      final resultPointer = _processImage!(pathPointer, sizePointer);
      final resultSize = sizePointer.value;

      if (resultSize == 0 || resultPointer == nullptr) {
        malloc.free(pathPointer);
        malloc.free(sizePointer);
        await tempFile.delete();
        return null;
      }

      final result = Uint8List.fromList(resultPointer.asTypedList(resultSize));

      _freeMemory!(resultPointer);
      malloc.free(pathPointer);
      malloc.free(sizePointer);
      await tempFile.delete();

      return result;
    } catch (e) {
      print('❌ Erreur Canny: $e');
      return null;
    }
  }

  /// Fonction legacy pour compatibilité
  @Deprecated('Utilisez extractFootMeasurements à la place')
  static FootMeasurement? analyzeMeasurement(Uint8List processedImageBytes) {
    print('⚠️ analyzeMeasurement deprecated');
    return FootMeasurement.failed();
  }

  /// Utilitaires
  static bool get isQRFunctionsAvailable {
    return _measureFootWithQR != null && _extractFootMeasurements != null;
  }

  static bool get isInitialized => _initialized;

  /// Nettoyage des ressources
  static void dispose() {
    print('🧹 Nettoyage OpenCV Service');
    _initialized = false;
    _lib = null;
    _testFunction = null;
    _processImage = null;
    _removeBackground = null;
    _measureFootWithQR = null;
    _extractFootMeasurements = null;
    _freeMemory = null;
  }
}

/// Classe pour les résultats de traitement
class ProcessingResult {
  final Uint8List processedImageBytes;
  final FootMeasurement measurement;
  final Rect? boundingBox;
  final List<Offset>? keyPoints;
  final bool hasQRCalibration;
  final DateTime processedAt;

  ProcessingResult({
    required this.processedImageBytes,
    required this.measurement,
    this.boundingBox,
    this.keyPoints,
    this.hasQRCalibration = false,
  }) : processedAt = DateTime.now();

  bool get isValid => measurement.isValid;
  
  String get statusMessage {
    if (!isValid) return 'Mesures invalides';
    if (hasQRCalibration) return 'Mesures calibrées (précises)';
    return 'Mesures estimées';
  }

  Color get statusColor {
    if (!isValid) return Colors.red;
    if (hasQRCalibration) return Colors.green;
    return Colors.orange;
  }

  String get confidenceDescription {
    if (!isValid) return 'Échec de détection';
    if (hasQRCalibration) return 'Confiance élevée (QR détecté)';
    return 'Confiance moyenne (estimation)';
  }

  Map<String, dynamic> toJson() => {
    'measurement': measurement.toJson(),
    'hasQRCalibration': hasQRCalibration,
    'processedAt': processedAt.toIso8601String(),
    'isValid': isValid,
  };
}