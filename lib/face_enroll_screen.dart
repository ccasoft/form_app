// ─────────────────────────────────────────────────────────────────────────────
//  Face Enrollment Screen
//
//  Mobile only. Opened from Admin > Users > (user) > Enroll Face.
//  Captures a face and stores its embedding against the given user,
//  enabling face login for them.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/face_capture_widget.dart';
import 'package:form_app/api_service.dart';

class FaceEnrollScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const FaceEnrollScreen({super.key, required this.userId, required this.userName});

  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends State<FaceEnrollScreen> {
  final _api = ApiService();
  bool _saving = false;

  Future<void> _onCaptured(List<double> embedding) async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await _api.enrollFace(widget.userId, embedding);
    if (!mounted) return;
    if (ok) {
      Get.back();
      Get.snackbar('Face Enrolled', '${widget.userName} can now log in with Face Login.',
          backgroundColor: Colors.green.shade50,
          colorText: Colors.green.shade800,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      setState(() => _saving = false);
      Get.snackbar('Error', 'Could not save face enrollment. Try again.',
          backgroundColor: Colors.red.shade50,
          colorText: Colors.red.shade800,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Enroll Face — ${widget.userName}', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _saving
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Saving…', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : FaceCaptureWidget(
                  instructionText: 'Center ${widget.userName}\'s face in the frame',
                  onCaptured: _onCaptured,
                ),
        ),
      ),
    );
  }
}
