// ─────────────────────────────────────────────────────────────────────────────
//  Office — Add dialogs (License, AMC, Important Number, Person,
//  Personal Document, One-Time License). Ported from add_dialogs.dart.
//  All Api.* calls -> ApiService. Permission gating happens at the
//  call site (the FAB that opens each dialog), not inside the dialogs
//  themselves — showing the dialog already implies canAdd passed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:form_app/office_notification_service.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';

// ========================================
// ADD LICENSE DIALOG
// ========================================
class AddLicenseDialog extends StatefulWidget {
  final String categoryName;

  const AddLicenseDialog({super.key, required this.categoryName});

  @override
  State<AddLicenseDialog> createState() => _AddLicenseDialogState();
}

class _AddLicenseDialogState extends State<AddLicenseDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _licenseNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _renewalDateController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _licenseNameController.dispose();
    _licenseNumberController.dispose();
    _renewalDateController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() {
        _renewalDateController.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _selectFromAddressBook() async {
    final notificationService = NotificationService();
    final contacts = await notificationService.getAllContacts();

    if (!mounted) return;

    final selected = await showDialog<AddressBookContact>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Contact'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: contacts.isEmpty
              ? const Center(child: Text('No contacts found in Address Book'))
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(contact.name[0].toUpperCase())),
                      title: Text(contact.name),
                      subtitle: Text('${contact.phone}\n${contact.category}'),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(context, contact),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _contactPersonController.text = selected.name;
        _contactPhoneController.text = selected.phone;
      });
    }
  }

  Future<void> _saveLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.addLicenseEntry(widget.categoryName, {
        'licenseName': _licenseNameController.text.trim(),
        'licenseNumber': _licenseNumberController.text.trim(),
        'renewalDate': _renewalDateController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add License - ${widget.categoryName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _licenseNameController,
                decoration: const InputDecoration(labelText: 'License Name *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseNumberController,
                decoration: const InputDecoration(labelText: 'License Number *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _renewalDateController,
                decoration: InputDecoration(
                  labelText: 'Renewal Date (DD/MM/YYYY) *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(
                  labelText: 'Contact Person',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts), onPressed: _selectFromAddressBook, tooltip: 'Select from Address Book'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                    labelText: 'Contact Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveLicense,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

// ========================================
// ADD AMC CONTRACT DIALOG
// ========================================
class AddAMCDialog extends StatefulWidget {
  const AddAMCDialog({super.key});

  @override
  State<AddAMCDialog> createState() => _AddAMCDialogState();
}

class _AddAMCDialogState extends State<AddAMCDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _contractNameController = TextEditingController();
  final _vendorController = TextEditingController();
  final _validityDateController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _serviceTypeController = TextEditingController();
  final _annualCostController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _contractNameController.dispose();
    _vendorController.dispose();
    _validityDateController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _serviceTypeController.dispose();
    _annualCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() {
        _validityDateController.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _selectFromAddressBook() async {
    final notificationService = NotificationService();
    final contacts = await notificationService.getAllContacts();

    if (!mounted) return;

    final selected = await showDialog<AddressBookContact>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Vendor Contact'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: contacts.isEmpty
              ? const Center(child: Text('No contacts found in Address Book'))
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(contact.name[0].toUpperCase())),
                      title: Text(contact.name),
                      subtitle: Text('${contact.phone}\n${contact.firmName ?? contact.category}'),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(context, contact),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ],
      ),
    );

    if (selected != null) {
      setState(() {
        _vendorController.text = selected.firmName ?? selected.name;
        _contactPersonController.text = selected.name;
        _contactPhoneController.text = selected.phone;
      });
    }
  }

  Future<void> _saveAMC() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.addAmcContract({
        'contractName': _contractNameController.text.trim(),
        'vendor': _vendorController.text.trim(),
        'validityDate': _validityDateController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'serviceType': _serviceTypeController.text.trim(),
        'annualCost': _annualCostController.text.isNotEmpty
            ? double.tryParse(_annualCostController.text.trim())
            : null,
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AMC Contract added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add AMC Contract'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _contractNameController,
                decoration: const InputDecoration(labelText: 'Contract Name *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vendorController,
                decoration: InputDecoration(
                  labelText: 'Vendor *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts), onPressed: _selectFromAddressBook, tooltip: 'Select from Address Book'),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _validityDateController,
                decoration: InputDecoration(
                  labelText: 'Validity Date (DD/MM/YYYY) *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                    labelText: 'Contact Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceTypeController,
                decoration: const InputDecoration(labelText: 'Service Type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _annualCostController,
                decoration: const InputDecoration(
                    labelText: 'Annual Cost', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAMC,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

// ========================================
// ADD IMPORTANT NUMBER DIALOG
// ========================================
class AddDocumentDialog extends StatefulWidget {
  const AddDocumentDialog({super.key});

  @override
  State<AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<AddDocumentDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Government ID';
  bool _isLoading = false;

  final List<String> _categories = [
    'Government ID', 'Tax Documents', 'Bank Details', 'Insurance', 'Legal Documents',
    'Property Papers', 'Vehicle Documents', 'Employee Records', 'Certificates', 'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.addImportantNumber({
        'title': _titleController.text.trim(),
        'number': _numberController.text.trim(),
        'category': _selectedCategory,
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Important Document'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(labelText: 'Document Number *', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDocument,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

// ========================================
// ADD PERSON DIALOG (for Personal Documents)
// ========================================
class AddPersonDialog extends StatefulWidget {
  const AddPersonDialog({super.key});

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _api.addPerson({
        'name': _nameController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      });

      if (result['success'] == false) {
        throw Exception(result['message'] ?? result['error'] ?? 'Could not save person');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Person added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Person'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _designationController,
                decoration: const InputDecoration(
                    labelText: 'Designation', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                    labelText: 'Department', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePerson,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

// ========================================
// ADD PERSONAL DOCUMENT DIALOG
// ========================================
class AddPersonalDocumentDialog extends StatefulWidget {
  final String personId;
  final String personName;

  const AddPersonalDocumentDialog({super.key, required this.personId, required this.personName});

  @override
  State<AddPersonalDocumentDialog> createState() => _AddPersonalDocumentDialogState();
}

class _AddPersonalDocumentDialogState extends State<AddPersonalDocumentDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _authorityController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedDocType;
  bool _isLoading = false;

  @override
  void dispose() {
    _numberController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _authorityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller, bool isFuture) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isFuture ? DateTime.now().add(const Duration(days: 365)) : DateTime.now(),
      firstDate: isFuture ? DateTime.now() : DateTime(1950),
      lastDate: isFuture ? DateTime.now().add(const Duration(days: 3650)) : DateTime.now(),
    );

    if (date != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDocType != null &&
        DocumentTypes.hasExpiry(_selectedDocType!) &&
        _expiryDateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry date is required for this document type'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _api.addPersonalDocument({
        'personId': widget.personId,
        'personName': widget.personName,
        'documentType': _selectedDocType!,
        'documentNumber': _numberController.text.trim(),
        'issueDate': _issueDateController.text.trim(),
        'expiryDate': _expiryDateController.text.trim(),
        'issuingAuthority': _authorityController.text.trim(),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Document for ${widget.personName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDocType,
                decoration: const InputDecoration(labelText: 'Document Type *', border: OutlineInputBorder()),
                items: DocumentTypes.getDocumentTypeNames()
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedDocType = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                    labelText: 'Document Number *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _issueDateController,
                decoration: InputDecoration(
                  labelText: 'Issue Date (DD/MM/YYYY)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () => _pickDate(_issueDateController, false)),
                ),
                readOnly: true,
                onTap: () => _pickDate(_issueDateController, false),
              ),
              if (_selectedDocType != null && DocumentTypes.hasExpiry(_selectedDocType!)) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expiryDateController,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (DD/MM/YYYY) *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(icon: const Icon(Icons.event_busy), onPressed: () => _pickDate(_expiryDateController, true)),
                  ),
                  readOnly: true,
                  onTap: () => _pickDate(_expiryDateController, true),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorityController,
                decoration: const InputDecoration(
                    labelText: 'Issuing Authority', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveDocument,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}

// ========================================
// ADD ONE-TIME LICENSE DIALOG
// ========================================
class AddOneTimeLicenseDialog extends StatefulWidget {
  const AddOneTimeLicenseDialog({super.key});

  @override
  State<AddOneTimeLicenseDialog> createState() => _AddOneTimeLicenseDialogState();
}

class _AddOneTimeLicenseDialogState extends State<AddOneTimeLicenseDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _licenseNameController = TextEditingController();
  final _licenseKeyController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _vendorController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedDepartment;
  bool _isLoading = false;

  @override
  void dispose() {
    _licenseNameController.dispose();
    _licenseKeyController.dispose();
    _purchaseDateController.dispose();
    _vendorController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(date);
      });
    }
  }

  Future<void> _saveLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.addOneTimeLicense({
        'licenseName': _licenseNameController.text.trim(),
        'licenseKey': _licenseKeyController.text.trim(),
        'purchaseDate': _purchaseDateController.text.trim(),
        'issuedBy': _selectedDepartment!,
        'vendor': _vendorController.text.trim(),
        'cost': _costController.text.trim().isEmpty ? null : double.tryParse(_costController.text.trim()),
        'notes': _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('One-time license added successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add One-Time License'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _licenseNameController,
                decoration: const InputDecoration(
                    labelText: 'License Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseKeyController,
                decoration: const InputDecoration(
                    labelText: 'License Key/Number *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key)),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchaseDateController,
                decoration: InputDecoration(
                  labelText: 'Purchase Date (DD/MM/YYYY) *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
                ),
                readOnly: true,
                onTap: _pickDate,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Issued By *', border: OutlineInputBorder()),
                items: DepartmentTypes.departments.map((dept) => DropdownMenuItem(value: dept, child: Text(dept))).toList(),
                onChanged: (value) => setState(() => _selectedDepartment = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(
                    labelText: 'Vendor (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                    labelText: 'Cost (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveLicense,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('SAVE'),
        ),
      ],
    );
  }
}
