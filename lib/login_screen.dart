// ─────────────────────────────────────────────────────────────────────────────
//  Login Screen  —  matches the reference screenshot exactly:
//  deep blue background, Krishna artwork (no border/shadow — the glow
//  is part of the artwork itself), "Jai Shri Krishna" subtitle,
//  underline-style Username/Password fields, orange LOGIN button, and
//  nothing else below it.
//
//  Krishna artwork ships at assets/krishna.png — register it in
//  pubspec.yaml:
//    flutter:
//      assets:
//        - assets/krishna.png
//  Falls back to a plain placeholder if the asset is missing so the
//  layout never breaks.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/face_login_screen.dart';
import 'package:get/get.dart';

const Color _kLoginBlue = Color(0xFF1E5FC2);
const Color _kLoginOrange = Color(0xFFF5A623);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await AuthService.to.login(
      _userIdCtrl.text,
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      Get.offAllNamed('/select');
    }
  }

  void _exit() {
    if (kIsWeb) {
      Get.snackbar(
        'Exit',
        'To exit, close this browser tab.',
        backgroundColor: _kLoginBlue,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Whole screen is sized to fit in one viewport (no scrolling): the
    // title/subtitle and login card take their natural height, and the
    // Krishna artwork (Expanded) grows or shrinks to soak up whatever
    // vertical space is left over on that device.
    return Scaffold(
      backgroundColor: _kLoginBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(children: [
            const Text('Chhattisgarh C & F Agency Pvt Ltd',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Jai Shri Krishna',
                style: TextStyle(
                    color: _kLoginOrange,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),

            // ── Krishna artwork — plain, no box/shadow. The glow around
            // the figure is baked into the PNG itself, so BoxFit.contain
            // shows the whole picture as designed instead of a UI-drawn
            // frame around it. The source file has a thin white margin
            // baked into its own canvas (visible as a line on the right
            // and bottom edges) — Transform.scale zooms in ~6% and
            // ClipRect trims the overflow, cropping that margin off all
            // four edges evenly without needing the file itself fixed. ──
            Expanded(
              child: ClipRect(
                child: Transform.scale(
                  scale: 1.06,
                  child: Center(
                    child: Image.asset(
                      'assets/krishna.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.self_improvement_rounded,
                          size: 90,
                          color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),

            // ── Login card ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _userIdCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: Colors.white,
                    decoration: _inputDec(
                        label: 'Username',
                        hint: 'Enter your username',
                        icon: Icons.person_outline_rounded),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your username'
                        : null,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: Colors.white,
                    decoration: _inputDec(
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded)
                        .copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.white70),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Please enter your password'
                        : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kLoginOrange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _kLoginOrange.withValues(alpha: 0.55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white))
                          : const Text('LOGIN',
                              style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6)),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => Get.to(() => const FaceLoginScreen()),
                        icon: const Icon(Icons.face_retouching_natural_rounded,
                            size: 18),
                        label: const Text('Login with Face'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),

            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _exit,
              icon: const Icon(Icons.exit_to_app_rounded,
                  size: 16, color: Colors.white70),
              label: const Text('Exit App',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDec(
      {required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      // The app's global theme (AppTheme.theme) sets filled:true,
      // fillColor:Colors.white for every text field by default. Left
      // unset here, these fields would silently inherit a solid white
      // background — invisible against the white text/labels used on
      // this dark-blue login screen. Explicitly turning fill off keeps
      // this screen's translucent underline look.
      filled: false,
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14.5),
      floatingLabelStyle: const TextStyle(
          color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
      prefixIcon: Icon(icon, size: 20, color: Colors.white70),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38)),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.4)),
      errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent)),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
    );
  }
}
