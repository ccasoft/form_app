// ─────────────────────────────────────────────────────────────────────────────
//  Face Capture Widget — shared by face login and face enrollment.
//
//  Flow: show camera preview → wait for a face → require a blink
//  (liveness — stops someone just holding up a photo) → take a still
//  photo → run detection + embedding extraction on the still →
//  return the 192-dim embedding via [onCaptured].
//
//  NOTE: the live-frame face detection (used only to know when to
//  prompt "blink now") uses the standard CameraImage → InputImage
//  conversion pattern for ML Kit. Camera plane formats differ by
//  device/OS in ways that are only really verifiable on real
//  hardware — test on your actual target devices before relying on
//  this in production, especially front-camera orientation on iOS.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:form_app/face_auth_service.dart';

enum _Stage { waitingForFace, waitingForBlink, capturing, processing }

class FaceCaptureWidget extends StatefulWidget {
  /// Called once a still is captured and a face + embedding were
  /// successfully extracted from it. Receives the 192-dim embedding.
  final Future<void> Function(List<double> embedding) onCaptured;
  final String instructionText;

  const FaceCaptureWidget({
    super.key,
    required this.onCaptured,
    this.instructionText = 'Center your face in the frame',
  });

  @override
  State<FaceCaptureWidget> createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget> {
  CameraController? _controller;
  _Stage _stage = _Stage.waitingForFace;
  String? _error;
  bool _wasEyesOpen = false;
  bool _blinkDetected = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      await FaceAuthService.instance.init();
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _controller!.startImageStream(_onFrame);
    } catch (e) {
      setState(() => _error = 'Camera setup failed: $e');
    }
  }

  void _onFrame(CameraImage image) async {
    if (_busy || _stage == _Stage.capturing || _stage == _Stage.processing)
      return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage == null) return;
      final faces =
          await FaceAuthService.instance.detectFacesFromInputImage(inputImage);

      if (faces.isEmpty) {
        if (_stage != _Stage.waitingForFace) {
          setState(() {
            _stage = _Stage.waitingForFace;
            _blinkDetected = false;
          });
        }
        return;
      }

      final face = faces.first;
      if (_stage == _Stage.waitingForFace) {
        setState(() => _stage = _Stage.waitingForBlink);
      }

      // Simple blink detection: eyes must go from open -> closed -> open.
      final eyesOpenNow = FaceAuthService.instance.isEyesOpen(face);
      final eyesClosedNow = FaceAuthService.instance.isEyesClosed(face);
      if (_stage == _Stage.waitingForBlink && !_blinkDetected) {
        if (_wasEyesOpen && eyesClosedNow) {
          _blinkDetected =
              true; // saw open -> closed; next open completes the blink
        }
        if (eyesOpenNow) _wasEyesOpen = true;
        if (_blinkDetected && eyesOpenNow) {
          await _captureAndProcess();
        }
      }
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    try {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      if (image.planes.length == 1) {
        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );
      }
      // Multi-plane (YUV420) — concatenate planes; this is the common
      // pattern but Android device/OEM camera stacks vary, so verify
      // on your actual target hardware.
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null ||
        _stage == _Stage.processing ||
        _stage == _Stage.capturing) return;
    setState(() => _stage = _Stage.capturing);
    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      setState(() => _stage = _Stage.processing);
      final faces = await FaceAuthService.instance.detectFacesInFile(file.path);
      if (faces.isEmpty) {
        setState(() {
          _error = 'No face found in the photo — try again.';
          _stage = _Stage.waitingForFace;
          _blinkDetected = false;
        });
        _controller!.startImageStream(_onFrame);
        return;
      }
      final embedding = await FaceAuthService.instance
          .getEmbeddingFromFile(file.path, faces.first);
      await widget.onCaptured(embedding);
    } catch (e) {
      setState(() {
        _error = 'Capture failed: $e';
        _stage = _Stage.waitingForFace;
        _blinkDetected = false;
      });
      try {
        _controller?.startImageStream(_onFrame);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    FaceAuthService.instance.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_stage) {
      case _Stage.waitingForFace:
        return widget.instructionText;
      case _Stage.waitingForBlink:
        return 'Now blink to confirm it\'s really you';
      case _Stage.capturing:
        return 'Capturing…';
      case _Stage.processing:
        return 'Processing…';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _stage = _Stage.waitingForFace;
                });
                _setup();
              },
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            CameraPreview(_controller!),
            if (_stage == _Stage.capturing || _stage == _Stage.processing)
              Container(
                color: Colors.black45,
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(_statusText,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (_stage == _Stage.waitingForFace ||
              _stage == _Stage.waitingForBlink) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _captureAndProcess,
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('Capture Now',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C63B6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Tip: it also captures automatically once you blink',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ]),
      ),
    ]);
  }
}
