// ─────────────────────────────────────────────────────────────────────────────
//  OTP Approvals
//
//  Admins: see every pending request across all users, with Approve /
//  Deny actions, plus recently-resolved ones below for context.
//  Non-admins: see only their own request history (read-only) — this
//  is where they can check "did admin approve me yet" without going
//  back into the Passwords screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';
import 'package:form_app/office_password_otp_gate.dart' show kOtpPrefix, kOtpCategory;

class OtpApprovalsScreen extends StatefulWidget {
  const OtpApprovalsScreen({super.key});

  @override
  State<OtpApprovalsScreen> createState() => _OtpApprovalsScreenState();
}

class _OtpApprovalsScreenState extends State<OtpApprovalsScreen> {
  final _api = ApiService();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final all = await _api.getOfficeCategoryEntries(kOtpPrefix, kOtpCategory);
    final isAdmin = AuthService.to.perms.isAdmin;
    final myId = AuthService.to.currentUser?.userId;
    final list = isAdmin ? all : all.where((e) => e['requestedByUserId'] == myId).toList();
    // Pending first, most recent first within each group.
    list.sort((a, b) {
      final aPending = a['status'] == 'pending' ? 0 : 1;
      final bPending = b['status'] == 'pending' ? 0 : 1;
      if (aPending != bPending) return aPending - bPending;
      final aTime = a['requestedAt']?.toString() ?? '';
      final bTime = b['requestedAt']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
    return list;
  }

  Future<void> _respond(Map<String, dynamic> entry, String status) async {
    final id = entry['id']?.toString();
    if (id == null) return;
    await _api.updateOfficeEntry(kOtpPrefix, id, {...entry, 'status': status});
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.to.perms.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('OTP Requests',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: Colors.black87)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: officePollingStream(_fetch, interval: const Duration(seconds: 4)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return Center(
              child: Text(
                isAdmin ? 'No OTP requests yet.' : 'You have no OTP requests yet.',
                style: const TextStyle(color: Color(0xFF7C8A97)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = requests[i];
              final status = r['status']?.toString() ?? 'pending';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User: ${r['requestedByName'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text('Requesting: ${r['label'] ?? 'a password'}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF7C8A97))),
                        const SizedBox(height: 2),
                        Text('Status: $status',
                            style: TextStyle(fontSize: 12, color: _statusColor(status))),
                      ],
                    ),
                  ),
                  if (isAdmin && status == 'pending') ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded, color: AppTheme.catGreen, size: 28),
                      tooltip: 'Approve',
                      onPressed: () => _respond(r, 'approved'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: AppTheme.danger, size: 28),
                      tooltip: 'Deny',
                      onPressed: () => _respond(r, 'denied'),
                    ),
                  ] else
                    Icon(_statusIcon(status), color: _statusColor(status), size: 24),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppTheme.catGreen;
      case 'used': return AppTheme.catGreen;
      case 'denied': return AppTheme.danger;
      case 'cancelled': return const Color(0xFF9AA5AD);
      default: return const Color(0xFFEF8A2E);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle_rounded;
      case 'used': return Icons.check_circle_rounded;
      case 'denied': return Icons.cancel_rounded;
      case 'cancelled': return Icons.remove_circle_outline_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }
}
