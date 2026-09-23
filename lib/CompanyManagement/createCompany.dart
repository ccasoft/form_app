import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';

class CreateCompany extends StatefulWidget {
  const CreateCompany({super.key});

  @override
  State<CreateCompany> createState() => _CreateCompanyState();
}

class _CreateCompanyState extends State<CreateCompany> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  bool _isEditing = false;
  String? _companyId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args != null) {
      _isEditing = args['isEditing'] ?? false;
      _companyId = args['companyId'];
      _nameCtrl.text = args['companyName'] ?? '';
      _addressCtrl.text = args['address'] ?? '';
      _gstCtrl.text = args['gstNumber'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Company' : 'Create Company')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.business_rounded, color: Color(0xFF1565C0), size: 18),
                        SizedBox(width: 8),
                        Text('Company Details', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1565C0), fontSize: 13)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Company Name *', prefixIcon: Icon(Icons.business_rounded)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Address *', prefixIcon: Icon(Icons.location_on_rounded)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _gstCtrl,
                            decoration: const InputDecoration(labelText: 'GST Number', prefixIcon: Icon(Icons.numbers_rounded)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEditing ? 'Update Company' : 'Create Company'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final fs = ApiService();
    final data = {
      'companyName': _nameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'gstNumber': _gstCtrl.text.trim(),
    };
    bool success;
    if (_isEditing) {
      success = await fs.updateCompany(_companyId!, data);
    } else {
      success = await fs.createCompany(data);
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      Get.snackbar('Success', _isEditing ? 'Company updated' : 'Company created',
          duration: const Duration(seconds: 2));
      Navigator.of(context).pop(true);
    } else {
      Get.snackbar('Error', 'Failed to save company');
    }
  }
}
