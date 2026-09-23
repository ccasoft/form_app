// admin_users_screen.dart
// Manage app_users collection from within the app.
// Only accessible when AuthService.to.perms.canAccessMasters == true (admin role).

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/user_roles.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:form_app/api_service.dart';
import 'package:form_app/permissions_editor_dialog.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/face_enroll_screen.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class _UserDoc {
  final String docId;
  String userId;
  String name;
  String password;
  String role;
  bool active;

  _UserDoc({
    required this.docId,
    required this.userId,
    required this.name,
    required this.password,
    required this.role,
    required this.active,
  });

  factory _UserDoc.fromMap(Map<String, dynamic> d) {
    return _UserDoc(
      docId: d['userId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      password: d['password'] as String? ?? '',
      role: d['role'] as String? ?? AppRole.viewer,
      active: d['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'password': password,
        'role': role,
        'active': active,
      };
}

// ─── Controller ───────────────────────────────────────────────────────────────
class _AdminUsersCtrl extends GetxController {
  final users = <_UserDoc>[].obs;
  final isLoading = true.obs;
  final search = ''.obs;
  final roleFilter = ''.obs;
  final loadError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    isLoading.value = true;
    loadError.value = '';
    try {
      final r = await http.get(
        Uri.parse('${ApiService.baseUrl}/auth/users'),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      );
      debugPrint('GET /auth/users -> ${r.statusCode}: ${r.body}');
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        users.value = (data['data'] as List)
            .map((d) => _UserDoc.fromMap(d as Map<String, dynamic>))
            .toList();
      } else {
        loadError.value =
            data['error']?.toString() ?? 'Server returned an error.';
      }
    } catch (e) {
      loadError.value = 'Could not reach the server: $e';
      debugPrint('GET /auth/users EXCEPTION: $e');
    }
    isLoading.value = false;
  }

  List<_UserDoc> get visible => users.where((u) {
        // Admin accounts are never shown here — protects them from being
        // accidentally edited, disabled, or deleted through this screen.
        if (u.role == AppRole.admin) return false;
        final q = search.value.toLowerCase();
        final matchSearch = q.isEmpty ||
            u.userId.toLowerCase().contains(q) ||
            u.name.toLowerCase().contains(q);
        final matchRole =
            roleFilter.value.isEmpty || u.role == roleFilter.value;
        return matchSearch && matchRole;
      }).toList();

  Future<String?> create(_UserDoc u) async {
    if (users.any((x) => x.userId == u.userId)) {
      return 'User ID "${u.userId}" already exists.';
    }
    return await _postUser(u);
  }

  Future<String?> saveUser(_UserDoc u) async {
    return await _postUser(u);
  }

  Future<String?> _postUser(_UserDoc u) async {
    try {
      final r = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/users'),
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(u.toMap()),
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        await _load();
        return null;
      }
      return data['error']?.toString() ?? 'Failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleActive(_UserDoc u) async {
    u.active = !u.active;
    return await _postUser(u);
  }

  Future<String?> delete(_UserDoc u) async {
    try {
      final r = await http.delete(
        Uri.parse('${ApiService.baseUrl}/auth/users/${u.userId}'),
        headers: const {'ngrok-skip-browser-warning': 'true'},
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        users.removeWhere((x) => x.userId == u.userId);
        return null;
      }
      return data['error']?.toString() ?? 'Failed';
    } catch (e) {
      return e.toString();
    }
  }
}

// ─── Role meta ────────────────────────────────────────────────────────────────
const _roles = [
  AppRole.computer,
  AppRole.godown,
  AppRole.dispatch,
  AppRole.collection,
  AppRole.admin,
  AppRole.viewer,
];

Color _roleColor(String role) =>
    Color(RolePermissions.roleColors[role] ?? 0xFF546E7A);

String _roleLabel(String role) => RolePermissions(role).displayName;

// ─── Screen ───────────────────────────────────────────────────────────────────
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  static const routeName = '/AdminUsers';

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(_AdminUsersCtrl());
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        guardScreenView(ScreenKeys.adminUsers, label: 'User Management'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _appBar(context, ctrl),
      body: Column(children: [
        _SearchBar(ctrl: ctrl),
        _RoleFilterRow(ctrl: ctrl),
        Expanded(child: _UserList(ctrl: ctrl)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ctrl, null),
        backgroundColor: const Color(0xFF4C63B6),
        icon:
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
        label: const Text('Add User',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, _AdminUsersCtrl ctrl) {
    return AppBar(
      backgroundColor: const Color(0xFF1C2340),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () {
          // On Flutter Web, GetX's route stack can drift out of sync with
          // the browser's own history (e.g. after a hot reload) — guard
          // against that leaving this button doing nothing.
          if (Navigator.of(context).canPop()) {
            Get.back();
          } else {
            Get.offAllNamed('/');
          }
        },
      ),
      title:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('User Management',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        Text('app_users  •  admin only',
            style: TextStyle(color: Color(0xFF8892B0), fontSize: 10)),
      ]),
      actions: [
        Obx(() {
          final total = ctrl.visible.length;
          final active = ctrl.visible.where((u) => u.active).length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4C63B6).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF4C63B6).withValues(alpha: 0.6)),
            ),
            child: Text('$active / $total active',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          );
        }),
      ],
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final _AdminUsersCtrl ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C2340),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: TextField(
        onChanged: (v) => ctrl.search.value = v,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by user ID or name…',
          hintStyle: const TextStyle(color: Color(0xFF4A5568), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF4A5568), size: 18),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

// ─── Role filter chips ────────────────────────────────────────────────────────
class _RoleFilterRow extends StatelessWidget {
  final _AdminUsersCtrl ctrl;
  const _RoleFilterRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C2340),
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        children: [
          _chip('All', '', ctrl),
          ..._roles.map((r) => _chip(r, r, ctrl)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, _AdminUsersCtrl ctrl) {
    return Obx(() {
      final sel = ctrl.roleFilter.value == value;
      final col = value.isEmpty ? const Color(0xFF4C63B6) : _roleColor(value);
      return GestureDetector(
        onTap: () => ctrl.roleFilter.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: sel ? col : col.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? col : col.withValues(alpha: 0.3)),
          ),
          child: Text(
            value.isEmpty ? 'All' : value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : col,
            ),
          ),
        ),
      );
    });
  }
}

// ─── User list ────────────────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final _AdminUsersCtrl ctrl;
  const _UserList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4C63B6)));
      }
      final list = ctrl.visible;
      if (list.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                ctrl.loadError.value.isNotEmpty
                    ? Icons.error_outline_rounded
                    : Icons.people_outline_rounded,
                size: 52,
                color: ctrl.loadError.value.isNotEmpty
                    ? Colors.red.shade300
                    : Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
                ctrl.loadError.value.isNotEmpty
                    ? ctrl.loadError.value
                    : 'No users found',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ctrl.loadError.value.isNotEmpty
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            if (ctrl.loadError.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ctrl.reload(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ]),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) => _UserCard(user: list[i], ctrl: ctrl),
      );
    });
  }
}

// ─── User card ────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final _UserDoc user;
  final _AdminUsersCtrl ctrl;
  const _UserCard({required this.user, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final roleCol = _roleColor(user.role);
    final isMe = AuthService.to.currentUser?.userId == user.userId;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: user.active ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: user.active
                ? roleCol.withValues(alpha: 0.18)
                : Colors.red.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: roleCol.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: roleCol.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (user.name.isNotEmpty ? user.name : user.userId)[0]
                      .toUpperCase(),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: roleCol),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(
                      user.name.isNotEmpty ? user.name : user.userId,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C2340)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF4C63B6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4C63B6))),
                      ),
                    ],
                    if (!user.active) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('DISABLED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.red.shade400,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.badge_outlined,
                        size: 11, color: const Color(0xFF8892B0)),
                    const SizedBox(width: 3),
                    Text(user.userId,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF8892B0))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleCol.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(user.role,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: roleCol)),
                    ),
                  ]),
                ])),
            // Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Color(0xFF8892B0), size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) => _onAction(context, v),
              itemBuilder: (_) => [
                _item('edit', Icons.edit_outlined, 'Edit'),
                _item('permissions', Icons.security_rounded, 'Permissions'),
                if (!kIsWeb)
                  _item('enrollFace', Icons.face_retouching_natural_rounded,
                      'Enroll Face'),
                _item(
                  'toggle',
                  user.active
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  user.active ? 'Disable' : 'Enable',
                ),
                _item('copy', Icons.copy_rounded, 'Copy Password'),
                const PopupMenuDivider(),
                _item('delete', Icons.delete_outline_rounded, 'Delete',
                    color: Colors.red.shade600),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String val, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, size: 15, color: color ?? const Color(0xFF475569)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: color ?? const Color(0xFF334155),
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _onAction(BuildContext context, String action) async {
    switch (action) {
      case 'edit':
        _openForm(context, ctrl, user);
        break;
      case 'permissions':
        showDialog(
          context: context,
          builder: (_) =>
              PermissionsEditorDialog(userId: user.userId, userName: user.name),
        );
        break;
      case 'enrollFace':
        Get.to(
            () => FaceEnrollScreen(userId: user.userId, userName: user.name));
        break;
      case 'toggle':
        // Prevent admin from disabling their own account
        if (AuthService.to.currentUser?.userId == user.userId) {
          Get.snackbar('Not Allowed', 'You cannot disable your own account.',
              backgroundColor: Colors.orange.shade50,
              colorText: Colors.orange.shade800,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        await ctrl.toggleActive(user);
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: user.password));
        Get.snackbar('Copied', 'Password copied to clipboard',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF1C2340),
            colorText: Colors.white,
            duration: const Duration(seconds: 2));
        break;
      case 'delete':
        _confirmDelete(context);
        break;
    }
  }

  void _confirmDelete(BuildContext context) {
    if (AuthService.to.currentUser?.userId == user.userId) {
      Get.snackbar('Not Allowed', 'You cannot delete your own account.',
          backgroundColor: Colors.red.shade50,
          colorText: Colors.red.shade700,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF1C2340))),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF5A6480), height: 1.5),
            children: [
              const TextSpan(text: 'Delete '),
              TextSpan(
                text: user.name.isNotEmpty ? user.name : user.userId,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF1C2340)),
              ),
              const TextSpan(
                  text: ' from app_users?\n\nThis cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8892B0))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Get.back();
              final err = await ctrl.delete(user);
              if (err != null) {
                Get.snackbar('Error', err,
                    backgroundColor: Colors.red.shade50,
                    colorText: Colors.red.shade800);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit form (bottom sheet) ──────────────────────────────────────────
void _openForm(BuildContext context, _AdminUsersCtrl ctrl, _UserDoc? existing) {
  final isEdit = existing != null;
  final formKey = GlobalKey<FormState>();

  final idCtrl = TextEditingController(text: existing?.userId ?? '');
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final passCtrl = TextEditingController(text: existing?.password ?? '');
  final role = (existing?.role ?? AppRole.viewer).obs;
  final active = (existing?.active ?? true).obs;
  final obscure = true.obs;
  final saving = false.obs;
  final errMsg = ''.obs;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header bar
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2340),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C63B6).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      isEdit ? 'Edit User' : 'Add New User',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                    Text(
                      isEdit
                          ? 'Updating ${existing.userId}'
                          : 'Creates a document in app_users',
                      style: const TextStyle(
                          color: Color(0xFF8892B0), fontSize: 11),
                    ),
                  ])),
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C63B6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF4C63B6).withValues(alpha: 0.5)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.close_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Cancel',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
          // Form body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Form(
                key: formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User ID
                      _formLabel('User ID  (login username)'),
                      _formField(
                        controller: idCtrl,
                        hint: 'e.g. computer2',
                        icon: Icons.badge_outlined,
                        enabled: !isEdit,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        formatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9_]'))
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Full name
                      _formLabel('Full Name'),
                      _formField(
                        controller: nameCtrl,
                        hint: 'e.g. Ravi Kumar',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Password
                      _formLabel('Password'),
                      Obx(() => _formField(
                            controller: passCtrl,
                            hint: 'Set a password',
                            icon: Icons.lock_outline_rounded,
                            obscure: obscure.value,
                            suffix: IconButton(
                              icon: Icon(
                                obscure.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 17,
                                color: const Color(0xFF8892B0),
                              ),
                              onPressed: () => obscure.value = !obscure.value,
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          )),
                      const SizedBox(height: 14),

                      // Role picker
                      _formLabel('Role'),
                      Obx(() => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _roles.map((r) {
                              final sel = role.value == r;
                              final col = _roleColor(r);
                              return GestureDetector(
                                onTap: () => role.value = r,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? col : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? col
                                          : col.withValues(alpha: 0.25),
                                    ),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                                color:
                                                    col.withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3))
                                          ]
                                        : [],
                                  ),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(r,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    sel ? Colors.white : col)),
                                        const SizedBox(height: 2),
                                        Text(
                                          r == AppRole.admin
                                              ? 'Full access'
                                              : r == AppRole.viewer
                                                  ? 'Read only'
                                                  : 'Step access',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: sel
                                                  ? Colors.white
                                                      .withValues(alpha: 0.7)
                                                  : col.withValues(alpha: 0.6)),
                                        ),
                                      ]),
                                ),
                              );
                            }).toList(),
                          )),
                      const SizedBox(height: 14),

                      // Active toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDE0EE)),
                        ),
                        child: Obx(() => Row(children: [
                              const Icon(Icons.toggle_on_rounded,
                                  color: Color(0xFF8892B0), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('Account Status',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1C2340))),
                                    Text(
                                      active.value
                                          ? 'Active — user can log in'
                                          : 'Disabled — login blocked',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: active.value
                                              ? Colors.green.shade600
                                              : Colors.red.shade400),
                                    ),
                                  ])),
                              Switch(
                                value: active.value,
                                onChanged: (v) => active.value = v,
                                activeColor: const Color(0xFF4C63B6),
                              ),
                            ])),
                      ),

                      // Error message
                      Obx(() => errMsg.value.isNotEmpty
                          ? Container(
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 15, color: Colors.red.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(errMsg.value,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700))),
                              ]),
                            )
                          : const SizedBox.shrink()),

                      const SizedBox(height: 18),

                      // Save button
                      Obx(() => SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4C63B6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: saving.value
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate())
                                        return;
                                      saving.value = true;
                                      errMsg.value = '';

                                      String? err;
                                      if (isEdit) {
                                        existing.name = nameCtrl.text.trim();
                                        existing.password = passCtrl.text;
                                        existing.role = role.value;
                                        existing.active = active.value;
                                        err = await ctrl.saveUser(existing);
                                      } else {
                                        err = await ctrl.create(_UserDoc(
                                          docId: idCtrl.text.trim(),
                                          userId: idCtrl.text.trim(),
                                          name: nameCtrl.text.trim(),
                                          password: passCtrl.text,
                                          role: role.value,
                                          active: active.value,
                                        ));
                                      }

                                      saving.value = false;
                                      if (err != null) {
                                        errMsg.value = err;
                                      } else {
                                        Get.back();
                                        Get.snackbar(
                                          isEdit ? 'Updated' : 'User Created',
                                          isEdit
                                              ? '${nameCtrl.text} updated successfully'
                                              : '${nameCtrl.text} added to app_users',
                                          snackPosition: SnackPosition.BOTTOM,
                                          backgroundColor:
                                              const Color(0xFF1C2340),
                                          colorText: Colors.white,
                                          duration: const Duration(seconds: 3),
                                        );
                                      }
                                    },
                              icon: saving.value
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Icon(
                                      isEdit
                                          ? Icons.save_rounded
                                          : Icons.person_add_rounded,
                                      size: 18),
                              label: Text(
                                saving.value
                                    ? 'Saving…'
                                    : isEdit
                                        ? 'Save Changes'
                                        : 'Create User',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          )),
                    ]),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─── Small helpers ────────────────────────────────────────────────────────────
Widget _formLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6480))),
    );

Widget _formField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  bool enabled = true,
  bool obscure = false,
  Widget? suffix,
  String? Function(String?)? validator,
  List<TextInputFormatter>? formatters,
}) {
  return TextFormField(
    controller: controller,
    enabled: enabled,
    obscureText: obscure,
    validator: validator,
    inputFormatters: formatters,
    style: const TextStyle(fontSize: 13, color: Color(0xFF1C2340)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
      prefixIcon: Icon(icon, size: 17, color: const Color(0xFF8892B0)),
      suffixIcon: suffix,
      filled: true,
      fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE0EE))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE0EE))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4C63B6), width: 1.5)),
      disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEEF0F6))),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red.shade300)),
    ),
  );
}
