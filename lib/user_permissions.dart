// ─────────────────────────────────────────────────────────────────────────────
//  User Permissions — per-individual-user, one unified model.
//
//  Every screen in the app (including the 5 workflow stages) gets the
//  same 4 independent flags: view / add / update / delete. No shared
//  roles — every user's grants are configured individually.
//
//  kScreenCapabilities defines which of the 4 flags are actually
//  meaningful for a given screen, so the admin UI can show only the
//  checkboxes that apply (e.g. a read-only dashboard only shows
//  "view").
// ─────────────────────────────────────────────────────────────────────────────

class ScreenKeys {
  static const step1                   = 'step1';
  static const step2                   = 'step2';
  static const step3                   = 'step3';
  static const step4                   = 'step4';
  static const step5                   = 'step5';
  static const invoiceRegister         = 'invoice_register';
  static const invoiceMasterManagement = 'invoice_master_management';
  static const ghostInvoiceFinder      = 'ghost_invoice_finder';
  static const garageSlipPending       = 'garage_slip_pending';
  static const telecalling             = 'telecalling';
  static const pipelineDashboard       = 'pipeline_dashboard';
  static const dispatchDashboard       = 'dispatch_dashboard';
  static const invoiceSeriesManagement = 'invoice_series_management';
  static const quickVoid               = 'quick_void';
  static const adminUsers              = 'admin_users';
  static const party                   = 'party';
  static const company                 = 'company';
  static const transport               = 'transport';
  static const route                   = 'route';
  // Office Console modules (merged from the separate CCA Admin
  // Console project). No separate "office hub" key — the hub screen
  // itself is freely enterable (same pattern as the Masters bottom
  // sheet), each module underneath self-guards individually.
  static const officeLicensesAmc       = 'office_licenses_amc';
  static const officeOneTimeLicenses   = 'office_one_time_licenses';
  static const officePersonalDocuments = 'office_personal_documents';
  static const officeImportantNumbers  = 'office_important_numbers';
  static const officeReminderMail      = 'office_reminder_mail';
  static const officeAddressBook       = 'office_address_book';
  static const officePasswords         = 'office_passwords';
  static const officeTransportContacts = 'office_transport_contacts';
  static const officeRegisters         = 'office_registers';
}

const List<String> kScreenKeys = [
  ScreenKeys.step1,
  ScreenKeys.step2,
  ScreenKeys.step3,
  ScreenKeys.step4,
  ScreenKeys.step5,
  ScreenKeys.invoiceRegister,
  ScreenKeys.invoiceMasterManagement,
  ScreenKeys.ghostInvoiceFinder,
  ScreenKeys.garageSlipPending,
  ScreenKeys.telecalling,
  ScreenKeys.pipelineDashboard,
  ScreenKeys.dispatchDashboard,
  ScreenKeys.invoiceSeriesManagement,
  ScreenKeys.quickVoid,
  ScreenKeys.adminUsers,
  ScreenKeys.party,
  ScreenKeys.company,
  ScreenKeys.transport,
  ScreenKeys.route,
  ScreenKeys.officeLicensesAmc,
  ScreenKeys.officeOneTimeLicenses,
  ScreenKeys.officePersonalDocuments,
  ScreenKeys.officeImportantNumbers,
  ScreenKeys.officeReminderMail,
  ScreenKeys.officeAddressBook,
  ScreenKeys.officePasswords,
  ScreenKeys.officeTransportContacts,
  ScreenKeys.officeRegisters,
];

const Map<String, String> kScreenLabels = {
  ScreenKeys.step1:                   'Stage 1 — Invoice Preparation',
  ScreenKeys.step2:                   'Stage 2 — Packing',
  ScreenKeys.step3:                   'Stage 3 — Dispatch',
  ScreenKeys.step4:                   'Stage 4 — Acknowledgement',
  ScreenKeys.step5:                   'Stage 5 — Cheque Collection',
  ScreenKeys.invoiceRegister:         'Invoice Register',
  ScreenKeys.invoiceMasterManagement: 'Invoice Master',
  ScreenKeys.ghostInvoiceFinder:      'Find & Fix Hidden Invoices',
  ScreenKeys.garageSlipPending:       'Garage Slip Pending',
  ScreenKeys.telecalling:             'Telecalling',
  ScreenKeys.pipelineDashboard:       'Pipeline Dashboard',
  ScreenKeys.dispatchDashboard:       'Dispatch Dashboard (in-app)',
  ScreenKeys.invoiceSeriesManagement: 'Invoice Series Management',
  ScreenKeys.quickVoid:               'Quick Void',
  ScreenKeys.adminUsers:              'Admin — User Management',
  ScreenKeys.party:                   'Masters — Party',
  ScreenKeys.company:                 'Masters — Company',
  ScreenKeys.transport:               'Masters — Transport',
  ScreenKeys.route:                   'Masters — Routes',
  ScreenKeys.officeLicensesAmc:       'Office — Licenses & AMC',
  ScreenKeys.officeOneTimeLicenses:   'Office — One-Time Licenses',
  ScreenKeys.officePersonalDocuments: 'Office — Personal Documents',
  ScreenKeys.officeImportantNumbers:  'Office — Important Numbers',
  ScreenKeys.officeReminderMail:      'Office — Reminder Mail Templates',
  ScreenKeys.officeAddressBook:       'Office — Address Book',
  ScreenKeys.officePasswords:         'Office — Passwords',
  ScreenKeys.officeTransportContacts: 'Office — Transport Contacts',
  ScreenKeys.officeRegisters:         'Office — Registers',
};

/// Which of the 4 flags are actually meaningful per screen — drives
/// which checkboxes the admin permissions editor shows for each row.
const Map<String, Set<String>> kScreenCapabilities = {
  ScreenKeys.step1:                   {'view', 'add', 'update'},
  ScreenKeys.step2:                   {'view', 'update'},
  ScreenKeys.step3:                   {'view', 'update'},
  ScreenKeys.step4:                   {'view', 'update'},
  ScreenKeys.step5:                   {'view', 'update'},
  ScreenKeys.invoiceRegister:         {'view'},
  ScreenKeys.invoiceMasterManagement: {'view', 'update', 'delete'},
  ScreenKeys.ghostInvoiceFinder:      {'view', 'update', 'delete'},
  ScreenKeys.garageSlipPending:       {'view', 'update'},
  ScreenKeys.telecalling:             {'view', 'update'},
  ScreenKeys.pipelineDashboard:       {'view'},
  ScreenKeys.dispatchDashboard:       {'view', 'update', 'delete'},
  ScreenKeys.invoiceSeriesManagement: {'view', 'add', 'update', 'delete'},
  ScreenKeys.quickVoid:               {'view', 'delete'},
  ScreenKeys.adminUsers:              {'view', 'add', 'update', 'delete'},
  ScreenKeys.party:                   {'view', 'add', 'update'},
  ScreenKeys.company:                 {'view', 'add', 'update', 'delete'},
  ScreenKeys.transport:               {'view', 'add', 'update', 'delete'},
  ScreenKeys.route:                   {'view', 'add', 'update', 'delete'},
  // Office Console modules — capabilities based on what the ported
  // UI actually supports (e.g. Licenses/AMC only ever POST — there's
  // no edit/delete flow in the source app for those two).
  ScreenKeys.officeLicensesAmc:       {'view', 'add'},
  ScreenKeys.officeOneTimeLicenses:   {'view', 'add', 'delete'},
  ScreenKeys.officePersonalDocuments: {'view', 'add', 'delete'},
  ScreenKeys.officeImportantNumbers:  {'view', 'add'},
  ScreenKeys.officeReminderMail:      {'view', 'add', 'update', 'delete'},
  ScreenKeys.officeAddressBook:       {'view', 'add', 'update', 'delete'},
  ScreenKeys.officePasswords:         {'view', 'add', 'update', 'delete'},
  ScreenKeys.officeTransportContacts: {'view', 'add', 'update', 'delete'},
  ScreenKeys.officeRegisters:         {'view', 'add', 'delete'},
};

class ScreenPerm {
  final bool view;
  final bool add;
  final bool update;
  final bool delete;
  const ScreenPerm({
    this.view = false,
    this.add = false,
    this.update = false,
    this.delete = false,
  });

  factory ScreenPerm.fromJson(Map<String, dynamic> j) => ScreenPerm(
        view: j['view'] == true,
        add: j['add'] == true,
        update: j['update'] == true,
        delete: j['delete'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'view': view, 'add': add, 'update': update, 'delete': delete};

  ScreenPerm copyWith({bool? view, bool? add, bool? update, bool? delete}) =>
      ScreenPerm(
        view: view ?? this.view,
        add: add ?? this.add,
        update: update ?? this.update,
        delete: delete ?? this.delete,
      );
}

class UserPermissions {
  final Map<String, ScreenPerm> screens;
  final String displayName;
  final int color;
  /// Admin accounts bypass the per-screen grants entirely and always
  /// have full access — this is a hard rule, not dependent on the
  /// screens map being populated. Without this, every time a new
  /// screen is added to the app, admin would need to be manually
  /// re-granted access to it (exactly the bug that motivated this).
  final bool isAdmin;

  const UserPermissions({
    required this.screens,
    this.displayName = 'User',
    this.color = 0xFF546E7A,
    this.isAdmin = false,
  });

  factory UserPermissions.empty({String displayName = 'User'}) =>
      UserPermissions(
        screens: {for (final k in kScreenKeys) k: const ScreenPerm()},
        displayName: displayName,
      );

  factory UserPermissions.fromJson(Map<String, dynamic> json,
      {String displayName = 'User', bool isAdmin = false}) {
    final screensJson = (json['screens'] as Map?) ?? {};
    return UserPermissions(
      screens: {
        for (final k in kScreenKeys)
          k: ScreenPerm.fromJson(
              (screensJson[k] as Map<String, dynamic>?) ?? const {}),
      },
      displayName: displayName,
      isAdmin: isAdmin,
    );
  }

  Map<String, dynamic> toJson() => {
        'screens': {for (final e in screens.entries) e.key: e.value.toJson()},
      };

  // ── Generic per-screen checks ────────────────────────────────────────────
  // Admin bypasses the map entirely — always true, regardless of what
  // (if anything) is stored for them.
  bool canView(String screenKey)   => isAdmin || (screens[screenKey]?.view   ?? false);
  bool canAdd(String screenKey)    => isAdmin || (screens[screenKey]?.add    ?? false);
  bool canUpdate(String screenKey) => isAdmin || (screens[screenKey]?.update ?? false);
  bool canDelete(String screenKey) => isAdmin || (screens[screenKey]?.delete ?? false);

  // ── Convenience aliases used around the app ─────────────────────────────
  bool get canEditStep1 => canUpdate(ScreenKeys.step1);
  bool get canEditStep2 => canUpdate(ScreenKeys.step2);
  bool get canEditStep3 => canUpdate(ScreenKeys.step3);
  bool get canEditStep4 => canUpdate(ScreenKeys.step4);
  bool get canEditStep5 => canUpdate(ScreenKeys.step5);
  bool canEditStep(int step) => canUpdate('step$step');
  bool canViewStep(int step) => canView('step$step');

  bool get canAccessMasters => canView(ScreenKeys.invoiceMasterManagement);
  // Shows the Office Tools entry point if the user can view at least
  // one office module — otherwise it'd lead to a hub screen that's
  // entirely locked tiles, which is pointless to show at all.
  bool get canAccessOffice =>
      canView(ScreenKeys.officeLicensesAmc) ||
      canView(ScreenKeys.officeOneTimeLicenses) ||
      canView(ScreenKeys.officePersonalDocuments) ||
      canView(ScreenKeys.officeImportantNumbers) ||
      canView(ScreenKeys.officeReminderMail) ||
      canView(ScreenKeys.officeAddressBook) ||
      canView(ScreenKeys.officePasswords) ||
      canView(ScreenKeys.officeTransportContacts) ||
      canView(ScreenKeys.officeRegisters);
  bool get canViewRegister  => canView(ScreenKeys.invoiceRegister);
  bool get canVoid           => canDelete(ScreenKeys.quickVoid);
}
