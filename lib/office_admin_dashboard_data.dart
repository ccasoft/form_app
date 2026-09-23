// ─────────────────────────────────────────────────────────────────────────────
//  Office — shared dashboard stats model + date/formatting utilities.
//  Ported unchanged from admin_dashboard_data.dart. That file's own
//  comment already explains it once carried dead Firestore model
//  classes (never instantiated anywhere) that were removed rather
//  than ported — nothing lost there.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ========================================
// DASHBOARD STATISTICS MODEL
// ========================================
class DashboardStats {
  final int totalLicenses;
  final int totalAMCs;
  final int expiring30;
  final int expiring90;
  final int expired;
  final int activeOneTimeLicenses;
  final int totalDocs;

  DashboardStats({
    required this.totalLicenses,
    required this.totalAMCs,
    required this.expiring30,
    required this.expiring90,
    required this.expired,
    required this.activeOneTimeLicenses,
    required this.totalDocs,
  });
}

// ========================================
// UTILITY FUNCTIONS
// ========================================
class AdminDashboardData {
  /// Parse date string (DD/MM/YYYY format) and calculate days until expiry
  static int getDaysUntilExpiry(String? renewalDate) {
    if (renewalDate == null || renewalDate.isEmpty) return 999999;

    try {
      final parts = renewalDate.split('/');
      if (parts.length != 3) return 999999;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final renewal = DateTime(year, month, day);
      return renewal.difference(DateTime.now()).inDays;
    } catch (e) {
      return 999999;
    }
  }

  /// Get status color based on days remaining
  static Color getStatusColor(int days) {
    if (days < 0) return const Color(0xFFB71C1C); // Expired - Dark Red
    if (days <= 7) return const Color(0xFFD32F2F); // Critical - Red
    if (days <= 30) return const Color(0xFFE64A19); // Urgent - Deep Orange
    if (days <= 90) return const Color(0xFFF57C00); // Warning - Orange
    return const Color(0xFF2E7D32); // Good - Green
  }

  /// Get status text based on days remaining
  static String getStatusText(int days) {
    if (days < 0) return 'EXPIRED';
    if (days <= 7) return 'CRITICAL';
    if (days <= 30) return 'URGENT';
    if (days <= 90) return 'ATTENTION';
    return 'VALID';
  }

  /// Get appropriate icon for document category
  static IconData getDocIcon(String category) {
    final Map<String, IconData> icons = {
      'Government ID': Icons.badge_outlined,
      'Tax Documents': Icons.receipt_long_outlined,
      'Bank Details': Icons.account_balance_outlined,
      'Insurance': Icons.shield_outlined,
      'Legal Documents': Icons.gavel_outlined,
      'Property Papers': Icons.home_outlined,
      'Vehicle Documents': Icons.directions_car_outlined,
      'Employee Records': Icons.person_outline,
      'Certificates': Icons.workspace_premium_outlined,
      'Other': Icons.description_outlined,
    };
    return icons[category] ?? Icons.description_outlined;
  }

  /// Format date from DD/MM/YYYY to readable format
  static String formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';

    try {
      final parts = date.split('/');
      if (parts.length != 3) return date;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final dateTime = DateTime(year, month, day);
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  /// Parse date from string to DateTime
  static DateTime? parseDate(String? date) {
    if (date == null || date.isEmpty) return null;

    try {
      final parts = date.split('/');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  /// Format DateTime to DD/MM/YYYY
  static String formatDateToString(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Get color for license category
  static List<Color> getCategoryColors(int index) {
    final List<List<Color>> colorSchemes = [
      [const Color(0xFF0D47A1), const Color(0xFF1976D2)], // Blue
      [const Color(0xFF1B5E20), const Color(0xFF388E3C)], // Green
      [const Color(0xFFE65100), const Color(0xFFFF6F00)], // Orange
      [const Color(0xFF4A148C), const Color(0xFF6A1B9A)], // Purple
      [const Color(0xFFB71C1C), const Color(0xFFD32F2F)], // Red
      [const Color(0xFF00695C), const Color(0xFF00897B)], // Teal
    ];
    return colorSchemes[index % colorSchemes.length];
  }

  /// Generate WhatsApp message for expiring license
  static String generateExpiryMessage({
    required String itemType,
    required String itemName,
    required String expiryDate,
    required int daysRemaining,
  }) {
    final companyName = 'Chhattisgarh C & F Agency';
    final urgency = daysRemaining <= 7 ? '🚨 URGENT' : daysRemaining <= 30 ? '⚠️ IMPORTANT' : '📋 REMINDER';

    return '''
$urgency - $itemType Expiry Alert

Dear Team,

This is an automated reminder from $companyName regarding:

📌 *$itemName*
📅 Expiry Date: *$expiryDate*
⏰ Days Remaining: *$daysRemaining days*

${daysRemaining < 0 ? '❗ This item has already expired. Please renew immediately.' : daysRemaining <= 7 ? '❗ Please initiate renewal process immediately.' : daysRemaining <= 30 ? 'Please plan for renewal at the earliest.' : 'Please keep track of the renewal date.'}

For assistance, please contact the admin team.

Thank you.
---
This is an automated message. Please do not reply.
''';
  }
}

// ========================================
// PREDEFINED CATEGORIES
// ========================================
class PredefinedCategories {
  static const List<Map<String, dynamic>> licenseCategories = [
    {'name': 'Software Licenses', 'icon': 'Icons.computer', 'color': 0xFF0D47A1},
    {'name': 'Trade Licenses', 'icon': 'Icons.store', 'color': 0xFF1B5E20},
    {'name': 'Regulatory Licenses', 'icon': 'Icons.policy', 'color': 0xFFE65100},
    {'name': 'Professional Memberships', 'icon': 'Icons.card_membership', 'color': 0xFF4A148C},
  ];

  static const List<Map<String, dynamic>> amcCategories = [
    {'name': 'IT Equipment', 'serviceType': 'Hardware Maintenance'},
    {'name': 'HVAC Systems', 'serviceType': 'Climate Control'},
    {'name': 'Fire Safety', 'serviceType': 'Safety Equipment'},
    {'name': 'Security Systems', 'serviceType': 'Security & Surveillance'},
  ];

  static const List<String> documentCategories = [
    'Government ID',
    'Tax Documents',
    'Bank Details',
    'Insurance',
    'Legal Documents',
    'Property Papers',
    'Vehicle Documents',
    'Employee Records',
    'Certificates',
    'Other',
  ];
}
