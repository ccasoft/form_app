// ─────────────────────────────────────────────────────────────────────────────
//  Office — One-Time Licenses
//  Ported from one_time_licenses_module.dart. Api.* -> ApiService,
//  screen guarded by canView, Add/Delete gated by canAdd/canDelete.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/office_admin_dashboard_data.dart';
import 'package:form_app/office_add_dialogs.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

class OneTimeLicensesModule extends StatefulWidget {
  const OneTimeLicensesModule({super.key});

  @override
  State<OneTimeLicensesModule> createState() => _OneTimeLicensesModuleState();
}

class _OneTimeLicensesModuleState extends State<OneTimeLicensesModule> {
  final _api = ApiService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officeOneTimeLicenses, label: 'One-Time Licenses'));
  }

  @override
  Widget build(BuildContext context) {
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('One-Time Licenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(APP_HEADER_COLOR),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildLicensesList()),
        ],
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeOneTimeLicenses)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await showDialog(context: context, builder: (_) => const AddOneTimeLicenseDialog());
                if (result == true) setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Add License'),
              backgroundColor: const Color(APP_PRIMARY_COLOR),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search licenses...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildLicensesList() {
    final perms = AuthService.to.perms;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: officePollingStream(() async {
        final list = await _api.getOneTimeLicenses();
        list.sort((a, b) => (a['licenseName'] ?? '').toString().compareTo((b['licenseName'] ?? '').toString()));
        return list;
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var licenses = snapshot.data!;

        if (_searchQuery.isNotEmpty) {
          licenses = licenses.where((data) {
            return (data['licenseName'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                (data['licenseKey'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                (data['issuedBy'] ?? '').toString().toLowerCase().contains(_searchQuery) ||
                (data['vendor'] ?? '').toString().toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (licenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 100, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(_searchQuery.isEmpty ? 'No licenses added yet' : 'No licenses found',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                if (_searchQuery.isEmpty && perms.canAdd(ScreenKeys.officeOneTimeLicenses)) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog(context: context, builder: (_) => const AddOneTimeLicenseDialog());
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add License'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(APP_PRIMARY_COLOR)),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: licenses.length,
          itemBuilder: (context, index) => _buildLicenseCard(licenses[index]),
        );
      },
    );
  }

  Widget _buildLicenseCard(Map<String, dynamic> data) {
    final licenseName = data['licenseName'] ?? '';
    final licenseKey = data['licenseKey'] ?? '';
    final issuedBy = data['issuedBy'] ?? '';
    final purchaseDate = data['purchaseDate'] ?? '';
    final vendor = data['vendor'];
    final cost = data['cost'];
    final notes = data['notes'];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showLicenseDetails(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(APP_PRIMARY_COLOR).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.verified, color: Color(APP_PRIMARY_COLOR), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(licenseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Key: $licenseKey',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(APP_SUCCESS_COLOR), borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildInfoChip(Icons.business, 'Issued By', issuedBy)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildInfoChip(
                        Icons.calendar_today, 'Purchase', AdminDashboardData.formatDate(purchaseDate))),
              ]),
              if (vendor != null) ...[
                const SizedBox(height: 8),
                _buildInfoChip(Icons.store, 'Vendor', vendor),
              ],
              if (cost != null) ...[
                const SizedBox(height: 8),
                _buildInfoChip(Icons.currency_rupee, 'Cost', '₹${(cost as num).toStringAsFixed(2)}'),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(notes,
                            style: TextStyle(color: Colors.blue[900], fontSize: 13, fontStyle: FontStyle.italic),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  void _showLicenseDetails(Map<String, dynamic> data) {
    final perms = AuthService.to.perms;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.verified, color: Color(APP_PRIMARY_COLOR)),
          const SizedBox(width: 8),
          Expanded(child: Text(data['licenseName'] ?? '', style: const TextStyle(fontSize: 18))),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('License Key', data['licenseKey'] ?? ''),
              const Divider(),
              _buildDetailRow('Purchase Date', AdminDashboardData.formatDate(data['purchaseDate'] ?? '')),
              _buildDetailRow('Issued By', data['issuedBy'] ?? ''),
              if (data['vendor'] != null) _buildDetailRow('Vendor', data['vendor']),
              if (data['cost'] != null) _buildDetailRow('Cost', '₹${(data['cost'] as num).toStringAsFixed(2)}'),
              if (data['notes'] != null && data['notes'].isNotEmpty) ...[
                const Divider(),
                const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(data['notes'], style: TextStyle(color: Colors.blue[900])),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (perms.canDelete(ScreenKeys.officeOneTimeLicenses))
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(data);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(APP_DELETE_COLOR)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete License'),
        content: Text('Are you sure you want to delete "${data['licenseName']}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await _api.deleteOneTimeLicense(data['id']);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'License deleted' : 'Delete failed')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(APP_DELETE_COLOR)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
