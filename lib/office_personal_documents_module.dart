// ─────────────────────────────────────────────────────────────────────────────
//  Office — Personal Documents (by Person)
//  Ported from personal_documents_module.dart. Api.* -> ApiService,
//  screen guarded by canView, Add gated by canAdd, Delete by canDelete.
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

class PersonalDocumentsModule extends StatefulWidget {
  const PersonalDocumentsModule({super.key});

  @override
  State<PersonalDocumentsModule> createState() => _PersonalDocumentsModuleState();
}

class _PersonalDocumentsModuleState extends State<PersonalDocumentsModule> {
  final _api = ApiService();
  String? _selectedPersonId;
  String? _selectedPersonName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officePersonalDocuments, label: 'Personal Documents'));
  }

  @override
  Widget build(BuildContext context) {
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Personal Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(APP_HEADER_COLOR),
        elevation: 0,
        actions: [
          if (perms.canAdd(ScreenKeys.officePersonalDocuments))
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              tooltip: 'Add Person',
              onPressed: () async {
                final result = await showDialog(context: context, builder: (_) => const AddPersonDialog());
                if (result == true) setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPersonSelector(),
          Expanded(child: _selectedPersonId == null ? _buildEmptyState() : _buildDocumentsList()),
        ],
      ),
      floatingActionButton: (_selectedPersonId != null && perms.canAdd(ScreenKeys.officePersonalDocuments))
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDocumentDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Document'),
              backgroundColor: const Color(APP_PRIMARY_COLOR),
            )
          : null,
    );
  }

  Widget _buildPersonSelector() {
    final perms = AuthService.to.perms;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: officePollingStream(() async {
          final list = await _api.getPersons();
          list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          return list;
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final persons = snapshot.data!;

          if (persons.isEmpty) {
            return Column(
              children: [
                const Text('No persons added yet', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                if (perms.canAdd(ScreenKeys.officePersonalDocuments))
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog(context: context, builder: (_) => const AddPersonDialog());
                      if (result == true) setState(() {});
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Person'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(APP_PRIMARY_COLOR)),
                  ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Person:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: persons.map((p) {
                  final personId = p['id'] as String;
                  final personName = p['name'] ?? '';
                  final isSelected = _selectedPersonId == personId;
                  return ChoiceChip(
                    label: Text(personName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPersonId = selected ? personId : null;
                        _selectedPersonName = selected ? personName : null;
                      });
                    },
                    selectedColor: const Color(APP_PRIMARY_COLOR),
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Select a person to view documents', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildDocumentsList() {
    final perms = AuthService.to.perms;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: officePollingStream(() async {
        final list = await _api.getPersonalDocuments(personId: _selectedPersonId!);
        list.sort((a, b) => (a['documentType'] ?? '').toString().compareTo((b['documentType'] ?? '').toString()));
        return list;
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final documents = snapshot.data!;

        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No documents added yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 8),
                if (perms.canAdd(ScreenKeys.officePersonalDocuments))
                  ElevatedButton.icon(
                    onPressed: () => _showAddDocumentDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Document'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(APP_PRIMARY_COLOR)),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (context, index) => _buildDocumentCard(documents[index]),
        );
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> data) {
    final documentType = data['documentType'] ?? '';
    final documentNumber = data['documentNumber'] ?? '';
    final expiryDate = data['expiryDate'];
    final notes = data['notes'];

    int? daysUntilExpiry;
    if (expiryDate != null && expiryDate.isNotEmpty) {
      daysUntilExpiry = AdminDashboardData.getDaysUntilExpiry(expiryDate);
    }

    final isExpired = daysUntilExpiry != null && daysUntilExpiry < 0;
    final isExpiring = daysUntilExpiry != null && daysUntilExpiry <= 30 && daysUntilExpiry >= 0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isExpired
            ? const BorderSide(color: Color(APP_DELETE_COLOR), width: 2)
            : isExpiring
                ? const BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showDocumentDetails(data),
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
                    child: const Icon(Icons.badge, color: Color(APP_PRIMARY_COLOR), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(documentType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(documentNumber, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  if (daysUntilExpiry != null) _buildExpiryBadge(daysUntilExpiry),
                ],
              ),
              if (expiryDate != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.calendar_today, size: 16, color: isExpired || isExpiring ? Colors.orange : Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Expiry: ${AdminDashboardData.formatDate(expiryDate)}',
                      style: TextStyle(
                          color: isExpired || isExpiring ? Colors.orange : Colors.grey[600],
                          fontWeight: isExpired || isExpiring ? FontWeight.bold : FontWeight.normal)),
                ]),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(notes,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryBadge(int daysUntilExpiry) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (daysUntilExpiry < 0) {
      badgeColor = const Color(APP_DELETE_COLOR);
      badgeText = 'EXPIRED';
      badgeIcon = Icons.error;
    } else if (daysUntilExpiry <= 7) {
      badgeColor = Colors.red;
      badgeText = '${daysUntilExpiry}d';
      badgeIcon = Icons.warning;
    } else if (daysUntilExpiry <= 30) {
      badgeColor = Colors.orange;
      badgeText = '${daysUntilExpiry}d';
      badgeIcon = Icons.access_time;
    } else {
      badgeColor = const Color(APP_SUCCESS_COLOR);
      badgeText = '${daysUntilExpiry}d';
      badgeIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(badgeIcon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Text(badgeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  void _showAddDocumentDialog() async {
    final personName = _selectedPersonName ?? '';

    if (!mounted) return;

    final result = await showDialog(
      context: context,
      builder: (_) => AddPersonalDocumentDialog(personId: _selectedPersonId!, personName: personName),
    );

    if (result == true) setState(() {});
  }

  void _showDocumentDetails(Map<String, dynamic> data) {
    final perms = AuthService.to.perms;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['documentType'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Person', data['personName'] ?? ''),
              _buildDetailRow('Document Number', data['documentNumber'] ?? ''),
              if (data['issueDate'] != null) _buildDetailRow('Issue Date', AdminDashboardData.formatDate(data['issueDate'])),
              if (data['expiryDate'] != null) _buildDetailRow('Expiry Date', AdminDashboardData.formatDate(data['expiryDate'])),
              if (data['issuingAuthority'] != null) _buildDetailRow('Issuing Authority', data['issuingAuthority']),
              if (data['notes'] != null) _buildDetailRow('Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (perms.canDelete(ScreenKeys.officePersonalDocuments))
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
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final ok = await _api.deletePersonalDocument(data['id']);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Document deleted' : 'Delete failed')),
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
