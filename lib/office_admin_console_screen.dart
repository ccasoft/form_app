// ─────────────────────────────────────────────────────────────────────────────
//  Admin Console — matches the reference screenshot:
//  2×2 stat cards (Expired / Expiring 30d / One-Time / Personal Docs)
//  followed by a plain list: Personal Documents, One-Time Licenses,
//  Add New License, Check All Notifications.
//
//  Note: the reference app bar also shows a "people" icon and a 3-dot
//  menu on the right. I don't know what those are meant to do in your
//  app (user management? more actions?) — left them out rather than
//  guess; happy to wire them up once you tell me what they should do.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/office_admin_dashboard_data.dart';
import 'package:form_app/office_notification_service.dart';
import 'package:form_app/office_add_dialogs.dart';
import 'package:form_app/office_one_time_licenses_module.dart';
import 'package:form_app/office_personal_documents_module.dart';
import 'package:form_app/admin_users_screen.dart';
import 'package:form_app/office_audit_log_screen.dart';

const Color _kAdminTeal = Color(0xFF0D5C63);

class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  final _api = ApiService();
  final NotificationService _notificationService = NotificationService();

  Future<DashboardStats> _getStatistics() async {
    final data = await _api.getOfficeDashboardStats();
    return DashboardStats(
      totalLicenses: data['totalLicenses'] ?? 0,
      totalAMCs: data['totalAMCs'] ?? 0,
      expiring30: data['expiring30'] ?? 0,
      expiring90: data['expiring90'] ?? 0,
      expired: data['expired'] ?? 0,
      activeOneTimeLicenses: data['activeOneTimeLicenses'] ?? 0,
      totalDocs: data['totalDocs'] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _kAdminTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Chhattisgarh C & F Agency Pvt Ltd',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_rounded),
            tooltip: 'Manage Users',
            onPressed: () => Get.toNamed(AdminUsersScreen.routeName),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'audit') Get.to(() => const AuditLogScreen());
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'audit', child: Text('Audit Log')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<DashboardStats>(
        future: _getStatistics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(
                    icon: Icons.error_rounded,
                    iconColor: AppTheme.danger,
                    value: '${stats.expired}',
                    label: 'Expired',
                  ),
                  _StatCard(
                    icon: Icons.warning_rounded,
                    iconColor: AppTheme.catAmber,
                    value: '${stats.expiring30}',
                    label: 'Expiring 30d',
                  ),
                  _StatCard(
                    icon: Icons.verified_rounded,
                    iconColor: AppTheme.catGreen,
                    value: '${stats.activeOneTimeLicenses}',
                    label: 'One-Time',
                  ),
                  _StatCard(
                    icon: Icons.badge_rounded,
                    iconColor: _kAdminTeal,
                    value: '${stats.totalDocs}',
                    label: 'Personal Docs',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ActionRow(
                icon: Icons.badge_rounded,
                title: 'Personal Documents',
                subtitle: 'Manage documents by person',
                onTap: () => Get.to(() => const PersonalDocumentsModule()),
              ),
              const SizedBox(height: 10),
              _ActionRow(
                icon: Icons.verified_rounded,
                title: 'One-Time Licenses',
                subtitle: 'Department licenses (no expiry)',
                onTap: () => Get.to(() => const OneTimeLicensesModule()),
              ),
              const SizedBox(height: 10),
              _ActionRow(
                icon: Icons.add_moderator_rounded,
                title: 'Add New License',
                subtitle: null,
                onTap: () => showDialog(
                    context: context,
                    builder: (_) => const AddLicenseDialog(categoryName: 'General')),
              ),
              const SizedBox(height: 10),
              _ActionRow(
                icon: Icons.notifications_active_rounded,
                title: 'Check All Notifications',
                subtitle: null,
                onTap: () => _runNotificationCheck(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runNotificationCheck(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Checking and sending notifications...', textAlign: TextAlign.center),
        ]),
      ),
    );
    await _notificationService.checkAndNotifyExpiringLicenses();
    await _notificationService.checkPersonalDocumentsExpiry();
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ All notifications checked and sent')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cleanCardDecoration(radius: 14),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF7C8A97))),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: AppTheme.cleanCardDecoration(radius: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _kAdminTeal.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _kAdminTeal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF7C8A97))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA5AD)),
          ]),
        ),
      ),
    );
  }
}
