import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';

class Transportmanagement extends StatefulWidget {
  const Transportmanagement({super.key});

  @override
  State<Transportmanagement> createState() => _TransportmanagementState();
}

class _TransportmanagementState extends State<Transportmanagement> {
  final _transportCtrl = TextEditingController();
  List<String> transportList = [];
  final ApiService _fs = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.transport, label: 'Transport'));
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final t = await _fs.getTransport();
    setState(() {
      transportList = t;
      _isLoading = false;
    });
  }

  Future<void> _addTransport() async {
    final name = _transportCtrl.text.trim();
    if (name.isEmpty) return;
    if (transportList.contains(name)) {
      Get.snackbar('Duplicate', 'Transport already exists');
      return;
    }
    setState(() {
      transportList.add(name);
      transportList.sort();
    });
    _transportCtrl.clear();
    await _fs.saveTransport(transportList);
    Get.snackbar('Added', 'Transport added');
  }

  Future<void> _delete(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Transport'),
        content: Text('Remove "$name" from the list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => transportList.remove(name));
      await _fs.saveTransport(transportList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _transportCtrl,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _addTransport(),
                    decoration: InputDecoration(
                      hintText: 'Enter transport name...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: !AuthService.to.perms.canAdd(ScreenKeys.transport)
                      ? null
                      : _addTransport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Add',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (transportList.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No transports added',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transportList.length,
                itemBuilder: (ctx, i) {
                  final t = transportList[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: Color(0xFF6A1B9A), size: 20),
                      ),
                      title: Text(t,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 15)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        onPressed: !AuthService.to.perms
                                .canDelete(ScreenKeys.transport)
                            ? null
                            : () async {
                                final ok = await AdminPin.verify(context,
                                    action: 'delete transport');
                                if (!ok) return;
                                _delete(t);
                              },
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
