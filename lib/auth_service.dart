// ============================================================
//  auth_service.dart  —  MySQL version
//  Drop-in replacement for the Firebase-based AuthService
//  Uses ApiService instead of Firestore
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/user_roles.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/api_service.dart';

class AppUser {
  final String userId;
  final String name;
  final String role; // display label only — no longer drives permissions
  final bool active;

  const AppUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.active,
  });

  factory AppUser.fromJson(Map<String, dynamic> data) => AppUser(
        userId: data['userId'] as String? ?? '',
        name: data['name'] as String? ?? '',
        role: data['role'] as String? ?? AppRole.viewer,
        active: data['active'] as bool? ?? true,
      );
}

class AuthService extends GetxController {
  static AuthService get to => Get.find<AuthService>();

  final _api = ApiService();
  final Rxn<AppUser> _currentUser = Rxn<AppUser>();
  final Rxn<UserPermissions> _currentPerms = Rxn<UserPermissions>();

  AppUser? get currentUser => _currentUser.value;
  bool get isLoggedIn => _currentUser.value != null;
  String get role => _currentUser.value?.role ?? '';
  UserPermissions get perms =>
      _currentPerms.value ??
      UserPermissions.empty(displayName: _currentUser.value?.name ?? 'User');

  Future<String?> login(String userId, String password) async {
    final data = await _api.loginData(userId, password);
    if (data == null) return 'Login failed. Check credentials.';
    _currentUser.value = AppUser.fromJson(data);

    final permsData = await _api.fetchPermissions(_currentUser.value!.userId);
    _currentPerms.value = UserPermissions.fromJson(
      permsData ?? const {},
      displayName: _currentUser.value!.name,
      isAdmin: _currentUser.value!.role == AppRole.admin,
    );
    return null; // success
  }

  /// Same end result as login(), but authenticated via a face embedding
  /// instead of userId/password — matching happens server-side against
  /// every enrolled user. Returns an error message on failure, null on
  /// success (mirrors login()'s return shape).
  Future<String?> loginWithFaceEmbedding(List<double> embedding) async {
    final r = await _api.loginWithFace(embedding);
    if (r['success'] != true) {
      return r['error']?.toString() ?? 'Face not recognized.';
    }
    final data = r['data'] as Map<String, dynamic>?;
    if (data == null) return 'Face not recognized.';
    _currentUser.value = AppUser.fromJson(data);

    final permsData = await _api.fetchPermissions(_currentUser.value!.userId);
    _currentPerms.value = UserPermissions.fromJson(
      permsData ?? const {},
      displayName: _currentUser.value!.name,
      isAdmin: _currentUser.value!.role == AppRole.admin,
    );
    return null; // success
  }

  /// Re-fetch this user's permissions without a full re-login — call
  /// after an admin updates them, or on app resume, to pick up changes.
  Future<void> refreshPermissions() async {
    final u = _currentUser.value;
    if (u == null) return;
    final permsData = await _api.fetchPermissions(u.userId);
    _currentPerms.value = UserPermissions.fromJson(
      permsData ?? const {},
      displayName: u.name,
      isAdmin: u.role == AppRole.admin,
    );
  }

  void logout() {
    _currentUser.value = null;
    _currentPerms.value = null;
    Get.offAllNamed('/login');
  }
}
