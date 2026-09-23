// ─────────────────────────────────────────────────────────────────────────────
//  Face Login Screen
//
//  Mobile only. Captures a face, sends the embedding to
//  /auth/face/login for server-side matching against every enrolled
//  user, and logs in as whoever matches (below the distance
//  threshold) — same as a normal password login from that point on.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/face_capture_widget.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/auth_service.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  bool _loggingIn = false;

  Future<void> _onCaptured(List<double> embedding) async {
    if (_loggingIn) return;
    setState(() => _loggingIn = true);
    try {
      final result = await AuthService.to.loginWithFaceEmbedding(embedding);
      if (result == null) {
        if (mounted) Get.offAllNamed('/select');
        return;
      }
      if (mounted) {
        Get.snackbar('Face not recognized', result,
            backgroundColor: Colors.red.shade50,
            colorText: Colors.red.shade800,
            snackPosition: SnackPosition.BOTTOM);
        setState(() => _loggingIn = false);
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Face login failed: $e',
            backgroundColor: Colors.red.shade50,
            colorText: Colors.red.shade800,
            snackPosition: SnackPosition.BOTTOM);
        setState(() => _loggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1420),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Face Login', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loggingIn
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Checking face…', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : FaceCaptureWidget(
                  instructionText: 'Look at the camera to log in',
                  onCaptured: _onCaptured,
                ),
        ),
      ),
    );
  }
}
