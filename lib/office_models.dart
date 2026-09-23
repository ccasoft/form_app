// ─────────────────────────────────────────────────────────────────────────────
//  Office Console — shared branding constants and widgets.
//  Ported unchanged from the standalone CCA Admin Console project
//  (models.dart) — no API calls here, so nothing needed rewiring.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ==================== COMPANY BRANDING ====================
const String APP_COMPANY_NAME = "Chhattisgarh C & F Agency Pvt Ltd ";
const String APP_COMPANY_SHORT = "CCA";

// === MODULE TITLES ===
const String REGISTERS_MODULE_TITLE = "Registers";

// ==================== APP COLORS ====================
const int APP_PRIMARY_COLOR = 0xff004966;
const int APP_HEADER_COLOR = 0xff004966;
const int APP_ACCENT_COLOR = 0xff0D47A1;
const int APP_SUCCESS_COLOR = 0xff4CAF50;
const int APP_DELETE_COLOR = 0xffF44336;

const int APP_BADGE_BG_COLOR = 0xffffffff;
const int APP_BADGE_TEXT_COLOR = 0xff646600;

// NOTE: the console app used this as a manual delete-confirmation PIN
// (AdminPin-style gate) independent of any real permission system.
// Now that these screens are gated by form_app's own per-user
// view/add/update/delete permissions, this constant is unused by the
// ported screens — delete actions are gated by canDelete(...) instead.
// Left here only in case some ported screen still references it.
const String APP_DELETE_PIN = "1234";

// ==================== UI SETTINGS ====================
const bool SHOW_COMPANY_NAME_IN_APPBAR = true;
const bool SHOW_ENTRY_COUNT_BADGE = true;
const int DEFAULT_DISPLAY_LIMIT = 30;

class ModuleItem {
  final String name;
  final IconData icon;
  final List<Color> gradient;
  ModuleItem({required this.name, required this.icon, required this.gradient});
}

// --- UNIFIED CCADropdown ---
class CCADropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const CCADropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff004966).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color(0xff004966),
              fontWeight: FontWeight.bold,
              fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xff004966), size: 20),
          border: InputBorder.none,
        ),
        icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.orange),
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================================
// DOCUMENT TYPES (for Personal Documents by Person)
// ============================================================================
class DocumentTypes {
  static const List<Map<String, dynamic>> personalDocuments = [
    {'name': 'Aadhaar Card', 'hasExpiry': false},
    {'name': 'PAN Card', 'hasExpiry': false},
    {'name': 'Driving License', 'hasExpiry': true},
    {'name': 'Passport', 'hasExpiry': true},
    {'name': 'Voter ID', 'hasExpiry': false},
    {'name': 'GST Certificate', 'hasExpiry': false},
    {'name': 'Food License', 'hasExpiry': true},
    {'name': 'Trade License', 'hasExpiry': true},
    {'name': 'Bank Account Details', 'hasExpiry': false},
    {'name': 'Insurance Policy', 'hasExpiry': true},
    {'name': 'Other', 'hasExpiry': false},
  ];

  static bool hasExpiry(String documentType) {
    final doc = personalDocuments.firstWhere(
      (d) => d['name'] == documentType,
      orElse: () => personalDocuments.last,
    );
    return doc['hasExpiry'] as bool;
  }

  static List<String> getDocumentTypeNames() {
    return personalDocuments.map((d) => d['name'] as String).toList();
  }
}

// ============================================================================
// DEPARTMENT TYPES (for One-Time Licenses)
// ============================================================================
class DepartmentTypes {
  static const List<String> departments = [
    'Government of India',
    'State Government',
    'Municipal Corporation',
    'Food & Drug Administration',
    'Tax Department',
    'Labour Department',
    'Pollution Control Board',
    'Fire Department',
    'Health Department',
    'Trade & Commerce',
    'Other',
  ];
}
