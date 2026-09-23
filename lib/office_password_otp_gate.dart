// ─────────────────────────────────────────────────────────────────────────────
//  Password OTP gate — APPROVAL QUEUE version
//
//  Replaces the earlier code-entry gate. Flow:
//   1. Non-admin taps to view/copy a password → a pending request is
//      created (prefix 'otp', category 'requests').
//   2. An admin opens "OTP Approvals" and approves or denies it.
//   3. The requester's screen is polling that specific request; the
//      moment it flips to 'approved' the reveal is granted and the
//      request is marked 'used' so it can't unlock anything else.
//   4. Admins bypass this entirely — they can always see passwords.
//
//  Storage reuses the same generic office category/entry API that
//  Address Book, Passwords, and Transport Contacts already share.
//
//  ⚠ ASSUMPTION carried over from the previous version: this depends on
//  the backend treating `prefix` as a generic path segment. Verify a
//  request round-trips before relying on this in the field.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String kOtpPrefix = 'otp';
const String kOtpCategory = 'requests';

/// Returns true if the current user is allowed to see/copy a password
/// right now — either because they're an admin, or because an admin
/// just approved a fresh request (which this call then marks used).
Future<bool> requestPasswordOtpUnlock(BuildContext context, {String? label}) async {
  final auth = AuthService.to;
  if (auth.perms.isAdmin) return true;

  final api = ApiService();
  final token = '${DateTime.now().microsecondsSinceEpoch}-${auth.currentUser?.userId ?? 'u'}';

  final created = await api.addOfficeCategoryEntry(kOtpPrefix, kOtpCategory, {
    'token': token,
    'requestedByName': auth.currentUser?.name ?? 'Staff',
    'requestedByUserId': auth.currentUser?.userId ?? '',
    'label': label ?? 'a password',
    'status': 'pending',
    'requestedAt': DateTime.now().toIso8601String(),
  });

  if (!created) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send the OTP request. Try again.')));
    }
    return false;
  }

  if (!context.mounted) return false;

  bool cancelled = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Waiting for approval',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: StreamBuilder<Map<String, dynamic>?>(
          stream: officePollingStream(
            () => _findRequest(api, token),
            interval: const Duration(seconds: 3),
          ),
          builder: (context, snapshot) {
            final entry = snapshot.data;
            final status = entry?['status']?.toString() ?? 'pending';

            if (status == 'approved' && !cancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!dialogContext.mounted) return;
                final id = entry?['id']?.toString();
                if (id != null) {
                  await api.updateOfficeEntry(kOtpPrefix, id, {...entry!, 'status': 'used'});
                }
                Navigator.pop(dialogContext, true);
              });
            } else if (status == 'denied' && !cancelled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) Navigator.pop(dialogContext, false);
              });
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ask an admin to approve your request to view ${label ?? 'this password'}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              cancelled = true;
              final entry = await _findRequest(api, token);
              final id = entry?['id']?.toString();
              if (id != null) {
                await api.updateOfficeEntry(kOtpPrefix, id, {...entry!, 'status': 'cancelled'});
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, false);
            },
            child: const Text('CANCEL'),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}

Future<Map<String, dynamic>?> _findRequest(ApiService api, String token) async {
  final entries = await api.getOfficeCategoryEntries(kOtpPrefix, kOtpCategory);
  for (final e in entries) {
    if (e['token']?.toString() == token) return e;
  }
  return null;
}
