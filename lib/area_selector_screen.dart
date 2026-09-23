// ─────────────────────────────────────────────────────────────────────────────
//  Area Selector — shown right after login. Lets the user choose
//  between the two sides of the app: the invoice-to-acknowledgement
//  workflow (Activity Manager) and the Office Console (Office
//  Administration). If a user has no access to Office at all, this
//  screen skips itself entirely and goes straight to Activity
//  Manager — no point showing a "choice" with only one real option.
//
//  Sky Blue & Cream theme.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/home.dart';
import 'package:form_app/office_hub_screen.dart';
import 'package:form_app/auth_service.dart';

class AreaSelectorScreen extends StatefulWidget {
  const AreaSelectorScreen({super.key});

  @override
  State<AreaSelectorScreen> createState() => _AreaSelectorScreenState();
}

class _AreaSelectorScreenState extends State<AreaSelectorScreen> {
  @override
  void initState() {
    super.initState();
    // If Office isn't accessible to this user at all, don't make them
    // tap through a selector with only one real option.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AuthService.to.perms.canAccessOffice) {
        Get.off(() => const HomePage());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.to.currentUser;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.appGradient),
        child: SafeArea(
          child: Stack(children: [
            // Watermark tagline
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: AppTagline(),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 56),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      user != null && user.name.isNotEmpty
                          ? 'Welcome, ${user.name}'
                          : 'Welcome',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.4,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Where would you like to go?',
                      style: TextStyle(
                          fontSize: 15,
                          color:
                              AppTheme.textSecondary.withValues(alpha: 0.95)),
                    ),
                    const SizedBox(height: 30),
                    _AreaCard(
                      icon: Icons.assignment_turned_in_rounded,
                      title: 'Activity Manager',
                      subtitle:
                          'Invoice to Acknowledgement — the day-to-day dispatch workflow',
                      accent: const Color(0xFF3E93C4),
                      tint: const Color(0xFFE4F1F9),
                      extraIcons: const [
                        Icons.description_rounded,
                        Icons.local_shipping_rounded,
                      ],
                      onTap: () => Get.off(() => const HomePage()),
                    ),
                    const SizedBox(height: 18),
                    _AreaCard(
                      icon: Icons.business_center_rounded,
                      title: 'Office Administration',
                      subtitle:
                          'Licenses, documents, passwords, registers & more',
                      accent: const Color(0xFF8E24AA),
                      tint: const Color(0xFFF4EAF8),
                      extraIcons: const [
                        Icons.vpn_key_rounded,
                        Icons.workspace_premium_rounded,
                        Icons.badge_rounded,
                      ],
                      onTap: () => Get.off(() => const OfficeHubScreen()),
                    ),
                    const SizedBox(height: 34),
                    const Center(child: LogoutPillButton()),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Area card ─────────────────────────────────────────────────────────────────
class _AreaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color tint;
  final List<IconData> extraIcons;
  final VoidCallback onTap;

  const _AreaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tint,
    required this.extraIcons,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 62, color: accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  color: AppTheme.textPrimary)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 24, color: accent.withValues(alpha: 0.75)),
                      ]),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Color(0xFF546E7A))),
                      const SizedBox(height: 12),
                      Row(
                        children: extraIcons
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: Icon(e,
                                      size: 24,
                                      color: accent.withValues(alpha: 0.7)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared: log out pill + confirmation ───────────────────────────────────────
class LogoutPillButton extends StatelessWidget {
  final bool compact;
  const LogoutPillButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(30),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => confirmLogout(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 30, vertical: compact ? 10 : 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.logout_rounded,
                size: 19, color: AppTheme.textPrimary),
            const SizedBox(width: 10),
            Text('Log out',
                style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

void confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log out?',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppTheme.textPrimary)),
      content: const Text(
        'You\'ll need to sign in again to continue using the app.',
        style: TextStyle(fontSize: 14, color: Color(0xFF546E7A)),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel',
              style: TextStyle(
                  color: Color(0xFF546E7A), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            AuthService.to.logout();
          },
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Log Out',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ],
    ),
  );
}

// ── Shared: tagline watermark ─────────────────────────────────────────────────
class AppTagline extends StatelessWidget {
  const AppTagline({super.key});

  @override
  Widget build(BuildContext context) => Text(
        'A Century of Trust',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: AppTheme.textSecondary.withValues(alpha: 0.38),
        ),
      );
}
