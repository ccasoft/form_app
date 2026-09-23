// ─────────────────────────────────────────────────────────────────────────────
//  Office — Notification Service
//  Ported from notification_service.dart. Api.* -> ApiService throughout.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:url_launcher/url_launcher.dart';
import 'package:form_app/office_admin_dashboard_data.dart';
import 'package:form_app/api_service.dart';

class NotificationService {
  static const int criticalThreshold = 7;
  static const int urgentThreshold = 30;
  static const int warningThreshold = 90;

  final _api = ApiService();

  Future<void> checkAndNotifyExpiringLicenses() async {
    try {
      await _checkLicenses();
      await _checkAMCContracts();
      print('Notification check completed successfully');
    } catch (e) {
      print('Error in notification service: $e');
    }
  }

  Future<void> _checkLicenses() async {
    final categories = await _api.getLicenseCategories();

    for (var category in categories) {
      final entries = (category['entries'] as List).cast<Map<String, dynamic>>();

      for (var data in entries) {
        final licenseName = data['licenseName'] ?? 'Unknown License';
        final renewalDate = data['renewalDate'];
        final contactPhone = data['contactPhone'];

        final days = AdminDashboardData.getDaysUntilExpiry(renewalDate);

        if (_shouldNotify(days)) {
          String? phoneNumber = contactPhone;

          if (phoneNumber == null || phoneNumber.isEmpty) {
            phoneNumber = await _getContactFromAddressBook(data['contactPerson']);
          }

          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            final message = AdminDashboardData.generateExpiryMessage(
              itemType: 'License',
              itemName: licenseName,
              expiryDate: renewalDate ?? 'N/A',
              daysRemaining: days,
            );

            await _sendWhatsAppNotification(phoneNumber, message);
          }
        }
      }
    }
  }

  Future<void> _checkAMCContracts() async {
    final contracts = await _api.getAmcContracts();

    for (var data in contracts) {
      final contractName = data['contractName'] ?? 'Unknown Contract';
      final validityDate = data['validityDate'];
      final contactPhone = data['contactPhone'];

      final days = AdminDashboardData.getDaysUntilExpiry(validityDate);

      if (_shouldNotify(days)) {
        String? phoneNumber = contactPhone;

        if (phoneNumber == null || phoneNumber.isEmpty) {
          phoneNumber = await _getContactFromAddressBook(data['vendor']);
        }

        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final message = AdminDashboardData.generateExpiryMessage(
            itemType: 'AMC Contract',
            itemName: '$contractName (${data['vendor'] ?? ''})',
            expiryDate: validityDate ?? 'N/A',
            daysRemaining: days,
          );

          await _sendWhatsAppNotification(phoneNumber, message);
        }
      }
    }
  }

  bool _shouldNotify(int days) {
    if (days > warningThreshold) return false;
    if (days < 0) return true;
    if (days <= criticalThreshold) return true;
    if (days <= urgentThreshold) return true;
    if (days <= warningThreshold) return true;
    return false;
  }

  Future<String?> _getContactFromAddressBook(String? name) async {
    if (name == null || name.isEmpty) return null;

    try {
      final categories = await _api.getOfficeCategories('address-book');

      for (var category in categories) {
        final categoryName = category['name'];
        final entries = await _api.getOfficeCategoryEntries('address-book', categoryName);

        final match = entries.where((e) => e['name'] == name);
        if (match.isNotEmpty) {
          return match.first['phone'];
        }
      }

      for (var category in categories) {
        final categoryName = category['name'];
        final entries = await _api.getOfficeCategoryEntries('address-book', categoryName);

        for (var contact in entries) {
          final contactName = contact['name']?.toString().toLowerCase() ?? '';

          if (contactName.contains(name.toLowerCase()) ||
              name.toLowerCase().contains(contactName)) {
            return contact['phone'];
          }
        }
      }
    } catch (e) {
      print('Error fetching contact from address book: $e');
    }

    return null;
  }

  Future<void> _sendWhatsAppNotification(String phoneNumber, String message) async {
    try {
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      if (cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
      final uri = Uri.parse(whatsappUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('WhatsApp notification sent to: $cleanNumber');
      } else {
        print('Could not launch WhatsApp for: $cleanNumber');
      }
    } catch (e) {
      print('Error sending WhatsApp notification: $e');
    }
  }

  Future<List<ExpiryItem>> getUpcomingExpiries({int? daysThreshold}) async {
    final threshold = daysThreshold ?? warningThreshold;
    List<ExpiryItem> items = [];

    final categories = await _api.getLicenseCategories();
    for (var category in categories) {
      final entries = (category['entries'] as List).cast<Map<String, dynamic>>();

      for (var data in entries) {
        final days = AdminDashboardData.getDaysUntilExpiry(data['renewalDate']);

        if (days <= threshold) {
          items.add(ExpiryItem(
            type: 'License',
            name: data['licenseName'] ?? 'Unknown',
            category: category['name'] ?? 'Unknown',
            expiryDate: data['renewalDate'] ?? '',
            daysRemaining: days,
            contactPhone: data['contactPhone'],
          ));
        }
      }
    }

    final contracts = await _api.getAmcContracts();
    for (var data in contracts) {
      final days = AdminDashboardData.getDaysUntilExpiry(data['validityDate']);

      if (days <= threshold) {
        items.add(ExpiryItem(
          type: 'AMC',
          name: data['contractName'] ?? 'Unknown',
          category: data['vendor'] ?? 'Unknown',
          expiryDate: data['validityDate'] ?? '',
          daysRemaining: days,
          contactPhone: data['contactPhone'],
        ));
      }
    }

    items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return items;
  }

  Future<void> saveNotificationSettings({
    required bool enabled,
    required int notifyDaysBefore,
    List<String>? excludedCategories,
  }) async {
    await _api.updateNotificationSettings({
      'enabled': enabled,
      'notifyDaysBefore': notifyDaysBefore,
      'excludedCategories': excludedCategories ?? [],
    });
  }

  Future<Map<String, dynamic>> getNotificationSettings() async {
    final data = await _api.getNotificationSettings();

    if (data.isNotEmpty) return data;

    return {
      'enabled': true,
      'notifyDaysBefore': 30,
      'excludedCategories': [],
    };
  }

  /// Get all contacts from address book for linking
  Future<List<AddressBookContact>> getAllContacts() async {
    List<AddressBookContact> contacts = [];

    final categories = await _api.getOfficeCategories('address-book');

    for (var category in categories) {
      final categoryName = category['name'];
      final entries = await _api.getOfficeCategoryEntries('address-book', categoryName);

      for (var data in entries) {
        contacts.add(AddressBookContact(
          name: data['name'] ?? '',
          phone: data['phone'] ?? '',
          firmName: data['firmName'],
          designation: data['designation'],
          category: categoryName,
        ));
      }
    }

    contacts.sort((a, b) => a.name.compareTo(b.name));

    return contacts;
  }

  Future<void> scheduleRecurringNotifications() async {
    final settings = await getNotificationSettings();

    if (settings['enabled'] == true) {
      await checkAndNotifyExpiringLicenses();
    }
  }

  Future<void> checkPersonalDocumentsExpiry() async {
    final documents = await _api.getPersonalDocuments();

    for (var data in documents) {
      final documentType = data['documentType'] ?? 'Unknown Document';
      final personName = data['personName'] ?? 'Unknown Person';
      final documentNumber = data['documentNumber'] ?? '';
      final expiryDate = data['expiryDate'];
      final personId = data['personId'];

      if (expiryDate == null || expiryDate.isEmpty) continue;

      final days = AdminDashboardData.getDaysUntilExpiry(expiryDate);

      if (_shouldNotify(days)) {
        String? phoneNumber = await _getPersonPhoneNumber(personId);

        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final message = _generatePersonalDocExpiryMessage(
            personName: personName,
            documentType: documentType,
            documentNumber: documentNumber,
            expiryDate: expiryDate,
            daysRemaining: days,
          );

          await _sendWhatsAppNotification(phoneNumber, message);
        }
      }
    }
  }

  Future<String?> _getPersonPhoneNumber(String? personId) async {
    if (personId == null || personId.isEmpty) return null;

    try {
      final persons = await _api.getPersons();
      final match = persons.where((p) => p['id'] == personId);
      if (match.isNotEmpty) {
        return match.first['phoneNumber'];
      }
    } catch (e) {
      print('Error fetching person phone number: $e');
    }
    return null;
  }

  String _generatePersonalDocExpiryMessage({
    required String personName,
    required String documentType,
    required String documentNumber,
    required String expiryDate,
    required int daysRemaining,
  }) {
    const companyName = 'Chhattisgarh C & F Agency';
    final urgency = daysRemaining <= 7
        ? '🚨 URGENT'
        : daysRemaining <= 30
            ? '⚠️ IMPORTANT'
            : '📋 REMINDER';

    return '''
$urgency - Document Expiry Alert

Dear $personName,

This is an automated reminder from $companyName regarding your document:

🆔 Document: *$documentType*
🔢 Number: *$documentNumber*
📅 Expiry Date: *$expiryDate*
⏰ Days Remaining: *$daysRemaining days*

${daysRemaining < 0 ? '❗ Your document has expired. Please renew immediately to avoid any inconvenience.' : daysRemaining <= 7 ? '❗ Your document is expiring soon. Please initiate renewal immediately.' : daysRemaining <= 30 ? 'Please plan for renewal at the earliest.' : 'Please keep track of the renewal date.'}

For assistance, please contact the admin team.

Thank you.
---
This is an automated message. Please do not reply.
''';
  }
}

class ExpiryItem {
  final String type;
  final String name;
  final String category;
  final String expiryDate;
  final int daysRemaining;
  final String? contactPhone;

  ExpiryItem({
    required this.type,
    required this.name,
    required this.category,
    required this.expiryDate,
    required this.daysRemaining,
    this.contactPhone,
  });

  bool get isExpired => daysRemaining < 0;
  bool get isCritical => daysRemaining >= 0 && daysRemaining <= 7;
  bool get isUrgent => daysRemaining > 7 && daysRemaining <= 30;
  bool get needsAttention => daysRemaining > 30 && daysRemaining <= 90;
}

class AddressBookContact {
  final String name;
  final String phone;
  final String? firmName;
  final String? designation;
  final String category;

  AddressBookContact({
    required this.name,
    required this.phone,
    this.firmName,
    this.designation,
    required this.category,
  });

  String get displayName {
    if (firmName != null && firmName!.isNotEmpty) {
      return '$name ($firmName)';
    }
    return name;
  }
}
