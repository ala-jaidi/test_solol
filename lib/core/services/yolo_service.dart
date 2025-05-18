import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class TFLiteYoloService {
  static const String modelPath = 'assets/ml/yolov8n-seg_float32.tflite';
  static const int inputSize = 640;
  static const double pixelToCmRatio = 0.026458;
  static const double confidenceThreshold = 0.1;
  Map<int, Object>? outputs;
  int bestIndex = -1;

  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<List<int>>? _outputShapes;
  int _numOutputs = 0;

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    debugPrint('TFLiteYoloService libéré');
  }

  Future<void> printModelInputShape() async {
    final interpreter = await Interpreter.fromAsset('assets/ml/yolov8n-seg_float32.tflite');
    var shape = interpreter.getInputTensor(0).shape;
    debugPrint('Forme attendue par le modèle : $shape');
    interpreter.close();
  }

  Future<ui.Image?> generateSegmentationMask(Map<int, Object> outputs, int bestIndex) async {
    final prototypes = outputs[1] as List;
    final prototypeData = prototypes[0];

    final detections = outputs[0] as List;
    final detectionData = detections[0];

    List<double> maskCoefficients = List.generate(
        32, (index) => detectionData[84 + index][bestIndex]);

    List<List<double>> mask = List.generate(
        160, (_) => List.filled(160, 0.0));

    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        double sum = 0.0;
        for (int c = 0; c < 32; c++) {
          sum += prototypeData[y][x][c] * maskCoefficients[c];
        }
        mask[y][x] = 1 / (1 + math.exp(-sum));
      }
    }

    final paint = ui.Paint()..color = ui.Color.fromARGB(150, 0, 255, 0);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, 160, 160));

    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        if (mask[y][x] > 0.5) {
          canvas.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
        }
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(160, 160);
    return img;
  }

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;

      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      _inputShape = _interpreter!.getInputTensor(0).shape;

      _numOutputs = _interpreter!.getOutputTensors().length;
      debugPrint('Nombre de tenseurs de sortie: $_numOutputs');

      _outputShapes = [];
      for (int i = 0; i < _numOutputs; i++) {
        final shape = _interpreter!.getOutputTensor(i).shape;
        _outputShapes!.add(shape);
        debugPrint('Forme du tenseur de sortie $i: $shape');
      }

      debugPrint('✅ Modèle YOLOv8-seg chargé');
      debugPrint('Forme du tenseur d\'entrée: $_inputShape');
    } catch (e) {
      debugPrint('❌ Erreur chargement modèle: $e');
      rethrow;
    }
  }

  Future<FootMeasurement?> runOnImage(img.Image image, int originalWidth, int originalHeight) async {
    if (_interpreter == null) await initialize();

    if (_interpreter == null || _inputShape == null || _outputShapes == null) {
      debugPrint('❌ Interpréteur non initialisé');
      return null;
    }

    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    final input = List.generate(1, (_) => List.generate(inputSize, (y) => List.generate(inputSize, (x) {
      final pixel = resized.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    })));

    final localOutputs = <int, Object>{};

    for (int i = 0; i < _numOutputs; i++) {
      localOutputs[i] = _createMultidimensionalList(_outputShapes![i]);
    }

    try {
      _interpreter!.runForMultipleInputs([input], localOutputs);
      debugPrint('✅ Inference exécutée avec succès');
      outputs = localOutputs;
      return _adaptiveParseOutputMultidimensional(localOutputs, originalWidth, originalHeight);
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'inférence: $e');
      debugPrint(StackTrace.current.toString());
      return null;
    }
  }

  dynamic _createMultidimensionalList(List<int> shape, [int index = 0]) {
    if (index >= shape.length - 1) {
      return Float32List(shape[index]);
    } else {
      return List.generate(shape[index], (_) => _createMultidimensionalList(shape, index + 1));
    }
  }

  FootMeasurement? _adaptiveParseOutputMultidimensional(
      Map<int, Object> outputs, int originalWidth, int originalHeight) {
    debugPrint('Traitement des 2 sorties du modèle YOLOv8-seg.');

    final boxesTensor = outputs[0] as List;
    final boxesData = boxesTensor[0];

    const int numBoxes = 8400;

    double bestScore = 0.0;
    Rect? bestBox;
    int bestI = -1;

    for (int i = 0; i < numBoxes; i++) {
      double confidence = boxesData[4][i];
      debugPrint("Détection $i → Confiance : $confidence");

      if (confidence < confidenceThreshold) continue;

      if (confidence > bestScore) {
        bestScore = confidence;
        bestI = i;

        double x = boxesData[0][i];
        double y = boxesData[1][i];
        double w = boxesData[2][i];
        double h = boxesData[3][i];

        final centerX = x * originalWidth;
        final centerY = y * originalHeight;
        final width = w * originalWidth;
        final height = h * originalHeight;

        bestBox = Rect.fromLTWH(
          centerX - width / 2,
          centerY - height / 2,
          width,
          height,
        );
      }
    }

    bestIndex = bestI;

    if (bestBox == null) {
      debugPrint('⚠️ Aucun pied détecté avec confiance suffisante.');
      return null;
    }

    final lengthCm = bestBox.height * pixelToCmRatio;
    final widthCm = bestBox.width * pixelToCmRatio;

    debugPrint('📏 Mesures (cm) obtenues : longueur=$lengthCm, largeur=$widthCm');

    return FootMeasurement(
      boundingBox: bestBox,
      lengthCm: lengthCm,
      widthCm: widthCm,
    );
  }
}

class FootMeasurement {
  final Rect boundingBox;
  final double lengthCm;
  final double widthCm;

  FootMeasurement({required this.boundingBox, required this.lengthCm, required this.widthCm});

  double getEuropeanSize() => (lengthCm * 1.5) + 2;
  double getUKSize() => (lengthCm - 23) * 3;
  double getUSSize(bool isMale) => isMale ? (lengthCm - 24) * 3 + 4 : (lengthCm - 22) * 3 + 5;
}
