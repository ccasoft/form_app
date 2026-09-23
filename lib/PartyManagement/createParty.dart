import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class CreateParty extends StatefulWidget {
  const CreateParty({super.key});

  @override
  State<CreateParty> createState() => _CreatePartyState();
}

class _CreatePartyState extends State<CreateParty> {
  final _formKey = GlobalKey<FormState>();
  final _partyNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contact1Ctrl = TextEditingController();
  final _contact2Ctrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();

  String? _selectedTransport;
  String? _selectedRoute;
  String? _selectedStopName;
  int _selectedStopSeq = 999;
  bool _isEditing = false;
  String? _partyId;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _needsCheque = false;
  List<String> _transportList = [];
  List<RouteData> _routes = [];
  List<CompanyData> _allCompanies = [];
  List<String> _selectedCompanyIds = [];
  final ApiService _firebaseService = ApiService();

  @override
  void initState() {
    super.initState();
    // Read args FIRST so _selectedCompanyIds is set before _loadData rebuilds
    final args = Get.arguments;
    if (args != null) {
      _isEditing = args['isEditing'] ?? false;
      _partyId = args['partyId'];
      _partyNameCtrl.text = args['partyName'] ?? '';
      _addressCtrl.text = args['address'] ?? '';
      _contact1Ctrl.text = args['contactNumber1'] ?? '';
      _contact2Ctrl.text = args['contactNumber2'] ?? '';
      _contactPersonCtrl.text = args['contactPerson'] ?? '';
      _selectedTransport = (args['transportName'] as String?)?.trim();
      _selectedRoute = args['routeName'];
      _selectedStopName = args['stopName'] as String?;
      _selectedStopSeq = (args['stopSeq'] as num?)?.toInt() ?? 999;
      _selectedCompanyIds = List<String>.from(args['companyIds'] ?? []);
      _needsCheque = args['needsCheque'] ?? false;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transports = await _firebaseService.getTransport();
    final routes = await _firebaseService.getRoutes();
    final companies = await _firebaseService.getCompanies();
    // Trim all transport names to avoid whitespace mismatches
    final trimmedTransports = transports.map((t) => t.trim()).toList();
    // Snapshot current selections before setState so they are never overwritten
    final savedCompanyIds = List<String>.from(_selectedCompanyIds);
    setState(() {
      _transportList = trimmedTransports;
      _routes = routes;
      _allCompanies = companies;
      // Restore selections explicitly — guards against any accidental reset
      _selectedCompanyIds = savedCompanyIds;
      // Sanitize transport: clear if stored value no longer exists in list
      if (_selectedTransport != null &&
          !trimmedTransports.contains(_selectedTransport)) {
        _selectedTransport = null;
      }
      _isLoading = false;
    });
  }

  void _toggleCompany(String companyId) {
    setState(() {
      if (_selectedCompanyIds.contains(companyId)) {
        _selectedCompanyIds.remove(companyId);
      } else {
        _selectedCompanyIds.add(companyId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Party' : 'Create Party'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildCard(
                      title: 'Party Information',
                      icon: Icons.people_alt_rounded,
                      children: [
                        _buildField(
                          controller: _partyNameCtrl,
                          label: 'Party Name',
                          icon: Icons.store_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _addressCtrl,
                          label: 'Address',
                          icon: Icons.location_on_rounded,
                          maxLines: 3,
                          required: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Contact Details',
                      icon: Icons.contact_phone_rounded,
                      children: [
                        _buildField(
                          controller: _contactPersonCtrl,
                          label: 'Contact Person',
                          icon: Icons.person_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _contact1Ctrl,
                          label: 'Primary Contact',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _contact2Ctrl,
                          label: 'Secondary Contact',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      title: 'Logistics Assignment',
                      icon: Icons.local_shipping_rounded,
                      children: [
                        _buildDropdown<String>(
                          label: 'Default Transport',
                          icon: Icons.local_shipping_rounded,
                          value: _selectedTransport,
                          items: _transportList,
                          displayString: (t) => t,
                          onChanged: (val) =>
                              setState(() => _selectedTransport = val),
                          validator: (val) =>
                              val == null ? 'Please select transport' : null,
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown<RouteData>(
                          label: 'Route',
                          icon: Icons.route_rounded,
                          value: _routes.isEmpty
                              ? null
                              : _routes.cast<RouteData?>().firstWhere(
                                  (r) => r?.routeName == _selectedRoute,
                                  orElse: () => null),
                          items: _routes,
                          displayString: (r) => r.routeName,
                          onChanged: (val) => setState(() {
                            _selectedRoute = val?.routeName;
                            // Reset stop when route changes
                            _selectedStopName = null;
                            _selectedStopSeq = 999;
                          }),
                          helperText: 'Route determines vehicle at dispatch',
                        ),
                        // ── Stop picker — shown only when route has stops ──
                        Builder(builder: (ctx) {
                          final route = _routes.cast<RouteData?>().firstWhere(
                                (r) => r?.routeName == _selectedRoute,
                                orElse: () => null,
                              );
                          if (route == null || route.stops.isEmpty)
                            return const SizedBox.shrink();
                          return Column(children: [
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: _selectedStopSeq == 999
                                  ? null
                                  : _selectedStopSeq,
                              decoration: const InputDecoration(
                                labelText: 'Delivery Stop *',
                                prefixIcon:
                                    Icon(Icons.location_on_rounded, size: 20),
                                helperText:
                                    'Which stop on this route is this party at?',
                              ),
                              isExpanded: true,
                              items: route.stops.asMap().entries.map((e) {
                                return DropdownMenuItem<int>(
                                  value: e.key,
                                  child: Row(children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${e.key + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            )),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(e.value,
                                            overflow: TextOverflow.ellipsis)),
                                  ]),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() {
                                if (val != null) {
                                  _selectedStopSeq = val;
                                  _selectedStopName = route.stops[val];
                                }
                              }),
                              validator: (val) => val == null
                                  ? 'Please select delivery stop'
                                  : null,
                            ),
                          ]);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Company Assignment (multi-select chips) ─────────────
                    _buildCard(
                      title: 'Company Assignment',
                      icon: Icons.business_rounded,
                      children: [
                        if (_allCompanies.isEmpty)
                          const Text(
                            'No companies found. Please add companies first.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          )
                        else ...[
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Select all companies this party is a dealer for',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allCompanies.map((company) {
                              final selected = _selectedCompanyIds
                                  .contains(company.companyId);
                              return FilterChip(
                                label: Text(
                                  company.companyName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                avatar: Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 15,
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                                selected: selected,
                                onSelected: (_) =>
                                    _toggleCompany(company.companyId),
                                showCheckmark: false,
                                backgroundColor: Colors.white,
                                selectedColor: const Color(0xFF1565C0),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xFF1565C0)
                                      : Colors.grey.shade300,
                                  width: selected ? 1.5 : 1.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 4),
                              );
                            }).toList(),
                          ),
                          if (_selectedCompanyIds.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF1565C0)
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '${_selectedCompanyIds.length} ${_selectedCompanyIds.length == 1 ? 'company' : 'companies'} assigned',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Cheque Collection ───────────────────────────────────
                    _buildCard(
                      title: 'Cheque Collection',
                      icon: Icons.payments_rounded,
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _needsCheque = !_needsCheque),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: Row(children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _needsCheque
                                      ? AppTheme.stageCheque
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _needsCheque
                                        ? AppTheme.stageCheque
                                        : AppTheme.textSecondary,
                                    width: 1.5,
                                  ),
                                ),
                                child: _needsCheque
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('Requires Cheque Collection',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary)),
                                    Text(
                                        'Party will appear in Cheque Collection tab',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ])),
                              if (_needsCheque)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: AppTheme.stageCheque
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.stageCheque,
                                          fontWeight: FontWeight.w700)),
                                ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label:
                            Text(_isEditing ? 'Update Party' : 'Create Party'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.primary,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: required
          ? (val) => val == null || val.trim().isEmpty ? 'Required field' : null
          : null,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) displayString,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    String? helperText,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        helperText: helperText,
      ),
      isExpanded: true,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayString(item),
              maxLines: 1, overflow: TextOverflow.fade),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final id = _isEditing ? _partyId! : const Uuid().v4();
    final data = {
      'partyId': id,
      'partyName': _partyNameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'contactNumber1': _contact1Ctrl.text.trim(),
      'contactNumber2': _contact2Ctrl.text.trim(),
      'contactPerson': _contactPersonCtrl.text.trim(),
      'transportName': _selectedTransport ?? '',
      'routeName': _selectedRoute ?? '',
      'stopName': _selectedStopName ?? '',
      'companyIds': _selectedCompanyIds,
      'needsCheque': _needsCheque,
    };
    final success = await _firebaseService.createParty(data, _isEditing);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      // Show snackbar BEFORE popping so it renders on the previous screen
      Get.snackbar(
        'Success',
        _isEditing
            ? 'Party updated successfully'
            : 'Party created successfully',
        duration: const Duration(seconds: 2),
      );
      // Use Navigator directly to guarantee the screen pops
      Navigator.of(context).pop(true);
    } else {
      Get.snackbar('Error', 'Failed to save party');
    }
  }
}
