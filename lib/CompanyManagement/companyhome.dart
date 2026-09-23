import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/CompanyManagement/createCompany.dart';
import 'package:get/get.dart';

class CompanyHome extends StatefulWidget {
  const CompanyHome({super.key});

  @override
  State<CompanyHome> createState() => _CompanyHomeState();
}

class _CompanyHomeState extends State<CompanyHome> {
  final ApiService _fs = ApiService();
  List<CompanyData> _companies = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  List<CompanyData> _filtered = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.company, label: 'Company'));
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final companies = await _fs.getCompanies();
    setState(() {
      _companies = companies;
      _filtered = companies;
      _isLoading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _companies
          .where((c) =>
              c.companyName.toLowerCase().contains(q) ||
              c.gstNumber.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Management')),
      floatingActionButton: !AuthService.to.perms.canAdd(ScreenKeys.company)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Get.to(() => const CreateCompany());
                if (result == true) _load();
              },
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Company',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: Column(
        children: [
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search companies...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('No companies found',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ]),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final c = _filtered[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.business_rounded,
                            color: Color(0xFF1565C0)),
                      ),
                      title: Text(c.companyName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.address.isNotEmpty)
                            Text(c.address,
                                style: const TextStyle(fontSize: 12)),
                          if (c.gstNumber.isNotEmpty)
                            Text('GST: ${c.gstNumber}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: AppTheme.primary),
                            onPressed: !AuthService.to.perms
                                    .canUpdate(ScreenKeys.company)
                                ? null
                                : () async {
                                    final pinOk = await AdminPin.verify(context,
                                        action: 'edit company');
                                    if (!pinOk) return;
                                    final result = await Get.to(
                                        () => const CreateCompany(),
                                        arguments: {
                                          'isEditing': true,
                                          'companyId': c.companyId,
                                          'companyName': c.companyName,
                                          'address': c.address,
                                          'gstNumber': c.gstNumber
                                        });
                                    if (result == true) _load();
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: !AuthService.to.perms
                                    .canDelete(ScreenKeys.company)
                                ? null
                                : () async {
                                    final pinOk = await AdminPin.verify(context,
                                        action: 'delete company');
                                    if (!pinOk) return;
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        title: const Text('Delete Company'),
                                        content:
                                            Text('Delete "${c.companyName}"?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _fs.deleteCompany(c.companyId);
                                      _load();
                                    }
                                  },
                          ),
                        ],
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
