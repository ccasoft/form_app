// ─────────────────────────────────────────────────────────────────────────────
//  Office — Password entries (within one category)
//  Ported from password_data_list.dart. Only reachable through
//  office_password_module.dart, which already guards entry to
//  Passwords as a whole — action-level gating only here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';
import 'package:form_app/office_password_otp_gate.dart';

const String _kPrefix = 'passwords';

class PasswordDataList extends StatefulWidget {
  final ModuleItem category;
  const PasswordDataList({super.key, required this.category});

  @override
  State<PasswordDataList> createState() => _PasswordDataListState();
}

class _PasswordDataListState extends State<PasswordDataList> {
  final _api = ApiService();
  String _searchQuery = "";

  void _showPasswordDetails(Map<String, dynamic> data) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;
    // Local to THIS sheet instance — always starts hidden, so every
    // fresh "view password" action needs its own OTP, per entry.
    bool isObscured = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 50, height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: themeColor.withOpacity(0.1),
                        child: Icon(Icons.lock_person, size: 35, color: themeColor),
                      ),
                      const SizedBox(height: 15),
                      Text(data['serviceName']?.toString().toUpperCase() ?? 'UNKNOWN',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(data['company'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _circleAction(Icons.copy, "Copy Pass", Colors.blue, () async {
                      final unlocked = await requestPasswordOtpUnlock(context);
                      if (!unlocked) return;
                      Clipboard.setData(ClipboardData(text: data['password'] ?? ''));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password Copied!")));
                      }
                    }),
                    _circleAction(Icons.open_in_browser, "Launch", Colors.purple, () async {
                      final url = data['loginUrl'] ?? '';
                      if (url.isNotEmpty) {
                        final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      }
                    }),
                    if (perms.canUpdate(ScreenKeys.officePasswords))
                      _circleAction(Icons.edit, "Edit", Colors.orange, () {
                        Navigator.pop(context);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          _showPasswordDialog(entry: data);
                        });
                      }),
                  ],
                ),
                const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
                _fullDetailTile(Icons.person_outline, "Username / ID", data['username']),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 25),
                  leading: const Icon(Icons.password),
                  title: const Text("Password", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(isObscured ? "••••••••" : (data['password'] ?? ''),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  trailing: IconButton(
                    icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                    onPressed: () async {
                      if (isObscured) {
                        // About to reveal — gate it. Hiding again is free.
                        final unlocked = await requestPasswordOtpUnlock(context);
                        if (!unlocked) return;
                      }
                      setSheetState(() => isObscured = !isObscured);
                    },
                  ),
                ),
                _fullDetailTile(Icons.link, "Login URL", data['loginUrl']),
                _fullDetailTile(Icons.business, "Account Provider", data['provider']),
                _fullDetailTile(Icons.update, "Last Updated", data['lastUpdated']),
                _fullDetailTile(Icons.notes, "Notes", data['notes']),
                const SizedBox(height: 30),
                if (perms.canDelete(ScreenKeys.officePasswords))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0),
                        onPressed: () {
                          Navigator.pop(context);
                          _secureDelete(context, data['id'], data['serviceName'] ?? "this entry");
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text("PERMANENTLY DELETE"),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog({Map<String, dynamic>? entry}) {
    final isEditing = entry != null;
    final data = isEditing ? entry : <String, dynamic>{};

    final serviceName = TextEditingController(text: data['serviceName'] ?? '');
    String? selectedProvider = data['provider'];
    final loginUrl = TextEditingController(text: data['loginUrl'] ?? '');
    final username = TextEditingController(text: data['username'] ?? '');
    final password = TextEditingController(text: data['password'] ?? '');
    final company = TextEditingController(text: data['company'] ?? '');
    final notes = TextEditingController(text: data['notes'] ?? '');

    final List<String> providers = ["Google", "Bank", "GST Portal", "Microsoft", "Social Media", "Other"];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? "Edit Credentials" : "Add Credentials"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(serviceName, "Service Name", "Ex: SAP"),
                DropdownButtonFormField<String>(
                  value: (providers.contains(selectedProvider)) ? selectedProvider : null,
                  decoration: const InputDecoration(labelText: "Provider", border: OutlineInputBorder()),
                  items: providers.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setDialogState(() => selectedProvider = val),
                ),
                const SizedBox(height: 12),
                _buildInput(loginUrl, "Login URL", "https://..."),
                _buildInput(username, "Username", "User ID"),
                _buildInput(password, "Password", "Passcode"),
                _buildInput(company, "Account Company", "Ex: Emcure"),
                _buildInput(notes, "Notes", "Extra details", maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.orange : widget.category.gradient[0],
              ),
              onPressed: () async {
                final payload = {
                  'serviceName': serviceName.text,
                  'provider': selectedProvider ?? 'Other',
                  'loginUrl': loginUrl.text,
                  'username': username.text,
                  'password': password.text,
                  'company': company.text,
                  'lastUpdated': DateTime.now().toString().split(' ')[0],
                  'notes': notes.text,
                };

                if (isEditing) {
                  await _api.updateOfficeEntry(_kPrefix, entry['id'], payload);
                } else {
                  await _api.addOfficeCategoryEntry(_kPrefix, widget.category.name, payload);
                }
                if (mounted) Navigator.pop(context);
              },
              child: Text(isEditing ? "UPDATE" : "SAVE", style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _secureDelete(BuildContext context, String entryId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: Text("Delete '$name'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await _api.deleteOfficeEntry(_kPrefix, entryId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? "Deleted Successfully" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _fullDetailTile(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey[400]),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
    );
  }

  Widget _circleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String lbl, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: lbl, hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text(widget.category.name), backgroundColor: themeColor, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: officePollingStream(() => _api.getOfficeCategoryEntries(_kPrefix, widget.category.name)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.where((d) {
                  return d.values.any((v) => v.toString().toLowerCase().contains(_searchQuery));
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: themeColor.withOpacity(0.1),
                            child: Icon(Icons.vpn_key, color: themeColor, size: 20)),
                        title: Text(data['serviceName'] ?? 'Unnamed'),
                        subtitle: Text(data['username'] ?? ''),
                        onTap: () => _showPasswordDetails(data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officePasswords)
          ? FloatingActionButton(
              backgroundColor: themeColor,
              onPressed: () => _showPasswordDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
