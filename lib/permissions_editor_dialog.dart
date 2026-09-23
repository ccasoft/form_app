// ─────────────────────────────────────────────────────────────────────────────
//  Permissions Editor Dialog
//
//  Opened from Admin > Users > (user) > Permissions. One unified list
//  of every screen in the app (including the 5 workflow stages), each
//  with only the checkboxes that are actually meaningful for it
//  (kScreenCapabilities) — a read-only dashboard only shows View, a
//  full CRUD screen shows all 4.
//
//  No shared roles — this is the only place permissions are set.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/user_permissions.dart';

class PermissionsEditorDialog extends StatefulWidget {
  final String userId;
  final String userName;
  const PermissionsEditorDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<PermissionsEditorDialog> createState() =>
      _PermissionsEditorDialogState();
}

class _PermissionsEditorDialogState extends State<PermissionsEditorDialog> {
  final _api = ApiService();
  bool _loading = true;
  bool _saving = false;

  final Map<String, ScreenPerm> _screens = {
    for (final k in kScreenKeys) k: const ScreenPerm(),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.fetchPermissions(widget.userId);
    if (data != null) {
      final perms = UserPermissions.fromJson(data);
      _screens.addAll(perms.screens);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await _api.savePermissions(
      widget.userId,
      {for (final e in _screens.entries) e.key: e.value.toJson()},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (AuthService.to.currentUser?.userId == widget.userId) {
        await AuthService.to.refreshPermissions();
      }
      Get.back();
      Get.snackbar('Saved', 'Permissions updated for ${widget.userName}.',
          backgroundColor: Colors.green.shade50,
          colorText: Colors.green.shade800,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('Error', 'Could not save permissions. Try again.',
          backgroundColor: Colors.red.shade50,
          colorText: Colors.red.shade800,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: _loading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  _columnHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: kScreenKeys.map((key) => _screenRow(key)).toList(),
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(children: [
          const Icon(Icons.security_rounded, size: 20, color: Color(0xFF334155)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Permissions — ${widget.userName}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155))),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Get.back(),
          ),
        ]),
      );

  Widget _columnHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Row(children: [
          const Expanded(flex: 3, child: SizedBox()),
          _colLabel('View'),
          _colLabel('Add'),
          _colLabel('Update'),
          _colLabel('Delete'),
        ]),
      );

  Widget _colLabel(String text) => Expanded(
        flex: 2,
        child: Text(text,
            textAlign: TextAlign.left,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Color(0xFF94A3B8))),
      );

  Widget _screenRow(String key) {
    final perm = _screens[key] ?? const ScreenPerm();
    final caps = kScreenCapabilities[key] ?? const {'view'};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(kScreenLabels[key] ?? key,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
        ),
        _miniCheck(caps.contains('view'), perm.view,
            (v) => setState(() => _screens[key] = perm.copyWith(view: v))),
        _miniCheck(caps.contains('add'), perm.add,
            (v) => setState(() => _screens[key] = perm.copyWith(add: v))),
        _miniCheck(caps.contains('update'), perm.update,
            (v) => setState(() => _screens[key] = perm.copyWith(update: v))),
        _miniCheck(caps.contains('delete'), perm.delete,
            (v) => setState(() => _screens[key] = perm.copyWith(delete: v))),
      ]),
    );
  }

  /// Renders a checkbox only if [applicable] — otherwise an empty slot,
  /// so columns still line up for screens that don't use every flag.
  Widget _miniCheck(bool applicable, bool value, ValueChanged<bool> onChanged) {
    if (!applicable) return const Expanded(flex: 2, child: SizedBox());
    return Expanded(
      flex: 2,
      child: Checkbox(
        value: value,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (v) => onChanged(v ?? false),
      ),
    );
  }

  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : () => Get.back(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      );
}
