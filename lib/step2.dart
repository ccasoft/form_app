import 'package:flutter/material.dart';
import 'package:form_app/home.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/step1.dart' show OrderTypeFlag;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:form_app/garage_slip_pending.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';

class Step2 extends StatefulWidget {
  @override
  _Step2State createState() => _Step2State();
}

class _Step2State extends State<Step2> {
  final _formKey = GlobalKey<FormState>();
  final _packCaseCtrl = TextEditingController();
  final _looseCaseCtrl = TextEditingController();
  final _totalCaseCtrl = TextEditingController();
  final _lrNumberCtrl = TextEditingController();
  final _lrDateCtrl = TextEditingController();
  final _garageSlipCtrl = TextEditingController();
  String? _selectedTransport;
  List<String> _transportList = [];

  Set<String> selectedInvoices = {};
  List<InvoiceData> invoices = [];
  List<String> selectedInvoicesIdList = [];
  bool isLoading = false;
  bool isSaving = false;
  Map<String, TextEditingController> ewayBillControllers = {};
  // Key to reset the Autocomplete widget (clears search box after selection)
  Key _autocompleteKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step2, label: 'Packing'));
    _fetchInvoices();
    _lrDateCtrl.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _packCaseCtrl.addListener(_calcTotal);
    _looseCaseCtrl.addListener(_calcTotal);
  }

  @override
  void dispose() {
    ewayBillControllers.values.forEach((c) => c.dispose());
    _garageSlipCtrl.dispose();
    _packCaseCtrl.removeListener(_calcTotal);
    _looseCaseCtrl.removeListener(_calcTotal);
    super.dispose();
  }

  void _calcTotal() {
    final pack = int.tryParse(_packCaseCtrl.text) ?? 0;
    final loose = int.tryParse(_looseCaseCtrl.text) ?? 0;
    _totalCaseCtrl.text = (pack + loose).toString();
  }

  Future<void> _fetchInvoices() async {
    setState(() => isLoading = true);
    final fetched = await ApiService().getInvoices(1);
    final transports = await ApiService().getTransport();
    // Sort ascending by invoice number (alphanumeric) for easy selection
    fetched.sort((a, b) {
      // Primary: stop sequence (delivery order on route)
      final stopCmp = a.partyData.stopSeq.compareTo(b.partyData.stopSeq);
      if (stopCmp != 0) return stopCmp;
      // Secondary: party name
      final partyCmp = a.partyData.partyName.compareTo(b.partyData.partyName);
      if (partyCmp != 0) return partyCmp;
      // Tertiary: invoice number
      return a.invoiceNumber.compareTo(b.invoiceNumber);
    });
    if (mounted)
      setState(() {
        invoices = fetched;
        _transportList = transports.map((t) => t.trim()).toList();
        isLoading = false;
      });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null)
      _lrDateCtrl.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  void _updateEwayControllers() {
    ewayBillControllers.keys
        .where((inv) => !selectedInvoices.contains(inv))
        .toList()
        .forEach((inv) {
      ewayBillControllers[inv]?.dispose();
      ewayBillControllers.remove(inv);
    });
    for (String invNum in selectedInvoices) {
      if (!ewayBillControllers.containsKey(invNum)) {
        final inv = invoices.firstWhere((d) => d.invoiceNumber == invNum);
        ewayBillControllers[invNum] =
            TextEditingController(text: inv.ewayBillNumber);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Packing',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Chhattisgarh C & F Agency Pvt Ltd',
              style: TextStyle(color: Colors.white60, fontSize: 10))
        ]),
        backgroundColor: AppTheme.stagePacking,
        actions: [
          GestureDetector(
            onTap: () => HomePage.openMasters(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_special_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text('Masters',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14)),
            child: Text('Stage 2',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Add Invoice to Existing Packing Banner ──────────────────────
          GestureDetector(
            onTap: _showAddInvoiceToPackaging,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.stagePacking.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.stagePacking.withValues(alpha: 0.35),
                    width: 1.5),
              ),
              child: Row(children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.stagePacking, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Invoice to Existing Packing',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.stagePacking,
                                fontSize: 13)),
                        const Text(
                            'Missed tagging an invoice? Add it to an existing LR group.',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.stagePacking, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          // ── Garage Slip Pending Banner ──────────────────────────────────
          GestureDetector(
            onTap: () => Get.to(() => const GarageSlipPendingPage()),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.4),
                    width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFFE65100), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Garage Slip → LR Pending',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                                fontSize: 13)),
                        const Text(
                            'Update LR numbers for entries with only a Garage Slip.',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFE65100), size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) => SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(12, 12, 12,
                            MediaQuery.of(context).viewInsets.bottom + 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildCard(
                                title: 'Select Invoices',
                                icon: Icons.receipt_long_rounded,
                                color: AppTheme.stagePacking,
                                children: [
                                  Autocomplete<InvoiceData>(
                                    key: _autocompleteKey,
                                    optionsBuilder: (tv) {
                                      // Same party + same company required; different series of same company are allowed
                                      final firstInv = selectedInvoices
                                              .isNotEmpty
                                          ? invoices
                                              .cast<InvoiceData?>()
                                              .firstWhere(
                                                  (d) =>
                                                      d?.invoiceNumber ==
                                                      selectedInvoices.first,
                                                  orElse: () => null)
                                          : null;
                                      final filtered = invoices.where((d) {
                                        if (selectedInvoices.contains(
                                            d.invoiceNumber)) return false;
                                        if (firstInv != null) {
                                          if (d.partyData.partyId !=
                                              firstInv.partyData.partyId)
                                            return false;
                                          if (d.companyName !=
                                              firstInv.companyName)
                                            return false;
                                        }
                                        if (tv.text.isEmpty) return true;
                                        final q = tv.text.toLowerCase();
                                        return d.invoiceNumber
                                                .toLowerCase()
                                                .contains(q) ||
                                            d.partyData.partyName
                                                .toLowerCase()
                                                .contains(q) ||
                                            d.companyName
                                                .toLowerCase()
                                                .contains(q);
                                      }).toList();
                                      // Sort by company name then invoice number
                                      filtered.sort((a, b) {
                                        final cmp = a.companyName
                                            .compareTo(b.companyName);
                                        if (cmp != 0) return cmp;
                                        return a.invoiceNumber
                                            .compareTo(b.invoiceNumber);
                                      });
                                      return filtered;
                                    },
                                    optionsViewBuilder:
                                        (ctx, onSelected, options) {
                                      final optList = options.toList();
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxHeight: 320),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: optList.length,
                                              itemBuilder: (ctx, i) {
                                                final o = optList[i];
                                                return InkWell(
                                                  onTap: () => onSelected(o),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                        horizontal: 14,
                                                        vertical: 10),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          o.invoiceNumber +
                                                              '  ·  ' +
                                                              o.partyData
                                                                  .partyName,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13),
                                                        ),
                                                        Text(
                                                          o.companyName,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    displayStringForOption: (o) =>
                                        '${o.invoiceNumber}  ·  ${o.partyData.partyName}  [${o.companyName}]',
                                    fieldViewBuilder: (ctx, tc, fn, _) =>
                                        TextFormField(
                                      controller: tc,
                                      focusNode: fn,
                                      decoration: const InputDecoration(
                                        labelText: 'Search Invoice',
                                        prefixIcon: Icon(Icons.search),
                                        hintText:
                                            'Search by invoice no., party or company...',
                                      ),
                                    ),
                                    onSelected: (inv) {
                                      // Validate same party + same company (series can differ within same company)
                                      if (selectedInvoices.isNotEmpty) {
                                        final first = invoices
                                            .cast<InvoiceData?>()
                                            .firstWhere(
                                                (d) =>
                                                    d?.invoiceNumber ==
                                                    selectedInvoices.first,
                                                orElse: () => null);
                                        if (first != null) {
                                          if (inv.partyData.partyId !=
                                                  first.partyData.partyId ||
                                              inv.companyName !=
                                                  first.companyName) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(children: [
                                                  const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.white),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                      child: Text(
                                                    'Cannot add "${inv.invoiceNumber}" — Party or Company does not match.\n'
                                                    'Expected: ${first.partyData.partyName} / ${first.companyName}',
                                                  )),
                                                ]),
                                                backgroundColor:
                                                    AppTheme.danger,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration:
                                                    const Duration(seconds: 4),
                                              ),
                                            );
                                            return;
                                          }
                                        }
                                      }
                                      setState(() {
                                        selectedInvoices.add(inv.invoiceNumber);
                                        selectedInvoicesIdList.add(inv.id);
                                        _updateEwayControllers();
                                        _autocompleteKey =
                                            UniqueKey(); // clears search bar
                                        // Auto-fill transport from first selected invoice
                                        if (_selectedTransport == null &&
                                            inv.partyData.transportName
                                                .isNotEmpty) {
                                          _selectedTransport =
                                              _transportList.contains(inv
                                                      .partyData.transportName)
                                                  ? inv.partyData.transportName
                                                  : null;
                                        }
                                      });
                                    },
                                  ),
                                  if (selectedInvoices.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      children: selectedInvoices
                                          .map((inv) => Chip(
                                                label: Text(inv),
                                                deleteIcon: const Icon(
                                                    Icons.close,
                                                    size: 16),
                                                onDeleted: () {
                                                  setState(() {
                                                    final d = invoices
                                                        .cast<InvoiceData?>()
                                                        .firstWhere(
                                                            (d) =>
                                                                d?.invoiceNumber ==
                                                                inv,
                                                            orElse: () => null);
                                                    selectedInvoices
                                                        .remove(inv);
                                                    if (d != null)
                                                      selectedInvoicesIdList
                                                          .remove(d.id);
                                                    _updateEwayControllers();
                                                  });
                                                },
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Builder(builder: (ctx) {
                                      final first = invoices
                                          .cast<InvoiceData?>()
                                          .firstWhere(
                                              (d) =>
                                                  d?.invoiceNumber ==
                                                  selectedInvoices.first,
                                              orElse: () => null);
                                      if (first == null)
                                        return const SizedBox.shrink();
                                      // Collect unique series names from selected invoices
                                      final seriesLabels = selectedInvoices
                                          .map((invNum) {
                                            final d = invoices
                                                .cast<InvoiceData?>()
                                                .firstWhere(
                                                    (d) =>
                                                        d?.invoiceNumber ==
                                                        invNum,
                                                    orElse: () => null);
                                            return d?.seriesName ?? '';
                                          })
                                          .where((s) => s.isNotEmpty)
                                          .toSet()
                                          .toList();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: AppTheme.stagePacking
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppTheme.stagePacking
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                const Icon(Icons.lock_rounded,
                                                    size: 13,
                                                    color:
                                                        AppTheme.stagePacking),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                    child: Text(
                                                  'Locked to: ${first.partyData.partyName}  ·  ${first.companyName}',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          AppTheme.stagePacking,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )),
                                              ]),
                                              if (seriesLabels.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Wrap(
                                                    spacing: 6,
                                                    children: seriesLabels
                                                        .map((s) => Container(
                                                              padding: const EdgeInsets
                                                                      .symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 2),
                                                              decoration: BoxDecoration(
                                                                  color: AppTheme
                                                                      .stageInvoice
                                                                      .withValues(
                                                                          alpha:
                                                                              0.12),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5)),
                                                              child: Text(s,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: AppTheme
                                                                          .stageInvoice,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700)),
                                                            ))
                                                        .toList()),
                                              ],
                                            ]),
                                      );
                                    }),
                                    const SizedBox(height: 12),
                                    // Summary table — sorted ascending by invoice number, grouped by company
                                    Builder(builder: (ctx) {
                                      // Group selected invoices by company
                                      final Map<String, List<String>>
                                          byCompany = {};
                                      final sortedSelected =
                                          selectedInvoices.toList()..sort();
                                      for (final inv in sortedSelected) {
                                        final d = invoices
                                            .cast<InvoiceData?>()
                                            .firstWhere(
                                                (d) => d?.invoiceNumber == inv,
                                                orElse: () => null);
                                        final company =
                                            d?.companyName ?? 'Unknown';
                                        byCompany
                                            .putIfAbsent(company, () => [])
                                            .add(inv);
                                      }
                                      return Container(
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: AppTheme.divider),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Column(children: [
                                          _tableHeader(),
                                          ...byCompany.entries.expand((entry) {
                                            final companyInvoices = entry.value;
                                            return [
                                              // Company header row
                                              Container(
                                                color: AppTheme.stagePacking
                                                    .withValues(alpha: 0.12),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 5),
                                                child: Row(children: [
                                                  const Icon(
                                                      Icons.business_rounded,
                                                      size: 12,
                                                      color: AppTheme
                                                          .stagePacking),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                      child: Text(entry.key,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color: AppTheme
                                                                  .stagePacking))),
                                                  Text(
                                                      '${companyInvoices.length} invoice${companyInvoices.length > 1 ? "s" : ""}',
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppTheme
                                                              .textSecondary)),
                                                ]),
                                              ),
                                              ...companyInvoices.map((inv) {
                                                final d = invoices
                                                    .cast<InvoiceData?>()
                                                    .firstWhere(
                                                        (d) =>
                                                            d?.invoiceNumber ==
                                                            inv,
                                                        orElse: () => null);
                                                return _tableRow(
                                                    inv,
                                                    d?.companyName ?? '',
                                                    d?.partyData.partyName ??
                                                        '',
                                                    d?.invoiceAmount ?? '',
                                                    d?.orderType ?? 'regular',
                                                    d?.specialRemarks ?? '',
                                                    d?.seriesName,
                                                    d?.partyData
                                                            .transportName ??
                                                        '',
                                                    d?.partyData.stopName ?? '',
                                                    d?.partyData.stopSeq ??
                                                        999);
                                              }),
                                            ];
                                          }),
                                        ]),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                              if (selectedInvoices.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildCard(
                                  title: 'E-way Bill Numbers',
                                  icon: Icons.document_scanner_rounded,
                                  color: AppTheme.stagePacking,
                                  children: [
                                    ...selectedInvoices.map((inv) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: TextFormField(
                                            controller:
                                                ewayBillControllers[inv],
                                            decoration: InputDecoration(
                                              labelText: 'E-way Bill · $inv',
                                              prefixIcon: const Icon(
                                                  Icons
                                                      .document_scanner_rounded,
                                                  size: 18),
                                            ),
                                            validator: (v) =>
                                                v == null || v.isEmpty
                                                    ? 'Required'
                                                    : null,
                                          ),
                                        )),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildCard(
                                  title: 'Packing Details',
                                  icon: Icons.inventory_2_rounded,
                                  color: AppTheme.stagePacking,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: TextFormField(
                                        controller: _packCaseCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Pack Cases',
                                            prefixIcon: Icon(
                                                Icons.inventory_2_rounded)),
                                      )),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: TextFormField(
                                        controller: _looseCaseCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Loose Cases',
                                            prefixIcon:
                                                Icon(Icons.inbox_rounded)),
                                      )),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: TextFormField(
                                        controller: _totalCaseCtrl,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Total',
                                          filled: true,
                                          fillColor: Color(0xFFF5F6FA),
                                        ),
                                      )),
                                    ]),
                                    const SizedBox(height: 12),
                                    // LR + Garage Slip: at least one is required
                                    Builder(builder: (ctx) {
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: TextFormField(
                                                controller: _lrNumberCtrl,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'LR Number',
                                                        prefixIcon: Icon(
                                                            Icons.pin_rounded)),
                                                onChanged: (_) => ctx
                                                    .findAncestorStateOfType<
                                                        FormState>()
                                                    ?.validate(),
                                                validator: (v) {
                                                  if ((v == null ||
                                                          v.trim().isEmpty) &&
                                                      _garageSlipCtrl.text
                                                          .trim()
                                                          .isEmpty) {
                                                    return 'LR or Garage Slip required';
                                                  }
                                                  return null;
                                                },
                                              )),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: TextFormField(
                                                controller: _lrDateCtrl,
                                                readOnly: true,
                                                onTap: _pickDate,
                                                decoration: const InputDecoration(
                                                    labelText: 'LR Date',
                                                    prefixIcon: Icon(Icons
                                                        .calendar_today_rounded)),
                                              )),
                                            ]),
                                            const SizedBox(height: 12),
                                            TextFormField(
                                              controller: _garageSlipCtrl,
                                              decoration: InputDecoration(
                                                labelText: 'Garage Slip No.',
                                                prefixIcon: const Icon(
                                                    Icons.receipt_rounded),
                                                helperText:
                                                    'Enter if LR not yet received',
                                                suffixIcon: _lrNumberCtrl.text
                                                            .trim()
                                                            .isEmpty &&
                                                        _garageSlipCtrl.text
                                                            .trim()
                                                            .isEmpty
                                                    ? const Icon(
                                                        Icons
                                                            .warning_amber_rounded,
                                                        color: Colors.orange,
                                                        size: 18)
                                                    : null,
                                              ),
                                              onChanged: (_) => ctx
                                                  .findAncestorStateOfType<
                                                      FormState>()
                                                  ?.validate(),
                                              validator: (v) {
                                                if ((v == null ||
                                                        v.trim().isEmpty) &&
                                                    _lrNumberCtrl.text
                                                        .trim()
                                                        .isEmpty) {
                                                  return 'LR or Garage Slip required';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                            DropdownButtonFormField<String>(
                                              value: _transportList.contains(
                                                      _selectedTransport)
                                                  ? _selectedTransport
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Transport Name',
                                                prefixIcon: Icon(Icons
                                                    .local_shipping_rounded),
                                              ),
                                              isExpanded: true,
                                              hint: const Text(
                                                  'Select transport'),
                                              items: _transportList
                                                  .map((t) => DropdownMenuItem(
                                                      value: t,
                                                      child: Text(t,
                                                          overflow: TextOverflow
                                                              .ellipsis)))
                                                  .toList(),
                                              onChanged: (val) => setState(() =>
                                                  _selectedTransport = val),
                                            ),
                                          ]);
                                    }),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    )), // closes Expanded + Builder
          if (selectedInvoices.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.stagePacking,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: (isSaving || !AuthService.to.perms.canUpdate(ScreenKeys.step2)) ? null : _submit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.inventory_2_rounded),
                  label: const Text('Save Packing Details',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
      {required String title,
      required IconData icon,
      required Color color,
      required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: color, fontSize: 13)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: AppTheme.stagePacking.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: const [
        Expanded(
            flex: 2,
            child: Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        Expanded(
            flex: 2,
            child: Text('Party',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        Expanded(
            flex: 1,
            child: Text('Series',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        Expanded(
            flex: 2,
            child: Text('Amount',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
      ]),
    );
  }

  Widget _tableRow(String inv, String company, String party, String amount,
      [String orderType = 'regular',
      String specialRemarks = '',
      String? seriesName,
      String transport = '',
      String stopName = '',
      int stopSeq = 999]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            OrderTypeFlag(
                orderTypeKey: orderType,
                specialRemarks: specialRemarks,
                compact: true),
            const SizedBox(width: 8),
            Expanded(
                child: Text(inv,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (seriesName != null && seriesName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: AppTheme.stageInvoice.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(seriesName,
                    style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.stageInvoice,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
            ],
            Text('₹$amount', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(
                child: Text(party,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (transport.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: const Color(0xFFAB47BC).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_shipping_rounded,
                      size: 10, color: Color(0xFFAB47BC)),
                  const SizedBox(width: 3),
                  Text(transport,
                      style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFFAB47BC),
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            // ── Stop badge ──────────────────────────────────────────────
            if (stopName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_rounded,
                      size: 10, color: Color(0xFF00897B)),
                  const SizedBox(width: 3),
                  Text('${stopSeq < 999 ? stopSeq + 1 : "?"}. $stopName',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  // ── Add Invoice to Existing Packing ────────────────────────────────────────
  Future<void> _showAddInvoiceToPackaging() async {
    if (!mounted) return;

    // Data loaded lazily — nothing fetched upfront
    List<Map<String, dynamic>> allGroups = [];
    List<InvoiceData> allStage1Invoices = [];
    bool dataLoaded = false;
    bool dataLoading = false;

    final searchCtrl = TextEditingController();
    String searchQuery = '';

    // Filtered results
    List<Map<String, dynamic>> filteredGroups = [];
    List<InvoiceData> filteredInvoices = [];

    Map<String, dynamic>? selectedGroup;
    InvoiceData? selectedInvoice;
    final ewayCtrl = TextEditingController();
    bool saving = false;

    void runSearch(String query, StateSetter setModal) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        setModal(() {
          filteredGroups = [];
          filteredInvoices = [];
          selectedGroup = null;
          selectedInvoice = null;
        });
        return;
      }

      // Match groups by LR number or any invoice number inside the group
      final grps = allGroups.where((g) {
        final lr = (g['lrNumber'] ?? '').toString().toLowerCase();
        if (lr.contains(q)) return true;
        final invs = g['invoices'] as List<InvoiceData>;
        return invs.any((inv) => inv.invoiceNumber.toLowerCase().contains(q));
      }).toList();

      List<InvoiceData> displayInvs;
      if (grps.isNotEmpty) {
        // Groups found — show only invoices matching same party + company
        final validCombos = <String>{};
        for (final g in grps) {
          final invs = g['invoices'] as List<InvoiceData>;
          for (final inv in invs) {
            validCombos.add('${inv.partyData.partyId}||${inv.companyName}');
          }
        }
        displayInvs = allStage1Invoices
            .where((inv) => validCombos
                .contains('${inv.partyData.partyId}||${inv.companyName}'))
            .toList();
      } else {
        // No LR group matched — directly search stage-1 invoices by query
        displayInvs = allStage1Invoices.where((inv) {
          return inv.invoiceNumber.toLowerCase().contains(q) ||
              inv.partyData.partyName.toLowerCase().contains(q) ||
              inv.companyName.toLowerCase().contains(q);
        }).toList();
      }

      setModal(() {
        filteredGroups = grps;
        filteredInvoices = displayInvs;
        if (selectedGroup != null && !grps.contains(selectedGroup)) {
          selectedGroup = null;
          selectedInvoice = null;
        }
        if (selectedInvoice != null && !displayInvs.contains(selectedInvoice)) {
          selectedInvoice = null;
        }
      });
    }

    Future<void> loadData(StateSetter setModal) async {
      if (dataLoaded) return;
      setModal(() => dataLoading = true);
      allGroups = await ApiService().getPackagingGroupsByLR();
      allStage1Invoices = await ApiService().getInvoices(1);
      dataLoaded = true;
      setModal(() => dataLoading = false);
      // Re-run search in case user typed while data was loading
      if (searchCtrl.text.trim().isNotEmpty) {
        runSearch(searchCtrl.text, setModal);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          // Load data once when sheet opens
          if (!dataLoaded && !dataLoading) {
            loadData(setModal);
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: AppTheme.stagePacking.withValues(alpha: 0.1),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: AppTheme.stagePacking, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Add Invoice to Existing Packing',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.stagePacking,
                              fontSize: 14)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),

                // ── Search Bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by Invoice No. or LR Number...',
                      prefixIcon: dataLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.stagePacking)))
                          : const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                searchCtrl.clear();
                                runSearch('', setModal);
                              })
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppTheme.stagePacking, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      searchQuery = val;
                      runSearch(val, setModal);
                    },
                  ),
                ),

                // ── Hint text ────────────────────────────────────────────
                if (searchCtrl.text.trim().isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                        'Search by LR number or invoice number to find a packing group',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      )),
                    ]),
                  ),

                // ── Results ──────────────────────────────────────────────
                Expanded(
                  child: dataLoading
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(
                                color: AppTheme.stagePacking),
                            const SizedBox(height: 12),
                            const Text('Loading data...',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ]),
                        )
                      : searchCtrl.text.trim().isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_rounded,
                                        size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 10),
                                    Text('Search by LR or invoice number',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 13)),
                                  ]),
                            )
                          : (filteredGroups.isEmpty && filteredInvoices.isEmpty)
                              ? Center(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_off_rounded,
                                            size: 48,
                                            color: Colors.grey.shade300),
                                        const SizedBox(height: 10),
                                        Text(
                                            'No matching LR groups or open invoices for "${searchCtrl.text}"',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.grey.shade400,
                                                fontSize: 13)),
                                      ]),
                                )
                              : SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 8, 14, 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Matching LR Groups ───────────────
                                      if (filteredGroups.isNotEmpty) ...[
                                        _sectionLabel(
                                            'Existing Packing Groups (LR)',
                                            Icons.local_shipping_rounded),
                                        const SizedBox(height: 8),
                                        ...filteredGroups.map((group) {
                                          final invs = group['invoices']
                                              as List<InvoiceData>;
                                          final isSelected =
                                              selectedGroup == group;
                                          return GestureDetector(
                                            onTap: () => setModal(() {
                                              selectedGroup =
                                                  isSelected ? null : group;
                                              selectedInvoice = null;
                                            }),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppTheme.stagePacking
                                                        .withValues(alpha: 0.08)
                                                    : Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppTheme.stagePacking
                                                      : Colors.grey.shade200,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      Icon(
                                                          Icons
                                                              .local_shipping_rounded,
                                                          size: 14,
                                                          color: isSelected
                                                              ? AppTheme
                                                                  .stagePacking
                                                              : Colors.grey),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                          'LR: ${group['lrNumber']}',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 13,
                                                              color: isSelected
                                                                  ? AppTheme
                                                                      .stagePacking
                                                                  : Colors
                                                                      .black87)),
                                                      const Spacer(),
                                                      Text('${invs.length} inv',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme
                                                                  .textSecondary)),
                                                      if (isSelected) ...[
                                                        const SizedBox(
                                                            width: 6),
                                                        Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            color: AppTheme
                                                                .stagePacking,
                                                            size: 18),
                                                      ],
                                                    ]),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Date: ${group['lrDate']}  ·  Cases: ${group['totalCase']} (${group['packCase']} pack + ${group['looseCase']} loose)',
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme
                                                              .textSecondary),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: invs
                                                          .map(
                                                              (inv) =>
                                                                  Container(
                                                                    padding: const EdgeInsets
                                                                            .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: AppTheme
                                                                          .stagePacking
                                                                          .withValues(
                                                                              alpha: 0.12),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              5),
                                                                    ),
                                                                    child: Text(
                                                                        inv
                                                                            .invoiceNumber,
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                10,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color: AppTheme.stagePacking)),
                                                                  ))
                                                          .toList(),
                                                    ),
                                                  ]),
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: 4),
                                      ],

                                      // ── Matching Stage-1 Invoices ────────
                                      if (filteredGroups.isNotEmpty &&
                                          filteredInvoices.isEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.orange.shade200),
                                          ),
                                          child: Row(children: [
                                            Icon(Icons.info_outline_rounded,
                                                size: 15,
                                                color: Colors.orange.shade700),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text(
                                              'No open invoices found for this party and company',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.orange.shade800),
                                            )),
                                          ]),
                                        ),
                                      ],
                                      if (filteredInvoices.isNotEmpty) ...[
                                        _sectionLabel(
                                            'Pending Invoices (Stage 1)',
                                            Icons.receipt_long_rounded),
                                        const SizedBox(height: 8),
                                        ...filteredInvoices.map((inv) {
                                          final isSelected =
                                              selectedInvoice?.id == inv.id;
                                          return GestureDetector(
                                            onTap: () => setModal(() =>
                                                selectedInvoice =
                                                    isSelected ? null : inv),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.green
                                                        .withValues(alpha: 0.07)
                                                    : Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.green
                                                      : Colors.grey.shade200,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: Row(children: [
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(inv.invoiceNumber,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize:
                                                                      13)),
                                                      Text(
                                                          '${inv.partyData.partyName}  ·  ${inv.companyName}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme
                                                                  .textSecondary)),
                                                      Text(
                                                          '₹${inv.invoiceAmount}  ·  ${inv.invoiceDate}',
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppTheme
                                                                  .textSecondary)),
                                                    ])),
                                                if (isSelected)
                                                  const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.green,
                                                      size: 20)
                                                else
                                                  Icon(
                                                      Icons
                                                          .radio_button_unchecked_rounded,
                                                      color:
                                                          Colors.grey.shade300,
                                                      size: 20),
                                              ]),
                                            ),
                                          );
                                        }),
                                      ],

                                      // ── Validation warning ───────────────
                                      if (selectedGroup != null &&
                                          selectedInvoice != null) ...[
                                        Builder(builder: (_) {
                                          final groupInvs =
                                              selectedGroup!['invoices']
                                                  as List<InvoiceData>;
                                          final firstInv = groupInvs.isNotEmpty
                                              ? groupInvs.first
                                              : null;
                                          final compatible = firstInv == null ||
                                              (selectedInvoice!
                                                          .partyData.partyId ==
                                                      firstInv
                                                          .partyData.partyId &&
                                                  selectedInvoice!
                                                          .companyName ==
                                                      firstInv.companyName);
                                          if (!compatible) {
                                            return Container(
                                              margin:
                                                  const EdgeInsets.only(top: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.red.shade200),
                                              ),
                                              child: Row(children: [
                                                Icon(
                                                    Icons.warning_amber_rounded,
                                                    size: 16,
                                                    color: Colors.red.shade600),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(
                                                  'Party or Company mismatch!\nExpected: ${firstInv!.partyData.partyName} · ${firstInv.companyName}',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.red.shade700),
                                                )),
                                              ]),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }),
                                      ],

                                      // ── E-way Bill ───────────────────────
                                      if (selectedGroup != null &&
                                          selectedInvoice != null) ...[
                                        const SizedBox(height: 14),
                                        // Summary chip row
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.stagePacking
                                                .withValues(alpha: 0.06),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppTheme.stagePacking
                                                    .withValues(alpha: 0.25)),
                                          ),
                                          child: Row(children: [
                                            Icon(Icons.merge_rounded,
                                                size: 16,
                                                color: AppTheme.stagePacking),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87),
                                                children: [
                                                  TextSpan(
                                                    text: selectedInvoice!
                                                        .invoiceNumber,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800),
                                                  ),
                                                  const TextSpan(
                                                      text: '  →  LR '),
                                                  TextSpan(
                                                    text: selectedGroup![
                                                        'lrNumber'],
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppTheme
                                                            .stagePacking),
                                                  ),
                                                ],
                                              ),
                                            )),
                                          ]),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: ewayCtrl,
                                          decoration: InputDecoration(
                                            labelText:
                                                'E-way Bill No. (optional)',
                                            prefixIcon: const Icon(
                                                Icons.document_scanner_rounded,
                                                size: 18),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ),
                                        const SizedBox(
                                            height:
                                                80), // space for save button
                                      ],
                                    ],
                                  ),
                                ),
                ),

                // ── Save Button ──────────────────────────────────────────
                if (selectedGroup != null && selectedInvoice != null)
                  Builder(builder: (_) {
                    final groupInvs =
                        selectedGroup!['invoices'] as List<InvoiceData>;
                    final firstInv =
                        groupInvs.isNotEmpty ? groupInvs.first : null;
                    final compatible = firstInv == null ||
                        (selectedInvoice!.partyData.partyId ==
                                firstInv.partyData.partyId &&
                            selectedInvoice!.companyName ==
                                firstInv.companyName);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                          16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: compatible
                                ? AppTheme.stagePacking
                                : Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: (!compatible || saving)
                              ? null
                              : () async {
                                  setModal(() => saving = true);
                                  final group = selectedGroup!;
                                  final invs =
                                      group['invoices'] as List<InvoiceData>;
                                  final rawData =
                                      group['rawData'] as Map<String, dynamic>;
                                  final sibIds = invs.map((i) => i.id).toList();
                                  final success = await ApiService()
                                      .addInvoiceToExistingPackaging(
                                    newInvoiceId: selectedInvoice!.id,
                                    ewayBillNumber: ewayCtrl.text.trim(),
                                    packagingData: rawData,
                                    siblingInvoiceIds: sibIds,
                                  );
                                  setModal(() => saving = false);
                                  if (success) {
                                    Navigator.pop(ctx);
                                    Get.snackbar(
                                      'Invoice Added!',
                                      '${selectedInvoice!.invoiceNumber} added to LR ${group['lrNumber']}',
                                      backgroundColor: AppTheme.stagePacking,
                                      colorText: Colors.white,
                                    );
                                    _fetchInvoices();
                                  } else {
                                    Get.snackbar('Error',
                                        'Failed to add invoice. Please try again.');
                                  }
                                },
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.add_circle_rounded),
                          label: const Text('Add Invoice to Packing',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
    ewayCtrl.dispose();
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 13, color: AppTheme.stagePacking),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.stagePacking,
              fontSize: 12)),
    ]);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedInvoices.isEmpty) {
      Get.snackbar('Error', 'Please select at least one invoice');
      return;
    }
    setState(() => isSaving = true);

    Map<String, String> ewayBillMap = {};
    for (String inv in selectedInvoices) {
      final invData = invoices.firstWhere((d) => d.invoiceNumber == inv);
      ewayBillMap[invData.id] = ewayBillControllers[inv]?.text ?? '';
    }

    final data = {
      'packCase': _packCaseCtrl.text.trim(),
      'looseCase': _looseCaseCtrl.text.trim(),
      'totalCase': _totalCaseCtrl.text.trim(),
      'lrNumber': _lrNumberCtrl.text.trim(),
      'lrDate': _lrDateCtrl.text.trim(),
      'garageSlip': _garageSlipCtrl.text.trim(),
      'transportName': _selectedTransport ?? '',
      'ewayBillNumbers': ewayBillMap,
      'selectedInvoicesIdList': selectedInvoicesIdList,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final success = await ApiService().createPackaging(data);
    setState(() => isSaving = false);
    if (success) {
      Get.snackbar('Saved!', 'Packing details saved',
          backgroundColor: AppTheme.stagePacking, colorText: Colors.white);
      setState(() {
        selectedInvoices.clear();
        selectedInvoicesIdList.clear();
        ewayBillControllers.values.forEach((c) => c.dispose());
        ewayBillControllers.clear();
        _packCaseCtrl.clear();
        _looseCaseCtrl.clear();
        _totalCaseCtrl.clear();
        _lrNumberCtrl.clear();
        _garageSlipCtrl.clear();
        _selectedTransport = null;
      });
      _fetchInvoices();
    } else {
      Get.snackbar('Error', 'Failed to save');
    }
  }
}
