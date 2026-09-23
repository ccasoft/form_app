// ─────────────────────────────────────────────────────────────────────────────
//  Face Auth Service
//
//  Two separate jobs, deliberately not the same thing:
//   1. DETECTION (google_mlkit_face_detection) — finds a face in the
//      frame, its landmarks, and eye-open probabilities. Used to guide
//      the user and to require a blink (basic liveness check, so a
//      printed photo held up to the camera won't match).
//   2. RECOGNITION (mobilefacenet.tflite) — turns a cropped, aligned
//      112x112 face into a 192-dim embedding vector. Identity matching
//      (whose face is this) happens server-side by comparing this
//      vector against every enrolled user's stored vector — see
//      /auth/face/login in server.js. This service only ever produces
//      the vector; it never decides "who" on its own.
//
//  Mobile only — no web support (camera + tflite_flutter are not
//  reliable on Flutter Web). Callers should check kIsWeb before
//  offering face login/enrollment at all.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:form_app/face_embedding_backend.dart';
import 'package:image/image.dart' as img;

class FaceAuthService {
  FaceAuthService._();
  static final FaceAuthService instance = FaceAuthService._();

  FaceEmbeddingInterpreter? _interpreter;
  FaceDetector? _detector;

  static const int _inputSize = 112;
  static const int _embeddingSize = 192;

  Future<void> init() async {
    _interpreter ??= await FaceEmbeddingInterpreter.load('assets/mobilefacenet.tflite');
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // needed for eye-open probabilities (liveness)
        enableLandmarks: false,
        enableContours: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  void dispose() {
    _detector?.close();
    _interpreter?.close();
    _detector = null;
    _interpreter = null;
  }

  /// Detect faces from a live camera InputImage (for the stream path,
  /// as opposed to [detectFacesInFile] used on a captured still).
  Future<List<Face>> detectFacesFromInputImage(InputImage inputImage) async {
    if (_detector == null) {
      throw StateError('FaceAuthService.init() must be called first.');
    }
    return _detector!.processImage(inputImage);
  }

  /// Detect faces in a still image file (e.g. a just-captured photo).
  /// Returns an empty list if none found. Throws if init() wasn't called.
  Future<List<Face>> detectFacesInFile(String imagePath) async {
    if (_detector == null) {
      throw StateError('FaceAuthService.init() must be called first.');
    }
    final inputImage = InputImage.fromFilePath(imagePath);
    return _detector!.processImage(inputImage);
  }

  /// True if either eye-open probability is available and below
  /// [threshold] — i.e. the person blinked. Both must be non-null;
  /// if the detector couldn't tell (dark image, side profile), returns
  /// false rather than guessing.
  bool isEyesClosed(Face face, {double threshold = 0.4}) {
    final l = face.leftEyeOpenProbability;
    final r = face.rightEyeOpenProbability;
    if (l == null || r == null) return false;
    return l < threshold && r < threshold;
  }

  bool isEyesOpen(Face face, {double threshold = 0.7}) {
    final l = face.leftEyeOpenProbability;
    final r = face.rightEyeOpenProbability;
    if (l == null || r == null) return false;
    return l > threshold && r > threshold;
  }

  /// Crops the face out of the image at [imagePath] using [face]'s
  /// bounding box (with a small margin), resizes to 112x112, and
  /// returns the 192-dim embedding vector from MobileFaceNet.
  Future<List<double>> getEmbeddingFromFile(String imagePath, Face face) async {
    if (_interpreter == null) {
      throw StateError('FaceAuthService.init() must be called first.');
    }
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('Could not decode captured image.');

    // Add ~25% margin around the detected box so the crop isn't overly
    // tight (MobileFaceNet expects a bit of context around the face).
    final box = face.boundingBox;
    final marginX = box.width * 0.25;
    final marginY = box.height * 0.25;
    final left = (box.left - marginX).clamp(0, decoded.width.toDouble()).toInt();
    final top = (box.top - marginY).clamp(0, decoded.height.toDouble()).toInt();
    final right = (box.right + marginX).clamp(0, decoded.width.toDouble()).toInt();
    final bottom = (box.bottom + marginY).clamp(0, decoded.height.toDouble()).toInt();
    final cropW = (right - left).clamp(1, decoded.width);
    final cropH = (bottom - top).clamp(1, decoded.height);

    final cropped = img.copyCrop(decoded, x: left, y: top, width: cropW, height: cropH);
    final resized = img.copyResize(cropped, width: _inputSize, height: _inputSize);

    // Normalize to [-1, 1], NHWC float32, as MobileFaceNet expects.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [
              (p.r / 127.5) - 1.0,
              (p.g / 127.5) - 1.0,
              (p.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_embeddingSize, 0.0));
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }

  double euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]) * (a[i] - b[i]);
    }
    return sqrt(sum);
  }
}
