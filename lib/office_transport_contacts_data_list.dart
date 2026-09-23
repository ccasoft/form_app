// ─────────────────────────────────────────────────────────────────────────────
//  Office — Transport Contacts entries (within one category)
//  Ported from transport_data_list.dart (TransportDataList ->
//  TransportContactsDataList). Only reachable through
//  office_transport_contacts_module.dart, which already guards entry
//  as a whole — action-level gating only here.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String _kPrefix = 'transport';

class TransportContactsDataList extends StatefulWidget {
  final ModuleItem category;
  const TransportContactsDataList({super.key, required this.category});

  @override
  State<TransportContactsDataList> createState() => _TransportContactsDataListState();
}

class _TransportContactsDataListState extends State<TransportContactsDataList> {
  final _api = ApiService();
  String _searchQuery = "";

  void _showTransportDetails(Map<String, dynamic> data) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
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
                      child: Icon(Icons.local_shipping, size: 35, color: themeColor),
                    ),
                    const SizedBox(height: 15),
                    Text(data['name']?.toString().toUpperCase() ?? 'UNKNOWN',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("For Location: ${data['location'] ?? 'Not Specified'}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleAction(Icons.call, "Call", Colors.green, () => _makeCall(data['phone'] ?? '')),
                  _circleAction(Icons.message, "WhatsApp", Colors.blue, () => _openWhatsApp(data['phone'] ?? '')),
                  if (perms.canUpdate(ScreenKeys.officeTransportContacts))
                    _circleAction(Icons.edit, "Edit", Colors.orange, () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), () => _showTransportDialog(entry: data));
                    }),
                ],
              ),
              const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
              _fullDetailTile(Icons.assignment_ind, "Contact Person", data['contactPerson']),
              _fullDetailTile(Icons.phone_android, "Phone Number", data['phone']),
              _fullDetailTile(Icons.receipt_long, "GST Number", data['gst']),
              _fullDetailTile(Icons.location_on, "For Location", data['location']),
              _fullDetailTile(Icons.calendar_today, "Added On",
                  data['createdAt'] != null
                      ? (DateTime.tryParse(data['createdAt'].toString())?.toString().split(' ')[0] ?? "N/A")
                      : "N/A"),
              const SizedBox(height: 30),
              if (perms.canDelete(ScreenKeys.officeTransportContacts))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(context, data['id'], data['name'] ?? "this entry");
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
    );
  }

  void _showTransportDialog({Map<String, dynamic>? entry}) {
    final isEditing = entry != null;
    final data = isEditing ? entry : <String, dynamic>{};

    final n = TextEditingController(text: data['name'] ?? '');
    final g = TextEditingController(text: data['gst'] ?? '');
    final p = TextEditingController(text: data['contactPerson'] ?? '');
    final ph = TextEditingController(text: data['phone'] ?? '');
    final loc = TextEditingController(text: data['location'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Transporter' : 'Add Transporter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInput(n, "Company Name", "Ex: ABC Transport"),
                const SizedBox(height: 12),
                _buildInput(loc, "For Location", "Ex: Raigarh"),
                const SizedBox(height: 12),
                _buildInput(g, "GST Number", "Optional"),
                _buildInput(p, "Contact Person", "Name"),
                _buildInput(ph, "Phone Number", "10 Digits", isPhone: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing ? Colors.orange : widget.category.gradient[0]),
              onPressed: () async {
                if (n.text.isNotEmpty && ph.text.isNotEmpty) {
                  final payload = {
                    'name': n.text,
                    'location': loc.text,
                    'gst': g.text,
                    'contactPerson': p.text,
                    'phone': ph.text,
                  };

                  if (isEditing) {
                    await _api.updateOfficeEntry(_kPrefix, entry['id'], payload);
                  } else {
                    await _api.addOfficeCategoryEntry(_kPrefix, widget.category.name, payload);
                  }
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(isEditing ? 'UPDATE' : 'SAVE', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) cleanNumber = '91$cleanNumber';
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmDelete(BuildContext context, String entryId, String name) {
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
                  SnackBar(content: Text(ok ? "Entry Deleted" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String lbl, String hint, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(labelText: lbl, hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _fullDetailTile(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey[400]),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500)),
    );
  }

  Widget _circleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.category.gradient[0];
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: Text('${widget.category.name} Transport'),
          backgroundColor: themeColor,
          foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search by Name, GST or Location...",
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
                final docs = snapshot.data!.where((data) {
                  return (data['name'] ?? "").toString().toLowerCase().contains(_searchQuery) ||
                      (data['gst'] ?? "").toString().toLowerCase().contains(_searchQuery) ||
                      (data['location'] ?? "").toString().toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: themeColor.withOpacity(0.1),
                            child: Icon(Icons.local_shipping, color: themeColor)),
                        title: Text(data['name'] ?? 'Unnamed'),
                        subtitle: Text("GST: ${data['gst'] ?? 'N/A'}\nPhone: ${data['phone'] ?? 'N/A'}"),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => _showTransportDetails(data),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeTransportContacts)
          ? FloatingActionButton(
              backgroundColor: themeColor,
              onPressed: () => _showTransportDialog(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
