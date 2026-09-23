// ─────────────────────────────────────────────────────────────────────────────
//  User Roles & Permissions
//
//  Roles stored in Firestore under collection "app_users" as field "role":
//    computer   → Step 1 (Invoice Preparation) edit only
//    godown     → Step 2 (Packing) edit only
//    dispatch   → Step 3 (Dispatch) edit only
//    collection → Step 4 & Step 5 (Acknowledgement + Cheque) edit only
//    admin      → All steps + all rights (edit, delete, masters, register)
//    viewer     → View only — NO edit, NO delete on anything
//
//  All roles can VIEW everything.
// ─────────────────────────────────────────────────────────────────────────────

class AppRole {
  static const String computer   = 'computer';
  static const String godown     = 'godown';
  static const String dispatch   = 'dispatch';
  static const String collection = 'collection';
  static const String admin      = 'admin';
  static const String viewer     = 'viewer'; // read-only
}

class RolePermissions {
  final String role;
  const RolePermissions(this.role);

  // ── Edit permission per step ─────────────────────────────────────────────
  /// Step 1: Invoice Preparation
  bool get canEditStep1 =>
      role == AppRole.computer || role == AppRole.admin;

  /// Step 2: Packing
  bool get canEditStep2 =>
      role == AppRole.godown || role == AppRole.admin;

  /// Step 3: Dispatch
  bool get canEditStep3 =>
      role == AppRole.dispatch || role == AppRole.admin;

  /// Step 4: Acknowledgement
  bool get canEditStep4 =>
      role == AppRole.collection || role == AppRole.admin;

  /// Step 5 / Cheque Collection
  bool get canEditStep5 =>
      role == AppRole.collection || role == AppRole.admin;

  // ── Generic helper — can this role edit the given step number? ───────────
  bool canEditStep(int step) {
    switch (step) {
      case 1: return canEditStep1;
      case 2: return canEditStep2;
      case 3: return canEditStep3;
      case 4: return canEditStep4;
      case 5: return canEditStep5;
      default: return false;
    }
  }

  // ── Delete: admin only ───────────────────────────────────────────────────
  bool get canDelete => role == AppRole.admin;

  // ── Masters (Company, Party, Route, Transport, Series): admin only ───────
  bool get canAccessMasters => role == AppRole.admin;

  // ── Invoice Register view: all roles ────────────────────────────────────
  bool get canViewRegister => true;

  // ── Quick Void (cancel invoice): admin only ──────────────────────────────
  bool get canVoid => role == AppRole.admin;

  // ── Display label for the role ───────────────────────────────────────────
  String get displayName {
    switch (role) {
      case AppRole.computer:   return 'Computer Operator';
      case AppRole.godown:     return 'Godown';
      case AppRole.dispatch:   return 'Dispatch';
      case AppRole.collection: return 'Collection';
      case AppRole.admin:      return 'Admin';
      case AppRole.viewer:     return 'Viewer';
      default:                 return role;
    }
  }

  // ── Badge color per role ─────────────────────────────────────────────────
  static const Map<String, int> roleColors = {
    AppRole.computer:   0xFF1E88E5, // blue
    AppRole.godown:     0xFF43A047, // green
    AppRole.dispatch:   0xFFEF6C00, // orange
    AppRole.collection: 0xFF8E24AA, // purple
    AppRole.admin:      0xFFE53935, // red
    AppRole.viewer:     0xFF546E7A, // grey-blue
  };

  int get color => roleColors[role] ?? 0xFF546E7A;
}
