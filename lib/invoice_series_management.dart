import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/invoice_series_config.dart';
import 'package:get/get.dart';

class InvoiceSeriesManagement extends StatefulWidget {
  const InvoiceSeriesManagement({super.key});
  @override
  State<InvoiceSeriesManagement> createState() => _InvoiceSeriesManagementState();
}

class _InvoiceSeriesManagementState extends State<InvoiceSeriesManagement> {
  final _fs = ApiService();
  List<InvoiceSeriesConfig> _configs = [];
  List<CompanyData> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.invoiceSeriesManagement, label: 'Invoice Series Management'));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final configs = await _fs.getSeriesConfigs();
    final companies = await _fs.getCompanies();
    if (mounted) setState(() { _configs = configs; _companies = companies; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.stageInvoice,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Invoice Series', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Text('Configure per-company invoice numbering', style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
        ],
      ),
      floatingActionButton: AuthService.to.perms.canAdd(ScreenKeys.invoiceSeriesManagement)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.stageInvoice,
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Series', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _configs.length,
                    itemBuilder: (_, i) => _SeriesCard(
                      config: _configs[i],
                      onEdit: () async { final ok = await AdminPin.verify(context, action: 'edit invoice series'); if (!ok) return; _openEditor(_configs[i]); },
                      onDelete: () async { final ok = await AdminPin.verify(context, action: 'delete invoice series'); if (!ok) return; _delete(_configs[i]); },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.format_list_numbered_rounded, size: 56, color: AppTheme.stageInvoice.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('No invoice series configured', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Add a series for each company to enable invoice number validation and missing number tracking.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 24),
        if (AuthService.to.perms.canAdd(ScreenKeys.invoiceSeriesManagement))
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.stageInvoice, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          onPressed: () => _openEditor(null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add First Series'),
        ),
      ]),
    ));
  }

  void _openEditor(InvoiceSeriesConfig? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeriesEditorSheet(
        existing: existing,
        companies: _companies,
        onSaved: _load,
      ),
    );
  }

  Future<void> _delete(InvoiceSeriesConfig cfg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Series Config'),
        content: Text('Delete series configuration for "${cfg.companyName}" ${cfg.fyLabel}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _fs.deleteSeriesConfig(cfg.id);
      _load();
    }
  }
}

// ─── Series Card ─────────────────────────────────────────────────────────────
class _SeriesCard extends StatelessWidget {
  final InvoiceSeriesConfig config;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SeriesCard({required this.config, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageInvoice;
    final exampleNums = [config.startNumber, config.startNumber + 1, config.startNumber + 2];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.format_list_numbered_rounded, color: color, size: 17)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(config.companyName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.fade),
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(config.fyLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                  child: Text(config.seriesName, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                ),
              ]),
            ])),
            _Badge(config.isSequential ? 'Sequential' : 'Manual', config.isSequential ? AppTheme.success : AppTheme.warning),
            const SizedBox(width: 6),
            _Badge(config.isAlphanumeric ? 'Alpha' : 'Numeric', AppTheme.primary),
            const SizedBox(width: 8),
            if (AuthService.to.perms.canUpdate(ScreenKeys.invoiceSeriesManagement))
              GestureDetector(onTap: onEdit, child: const Icon(Icons.edit_rounded, color: AppTheme.stageInvoice, size: 18)),
            const SizedBox(width: 10),
            if (AuthService.to.perms.canDelete(ScreenKeys.invoiceSeriesManagement))
              GestureDetector(onTap: onDelete, child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18)),
          ]),
        ),
        // Details
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 16, runSpacing: 6, children: [
              _DetailItem(Icons.start_rounded, 'Start', '${config.startNumber}', color),
              if (config.prefix.isNotEmpty)
                _DetailItem(Icons.label_rounded, 'Prefix', '"${config.prefix}"', color),
              if (config.padLength > 0)
                _DetailItem(Icons.format_size_rounded, 'Pad', '${config.padLength} digits', color),
            ]),
            const SizedBox(height: 10),
            // Example numbers
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Example: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              ...exampleNums.map((n) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.2))),
                child: Text(config.formatNumber(n), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              )),
              const Text('...', style: TextStyle(color: AppTheme.textSecondary)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailItem(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text('$label: ', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
  ]);
}

// ─── Series Editor Sheet ─────────────────────────────────────────────────────
class _SeriesEditorSheet extends StatefulWidget {
  final InvoiceSeriesConfig? existing;
  final List<CompanyData> companies;
  final VoidCallback onSaved;
  const _SeriesEditorSheet({required this.existing, required this.companies, required this.onSaved});
  @override
  State<_SeriesEditorSheet> createState() => _SeriesEditorSheetState();
}

class _SeriesEditorSheetState extends State<_SeriesEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _seriesNameCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _padCtrl = TextEditingController();

  CompanyData? _company;
  int _fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
  bool _isSequential = true;
  bool _isAlphanumeric = false;
  bool _saving = false;

  // Preview
  String get _previewNum {
    final start = int.tryParse(_startCtrl.text) ?? 1;
    final pad = int.tryParse(_padCtrl.text) ?? 0;
    final prefix = _prefixCtrl.text;
    final numStr = pad > 0 ? start.toString().padLeft(pad, '0') : start.toString();
    return '$prefix$numStr';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _seriesNameCtrl.text = e.seriesName;
      _prefixCtrl.text = e.prefix;
      _startCtrl.text = e.startNumber.toString();
      _padCtrl.text = e.padLength > 0 ? e.padLength.toString() : '';
      _isSequential = e.isSequential;
      _isAlphanumeric = e.isAlphanumeric;
      _fy = e.financialYear;
      _company = widget.companies.cast<CompanyData?>().firstWhere(
          (c) => c?.companyId == e.companyId, orElse: () => null);
    } else {
      _startCtrl.text = '1';
      _seriesNameCtrl.text = 'Default';
    }
  }

  @override
  void dispose() {
    _seriesNameCtrl.dispose();
    _prefixCtrl.dispose();
    _startCtrl.dispose();
    _padCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_company == null) { Get.snackbar('Error', 'Select a company'); return; }
    setState(() => _saving = true);
    final companyId = _company!.companyId;
    final seriesName = _seriesNameCtrl.text.trim().isEmpty ? 'Default' : _seriesNameCtrl.text.trim();
    final cfg = InvoiceSeriesConfig(
      id: InvoiceSeriesConfig.docId(companyId, _fy, seriesName),
      companyId: companyId,
      companyName: _company!.companyName,
      financialYear: _fy,
      seriesName: seriesName,
      prefix: _prefixCtrl.text.trim(),
      startNumber: int.tryParse(_startCtrl.text) ?? 1,
      isSequential: _isSequential,
      isAlphanumeric: _isAlphanumeric,
      padLength: int.tryParse(_padCtrl.text) ?? 0,
    );
    final ok = await ApiService().saveSeriesConfig(cfg);
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Saved!', 'Series "$seriesName" saved for ${_company!.companyName}',
          backgroundColor: AppTheme.success, colorText: Colors.white);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } else {
      Get.snackbar('Error', 'Failed to save series config');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fyOptions = List.generate(5, (i) {
      final y = DateTime.now().year - 1 + i;
      return y;
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.98,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          // Header
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.stageInvoice, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.format_list_numbered_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.existing != null ? 'Edit Series Config' : 'New Invoice Series',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
              GestureDetector(onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Company
                _sectionLabel('Company & Financial Year'),
                Autocomplete<CompanyData>(
                  initialValue: _company != null ? TextEditingValue(text: _company!.companyName) : null,
                  optionsBuilder: (tv) => tv.text.isEmpty ? widget.companies
                      : widget.companies.where((c) => c.companyName.toLowerCase().contains(tv.text.toLowerCase())),
                  displayStringForOption: (o) => o.companyName,
                  fieldViewBuilder: (ctx, tc, fn, _) => TextFormField(
                    controller: tc, focusNode: fn,
                    decoration: const InputDecoration(labelText: 'Company *', prefixIcon: Icon(Icons.business_rounded)),
                    validator: (v) => (v == null || v.isEmpty) ? 'Select a company' : null,
                  ),
                  onSelected: (c) => setState(() => _company = c),
                ),
                const SizedBox(height: 12),
                // Series Name — unique label for this series within the company
                TextFormField(
                  controller: _seriesNameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Series Name *',
                    prefixIcon: Icon(Icons.label_rounded),
                    hintText: 'e.g. INV, CG, Main, Secondary',
                    helperText: 'Unique name per company — used to distinguish multiple series',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                // FY selector
                const Text('Financial Year', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                  children: fyOptions.map((y) {
                    final next = (y + 1).toString().substring(2);
                    final active = y == _fy;
                    return GestureDetector(
                      onTap: () => setState(() => _fy = y),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.stageInvoice : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppTheme.stageInvoice : AppTheme.divider),
                        ),
                        child: Text('FY $y–$next', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppTheme.textSecondary)),
                      ),
                    );
                  }).toList(),
                )),
                const SizedBox(height: 16),

                // Series Type
                _sectionLabel('Series Type'),
                Row(children: [
                  Expanded(child: _ToggleTile('Sequential', 'Validate order & track missing', Icons.format_list_numbered_rounded, _isSequential, () => setState(() => _isSequential = true))),
                  const SizedBox(width: 8),
                  Expanded(child: _ToggleTile('Manual', 'No validation, free entry', Icons.edit_rounded, !_isSequential, () => setState(() => _isSequential = false))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _ToggleTile('Numeric', '1, 2, 3... or 001, 002...', Icons.numbers_rounded, !_isAlphanumeric, () => setState(() => _isAlphanumeric = false))),
                  const SizedBox(width: 8),
                  Expanded(child: _ToggleTile('Alphanumeric', 'INV-001, CG/001...', Icons.abc_rounded, _isAlphanumeric, () => setState(() => _isAlphanumeric = true))),
                ]),
                const SizedBox(height: 16),

                // Number config
                _sectionLabel('Numbering Configuration'),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _startCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Start Number *', prefixIcon: Icon(Icons.start_rounded), hintText: 'e.g. 1 or 1001'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Must be a number';
                      return null;
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(
                    controller: _padCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Pad Digits', prefixIcon: Icon(Icons.format_size_rounded), hintText: '0 = none, 3 = 001'),
                  )),
                ]),
                if (_isAlphanumeric) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _prefixCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Prefix (e.g. INV-, CG/)', prefixIcon: Icon(Icons.label_rounded), hintText: 'Leave empty for numeric only'),
                  ),
                ],
                const SizedBox(height: 16),

                // Live preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.stageInvoice.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.stageInvoice.withValues(alpha: 0.25)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.preview_rounded, color: AppTheme.stageInvoice, size: 15),
                      SizedBox(width: 6),
                      Text('Live Preview', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.stageInvoice, fontSize: 12)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: List.generate(5, (i) {
                      final start = int.tryParse(_startCtrl.text) ?? 1;
                      final pad = int.tryParse(_padCtrl.text) ?? 0;
                      final prefix = _isAlphanumeric ? _prefixCtrl.text : '';
                      final numStr = pad > 0 ? (start + i).toString().padLeft(pad, '0') : (start + i).toString();
                      final example = '$prefix$numStr';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppTheme.stageInvoice.withValues(alpha: 0.3))),
                        child: Text(example, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.stageInvoice)),
                      );
                    }).toList()),
                    const SizedBox(height: 8),
                    Text(
                      _isSequential
                          ? '✓ Sequence validated on entry. Missing numbers tracked automatically.'
                          : '○ Manual mode — any invoice number accepted.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.stageInvoice, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: (_saving || !(widget.existing != null
                            ? AuthService.to.perms.canUpdate(ScreenKeys.invoiceSeriesManagement)
                            : AuthService.to.perms.canAdd(ScreenKeys.invoiceSeriesManagement)))
                        ? null
                        : _save,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                    label: Text(widget.existing != null ? 'Update Series Config' : 'Save Series Config', style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
  );

  Widget _ToggleTile(String title, String sub, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppTheme.stageInvoice.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.stageInvoice : AppTheme.divider, width: active ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: active ? AppTheme.stageInvoice : AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? AppTheme.stageInvoice : AppTheme.textPrimary)),
            Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.fade),
          ])),
          if (active) Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.stageInvoice),
        ]),
      ),
    );
  }
}
