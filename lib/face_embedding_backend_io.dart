// Real implementation — only ever compiled in on platforms where
// dart:library.io is available (Android/iOS/desktop), never web.
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbeddingInterpreter {
  final Interpreter _interpreter;
  FaceEmbeddingInterpreter._(this._interpreter);

  static Future<FaceEmbeddingInterpreter> load(String assetPath) async {
    final interpreter = await Interpreter.fromAsset(assetPath);
    return FaceEmbeddingInterpreter._(interpreter);
  }

  void run(Object input, Object output) => _interpreter.run(input, output);

  void close() => _interpreter.close();
}
