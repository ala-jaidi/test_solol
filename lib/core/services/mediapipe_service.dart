import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class MediaPipeService {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/ml/pose_landmark_full.tflite');
  }

  List<dynamic> runInference(Uint8List imageBytes) {
    final input = imageBytes.buffer.asUint8List();
    var output = List.filled(1 * 195, 0.0).reshape([1, 195]);
    _interpreter.run(input, output);
    return output;
  }

  void dispose() {
    _interpreter.close();
  }
}
