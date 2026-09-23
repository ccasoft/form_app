import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:form_app/home.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/step1.dart' show OrderTypeFlag;
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ChequeCollection extends StatefulWidget {
  const ChequeCollection({super.key});
  @override
  State<ChequeCollection> createState() => _ChequeCollectionState();
}

class _ChequeCollectionState extends State<ChequeCollection> {
  final _fs = ApiService();
  Map<String, List<InvoiceData>> _invoicesByParty = {};
  List<String> _partyOrder = [];
  String? _selectedPartyId;
  bool _loadingAll = true;
  bool _selectionMode = false;
  Set<String> _selectedIds = {};
  Set<String> _selectedNos = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step5, label: 'Cheque Collection'));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingAll = true);
    try {
      final all = await _fs.getInvoicesForChequeAllStages();
      final map = <String, List<InvoiceData>>{};
      for (final inv in all)
        map.putIfAbsent(inv.partyData.partyId, () => []).add(inv);
      for (final list in map.values)
        list.sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
      final parties = map.keys.toList()
        ..sort((a, b) => map[a]!
            .first
            .partyData
            .partyName
            .compareTo(map[b]!.first.partyData.partyName));
      if (mounted)
        setState(() {
          _invoicesByParty = map;
          _partyOrder = parties;
          _loadingAll = false;
          if (_selectedPartyId == null && parties.isNotEmpty)
            _selectedPartyId = parties.first;
          _clearSelection();
        });
    } catch (e) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  void _clearSelection() {
    _selectionMode = false;
    _selectedIds = {};
    _selectedNos = {};
  }

  void _enterSelectionMode(InvoiceData inv) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds = {inv.id};
      _selectedNos = {inv.invoiceNumber};
    });
  }

  void _toggleInvoice(InvoiceData inv) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedIds.contains(inv.id)) {
        _selectedIds.remove(inv.id);
        _selectedNos.remove(inv.invoiceNumber);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(inv.id);
        _selectedNos.add(inv.invoiceNumber);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _currentInvoices.map((i) => i.id).toSet();
      _selectedNos = _currentInvoices.map((i) => i.invoiceNumber).toSet();
    });
  }

  List<InvoiceData> get _currentInvoices => _selectedPartyId != null
      ? (_invoicesByParty[_selectedPartyId] ?? [])
      : [];

  static String _stageLabel(int stage) {
    switch (stage) {
      case 1:
        return 'Inv';
      case 2:
        return 'Pack';
      case 3:
        return 'Disp';
      case 4:
        return 'Ack';
      default:
        return 'S$stage';
    }
  }

  void _openChequeSheet() {
    final selected =
        _currentInvoices.where((i) => _selectedIds.contains(i.id)).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChequeEntrySheet(
        invoices: selected,
        fs: _fs,
        onSaved: () async {
          Navigator.pop(context);
          setState(() => _clearSelection());
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: _buildAppBar(),
        body: _loadingAll
            ? const Center(child: CircularProgressIndicator())
            : _invoicesByParty.isEmpty
                ? _buildEmpty()
                : Row(children: [
                    _buildPartySidebar(),
                    Expanded(child: _buildInvoiceList())
                  ]),
      );

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        backgroundColor: AppTheme.stageCheque,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => setState(() => _clearSelection()),
        ),
        title: Text('${_selectedIds.length} selected',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _selectAll,
            icon: const Icon(Icons.done_all_rounded,
                color: Colors.white, size: 16),
            label:
                const Text('Select All', style: TextStyle(color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _openChequeSheet,
              icon: const Icon(Icons.payments_rounded, size: 15),
              label: const Text('Add Cheque'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.stageCheque,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }
    return AppBar(
      backgroundColor: AppTheme.stageCheque,
      title:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cheque Collection',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        Text('Long-press a row to select  •  then tap Add Cheque',
            style: TextStyle(color: Colors.white60, fontSize: 10)),
      ]),
      actions: [
        IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
        GestureDetector(
          onTap: () => HomePage.openMasters(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_special_rounded, size: 13, color: Colors.white),
              SizedBox(width: 4),
              Text('Masters',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 48, color: AppTheme.stageCheque.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('All Clear!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('No pending cheque collections.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.stageCheque,
                side: const BorderSide(color: AppTheme.stageCheque))),
      ]));

  Widget _buildPartySidebar() {
    return Container(
      width: 130,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppTheme.divider))),
      child: Column(children: [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: AppTheme.stageCheque.withValues(alpha: 0.06),
            child: const Text('PARTIES',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.stageCheque,
                    letterSpacing: 0.8))),
        Expanded(
            child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _partyOrder.length,
          itemBuilder: (_, i) {
            final partyId = _partyOrder[i];
            final invoices = _invoicesByParty[partyId] ?? [];
            final name = invoices.isNotEmpty
                ? invoices.first.partyData.partyName
                : partyId;
            final route =
                invoices.isNotEmpty ? invoices.first.partyData.routeName : '';
            final selected = _selectedPartyId == partyId;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedPartyId = partyId;
                _clearSelection();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.stageCheque.withValues(alpha: 0.07)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                        color: selected
                            ? AppTheme.stageCheque
                            : Colors.transparent,
                        width: 3),
                    bottom:
                        const BorderSide(color: AppTheme.divider, width: 0.5),
                  ),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppTheme.stageCheque
                                        : AppTheme.textPrimary),
                                maxLines: 2,
                                overflow: kIsWeb
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis),
                            if (route.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(route,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: kIsWeb
                                      ? TextOverflow.clip
                                      : TextOverflow.ellipsis)
                            ],
                          ])),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.stageCheque
                                : AppTheme.stageCheque.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${invoices.length}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.stageCheque)),
                      ),
                    ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _buildInvoiceList() {
    final invoices = _currentInvoices;
    if (invoices.isEmpty)
      return Center(
          child: Text('No invoices',
              style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6))));
    final partyName = invoices.first.partyData.partyName;
    final route = invoices.first.partyData.routeName;

    return Column(children: [
      // Party header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(partyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                if (route.isNotEmpty)
                  Text(route,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.stageCheque.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
                '${invoices.length} invoice${invoices.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.stageCheque,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),

      const Divider(height: 1, color: AppTheme.divider),

      Expanded(
          child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: invoices.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppTheme.divider),
        itemBuilder: (_, i) => _buildRow(invoices[i]),
      )),

      if (!_selectionMode)
        Container(
          width: double.infinity,
          color: AppTheme.stageCheque.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: const Text('💡  Long-press any row to start selecting',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ),
    ]);
  }

  Widget _buildRow(InvoiceData inv) {
    final selected = _selectedIds.contains(inv.id);
    final stageColor = AppStages.color(inv.stage);

    return GestureDetector(
      onLongPress: () {
        if (!_selectionMode) _enterSelectionMode(inv);
      },
      onTap: () {
        if (_selectionMode) _toggleInvoice(inv);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: selected
            ? AppTheme.stageCheque.withValues(alpha: 0.07)
            : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Checkbox — only visible in selection mode
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _selectionMode ? 26 : 0,
            height: 20,
            margin: EdgeInsets.only(right: _selectionMode ? 10 : 0),
            decoration: BoxDecoration(
              color: selected ? AppTheme.stageCheque : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: _selectionMode
                  ? Border.all(
                      color: selected
                          ? AppTheme.stageCheque
                          : AppTheme.textSecondary.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
          ),

          // Two-line content block
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // LINE 1: Invoice number (dominant) + Stage badge (right)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Text(
                    inv.invoiceNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected
                          ? AppTheme.stageCheque
                          : AppTheme.textPrimary,
                      letterSpacing: 0.1,
                    ),
                  )),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(5),
                      border:
                          Border.all(color: stageColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      _stageLabel(inv.stage),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: stageColor),
                    ),
                  ),
                ]),

                const SizedBox(height: 5),

                // LINE 2: Company · Amount · Date
                Row(children: [
                  // Company name
                  Expanded(
                      child: Text(
                    inv.companyName,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow:
                        kIsWeb ? TextOverflow.clip : TextOverflow.ellipsis,
                  )),
                  const SizedBox(width: 8),
                  // Amount
                  Text(
                    '₹${inv.invoiceAmount}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: selected ? AppTheme.stageCheque : AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Date
                  Text(
                    inv.invoiceDate,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ]),
              ])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cheque Entry Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ChequeEntrySheet extends StatefulWidget {
  final List<InvoiceData> invoices;
  final VoidCallback onSaved;
  final ApiService fs;
  const _ChequeEntrySheet(
      {required this.invoices, required this.onSaved, required this.fs});
  @override
  State<_ChequeEntrySheet> createState() => _ChequeEntrySheetState();
}

class _ChequeEntrySheetState extends State<_ChequeEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _chequeNoCtrl = TextEditingController();
  final _chequeDateCtrl = TextEditingController();
  final _chequeAmtCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _chequeDateCtrl.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    if (widget.invoices.length == 1)
      _chequeAmtCtrl.text = widget.invoices.first.invoiceAmount;
  }

  @override
  void dispose() {
    for (final c in [
      _chequeNoCtrl,
      _chequeDateCtrl,
      _chequeAmtCtrl,
      _bankNameCtrl
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      initial = DateFormat('dd-MM-yyyy').parse(_chequeDateCtrl.text);
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme:
                  const ColorScheme.light(primary: AppTheme.stageCheque)),
          child: child!),
    );
    if (picked != null)
      _chequeDateCtrl.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await widget.fs.createChequeCollection({
      'chequeNumber': _chequeNoCtrl.text.trim(),
      'chequeDate': _chequeDateCtrl.text.trim(),
      'chequeAmount': _chequeAmtCtrl.text.trim(),
      'bankName': _bankNameCtrl.text.trim(),
      'selectedInvoicesIdList': widget.invoices.map((i) => i.id).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Cheque Recorded',
          widget.invoices.map((i) => i.invoiceNumber).join(', '),
          backgroundColor: AppTheme.stageCheque, colorText: Colors.white);
      widget.onSaved();
    } else {
      Get.snackbar('Error', 'Failed to save.',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmt = widget.invoices
        .fold<double>(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          // Handle
          Center(
              child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.stageCheque.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.payments_rounded,
                      color: AppTheme.stageCheque, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Add Cheque Details',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    Text(
                        '${widget.invoices.length} invoice${widget.invoices.length != 1 ? 's' : ''} selected',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ])),
              IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
              child: SingleChildScrollView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice summary table
                      Container(
                        decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider)),
                        child: Column(children: [
                          // Table header
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(children: const [
                                Expanded(
                                    flex: 4,
                                    child: Text('INVOICE NO.',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 0.5))),
                                Expanded(
                                    flex: 3,
                                    child: Text('COMPANY',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 0.5))),
                                Expanded(
                                    flex: 2,
                                    child: Text('AMOUNT',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 0.5))),
                                SizedBox(width: 8),
                                SizedBox(
                                    width: 56,
                                    child: Text('DATE',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textSecondary,
                                            letterSpacing: 0.5))),
                              ])),
                          const Divider(height: 1, color: AppTheme.divider),
                          ...widget.invoices.asMap().entries.map((e) {
                            final inv = e.value;
                            final isLast = e.key == widget.invoices.length - 1;
                            return Column(children: [
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(children: [
                                    // Full invoice number — no truncation
                                    Expanded(
                                        flex: 4,
                                        child: Text(inv.invoiceNumber,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary))),
                                    Expanded(
                                        flex: 3,
                                        child: Text(inv.companyName,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary),
                                            maxLines: 2,
                                            overflow: kIsWeb
                                                ? TextOverflow.clip
                                                : TextOverflow.ellipsis)),
                                    Expanded(
                                        flex: 2,
                                        child: Text('₹${inv.invoiceAmount}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.success))),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                        width: 56,
                                        child: Text(inv.invoiceDate,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppTheme.textSecondary))),
                                  ])),
                              if (!isLast)
                                const Divider(
                                    height: 1, color: AppTheme.divider),
                            ]);
                          }).toList(),
                          // Total
                          if (widget.invoices.length > 1) ...[
                            const Divider(height: 1, color: AppTheme.divider),
                            Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  const Expanded(
                                      child: Text('TOTAL',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.textPrimary,
                                              letterSpacing: 0.5))),
                                  Text(
                                      '₹${NumberFormat('#,##,##0.00', 'en_IN').format(totalAmt)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.stageCheque)),
                                ])),
                          ],
                        ]),
                      ),

                      const SizedBox(height: 20),
                      const Text('Cheque Details',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),

                      TextFormField(
                          controller: _chequeNoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Cheque Number *',
                              prefixIcon: Icon(Icons.tag_rounded)),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null),
                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(
                            child: GestureDetector(
                                onTap: _pickDate,
                                child: AbsorbPointer(
                                    child: TextFormField(
                                        controller: _chequeDateCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Cheque Date *',
                                            prefixIcon: Icon(
                                                Icons.calendar_today_rounded)),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? 'Required'
                                                : null)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextFormField(
                                controller: _bankNameCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Bank Name',
                                    prefixIcon:
                                        Icon(Icons.account_balance_rounded)))),
                      ]),
                      const SizedBox(height: 12),

                      TextFormField(
                          controller: _chequeAmtCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Cheque Amount *',
                              prefixIcon: Icon(Icons.currency_rupee_rounded)),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null),
                      const SizedBox(height: 24),

                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_saving || !AuthService.to.perms.canUpdate(ScreenKeys.step5)) ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_circle_rounded,
                                    size: 18),
                            label: Text(_saving
                                ? 'Saving…'
                                : 'Record Cheque Collection'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.stageCheque,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700),
                                elevation: 0),
                          )),
                    ])),
          )),
        ]),
      ),
    );
  }
}
