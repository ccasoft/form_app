// ─────────────────────────────────────────────────────────────────────────────
//  Office — Address Book entries (within one category)
//  Ported from address_data_list.dart. Only reachable through
//  office_address_book_module.dart, which already guards entry to
//  Address Book as a whole — no separate guard needed here, just
//  action-level gating on Add/Edit/Delete.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String _kPrefix = 'address-book';

class AddressDataList extends StatefulWidget {
  final ModuleItem category;

  const AddressDataList({super.key, required this.category});

  @override
  State<AddressDataList> createState() => _AddressDataListState();
}

class _AddressDataListState extends State<AddressDataList> {
  final _api = ApiService();
  String _searchQuery = "";

  Future<void> _makeCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String num = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (num.length == 10) num = '91$num';
    final Uri uri = Uri.parse("https://wa.me/$num");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAddressDialog({Map<String, dynamic>? entry}) {
    final bool isEditing = entry != null;
    final data = isEditing ? entry : <String, dynamic>{};

    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
    final firmCtrl = TextEditingController(text: data['firmName'] ?? '');
    final addressCtrl = TextEditingController(text: data['city'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final notesCtrl = TextEditingController(text: data['notes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Edit Contact" : "Add Contact"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput(nameCtrl, "Name"),
              _buildInput(phoneCtrl, "Phone", isPhone: true),
              _buildInput(firmCtrl, "Firm / Department"),
              _buildInput(addressCtrl, "City / Address"),
              _buildInput(emailCtrl, "Email"),
              _buildInput(notesCtrl, "Notes"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.category.gradient[0]),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;

              final payload = {
                'name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'firmName': firmCtrl.text,
                'city': addressCtrl.text,
                'email': emailCtrl.text,
                'notes': notesCtrl.text,
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
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  void _showContactDetails(Map<String, dynamic> data) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: themeColor.withOpacity(0.1),
                child: Icon(Icons.person, size: 40, color: themeColor),
              ),
              const SizedBox(height: 10),
              Text(data['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleAction(Icons.call, "Call", Colors.green, () => _makeCall(data['phone'])),
                  _circleAction(Icons.chat, "WhatsApp", Colors.blue, () => _openWhatsApp(data['phone'])),
                  if (perms.canUpdate(ScreenKeys.officeAddressBook))
                    _circleAction(Icons.edit, "Edit", Colors.orange, () {
                      Navigator.pop(context);
                      _showAddressDialog(entry: data);
                    }),
                ],
              ),
              const Divider(height: 30),
              _detailTile("Phone", data['phone']),
              _detailTile("Firm", data['firmName']),
              _detailTile("Address", data['city']),
              _detailTile("Email", data['email']),
              _detailTile("Notes", data['notes']),
              const SizedBox(height: 20),
              if (perms.canDelete(ScreenKeys.officeAddressBook))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.delete),
                  label: const Text("DELETE"),
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDelete(context, data['id'], data['name'] ?? "this contact");
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return ListTile(title: Text(label), subtitle: Text(value));
  }

  Widget _circleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, String entryId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Contact?"),
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
                  SnackBar(content: Text(ok ? "Contact Deleted" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
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
              stream: officePollingStream(() async {
                final list = await _api.getOfficeCategoryEntries(_kPrefix, widget.category.name);
                list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
                return list;
              }),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.where((d) {
                  return "${d['name']} ${d['phone']}".toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: themeColor.withOpacity(0.1),
                          child: Text((data['name'] ?? '?')[0].toString().toUpperCase(),
                              style: TextStyle(color: themeColor)),
                        ),
                        title: Text(data['name'] ?? ''),
                        subtitle: Text(data['phone'] ?? ''),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _showContactDetails(data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeAddressBook)
          ? FloatingActionButton(
              backgroundColor: themeColor,
              onPressed: () => _showAddressDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
