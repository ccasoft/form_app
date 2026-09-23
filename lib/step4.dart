import 'dart:typed_data';
import 'package:flutter/material.dart';
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
import 'package:form_app/year_month_filter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ─────────────────────────────────────────────────────────────────────────────
//  Helper: classify an invoice as Local (Raipur) or Upcountry
// ─────────────────────────────────────────────────────────────────────────────
bool _isLocal(InvoiceData inv) {
  final addr = inv.partyData.address.toLowerCase();
  final route = (inv.routeName ?? inv.partyData.routeName).toLowerCase();
  return addr.contains('raipur') || route.contains('raipur');
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 4 — Acknowledgement (tabbed: Local | Upcountry)
// ─────────────────────────────────────────────────────────────────────────────
class Step4 extends StatefulWidget {
  @override
  _Step4State createState() => _Step4State();
}

class _Step4State extends State<Step4> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<InvoiceData> invoices = [];
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  Map<int, Map<int, int>> _countMap = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step4, label: 'Acknowledgement'));
    _tabController = TabController(length: 2, vsync: this);
    _tabController
        .addListener(() => setState(() {})); // rebuild for badge colours
    _fetchInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    setState(() => isLoading = true);
    final fetched = await ApiService()
        .getInvoicesForAck(year: _selectedYear, month: _selectedMonth);
    final counts = await ApiService().getInvoiceCountMap(3);
    if (mounted)
      setState(() {
        invoices = fetched;
        _countMap = counts;
        isLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final localInvoices = invoices.where(_isLocal).toList();
    final upcountryInvoices = invoices.where((inv) => !_isLocal(inv)).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Acknowledgement',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Chhattisgarh C & F Agency Pvt Ltd',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        backgroundColor: AppTheme.stageAck,
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
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.folder_special_rounded,
                    size: 13, color: Colors.white),
                SizedBox(width: 4),
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
            child: const Text('Stage 4',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(
                child: _TabLabel(
              icon: Icons.location_city_rounded,
              label: 'Local',
              count: localInvoices.length,
              active: _tabController.index == 0,
            )),
            Tab(
                child: _TabLabel(
              icon: Icons.moving_rounded,
              label: 'Upcountry',
              count: upcountryInvoices.length,
              active: _tabController.index == 1,
            )),
          ],
        ),
      ),
      body: Column(children: [
        YearMonthFilter(
          color: AppTheme.stageAck,
          selectedYear: _selectedYear,
          selectedMonth: _selectedMonth,
          onYearChanged: (y) => setState(() {
            _selectedYear = y;
            _selectedMonth = null;
            _fetchInvoices();
          }),
          onMonthChanged: (m) => setState(() {
            _selectedMonth = m;
            _fetchInvoices();
          }),
          countMap: _countMap,
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _AckForm(
                      key: const ValueKey('local'),
                      invoices: localInvoices,
                      label: 'Local (Raipur)',
                      icon: Icons.location_city_rounded,
                      onSaved: _fetchInvoices,
                    ),
                    _AckForm(
                      key: const ValueKey('upcountry'),
                      invoices: upcountryInvoices,
                      label: 'Upcountry',
                      icon: Icons.moving_rounded,
                      onSaved: _fetchInvoices,
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab label with icon + badge
// ─────────────────────────────────────────────────────────────────────────────
class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  const _TabLabel(
      {required this.icon,
      required this.label,
      required this.count,
      required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15),
      const SizedBox(width: 5),
      Text(label),
      const SizedBox(width: 6),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? AppTheme.stageAck : Colors.white70,
            )),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Self-contained acknowledgement form (one per tab)
// ─────────────────────────────────────────────────────────────────────────────
class _AckForm extends StatefulWidget {
  final List<InvoiceData> invoices;
  final String label;
  final IconData icon;
  final VoidCallback onSaved;

  const _AckForm({
    Key? key,
    required this.invoices,
    required this.label,
    required this.icon,
    required this.onSaved,
  }) : super(key: key);

  @override
  _AckFormState createState() => _AckFormState();
}

class _AckFormState extends State<_AckForm> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // keep form state when switching tabs

  final _formKey = GlobalKey<FormState>();
  final _lrNumberCtrl = TextEditingController();
  final _lrDateCtrl = TextEditingController();
  final _packCaseCtrl = TextEditingController();
  final _looseCaseCtrl = TextEditingController();
  final _totalCaseCtrl = TextEditingController();
  final _openingKmCtrl = TextEditingController();
  final _tripNumberCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  Set<String> selectedInvoices = {};
  List<String> selectedInvoicesIdList = [];
  bool isSaving = false;

  // Photo capture (web-safe: use XFile, not dart:io File)
  XFile? _ackPhoto;
  bool _photoUploading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _lrDateCtrl.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _packCaseCtrl.addListener(_calcTotal);
    _looseCaseCtrl.addListener(_calcTotal);
  }

  @override
  void dispose() {
    _packCaseCtrl.removeListener(_calcTotal);
    _looseCaseCtrl.removeListener(_calcTotal);
    for (final c in [
      _lrNumberCtrl,
      _lrDateCtrl,
      _packCaseCtrl,
      _looseCaseCtrl,
      _totalCaseCtrl,
      _openingKmCtrl,
      _tripNumberCtrl,
      _remarksCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calcTotal() {
    final pack = int.tryParse(_packCaseCtrl.text) ?? 0;
    final loose = int.tryParse(_looseCaseCtrl.text) ?? 0;
    _totalCaseCtrl.text = (pack + loose).toString();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
              primary: AppTheme.stageAck, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) ctrl.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  void _onInvoiceSelected(InvoiceData inv) {
    setState(() {
      selectedInvoices.add(inv.invoiceNumber);
      selectedInvoicesIdList.add(inv.id);
      // Pre-fill dispatch details from invoice (from previous stages)
      if (_tripNumberCtrl.text.isEmpty)
        _tripNumberCtrl.text = inv.tripNumber ?? '';
      if (_openingKmCtrl.text.isEmpty)
        _openingKmCtrl.text = inv.openingKm ?? '';
      if (_lrNumberCtrl.text.isEmpty) _lrNumberCtrl.text = inv.lrNumber ?? '';
      if (_lrDateCtrl.text.isEmpty ||
          _lrDateCtrl.text ==
              DateFormat('dd-MM-yyyy')
                  .format(DateTime.now())) if (inv.lrDate != null &&
          inv.lrDate!.isNotEmpty) _lrDateCtrl.text = inv.lrDate!;
      if (_packCaseCtrl.text.isEmpty) _packCaseCtrl.text = inv.packCase ?? '';
      if (_looseCaseCtrl.text.isEmpty)
        _looseCaseCtrl.text = inv.looseCase ?? '';
      // totalCase will auto-calc from pack+loose via _calcTotal listener
    });
  }

  Future<void> _capturePhoto(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 55, // Compress at capture — good quality, much smaller
      maxWidth: 900, // Acknowledgement slips don't need full resolution
      maxHeight: 1200,
    );
    if (picked == null) return;
    setState(() => _ackPhoto = picked);
  }

  Future<void> _uploadAckPhoto() async {
    if (_ackPhoto == null || selectedInvoicesIdList.isEmpty) return;
    setState(() => _photoUploading = true);
    final invoiceNums = selectedInvoices.join('_');
    // Pass Uint8List bytes for web compatibility
    final bytes = await _ackPhoto!.readAsBytes();
    final ok = await ApiService().uploadAckPhotoBytes(
      invoiceIds: selectedInvoicesIdList,
      invoiceNumbers: invoiceNums,
      imageBytes: bytes,
      fileName: _ackPhoto!.name,
    );
    setState(() => _photoUploading = false);
    if (ok) {
      Get.snackbar('Photo Saved', 'Acknowledgement photo linked to invoices',
          backgroundColor: AppTheme.stageAck, colorText: Colors.white);
      setState(() => _ackPhoto = null);
    } else {
      Get.snackbar('Upload Failed', 'Could not upload photo — try again');
    }
  }

  void _showPhotoSourceSheet() {
    // On web, ImageSource.camera is not supported — offer Gallery only.
    if (kIsWeb) {
      _capturePhoto(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Acknowledgement Photo',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Photo will be compressed & stored with invoice number',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: _sourceBtn(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () {
                  Navigator.pop(context);
                  _capturePhoto(ImageSource.camera);
                },
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _sourceBtn(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _capturePhoto(ImageSource.gallery);
                },
              )),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _sourceBtn(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.stageAck.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.stageAck.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: AppTheme.stageAck, size: 28),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.stageAck)),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedInvoices.isEmpty) {
      Get.snackbar('Error', 'Please select at least one invoice');
      return;
    }
    setState(() => isSaving = true);
    final data = {
      'lrNumber': _lrNumberCtrl.text.trim(),
      'lrDate': _lrDateCtrl.text.trim(),
      'packCase': _packCaseCtrl.text.trim(),
      'looseCase': _looseCaseCtrl.text.trim(),
      'totalCase': _totalCaseCtrl.text.trim(),
      'tripNumber': _tripNumberCtrl.text.trim(),
      'openingKm': _openingKmCtrl.text.trim(),
      'remarks': _remarksCtrl.text.trim(),
      'ackType': widget.label, // 'Local (Raipur)' or 'Upcountry'
      'selectedInvoicesIdList': selectedInvoicesIdList,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final success = await ApiService().createAcknowledgement(data);
    setState(() => isSaving = false);
    if (success) {
      Get.snackbar('Saved!', '${widget.label} acknowledgement recorded',
          backgroundColor: AppTheme.stageAck, colorText: Colors.white);
      setState(() {
        selectedInvoices.clear();
        selectedInvoicesIdList.clear();
        _lrNumberCtrl.clear();
        _packCaseCtrl.clear();
        _looseCaseCtrl.clear();
        _totalCaseCtrl.clear();
        _tripNumberCtrl.clear();
        _openingKmCtrl.clear();
        _remarksCtrl.clear();
        _lrDateCtrl.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
        _ackPhoto = null;
      });
      widget.onSaved();
    } else {
      Get.snackbar('Error', 'Failed to save acknowledgement');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final color = AppTheme.stageAck;
    final available = widget.invoices
        .where((d) => !selectedInvoices.contains(d.invoiceNumber))
        .toList();

    return Builder(
        builder: (context) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                  12, 12, 12, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  // ── Type banner ──────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Icon(widget.icon, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.label == 'Local (Raipur)'
                              ? 'Local deliveries — Raipur address only'
                              : 'Upcountry deliveries — outside Raipur',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${widget.invoices.length} invoices',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ]),
                  ),

                  // ── Select invoices ──────────────────────────────────────────────
                  _buildCard(
                    title: 'Select Dispatched Invoices',
                    icon: Icons.receipt_long_rounded,
                    color: color,
                    children: [
                      widget.invoices.isEmpty
                          ? _emptyState()
                          : Autocomplete<InvoiceData>(
                              optionsBuilder: (tv) => tv.text.isEmpty
                                  ? available
                                  : available.where((d) =>
                                      d.invoiceNumber
                                          .toLowerCase()
                                          .contains(tv.text.toLowerCase()) ||
                                      d.partyData.partyName
                                          .toLowerCase()
                                          .contains(tv.text.toLowerCase())),
                              displayStringForOption: (o) =>
                                  '${o.invoiceNumber} - ${o.partyData.partyName}',
                              fieldViewBuilder: (ctx, tc, fn, _) =>
                                  TextFormField(
                                controller: tc,
                                focusNode: fn,
                                decoration: InputDecoration(
                                  labelText: 'Search ${widget.label} Invoice',
                                  prefixIcon: const Icon(Icons.search),
                                ),
                              ),
                              onSelected: _onInvoiceSelected,
                            ),
                      if (selectedInvoices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: selectedInvoices.map((inv) {
                            final d = widget.invoices
                                .cast<InvoiceData?>()
                                .firstWhere((d) => d?.invoiceNumber == inv,
                                    orElse: () => null);
                            return Chip(
                              avatar: d != null
                                  ? OrderTypeFlag(
                                      orderTypeKey: d.orderType,
                                      avatarOnly: true)
                                  : null,
                              label: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(inv,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  if (d != null)
                                    Text(
                                        '₹${d.invoiceAmount} · ${d.partyData.partyName}',
                                        style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() {
                                selectedInvoices.remove(inv);
                                if (d != null)
                                  selectedInvoicesIdList.remove(d.id);
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),

                  if (selectedInvoices.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    // ── Dispatch Details (fetched from Stage 3) ──────────────────
                    Builder(builder: (ctx) {
                      final first = widget.invoices
                          .cast<InvoiceData?>()
                          .firstWhere(
                              (inv) =>
                                  inv?.invoiceNumber == selectedInvoices.first,
                              orElse: () => null);
                      if (first == null) return const SizedBox.shrink();
                      final hasDetails =
                          (first.tripNumber?.isNotEmpty ?? false) ||
                              first.transportName.isNotEmpty ||
                              (first.vehicleNumber?.isNotEmpty ?? false) ||
                              (first.dispatchDate?.isNotEmpty ?? false);
                      if (!hasDetails) return const SizedBox.shrink();
                      return Column(children: [
                        _buildCard(
                          title: 'Dispatch Details (from Stage 3)',
                          icon: Icons.local_shipping_rounded,
                          color: AppTheme.stageDispatch,
                          children: [
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              if (first.tripNumber?.isNotEmpty ?? false)
                                _DispatchInfoChip(
                                    Icons.tag_rounded,
                                    'Trip #${first.tripNumber}',
                                    AppTheme.stageDispatch),
                              if (first.transportName.isNotEmpty)
                                _DispatchInfoChip(Icons.directions_car_rounded,
                                    first.transportName, AppTheme.stagePacking),
                              if (first.vehicleNumber?.isNotEmpty ?? false)
                                _DispatchInfoChip(
                                    Icons.pin_rounded,
                                    first.vehicleNumber!,
                                    const Color(0xFF5C6BC0)),
                              if (first.routeName?.isNotEmpty ?? false)
                                _DispatchInfoChip(Icons.route_rounded,
                                    first.routeName!, AppTheme.stageAck),
                              if (first.dispatchDate?.isNotEmpty ?? false)
                                _DispatchInfoChip(
                                    Icons.event_rounded,
                                    'Dispatched: ${first.dispatchDate}',
                                    const Color(0xFF6D4C41)),
                              if (first.openingKm?.isNotEmpty ?? false)
                                _DispatchInfoChip(
                                    Icons.speed_rounded,
                                    'KM: ${first.openingKm}',
                                    const Color(0xFF37474F)),
                              if (first.partyData.partyName.isNotEmpty)
                                _DispatchInfoChip(
                                    Icons.store_rounded,
                                    first.partyData.partyName,
                                    AppTheme.primary),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ]);
                    }),

                    // ── LR Details ───────────────────────────────────────────────
                    _buildCard(
                      title: 'LR Details',
                      icon: Icons.description_rounded,
                      color: color,
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextFormField(
                            controller: _lrNumberCtrl,
                            decoration: const InputDecoration(
                                labelText: 'LR Number *',
                                prefixIcon: Icon(Icons.pin_rounded)),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                            controller: _lrDateCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(_lrDateCtrl),
                            decoration: const InputDecoration(
                                labelText: 'LR Date *',
                                prefixIcon: Icon(Icons.calendar_today_rounded)),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          )),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Cases ────────────────────────────────────────────────────
                    _buildCard(
                      title: 'Cases',
                      icon: Icons.inventory_2_rounded,
                      color: color,
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextFormField(
                            controller: _packCaseCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Pack Cases',
                                prefixIcon: Icon(Icons.inventory_2_rounded)),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                            controller: _looseCaseCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Loose Cases',
                                prefixIcon: Icon(Icons.inbox_rounded)),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                            controller: _totalCaseCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Total Cases',
                              filled: true,
                              fillColor: Color(0xFFF5F6FA),
                            ),
                          )),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Trip Info ────────────────────────────────────────────────
                    _buildCard(
                      title: 'Trip Info',
                      icon: Icons.route_rounded,
                      color: color,
                      children: [
                        Row(children: [
                          Expanded(
                              child: TextFormField(
                            controller: _tripNumberCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Trip Number',
                                prefixIcon: Icon(Icons.tag_rounded)),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: TextFormField(
                            controller: _openingKmCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Opening KM',
                                prefixIcon: Icon(Icons.speed_rounded)),
                          )),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _remarksCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Remarks',
                              prefixIcon: Icon(Icons.notes_rounded)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Acknowledgement Photo ─────────────────────────────────────
                    _buildCard(
                      title: 'Acknowledgement Photo',
                      icon: Icons.photo_camera_rounded,
                      color: AppTheme.stageAck,
                      children: [
                        Text(
                          'Snap the signed acknowledgement slip for future reference. '
                          'Photo is compressed and stored against the invoice number.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        // Show already-saved photo from server if any selected invoice has one
                        Builder(builder: (ctx) {
                          final savedUrl = selectedInvoices.isNotEmpty
                              ? widget.invoices
                                  .cast<InvoiceData?>()
                                  .firstWhere(
                                    (d) =>
                                        d != null &&
                                        selectedInvoices
                                            .contains(d.invoiceNumber) &&
                                        (d.ackPhotoUrl?.isNotEmpty ?? false),
                                    orElse: () => null,
                                  )
                                  ?.ackPhotoUrl
                              : null;
                          if (savedUrl != null && _ackPhoto == null)
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 14, color: AppTheme.stageAck),
                                    const SizedBox(width: 6),
                                    Text('Photo already saved for this invoice',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.stageAck,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      savedUrl,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image_rounded,
                                                  size: 40,
                                                  color: Colors.grey.shade400),
                                              const SizedBox(height: 8),
                                              Text('Image not reachable',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .grey.shade500)),
                                              const SizedBox(height: 4),
                                              Text(savedUrl,
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          Colors.grey.shade400),
                                                  textAlign: TextAlign.center),
                                            ]),
                                      ),
                                      loadingBuilder: (_, child, progress) =>
                                          progress == null
                                              ? child
                                              : const SizedBox(
                                                  height: 200,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator())),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ]);
                          return const SizedBox.shrink();
                        }),
                        if (_ackPhoto != null) ...[
                          // Preview (web-safe using Image.memory with bytes)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FutureBuilder<Uint8List>(
                              future: _ackPhoto!.readAsBytes(),
                              builder: (ctx, snap) {
                                if (!snap.hasData)
                                  return const SizedBox(
                                      height: 200,
                                      child: Center(
                                          child: CircularProgressIndicator()));
                                return Image.memory(
                                  snap.data!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showPhotoSourceSheet,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retake'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.stageAck,
                                  side: BorderSide(color: AppTheme.stageAck),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _photoUploading ? null : _uploadAckPhoto,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.stageAck),
                                icon: _photoUploading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.cloud_upload_rounded,
                                        size: 16),
                                label: Text(_photoUploading
                                    ? 'Uploading...'
                                    : 'Upload Photo'),
                              ),
                            ),
                          ]),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _showPhotoSourceSheet,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.stageAck,
                                side: BorderSide(
                                    color: AppTheme.stageAck
                                        .withValues(alpha: 0.5)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.add_a_photo_rounded),
                              label: const Text('Capture / Select Photo',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Submit ───────────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: (isSaving || !AuthService.to.perms.canUpdate(ScreenKeys.step4)) ? null : _submit,
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.task_alt_rounded),
                        label: Text('Save ${widget.label} Acknowledgement',
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ]),
              ),
            ));
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(Icons.inbox_rounded,
              size: 40, color: AppTheme.stageAck.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            widget.label == 'Local (Raipur)'
                ? 'No Raipur invoices pending acknowledgement'
                : 'No upcountry invoices pending acknowledgement',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ]),
      );

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _DispatchInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _DispatchInfoChip(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}
