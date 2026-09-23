// ─────────────────────────────────────────────────────────────────────────────
//  OTP Request Generator — Utility
//
//  Admin-only. Generates a random 6-digit code and stores it (via the
//  generic office category/entry API, prefix 'otp') so the Passwords
//  module can verify it. The admin reads the code aloud to whoever
//  needs to view a password — it's valid for 90 seconds and single-use
//  (consumed the moment it successfully unlocks one password).
//
//  ⚠ ASSUMPTION: relies on the backend accepting a new generic prefix
//  ('otp') the same way it already does for 'passwords' /
//  'address-book' / 'transport-contacts'. Not verified against the
//  actual backend source — test before relying on this.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/auth_service.dart';

const int _kOtpValiditySeconds = 90;

class OtpRequestGeneratorModule extends StatefulWidget {
  const OtpRequestGeneratorModule({super.key});

  @override
  State<OtpRequestGeneratorModule> createState() =>
      _OtpRequestGeneratorModuleState();
}

class _OtpRequestGeneratorModuleState
    extends State<OtpRequestGeneratorModule> {
  final _api = ApiService();
  String? _otp;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _generating = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(seconds: _kOtpValiditySeconds));

    final ok = await _api.addOfficeCategoryEntry('otp', 'active', {
      'code': code,
      'createdAt': now.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'used': false,
      'generatedBy': AuthService.to.currentUser?.name ?? 'admin',
    });

    if (!mounted) return;
    setState(() => _generating = false);

    if (!ok) {
      setState(() => _error =
          'Could not save the OTP — the backend may not support this yet.');
      return;
    }

    _timer?.cancel();
    setState(() {
      _otp = code;
      _secondsLeft = _kOtpValiditySeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.to.perms.isAdmin;
    final expired = _otp != null && _secondsLeft == 0;

    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        backgroundColor: AppTheme.bannerVivid,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('OTP Request Generator',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(28),
            decoration: AppTheme.cleanCardDecoration(radius: 22),
            child: !isAdmin
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        size: 46, color: Color(0xFF9AA5AD)),
                    const SizedBox(height: 14),
                    const Text('Admins only',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C))),
                    const SizedBox(height: 6),
                    const Text(
                      'Ask an admin to generate a code and share it with you when you need to view a password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF7C8A97), height: 1.4),
                    ),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.catPurple.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.password_rounded,
                          size: 32, color: AppTheme.catPurple),
                    ),
                    const SizedBox(height: 18),
                    const Text('Generate a one-time code',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2B3C))),
                    const SizedBox(height: 6),
                    Text(
                      'Read this code aloud to the person who needs to view '
                      'one password. It unlocks a single view and expires '
                      'in $_kOtpValiditySeconds seconds.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7C8A97), height: 1.4),
                    ),
                    const SizedBox(height: 26),
                    if (_otp != null)
                      Column(children: [
                        Text(_otp!,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: expired
                                  ? const Color(0xFFB0B8BE)
                                  : const Color(0xFF1A2B3C),
                            )),
                        const SizedBox(height: 6),
                        Text(
                          expired ? 'Expired — generate a new one' : 'Valid for $_secondsLeft s',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: expired ? AppTheme.danger : AppTheme.catGreen),
                        ),
                        const SizedBox(height: 18),
                      ]),
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.danger)),
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh_rounded, size: 19),
                        label: Text(_otp == null ? 'Generate OTP' : 'Generate New OTP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.bannerVivid,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}
