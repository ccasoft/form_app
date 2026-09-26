import 'package:flutter/material.dart';
import 'package:form_app/home.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:form_app/invoice_series_config.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';

// ── Order type helpers ────────────────────────────────────────────────────────
enum OrderType { regular, coldChain, coolChain, special }

extension OrderTypeX on OrderType {
  String get key {
    switch (this) {
      case OrderType.regular:
        return 'regular';
      case OrderType.coldChain:
        return 'cold_chain';
      case OrderType.coolChain:
        return 'cool_chain';
      case OrderType.special:
        return 'special';
    }
  }

  String get label {
    switch (this) {
      case OrderType.regular:
        return 'Regular';
      case OrderType.coldChain:
        return 'Cold Chain';
      case OrderType.coolChain:
        return 'Cool Chain';
      case OrderType.special:
        return 'Special';
    }
  }

  Color get color {
    switch (this) {
      case OrderType.regular:
        return const Color(0xFF2E7D32);
      case OrderType.coldChain:
        return const Color(0xFFC62828);
      case OrderType.coolChain:
        return const Color(0xFFE65100);
      case OrderType.special:
        return const Color(0xFFF9A825);
    }
  }

  IconData get icon {
    switch (this) {
      case OrderType.regular:
        return Icons.receipt_rounded;
      case OrderType.coldChain:
        return Icons.ac_unit_rounded;
      case OrderType.coolChain:
        return Icons.device_thermostat_rounded;
      case OrderType.special:
        return Icons.star_rounded;
    }
  }

  bool get hasDeliveryDeadline =>
      this == OrderType.coldChain || this == OrderType.coolChain;
  String get deadlineNote {
    switch (this) {
      case OrderType.coldChain:
        return '⚠ Cold Chain: Delivery confirmation required within 24 hrs of dispatch';
      case OrderType.coolChain:
        return '⚠ Cool Chain: Delivery confirmation required within 24 hrs';
      default:
        return '';
    }
  }

  static OrderType fromKey(String key) {
    switch (key) {
      case 'cold_chain':
        return OrderType.coldChain;
      case 'cool_chain':
        return OrderType.coolChain;
      case 'special':
        return OrderType.special;
      default:
        return OrderType.regular;
    }
  }
}

class OrderTypeFlag extends StatelessWidget {
  final String orderTypeKey;
  final String? specialRemarks;
  final bool compact;
  final bool avatarOnly;
  const OrderTypeFlag(
      {super.key,
      required this.orderTypeKey,
      this.specialRemarks,
      this.compact = false,
      this.avatarOnly = false});

  @override
  Widget build(BuildContext context) {
    final type = OrderTypeX.fromKey(orderTypeKey);
    // avatarOnly: a small colored circle with icon — fits inside Chip avatar slot
    if (avatarOnly) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
        child: Icon(type.icon, size: 12, color: Colors.white),
      );
    }
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: type.color, borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(type.icon, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(type.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: type.color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: type.color, borderRadius: BorderRadius.circular(5)),
              child: Icon(type.icon, color: Colors.white, size: 13)),
          const SizedBox(width: 8),
          Text(type.label,
              style: TextStyle(
                  color: type.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const Spacer(),
          if (type.hasDeliveryDeadline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: type.color.withValues(alpha: 0.4))),
              child: Row(children: [
                Icon(Icons.timer_rounded, size: 10, color: type.color),
                const SizedBox(width: 3),
                Text('24hr delivery',
                    style: TextStyle(
                        fontSize: 9,
                        color: type.color,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        if (type.hasDeliveryDeadline) ...[
          const SizedBox(height: 4),
          Text(type.deadlineNote,
              style: TextStyle(
                  fontSize: 10, color: type.color.withValues(alpha: 0.85))),
        ],
        if (type == OrderType.special &&
            specialRemarks != null &&
            specialRemarks!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.notes_rounded, size: 11, color: type.color),
            const SizedBox(width: 4),
            Expanded(
                child: Text(specialRemarks!,
                    style: TextStyle(fontSize: 10, color: type.color))),
          ]),
        ],
      ]),
    );
  }
}

// ── Step 1 Screen ─────────────────────────────────────────────────────────────
class Step1 extends StatefulWidget {
  @override
  _Step1State createState() => _Step1State();
}

class _Step1State extends State<Step1> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();
  final _invoiceAmountCtrl = TextEditingController();
  final _ewayBillCtrl = TextEditingController();
  final _validityDateCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  List<PartyData> parties = [];
  List<PartyData> filteredParties = [];
  List<CompanyData> companies = [];
  List<String> _transportList = [];
  PartyData? selectedParty;
  CompanyData? selectedCompany;
  String? _selectedTransport;
  bool isLoading = false;
  bool isSaving = false;
  OrderType _orderType = OrderType.regular;

  // ── Invoice series validation ─────────────────────────────────────────────
  List<InvoiceSeriesConfig> _availableSeries =
      []; // all series for selected company
  InvoiceSeriesConfig? _seriesConfig; // currently selected series
  int _maxExistingNumber = 0;
  String? _seriesError; // hard error — blocks submit
  String? _seriesWarning; // soft warning — shown but doesn't block
  bool _loadingSeries = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.step1, label: 'Invoice Preparation'));
    _fetchData();
    _invoiceDateCtrl.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _validityDateCtrl.text = DateFormat('dd-MM-yyyy')
        .format(DateTime.now().add(const Duration(days: 30)));
  }

  @override
  void dispose() {
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _invoiceAmountCtrl.dispose();
    _ewayBillCtrl.dispose();
    _validityDateCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final fs = ApiService();
    final p = await fs.getParties();
    final c = await fs.getCompanies();
    final t = await fs.getTransport();
    if (mounted)
      setState(() {
        parties = p;
        filteredParties = [];
        companies = c;
        _transportList = t.map((s) => s.trim()).toList();
        isLoading = false;
      });
  }

  // Bounded, capped-height options list for Autocomplete fields — without
  // this, the default overlay grows to fit every match and can visually
  // cover the cards further down the form while the user is still typing.
  Widget _boundedOptionsView<T extends Object>({
    required List<T> options,
    required void Function(T) onSelected,
    required String Function(T) labelOf,
  }) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (ctx, i) {
              final o = options[i];
              return InkWell(
                onTap: () => onSelected(o),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(labelOf(o),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030));
    if (picked != null) ctrl.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  void _selectOrderType(OrderType type) {
    setState(() => _orderType = type);
    if (type == OrderType.special) _showRemarksSheet();
  }

  void _showRemarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: OrderType.special.color,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 16)),
                const SizedBox(width: 10),
                const Text('Special Order Remarks',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 4),
              const Text('Remarks are mandatory for Special orders.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              TextField(
                  controller: _remarksCtrl,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: 'Enter special instructions / remarks...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                              color: OrderType.special.color, width: 2)))),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: OrderType.special.color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Confirm Remarks',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)))),
            ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invoice Preparation',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Chhattisgarh C & F Agency Pvt Ltd',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        backgroundColor: AppTheme.stageInvoice,
        iconTheme: const IconThemeData(color: Colors.white),
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
            child: Text('Stage 1',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(12, 12, 12,
                        MediaQuery.of(context).viewInsets.bottom + 24),
                    child: Form(
                      key: _formKey,
                      child: Column(children: [
                        // ORDER TYPE — compact 2x2 row
                        _buildCard(
                            title: 'Order Type',
                            icon: Icons.category_rounded,
                            color: _orderType.color,
                            children: [
                              Row(children: [
                                Expanded(child: _orderTile(OrderType.regular)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _orderTile(OrderType.coldChain)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _orderTile(OrderType.coolChain)),
                                const SizedBox(width: 8),
                                Expanded(child: _orderTile(OrderType.special)),
                              ]),
                              if (_orderType != OrderType.regular) ...[
                                const SizedBox(height: 10),
                                OrderTypeFlag(
                                    orderTypeKey: _orderType.key,
                                    specialRemarks: _remarksCtrl.text),
                                if (_orderType == OrderType.special) ...[
                                  const SizedBox(height: 6),
                                  OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              OrderType.special.color,
                                          side: BorderSide(
                                              color: OrderType.special.color),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6)),
                                      onPressed: _showRemarksSheet,
                                      icon: const Icon(Icons.edit_note_rounded,
                                          size: 14),
                                      label: const Text('Edit Remarks',
                                          style: TextStyle(fontSize: 11))),
                                ],
                              ],
                            ]),
                        const SizedBox(height: 10),

                        // COMPANY + PARTY — in one card
                        _buildCard(
                            title: 'Company & Party',
                            icon: Icons.business_rounded,
                            color: AppTheme.stageInvoice,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Autocomplete<CompanyData>(
                                  optionsBuilder: (tv) => tv.text.isEmpty
                                      ? companies
                                      : companies.where((c) => c.companyName
                                          .toLowerCase()
                                          .contains(tv.text.toLowerCase())),
                                  optionsViewBuilder:
                                      (ctx, onSelected, options) =>
                                          _boundedOptionsView<CompanyData>(
                                              options: options.toList(),
                                              onSelected: onSelected,
                                              labelOf: (o) => o.companyName),
                                  displayStringForOption: (o) => o.companyName,
                                  fieldViewBuilder: (ctx, tc, fn, _) =>
                                      TextFormField(
                                          controller: tc,
                                          focusNode: fn,
                                          decoration: const InputDecoration(
                                              labelText: 'Company *',
                                              prefixIcon: Icon(
                                                  Icons.business_rounded,
                                                  size: 18),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12)),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Required'
                                                  : null),
                                  onSelected: (c) {
                                    setState(() {
                                      selectedCompany = c;
                                      selectedParty = null;
                                      filteredParties = parties
                                          .where((p) => p.companyIds
                                              .contains(c.companyId))
                                          .toList();
                                      _availableSeries = [];
                                      _seriesConfig = null;
                                      _seriesError = null;
                                      _seriesWarning = null;
                                      _maxExistingNumber = 0;
                                    });
                                    _loadSeriesConfig(c);
                                  },
                                )),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Autocomplete<PartyData>(
                                  optionsBuilder: (tv) {
                                    final source = filteredParties;
                                    return tv.text.isEmpty
                                        ? source
                                        : source.where((p) => p.partyName
                                            .toLowerCase()
                                            .contains(tv.text.toLowerCase()));
                                  },
                                  optionsViewBuilder:
                                      (ctx, onSelected, options) =>
                                          _boundedOptionsView<PartyData>(
                                              options: options.toList(),
                                              onSelected: onSelected,
                                              labelOf: (o) => o.partyName),
                                  displayStringForOption: (o) => o.partyName,
                                  fieldViewBuilder: (ctx, tc, fn, _) =>
                                      TextFormField(
                                    controller: tc,
                                    focusNode: fn,
                                    enabled: selectedCompany != null,
                                    decoration: InputDecoration(
                                      labelText: 'Party *',
                                      prefixIcon: const Icon(
                                          Icons.people_alt_rounded,
                                          size: 18),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      hintText: selectedCompany == null
                                          ? 'Select company first'
                                          : null,
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Required'
                                        : null,
                                  ),
                                  onSelected: (p) => setState(() {
                                    selectedParty = p;
                                    // Auto-fill transport from party default
                                    _selectedTransport =
                                        p.transportName.isNotEmpty
                                            ? p.transportName
                                            : null;
                                  }),
                                )),
                              ]),
                              if (selectedParty != null) ...[
                                const SizedBox(height: 8),
                                _partyInfoRow(selectedParty!),
                                const SizedBox(height: 10),
                                // ── Transport dropdown ──────────────────────
                                DropdownButtonFormField<String>(
                                  value: _transportList
                                          .contains(_selectedTransport)
                                      ? _selectedTransport
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Transport',
                                    prefixIcon: Icon(
                                        Icons.local_shipping_rounded,
                                        size: 18),
                                  ),
                                  isExpanded: true,
                                  items: _transportList
                                      .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t,
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedTransport = val),
                                  hint:
                                      const Text('Select transport (optional)'),
                                ),
                              ],
                            ]),
                        const SizedBox(height: 10),

                        // ── SERIES SELECTOR ──────────────────────────────────────
                        if (_loadingSeries)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('Loading invoice series...',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                  ])),

                        // Multiple series → show picker
                        if (!_loadingSeries && _availableSeries.length > 1) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.stageInvoice.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.stageInvoice
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(
                                        Icons.format_list_numbered_rounded,
                                        size: 14,
                                        color: AppTheme.stageInvoice),
                                    const SizedBox(width: 6),
                                    const Text('Select Invoice Series',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.stageInvoice)),
                                    const Spacer(),
                                    Text(
                                        '${_availableSeries.length} series available',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textSecondary)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: _availableSeries.map((s) {
                                      final active = _seriesConfig?.id == s.id;
                                      return GestureDetector(
                                        onTap: () => _selectSeries(s),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? AppTheme.stageInvoice
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                            border: Border.all(
                                                color: active
                                                    ? AppTheme.stageInvoice
                                                    : AppTheme.divider,
                                                width: active ? 1.5 : 1),
                                            boxShadow: active
                                                ? [
                                                    BoxShadow(
                                                        color: AppTheme
                                                            .stageInvoice
                                                            .withValues(
                                                                alpha: 0.18),
                                                        blurRadius: 6,
                                                        offset:
                                                            const Offset(0, 2))
                                                  ]
                                                : [],
                                          ),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .receipt_long_rounded,
                                                          size: 13,
                                                          color: active
                                                              ? Colors.white
                                                              : AppTheme
                                                                  .stageInvoice),
                                                      const SizedBox(width: 5),
                                                      Text(s.seriesName,
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 13,
                                                              color: active
                                                                  ? Colors.white
                                                                  : AppTheme
                                                                      .textPrimary)),
                                                      if (active) ...[
                                                        const SizedBox(
                                                            width: 5),
                                                        const Icon(
                                                            Icons
                                                                .check_circle_rounded,
                                                            size: 13,
                                                            color: Colors.white)
                                                      ],
                                                    ]),
                                                const SizedBox(height: 2),
                                                Text(
                                                  s.prefix.isNotEmpty
                                                      ? 'Prefix: ${s.prefix}  ·  Start: ${s.startNumber}'
                                                      : 'Start: ${s.startNumber}',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: active
                                                          ? Colors.white70
                                                          : AppTheme
                                                              .textSecondary),
                                                ),
                                                Text(
                                                  s.isSequential
                                                      ? 'Sequential'
                                                      : 'Manual',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: active
                                                          ? Colors.white60
                                                          : AppTheme
                                                              .textSecondary),
                                                ),
                                              ]),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (_seriesConfig == null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('⬆ Tap a series to select it',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.warning)),
                                    ),
                                ]),
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Single series → show banner as before
                        if (!_loadingSeries &&
                            _seriesConfig != null &&
                            _availableSeries.length == 1) ...[
                          const SizedBox(height: 6),
                          _SeriesBanner(config: _seriesConfig!),
                        ],

                        // Selected series banner when multiple exist
                        if (!_loadingSeries &&
                            _seriesConfig != null &&
                            _availableSeries.length > 1) ...[
                          _SeriesBanner(config: _seriesConfig!),
                        ],

                        if (!_loadingSeries &&
                            _availableSeries.isEmpty &&
                            selectedCompany != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: AppTheme.warning
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.warning
                                            .withValues(alpha: 0.3))),
                                child: Row(children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 14, color: AppTheme.warning),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                      child: Text(
                                          'No invoice series configured for this company. Numbers will not be validated. Set up a series in Masters → Invoice Series.',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.warning,
                                              height: 1.4))),
                                ]),
                              )),
                        const SizedBox(height: 4),
                        // INVOICE DETAILS — compact
                        _buildCard(
                            title: 'Invoice Details',
                            icon: Icons.receipt_long_rounded,
                            color: AppTheme.stageInvoice,
                            children: [
                              // Invoice number — full width so the full number is always visible
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onDoubleTap: _seriesConfig != null
                                          ? _openMissingInvoicePicker
                                          : null,
                                      child: TextFormField(
                                        controller: _invoiceNumberCtrl,
                                        onChanged: _validateInvoiceNumber,
                                        decoration: InputDecoration(
                                          labelText: 'Invoice No. *',
                                          hintText: _seriesConfig != null
                                              ? _seriesConfig!.prefix.isNotEmpty
                                                  ? '${_seriesConfig!.prefix}${_seriesConfig!.startNumber}'
                                                  : 'e.g. ${_seriesConfig!.startNumber}'
                                              : null,
                                          hintStyle: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                          prefixIcon: const Icon(
                                              Icons.tag_rounded,
                                              size: 18),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 12),
                                          suffixIcon: _loadingSeries
                                              ? const Padding(
                                                  padding: EdgeInsets.all(12),
                                                  child: SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2)))
                                              : _seriesConfig != null
                                                  ? Icon(Icons.verified_rounded,
                                                      color: _seriesError !=
                                                              null
                                                          ? AppTheme.danger
                                                          : AppTheme.success,
                                                      size: 18)
                                                  : null,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Required';
                                          if (_seriesError != null)
                                            return _seriesError;
                                          return null;
                                        },
                                      ),
                                    ),
                                    if (_seriesConfig != null)
                                      const Padding(
                                        padding:
                                            EdgeInsets.only(top: 4, left: 4),
                                        child: Text(
                                            'Double-tap to pick from unused invoice numbers',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textSecondary)),
                                      ),
                                    if (_seriesError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, left: 4),
                                        child: Row(children: [
                                          const Icon(
                                              Icons.error_outline_rounded,
                                              size: 12,
                                              color: AppTheme.danger),
                                          const SizedBox(width: 4),
                                          Flexible(
                                              child: Text(_seriesError!,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppTheme.danger))),
                                        ]),
                                      ),
                                    if (_seriesWarning != null &&
                                        _seriesError == null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, left: 4),
                                        child: Row(children: [
                                          const Icon(
                                              Icons.warning_amber_rounded,
                                              size: 12,
                                              color: AppTheme.warning),
                                          const SizedBox(width: 4),
                                          Flexible(
                                              child: Text(_seriesWarning!,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          AppTheme.warning))),
                                        ]),
                                      ),
                                    if (_seriesConfig != null &&
                                        _seriesError == null &&
                                        _seriesWarning == null &&
                                        _invoiceNumberCtrl.text.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, left: 4),
                                        child: Row(children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 12,
                                              color: AppTheme.success),
                                          const SizedBox(width: 4),
                                          Text(
                                              'Matches series ${_seriesConfig!.fyLabel}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.success)),
                                        ]),
                                      ),
                                  ]),
                              const SizedBox(height: 8),
                              // Amount — full width on its own row
                              Row(children: [
                                Expanded(
                                    child: TextFormField(
                                        controller: _invoiceAmountCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Amount *',
                                            prefixIcon: Icon(
                                                Icons.currency_rupee_rounded,
                                                size: 18),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12)),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Required'
                                            : null)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: _dateField(
                                        _invoiceDateCtrl, 'Invoice Date *')),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _dateField(
                                        _validityDateCtrl, 'Validity Date *')),
                              ]),
                              const SizedBox(height: 8),
                              TextFormField(
                                  controller: _ewayBillCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'E-way Bill No.',
                                      prefixIcon: Icon(
                                          Icons.document_scanner_rounded,
                                          size: 18),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12))),
                            ]),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.stageInvoice,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            onPressed: (isSaving ||
                                    !AuthService.to.perms
                                        .canAdd(ScreenKeys.step1))
                                ? null
                                : _submit,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_rounded,
                                    color: Colors.white),
                            label: const Text('Create Invoice',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  )),
    );
  }

  Widget _orderTile(OrderType type) {
    final isSelected = _orderType == type;
    return GestureDetector(
      onTap: () => _selectOrderType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? type.color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? type.color : AppTheme.divider,
              width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: type.color.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(type.icon,
              size: 18, color: isSelected ? Colors.white : type.color),
          const SizedBox(height: 4),
          Text(type.label.split(' ').first,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : type.color)),
          if (isSelected)
            Icon(Icons.check_circle_rounded,
                size: 12, color: Colors.white.withValues(alpha: 0.8)),
        ]),
      ),
    );
  }

  Widget _partyInfoRow(PartyData p) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppTheme.stageInvoice.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.stageInvoice.withValues(alpha: 0.2))),
      child: Row(children: [
        if (p.transportName.isNotEmpty) ...[
          Icon(Icons.local_shipping_rounded,
              size: 12, color: AppTheme.stageInvoice),
          const SizedBox(width: 4),
          Expanded(
              child: Text(p.transportName,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis))
        ],
        if (p.routeName.isNotEmpty) ...[
          const SizedBox(width: 10),
          Icon(Icons.route_rounded, size: 12, color: AppTheme.stageInvoice),
          const SizedBox(width: 4),
          Expanded(
              child: Text(p.routeName,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis))
        ],
      ]),
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
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 7),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: color, fontSize: 12))
            ])),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children)),
      ]),
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      onTap: () => _pickDate(ctrl),
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _loadSeriesConfig(CompanyData company) async {
    setState(() {
      _loadingSeries = true;
      _availableSeries = [];
      _seriesConfig = null;
      _seriesError = null;
      _seriesWarning = null;
    });
    final fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
    final all =
        await ApiService().getSeriesConfigsForCompany(company.companyId, fy);
    int maxNum = 0;
    InvoiceSeriesConfig? selected;
    if (all.length == 1) {
      selected = all.first;
      if (selected.isSequential) {
        maxNum = await ApiService()
            .getMaxInvoiceNumber(company.companyId, fy, selected.prefix);
      }
    }
    if (mounted) {
      setState(() {
        _availableSeries = all;
        _seriesConfig = selected;
        _maxExistingNumber = maxNum;
        _loadingSeries = false;
        if (_invoiceNumberCtrl.text.isNotEmpty)
          _validateInvoiceNumber(_invoiceNumberCtrl.text);
      });
    }
  }

  Future<void> _selectSeries(InvoiceSeriesConfig cfg) async {
    setState(() {
      _loadingSeries = true;
      _seriesConfig = cfg;
      _seriesError = null;
      _seriesWarning = null;
    });
    final fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
    int maxNum = 0;
    if (cfg.isSequential) {
      maxNum = await ApiService()
          .getMaxInvoiceNumber(selectedCompany!.companyId, fy, cfg.prefix);
    }
    if (mounted) {
      setState(() {
        _maxExistingNumber = maxNum;
        _loadingSeries = false;
        if (_invoiceNumberCtrl.text.isNotEmpty)
          _validateInvoiceNumber(_invoiceNumberCtrl.text);
      });
    }
  }

  // Double-tap on the Invoice No. field — lists up to 50 not-yet-entered
  // numbers in the selected series so the user can pick one instead of
  // typing it (fewer keystrokes, no typo'd/duplicate invoice numbers).
  Future<void> _openMissingInvoicePicker() async {
    final cfg = _seriesConfig;
    final company = selectedCompany;
    if (cfg == null || company == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Total numbers to offer in the picker, missing + next-in-sequence
    // combined — not each category capped independently.
    const pickerTotalCap = 50;

    final fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
    Map<String, dynamic>? res;
    try {
      res = await ApiService().getMissingInvoiceNumbers(
          company.companyId, fy, cfg.prefix,
          startNumber: cfg.startNumber,
          cap: pickerTotalCap,
          nextCap: pickerTotalCap);
    } catch (e) {
      res = null;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading dialog
    if (!mounted) return;

    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not check for missing invoice numbers. Try again.')));
      return;
    }

    final missingAll = List<int>.from(res['missing'] as List? ?? []);
    // Numbers past the latest entered one, never allocated to any party —
    // distinct from `missing`, which are gaps skipped inside the used range.
    final unallocatedAll = List<int>.from(res['unallocated'] as List? ?? []);

    // Combined total shown is capped at pickerTotalCap — missing numbers
    // fill the budget first, next-in-sequence numbers fill the rest.
    final missing = missingAll.take(pickerTotalCap).toList();
    final unallocated =
        unallocatedAll.take(pickerTotalCap - missing.length).toList();

    if (missing.isEmpty && unallocated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No missing or unused invoice numbers found in this series.')));
      return;
    }

    final totalFound = missing.length + unallocated.length;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(children: [
                const Expanded(
                    child: Text('Unused invoice numbers',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800))),
                Text('$totalFound found',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  if (missing.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                      child: Text(
                          'MISSING — SKIPPED IN SEQUENCE (${missing.length})',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppTheme.textSecondary)),
                    ),
                    ...missing.map((n) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.tag_rounded,
                              color: AppTheme.primary),
                          title: Text(cfg.formatNumber(n),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          onTap: () => Navigator.pop(context, n),
                        )),
                  ],
                  if (unallocated.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                      child: Text(
                          'NOT YET USED — NEXT IN SEQUENCE (${unallocated.length})',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppTheme.textSecondary)),
                    ),
                    ...unallocated.map((n) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.fiber_new_rounded,
                              color: AppTheme.stageDispatch),
                          title: Text(cfg.formatNumber(n),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          onTap: () => Navigator.pop(context, n),
                        )),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );

    if (picked != null) {
      final formatted = cfg.formatNumber(picked);
      _invoiceNumberCtrl.text = formatted;
      _invoiceNumberCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: formatted.length));
      _validateInvoiceNumber(formatted);
    }
  }

  void _validateInvoiceNumber(String value) {
    if (_seriesConfig == null) {
      setState(() {
        _seriesError = null;
        _seriesWarning = null;
      });
      return;
    }
    if (value.trim().isEmpty) {
      setState(() {
        _seriesError = null;
        _seriesWarning = null;
      });
      return;
    }

    // 1. Format validation (prefix, numeric part)
    final error = _seriesConfig!.validateFormat(value);
    if (error != null) {
      setState(() {
        _seriesError = error;
        _seriesWarning = null;
      });
      return;
    }

    // 2. Sequence / ordering warning
    final warning = _seriesConfig!.validateSequence(value, _maxExistingNumber);
    setState(() {
      _seriesError = null;
      _seriesWarning = warning;
    });

    // 3. Duplicate check (async, non-blocking — updates state when done)
    if (selectedCompany != null) {
      final fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
      ApiService()
          .invoiceNumberExists(selectedCompany!.companyId, fy, value.trim())
          .then((exists) {
        if (!mounted) return;
        if (exists) {
          setState(() {
            _seriesError =
                'Invoice ${value.trim()} already exists for ${selectedCompany!.companyName}. Possible duplicate entry.';
            _seriesWarning = null;
          });
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedParty == null || selectedCompany == null) {
      Get.snackbar('Error', 'Please select party and company');
      return;
    }
    if (_orderType == OrderType.special && _remarksCtrl.text.trim().isEmpty) {
      _showRemarksSheet();
      Get.snackbar(
          'Remarks Required', 'Please enter remarks for Special orders',
          backgroundColor: OrderType.special.color, colorText: Colors.white);
      return;
    }
    setState(() => isSaving = true);
    // Block hard series errors
    if (_seriesError != null) {
      Get.snackbar('Invalid Invoice Number', _seriesError!,
          backgroundColor: AppTheme.danger, colorText: Colors.white);
      setState(() => isSaving = false);
      return;
    }
    // Final duplicate check at submit time — catches async race conditions
    if (selectedCompany != null && _invoiceNumberCtrl.text.trim().isNotEmpty) {
      final fy = InvoiceSeriesConfig.financialYearOf(DateTime.now());
      final exists = await ApiService().invoiceNumberExists(
          selectedCompany!.companyId, fy, _invoiceNumberCtrl.text.trim());
      if (exists) {
        setState(() {
          _seriesError =
              'Invoice ${_invoiceNumberCtrl.text.trim()} already exists for ${selectedCompany!.companyName}. Entry blocked to prevent duplicate.';
          isSaving = false;
        });
        Get.snackbar('Duplicate Invoice', _seriesError!,
            backgroundColor: AppTheme.danger,
            colorText: Colors.white,
            duration: const Duration(seconds: 4));
        return;
      }
    }
    final now = DateTime.now();
    final fy = InvoiceSeriesConfig.financialYearOf(now);
    final data = {
      'invoiceNumber': _invoiceNumberCtrl.text.trim(),
      'invoiceDate': _invoiceDateCtrl.text.trim(),
      'validityDate': _validityDateCtrl.text.trim(),
      'invoiceAmount': _invoiceAmountCtrl.text.trim(),
      'ewayBillNumber': _ewayBillCtrl.text.trim(),
      'companyName': selectedCompany!.companyName,
      'companyId': selectedCompany!.companyId,
      'orderType': _orderType.key, 'specialRemarks': _remarksCtrl.text.trim(),
      'partyId': selectedParty!.partyId, 'partyName': selectedParty!.partyName,
      'address': selectedParty!.address,
      'contactNumber1': selectedParty!.contactNumber1,
      'contactNumber2': selectedParty!.contactNumber2,
      'contactPerson': selectedParty!.contactPerson,
      'transportName': _selectedTransport ?? selectedParty!.transportName,
      'routeName': selectedParty!.routeName,
      'selectedInvoicesIdList': [], 'timestamp': now.millisecondsSinceEpoch,
      'invoiceYear': now.year, 'invoiceMonth': now.month,
      'financialYear': fy,
      // Series tracking
      if (_seriesConfig != null) 'seriesId': _seriesConfig!.id,
      if (_seriesConfig != null) 'seriesName': _seriesConfig!.seriesName,
      // Snapshot needsCheque at invoice creation so cheque screen can track from Stage 1
      'needsCheque': selectedParty!.needsCheque,
      'chequeDone': false, // will be set true when cheque is collected
      'partyData': {
        'partyId': selectedParty!.partyId,
        'partyName': selectedParty!.partyName,
        'address': selectedParty!.address,
        'contactNumber1': selectedParty!.contactNumber1,
        'contactNumber2': selectedParty!.contactNumber2,
        'contactPerson': selectedParty!.contactPerson,
        'transportName': _selectedTransport ?? selectedParty!.transportName,
        'routeName': selectedParty!.routeName,
        'needsCheque': selectedParty!.needsCheque
      },
    };
    final result = await ApiService().createInvoice(data);
    setState(() => isSaving = false);
    if (result == 'true') {
      Get.snackbar(
          'Invoice Created!', 'Invoice ${_invoiceNumberCtrl.text} saved',
          backgroundColor: AppTheme.stageInvoice, colorText: Colors.white);
      _invoiceNumberCtrl.clear();
      _invoiceAmountCtrl.clear();
      _ewayBillCtrl.clear();
      setState(() {
        selectedParty = null;
        selectedCompany = null;
        _orderType = OrderType.regular;
        _remarksCtrl.clear();
        _availableSeries = [];
        _seriesConfig = null;
      });
    } else {
      Get.snackbar('Error', result);
    }
  }
}

// ─── Series Banner Widget ─────────────────────────────────────────────────────
class _SeriesBanner extends StatelessWidget {
  final InvoiceSeriesConfig config;
  const _SeriesBanner({required this.config});

  @override
  Widget build(BuildContext context) {
    final color = config.isSequential ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
            config.isSequential
                ? Icons.verified_rounded
                : Icons.edit_note_rounded,
            color: color,
            size: 16),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            config.isSequential
                ? 'Sequential Series Active — ${config.fyLabel}'
                : 'Manual Series — ${config.fyLabel}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            config.isSequential
                ? 'Format: ${config.formatNumber(config.startNumber)}, ${config.formatNumber(config.startNumber + 1)}, ... | Start: ${config.startNumber}'
                : 'Any invoice number accepted — no sequence validation',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ])),
      ]),
    );
  }
}
