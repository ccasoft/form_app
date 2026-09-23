import 'package:form_app/admin_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/year_month_filter.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_app/step1.dart' show OrderTypeFlag;
import 'package:form_app/invoice_series_config.dart';
import 'package:form_app/invoice_register.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/permission_guard.dart';

// Shared by both ack-photo viewer dialogs below (list card + edit sheet) —
// downloads the photo and hands it to the OS share sheet, which lets the
// user save it to their gallery/files or send it on.
Future<void> _exportAckPhoto(
    BuildContext context, String photoUrl, String invoiceNumber) async {
  try {
    final filename =
        photoUrl.contains('/') ? photoUrl.split('/').last : photoUrl;
    final url = '${ApiService.baseUrl}/uploads/$filename';
    final res = await http
        .get(Uri.parse(url), headers: {'ngrok-skip-browser-warning': 'true'});
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw Exception('Photo not available');
    }
    final ext = filename.contains('.') ? filename.split('.').last : 'jpg';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/AckPhoto_$invoiceNumber.$ext');
    await file.writeAsBytes(res.bodyBytes);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Acknowledgement photo — $invoiceNumber');
  } catch (e) {
    Get.snackbar('Export Failed', 'Could not export the photo. Please try again.',
        backgroundColor: Colors.red.shade50, colorText: Colors.red.shade800);
  }
}

class InvoiceMasterManagement extends StatefulWidget {
  const InvoiceMasterManagement({super.key});
  @override
  State<InvoiceMasterManagement> createState() =>
      _InvoiceMasterManagementState();
}

class _InvoiceMasterManagementState extends State<InvoiceMasterManagement> {
  final ApiService _fs = ApiService();
  List<InvoiceAcknowledgementData> invoices = [];
  bool isLoading = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;
  Map<int, Map<int, int>> _countMap = {};

  @override
  void initState() {
    super.initState();
    // Guard against direct-URL / deep-link access on Flutter Web — hiding
    // the home-screen tile alone doesn't stop someone reaching this route
    // directly. If they can't view Masters, bounce them back out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AuthService.to.perms.canAccessMasters) {
        Get.offAllNamed('/');
        Get.snackbar('Not Allowed', "You don't have access to Invoice Master.",
            backgroundColor: Colors.orange.shade50,
            colorText: Colors.orange.shade800,
            snackPosition: SnackPosition.BOTTOM);
      }
    });
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => isLoading = true);
    final data = await _fs.getAllMasterInvoices(
        year: _selectedYear, month: _selectedMonth);
    final allData = await _fs.getAllMasterInvoices();
    final countMap = <int, Map<int, int>>{};
    for (final inv in allData) {
      final y = inv.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(inv.timestamp).year
          : 0;
      final m = inv.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(inv.timestamp).month
          : 0;
      if (y == 0) continue;
      countMap.putIfAbsent(y, () => {});
      countMap[y]![m] = (countMap[y]![m] ?? 0) + 1;
    }
    if (mounted)
      setState(() {
        invoices = data;
        _countMap = countMap;
        isLoading = false;
      });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadInvoices();
      return;
    }
    setState(() => _isSearching = true);
    final data = await _fs.getAllMasterInvoicesWithDebounce(query);
    if (mounted)
      setState(() {
        invoices = data;
        _isSearching = false;
      });
  }

  Future<void> _openEdit(InvoiceAcknowledgementData inv) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceEditSheet(invoice: inv, fs: _fs),
    );
    if (updated == true) _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Invoice Master'),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book_rounded),
              tooltip: 'Invoice Register',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoiceRegister()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.manage_search_rounded),
              tooltip: 'Find & Fix Hidden Invoices',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _GhostInvoiceFinder()),
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.list_alt_rounded), text: 'All Invoices'),
              Tab(icon: Icon(Icons.search_off_rounded), text: 'Missing Check'),
            ],
          ),
        ),
        body: TabBarView(
            children: [_buildInvoiceList(), const _MissingInvoiceTab()]),
      ),
    );
  }

  Widget _buildInvoiceList() {
    return Column(children: [
      Container(
        color: AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) {
            setState(() => _searchQuery = v);
            _search(v);
          },
          decoration: InputDecoration(
            hintText: 'Search by party, invoice number...',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _loadInvoices();
                    })
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.15),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      YearMonthFilter(
        color: AppTheme.primary,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        onYearChanged: (y) => setState(() {
          _selectedYear = y;
          _selectedMonth = null;
          _loadInvoices();
        }),
        onMonthChanged: (m) => setState(() {
          _selectedMonth = m;
          _loadInvoices();
        }),
        countMap: _countMap,
      ),
      if (isLoading || _isSearching)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (invoices.isEmpty)
        const Expanded(
            child: Center(
                child: Text('No invoices found',
                    style: TextStyle(color: AppTheme.textSecondary))))
      else
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: invoices.length,
          itemBuilder: (ctx, i) => _InvoiceCard(
            invoice: invoices[i],
            onEdit: () async {
              final ok = await AdminPin.verify(context, action: 'edit invoice');
              if (!ok) return;
              _openEdit(invoices[i]);
            },
            onVoid: () async {
              final inv = invoices[i];
              final ok =
                  await AdminPin.verify(context, action: 'cancel invoice');
              if (!ok) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.orange, size: 36),
                  title: const Text('Mark as Cancelled?',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice: ${inv.invoiceNumber}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${inv.companyName}  ·  ${inv.partyName}',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                            'This will move the invoice to Stage 5 (complete) with all fields auto-filled as "CANCELLED / 0 cases". '
                            'The invoice number is preserved in the series. This cannot be undone.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Go Back')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Yes, Mark Cancelled',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final ok2 = await _fs.voidInvoice(inv.id);
                if (ok2) {
                  _loadInvoices();
                  Get.snackbar('Invoice Cancelled',
                      '${inv.invoiceNumber} marked as cancelled. Series number preserved.',
                      backgroundColor: Colors.orange,
                      colorText: Colors.white,
                      duration: const Duration(seconds: 4));
                } else {
                  Get.snackbar(
                      'Error', 'Could not cancel invoice. Please try again.',
                      backgroundColor: AppTheme.danger,
                      colorText: Colors.white);
                }
              }
            },
            onDelete: () async {
              final ok =
                  await AdminPin.verify(context, action: 'delete invoice');
              if (!ok) return;
              final inv = invoices[i];
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: const Text('Delete Invoice'),
                  content: Text(
                      'Delete invoice "${inv.invoiceNumber}"?\n\nThis cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700))),
                  ],
                ),
              );
              if (confirm == true) {
                await _fs.deleteInvoiceMaster(inv.id);
                _loadInvoices();
                Get.snackbar('Deleted', 'Invoice ${inv.invoiceNumber} deleted.',
                    backgroundColor: AppTheme.danger, colorText: Colors.white);
              }
            },
          ),
        )),
    ]);
  }
}

// ─── Invoice Card ─────────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final InvoiceAcknowledgementData invoice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onVoid;
  const _InvoiceCard(
      {required this.invoice,
      required this.onEdit,
      required this.onDelete,
      required this.onVoid});

  @override
  Widget build(BuildContext context) {
    final cancelled = invoice.isCancelled;
    final stage = invoice.stage;
    final stageColor =
        cancelled ? Colors.grey.shade400 : AppStages.color(stage);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cancelled ? const Color(0xFFF8F8F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: cancelled ? 0.02 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
        border: Border(left: BorderSide(color: stageColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cancelled banner
          if (cancelled)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cancel_rounded,
                    size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Text('CANCELLED / NOT SUPPLIED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5)),
              ]),
            ),
          Row(children: [
            Expanded(
                child: Text(invoice.invoiceNumber,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            cancelled ? Colors.grey.shade500 : AppTheme.primary,
                        decoration:
                            cancelled ? TextDecoration.lineThrough : null))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stageColor.withValues(alpha: 0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(AppStages.icon(stage), size: 11, color: stageColor),
                const SizedBox(width: 4),
                Text(AppStages.label(stage),
                    style: TextStyle(
                        fontSize: 11,
                        color: stageColor,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 4),
            // Edit button (hidden for cancelled, and unless permitted)
            if (!cancelled && AuthService.to.perms.canUpdate(ScreenKeys.invoiceMasterManagement))
              Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: AppTheme.stageInvoice.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_rounded,
                          size: 16, color: AppTheme.stageInvoice),
                    ),
                  )),
            if (!cancelled && AuthService.to.perms.canUpdate(ScreenKeys.invoiceMasterManagement)) const SizedBox(width: 4),
            // Cancel / Void button — only on non-cancelled invoices, and unless permitted
            if (!cancelled && AuthService.to.perms.canUpdate(ScreenKeys.invoiceMasterManagement))
              Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onVoid,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.remove_circle_outline_rounded,
                          size: 16, color: Colors.orange),
                    ),
                  )),
            if (AuthService.to.perms.canUpdate(ScreenKeys.invoiceMasterManagement)) const SizedBox(width: 4),
            // Delete button — unless permitted
            if (AuthService.to.perms.canUpdate(ScreenKeys.invoiceMasterManagement))
              Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppTheme.danger),
                    ),
                  )),
          ]),
          const SizedBox(height: 6),
          if (invoice.orderType.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OrderTypeFlag(
                    orderTypeKey: invoice.orderType,
                    specialRemarks: invoice.specialRemarks)),
          Row(children: [
            const Icon(Icons.people_alt_rounded,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Expanded(
                child: Text(invoice.partyName,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary))),
            const SizedBox(width: 8),
            const Icon(Icons.business_rounded,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Flexible(
                child: Text(invoice.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.currency_rupee_rounded,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Expanded(
                child: Text('₹${invoice.invoiceAmount}',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success))),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(invoice.invoiceDate,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ]),
          if (invoice.ewayBillNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.document_scanner_rounded,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('E-way: ${invoice.ewayBillNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))),
            ]),
          ],
          if (invoice.routeName != null && invoice.routeName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.route_rounded,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(invoice.routeName!,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary))),
            ]),
          ],
          // ── Ack Photo indicator ─────────────────────────────────────────
          if (invoice.ackPhotoUrl != null &&
              invoice.ackPhotoUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showAckPhoto(context, invoice),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.stageAck.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.stageAck.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.photo_camera_rounded,
                      size: 14, color: AppTheme.stageAck),
                  const SizedBox(width: 6),
                  Text('View Acknowledgement Photo',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.stageAck,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new_rounded,
                      size: 12, color: AppTheme.stageAck),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  void _showAckPhoto(BuildContext context, InvoiceAcknowledgementData inv) {
    _showAckPhotoDialog(context, inv.ackPhotoUrl!, inv.invoiceNumber);
  }

  void _showAckPhotoDialog(
      BuildContext context, String photoUrl, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(children: [
              Icon(Icons.photo_camera_rounded,
                  color: AppTheme.stageAck, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Ack Photo — $invoiceNumber',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14))),
              IconButton(
                onPressed: () => _exportAckPhoto(context, photoUrl, invoiceNumber),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Export photo',
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ]),
          ),
          const Divider(height: 1),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: FutureBuilder<Uint8List>(
              future: () {
                // Support both old full URLs and new filename-only values
                // Always extract just the filename and rebuild with current base URL
                // This handles: old full ngrok URLs, new filename-only values
                final filename = photoUrl.contains('/')
                    ? photoUrl.split('/').last
                    : photoUrl;
                final url = '${ApiService.baseUrl}/uploads/$filename';
                return http.get(Uri.parse(url), headers: {
                  'ngrok-skip-browser-warning': 'true',
                }).then((r) => r.bodyBytes);
              }(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.stageAck)),
                  );
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_rounded,
                          size: 40, color: AppTheme.textSecondary),
                      SizedBox(height: 8),
                      Text('Could not load photo',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ]),
                  );
                }
                return Image.memory(snap.data!, fit: BoxFit.contain);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Edit Sheet ───────────────────────────────────────────────────────────────
class _InvoiceEditSheet extends StatefulWidget {
  final InvoiceAcknowledgementData invoice;
  final ApiService fs;
  const _InvoiceEditSheet({required this.invoice, required this.fs});
  @override
  State<_InvoiceEditSheet> createState() => _InvoiceEditSheetState();
}

class _InvoiceEditSheetState extends State<_InvoiceEditSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _rollingBack = false;

  late final TextEditingController _invNoCtrl;
  late final TextEditingController _invDateCtrl;
  late final TextEditingController _invAmountCtrl;
  late final TextEditingController _ewayCtrl;
  late final TextEditingController _validityCtrl;
  late final TextEditingController _lrNumberCtrl;
  late final TextEditingController _lrDateCtrl;
  late final TextEditingController _packCaseCtrl;
  late final TextEditingController _looseCaseCtrl;
  late final TextEditingController _totalCaseCtrl;
  late final TextEditingController _tripNumberCtrl;
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _dispatchDateCtrl;
  late final TextEditingController _openingKmCtrl;
  late final TextEditingController _chequeNoCtrl;
  late final TextEditingController _chequeDateCtrl;
  late final TextEditingController _chequeAmtCtrl;
  late final TextEditingController _bankNameCtrl;

  @override
  void initState() {
    super.initState();
    final inv = widget.invoice;
    _invNoCtrl = TextEditingController(text: inv.invoiceNumber);
    _invDateCtrl = TextEditingController(text: inv.invoiceDate);
    _invAmountCtrl = TextEditingController(text: inv.invoiceAmount);
    _ewayCtrl = TextEditingController(text: inv.ewayBillNumber);
    _validityCtrl = TextEditingController(text: inv.validityDate);
    _lrNumberCtrl = TextEditingController(text: inv.lrNumber);
    _lrDateCtrl = TextEditingController(text: inv.lrDate);
    _packCaseCtrl = TextEditingController(text: inv.packCase);
    _looseCaseCtrl = TextEditingController(text: inv.looseCase);
    _totalCaseCtrl = TextEditingController(text: inv.totalCase);
    _tripNumberCtrl = TextEditingController(text: inv.tripNumber);
    _vehicleCtrl = TextEditingController(text: inv.vehicleNumber ?? '');
    _dispatchDateCtrl = TextEditingController(text: inv.dispatchDate ?? '');
    _openingKmCtrl = TextEditingController(text: inv.openingKm);
    _chequeNoCtrl = TextEditingController(text: inv.chequeNumber ?? '');
    _chequeDateCtrl = TextEditingController(text: inv.chequeDate ?? '');
    _chequeAmtCtrl = TextEditingController(text: inv.chequeAmount ?? '');
    _bankNameCtrl = TextEditingController(text: inv.bankName ?? '');
    _packCaseCtrl.addListener(_calcTotal);
    _looseCaseCtrl.addListener(_calcTotal);
  }

  @override
  void dispose() {
    for (final c in [
      _invNoCtrl,
      _invDateCtrl,
      _invAmountCtrl,
      _ewayCtrl,
      _validityCtrl,
      _lrNumberCtrl,
      _lrDateCtrl,
      _packCaseCtrl,
      _looseCaseCtrl,
      _totalCaseCtrl,
      _tripNumberCtrl,
      _vehicleCtrl,
      _dispatchDateCtrl,
      _openingKmCtrl,
      _chequeNoCtrl,
      _chequeDateCtrl,
      _chequeAmtCtrl,
      _bankNameCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calcTotal() {
    final p = int.tryParse(_packCaseCtrl.text) ?? 0;
    final l = int.tryParse(_looseCaseCtrl.text) ?? 0;
    _totalCaseCtrl.text = (p + l).toString();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial;
    try {
      initial = DateFormat('dd-MM-yyyy').parse(ctrl.text);
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030));
    if (picked != null) ctrl.text = DateFormat('dd-MM-yyyy').format(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final inv = widget.invoice;
    final updates = <String, dynamic>{
      'invoiceNumber': _invNoCtrl.text.trim(),
      'invoiceDate': _invDateCtrl.text.trim(),
      'invoiceAmount': _invAmountCtrl.text.trim(),
      'ewayBillNumber': _ewayCtrl.text.trim(),
      'validityDate': _validityCtrl.text.trim(),
    };
    if (inv.stage >= 2) {
      updates.addAll({
        'lrNumber': _lrNumberCtrl.text.trim(),
        'lrDate': _lrDateCtrl.text.trim(),
        'packCase': _packCaseCtrl.text.trim(),
        'looseCase': _looseCaseCtrl.text.trim(),
        'totalCase': _totalCaseCtrl.text.trim(),
      });
    }
    if (inv.stage >= 3) {
      updates.addAll({
        'tripNumber': _tripNumberCtrl.text.trim(),
        'vehicleNumber': _vehicleCtrl.text.trim(),
        'dispatchDate': _dispatchDateCtrl.text.trim(),
        'openingKm': _openingKmCtrl.text.trim(),
      });
    }
    if (inv.stage >= 5) {
      updates.addAll({
        'chequeNumber': _chequeNoCtrl.text.trim(),
        'chequeDate': _chequeDateCtrl.text.trim(),
        'chequeAmount': _chequeAmtCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
      });
    }
    final ok = await widget.fs.updateInvoiceMaster(inv.id, updates);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Saved', 'Invoice ${_invNoCtrl.text} updated.',
          backgroundColor: AppTheme.success, colorText: Colors.white);
      Navigator.pop(context, true);
    } else {
      Get.snackbar('Error', 'Could not save. Please try again.',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  // ── Stage rollback ─────────────────────────────────────────────────────────
  // Deleting stage N clears that stage's fields and moves invoice back to N-1.
  // Deleting stage 1 removes the entire invoice document and blanks invoice number.
  Future<void> _rollbackStage(int stageToDelete) async {
    final inv = widget.invoice;

    // Require admin PIN before any stage deletion
    final pinOk = await AdminPin.verify(
      context,
      action:
          stageToDelete == 1 ? 'delete invoice' : 'delete stage $stageToDelete',
    );
    if (!pinOk) return;

    // Stage 1 delete = full invoice removal
    if (stageToDelete == 1) {
      final confirm = await _confirm(
        context,
        title: 'Delete Entire Invoice',
        message: 'This will permanently delete invoice "${inv.invoiceNumber}" '
            'and clear its invoice number. This cannot be undone.',
        confirmLabel: 'Delete Invoice',
        isDestructive: true,
      );
      if (confirm != true) return;
      setState(() => _rollingBack = true);
      final ok = await widget.fs.deleteInvoiceMaster(inv.id);
      if (!mounted) return;
      setState(() => _rollingBack = false);
      if (ok) {
        Get.snackbar(
            'Deleted', 'Invoice ${inv.invoiceNumber} has been deleted.',
            backgroundColor: AppTheme.danger, colorText: Colors.white);
        Navigator.pop(context, true);
      } else {
        Get.snackbar('Error', 'Could not delete. Please try again.',
            backgroundColor: AppTheme.danger, colorText: Colors.white);
      }
      return;
    }

    // Stage 2–5 delete = rollback fields + decrement stage
    final stageNames = {
      2: 'Packing',
      3: 'Dispatch',
      4: 'Acknowledgement',
      5: 'Cheque Collection'
    };
    final previousStage = stageToDelete - 1;
    final confirm = await _confirm(
      context,
      title: 'Delete Stage $stageToDelete — ${stageNames[stageToDelete]}',
      message: 'This will clear all Stage $stageToDelete data and move the '
          'invoice back to Stage $previousStage. This cannot be undone.',
      confirmLabel: 'Delete Stage $stageToDelete',
      isDestructive: true,
    );
    if (confirm != true) return;

    setState(() => _rollingBack = true);

    // If rolling back stage 2, 3, or 4 — delete ack photo file from server storage
    if (stageToDelete <= 4 && (inv.ackPhotoUrl?.isNotEmpty ?? false)) {
      await widget.fs.deleteAckPhoto(inv.id);
    }

    final Map<String, dynamic> rollbackUpdates = {'stage': previousStage};

    if (stageToDelete == 2) {
      rollbackUpdates.addAll({
        'lrNumber': '',
        'lrDate': '',
        'packCase': '',
        'looseCase': '',
        'totalCase': '',
        'tripNumber': '',
        'vehicleNumber': null,
        'dispatchDate': null,
        'openingKm': '',
        'routeName': null,
        'chequeNumber': null,
        'chequeDate': null,
        'chequeAmount': null,
        'bankName': null,
        'ackDone': false,
        'ackPhotoUrl': null,
        'ackTimestamp': null,
        'chequeTimestamp': null,
      });
    } else if (stageToDelete == 3) {
      rollbackUpdates.addAll({
        'tripNumber': '',
        'vehicleNumber': null,
        'dispatchDate': null,
        'openingKm': '',
        'routeName': null,
        'chequeNumber': null,
        'chequeDate': null,
        'chequeAmount': null,
        'bankName': null,
        'ackDone': false,
        'ackPhotoUrl': null,
        'ackTimestamp': null,
        'chequeTimestamp': null,
      });
    } else if (stageToDelete == 4) {
      rollbackUpdates.addAll({
        'ackDone': false, // reset so invoice reappears in Stage 4 queue
        'ackPhotoUrl': null,
        'ackTimestamp': null,
        'chequeNumber': null,
        'chequeDate': null,
        'chequeAmount': null,
        'bankName': null,
        'chequeTimestamp': null,
      });
    } else if (stageToDelete == 5) {
      rollbackUpdates.addAll({
        'chequeNumber': null,
        'chequeDate': null,
        'chequeAmount': null,
        'bankName': null,
        'chequeTimestamp': null,
      });
    }

    final ok = await widget.fs.updateInvoiceMaster(inv.id, rollbackUpdates);
    if (!mounted) return;
    setState(() => _rollingBack = false);
    if (ok) {
      Get.snackbar(
        'Stage $stageToDelete Removed',
        'Invoice moved back to Stage $previousStage.',
        backgroundColor: AppTheme.warning,
        colorText: Colors.white,
      );
      Navigator.pop(context, true);
    } else {
      Get.snackbar('Error', 'Could not rollback. Please try again.',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: isDestructive ? AppTheme.danger : AppTheme.warning,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800))),
          ]),
          content:
              Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDestructive ? AppTheme.danger : AppTheme.warning,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final stage = inv.stage;
    final stageColor = AppStages.color(stage);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Form(
          key: _formKey,
          child: Column(children: [
            // Drag handle
            Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2))),
            // Header bar
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                  color: AppTheme.tabBarBg,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Edit Invoice',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white)),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: stageColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(AppStages.label(stage),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: stageColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(inv.invoiceNumber,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9FA8DA)))),
                      ]),
                    ])),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppTheme.mastersBtnBg,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mastersBtnText)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),

            // ── Scrollable form ──────────────────────────────────────────────
            Expanded(
                child: AbsorbPointer(
              absorbing: _rollingBack,
              child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  children: [
                    // ── STAGE 1 — Invoice Details ───────────────────────────────
                    _StageSection(
                      stageNumber: 1,
                      title: 'Invoice Details',
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.stageInvoice,
                      currentStage: stage,
                      onDeleteStage:
                          _rollingBack ? null : () => _rollbackStage(1),
                      child: Column(children: [
                        _field(
                            _invNoCtrl, 'Invoice Number *', Icons.tag_rounded,
                            required: true),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child:
                                  _dateField(_invDateCtrl, 'Invoice Date *')),
                          const SizedBox(width: 8),
                          Expanded(
                              child:
                                  _dateField(_validityCtrl, 'Validity Date')),
                        ]),
                        const SizedBox(height: 8),
                        _field(_invAmountCtrl, 'Invoice Amount *',
                            Icons.currency_rupee_rounded,
                            required: true, numeric: true),
                        const SizedBox(height: 8),
                        _field(_ewayCtrl, 'E-way Bill No.',
                            Icons.document_scanner_rounded),
                        const SizedBox(height: 4),
                        // Read-only party/company info
                        _readOnlyRow(
                            Icons.people_alt_rounded, 'Party', inv.partyName),
                        const SizedBox(height: 4),
                        _readOnlyRow(
                            Icons.business_rounded, 'Company', inv.companyName),
                      ]),
                    ),

                    // ── STAGE 2 — Packing ───────────────────────────────────────
                    const SizedBox(height: 12),
                    _StageSection(
                      stageNumber: 2,
                      title: 'Packing',
                      icon: Icons.inventory_2_rounded,
                      color: AppTheme.stagePacking,
                      currentStage: stage,
                      onDeleteStage: (stage >= 2 && !_rollingBack)
                          ? () => _rollbackStage(2)
                          : null,
                      child: stage >= 2
                          ? Column(children: [
                              Row(children: [
                                Expanded(
                                    child: _dateField(_lrDateCtrl, 'LR Date')),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(_lrNumberCtrl, 'LR Number',
                                        Icons.numbers_rounded)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: _field(_packCaseCtrl, 'Pack Cases',
                                        Icons.inventory_2_rounded,
                                        numeric: true)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(_looseCaseCtrl, 'Loose Cases',
                                        Icons.inventory_rounded,
                                        numeric: true)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(_totalCaseCtrl, 'Total',
                                        Icons.summarize_rounded,
                                        readOnly: true)),
                              ]),
                            ])
                          : null,
                    ),

                    // ── STAGE 3 — Dispatch ──────────────────────────────────────
                    const SizedBox(height: 12),
                    _StageSection(
                      stageNumber: 3,
                      title: 'Dispatch',
                      icon: Icons.local_shipping_rounded,
                      color: AppTheme.stageDispatch,
                      currentStage: stage,
                      onDeleteStage: (stage >= 3 && !_rollingBack)
                          ? () => _rollbackStage(3)
                          : null,
                      child: stage >= 3
                          ? Column(children: [
                              Row(children: [
                                Expanded(
                                    child: _field(_tripNumberCtrl,
                                        'Trip Number', Icons.numbers_rounded)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(
                                        _vehicleCtrl,
                                        'Vehicle Number',
                                        Icons.directions_car_rounded)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: _dateField(
                                        _dispatchDateCtrl, 'Dispatch Date')),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(_openingKmCtrl, 'Opening KM',
                                        Icons.speed_rounded,
                                        numeric: true)),
                              ]),
                              if (inv.routeName != null &&
                                  inv.routeName!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _readOnlyRow(Icons.route_rounded, 'Route',
                                    inv.routeName!),
                              ],
                              if (inv.transportName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _readOnlyRow(Icons.local_shipping_rounded,
                                    'Transport', inv.transportName),
                              ],
                            ])
                          : null,
                    ),

                    // ── STAGE 4 — Acknowledgement ───────────────────────────────
                    const SizedBox(height: 12),
                    _StageSection(
                      stageNumber: 4,
                      title: 'Acknowledgement',
                      icon: Icons.task_alt_rounded,
                      color: AppTheme.stageAck,
                      currentStage: stage,
                      onDeleteStage: (stage >= 4 && !_rollingBack)
                          ? () => _rollbackStage(4)
                          : null,
                      child: stage >= 4
                          ? Column(children: [
                              if (inv.ackPhotoUrl != null &&
                                  inv.ackPhotoUrl!.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: GestureDetector(
                                    onTap: () => _viewAckPhoto(context,
                                        inv.ackPhotoUrl!, inv.invoiceNumber),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: AppTheme.stageAck
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppTheme.stageAck
                                                .withValues(alpha: 0.35)),
                                      ),
                                      child: Row(children: [
                                        Icon(Icons.photo_camera_rounded,
                                            size: 14, color: AppTheme.stageAck),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                              'Tap to view acknowledgement photo',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.stageAck,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        Icon(Icons.open_in_new_rounded,
                                            size: 12, color: AppTheme.stageAck),
                                      ]),
                                    ),
                                  ),
                                )
                              else
                                _readOnlyRow(Icons.check_circle_rounded,
                                    'Status', 'Acknowledged — no photo'),
                            ])
                          : null,
                    ),

                    // ── STAGE 5 — Cheque Collection ─────────────────────────────
                    const SizedBox(height: 12),
                    _StageSection(
                      stageNumber: 5,
                      title: 'Cheque Collection',
                      icon: Icons.payments_rounded,
                      color: AppTheme.stageCheque,
                      currentStage: stage,
                      onDeleteStage: (stage >= 5 && !_rollingBack)
                          ? () => _rollbackStage(5)
                          : null,
                      child: stage >= 5
                          ? Column(children: [
                              Row(children: [
                                Expanded(
                                    child: _field(_chequeNoCtrl,
                                        'Cheque Number', Icons.tag_rounded)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _dateField(
                                        _chequeDateCtrl, 'Cheque Date')),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: _field(
                                        _chequeAmtCtrl,
                                        'Cheque Amount',
                                        Icons.currency_rupee_rounded,
                                        numeric: true)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _field(_bankNameCtrl, 'Bank Name',
                                        Icons.account_balance_rounded)),
                              ]),
                            ])
                          : null,
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 15,
                            color: AppTheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text(
                          'Tap the delete icon on any stage to roll back to the previous stage. '
                          'Deleting Stage 1 removes the entire invoice.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              height: 1.5),
                        )),
                      ]),
                    ),
                  ]),
            )),

            // ── Bottom action bar ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _rollingBack) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving
                      ? 'Saving...'
                      : _rollingBack
                          ? 'Processing...'
                          : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.stageInvoice,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _viewAckPhoto(
      BuildContext context, String photoUrl, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(children: [
              Icon(Icons.photo_camera_rounded,
                  color: AppTheme.stageAck, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Ack Photo — $invoiceNumber',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14))),
              IconButton(
                onPressed: () => _exportAckPhoto(context, photoUrl, invoiceNumber),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Export photo',
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ]),
          ),
          const Divider(height: 1),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: FutureBuilder<Uint8List>(
              future: () {
                // Support both old full URLs and new filename-only values
                // Always extract just the filename and rebuild with current base URL
                // This handles: old full ngrok URLs, new filename-only values
                final filename = photoUrl.contains('/')
                    ? photoUrl.split('/').last
                    : photoUrl;
                final url = '${ApiService.baseUrl}/uploads/$filename';
                return http.get(Uri.parse(url), headers: {
                  'ngrok-skip-browser-warning': 'true',
                }).then((r) => r.bodyBytes);
              }(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.stageAck)),
                  );
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image_rounded,
                          size: 40, color: AppTheme.textSecondary),
                      SizedBox(height: 8),
                      Text('Could not load photo',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ]),
                  );
                }
                return Image.memory(snap.data!, fit: BoxFit.contain);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _readOnlyRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
          Expanded(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textPrimary))),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, bool numeric = false, bool readOnly = false}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters:
          numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(
          color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    );
  }

  Widget _dateField(TextEditingController ctrl, String label) {
    return GestureDetector(
      onTap: () => _pickDate(ctrl),
      child: AbsorbPointer(
          child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16),
          suffixIcon: const Icon(Icons.edit_calendar_rounded,
              size: 15, color: AppTheme.textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      )),
    );
  }
}

// ─── Stage Section Widget ─────────────────────────────────────────────────────
// Shows a stage card: header with stage number, title, status badge, and
// optional delete button. If child is null the stage is shown as "not reached".
class _StageSection extends StatelessWidget {
  final int stageNumber;
  final String title;
  final IconData icon;
  final Color color;
  final int currentStage;
  final VoidCallback? onDeleteStage;
  final Widget? child; // null = not yet reached

  const _StageSection({
    required this.stageNumber,
    required this.title,
    required this.icon,
    required this.color,
    required this.currentStage,
    required this.onDeleteStage,
    required this.child,
  });

  bool get _reached => currentStage >= stageNumber;
  bool get _isCurrent => currentStage == stageNumber;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        _reached ? color : AppTheme.textSecondary.withValues(alpha: 0.35);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _reached ? color.withValues(alpha: 0.3) : AppTheme.divider,
          width: _isCurrent ? 1.5 : 1,
        ),
        boxShadow: _reached
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Section header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: _reached
                ? color.withValues(alpha: 0.06)
                : const Color(0xFFF8F8F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            // Stage number circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _reached
                    ? color
                    : AppTheme.textSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                  child: Text('$stageNumber',
                      style: TextStyle(
                          color:
                              _reached ? Colors.white : AppTheme.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13))),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: activeColor),
            const SizedBox(width: 7),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _reached ? color : AppTheme.textSecondary))),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _reached
                    ? (_isCurrent
                        ? color.withValues(alpha: 0.15)
                        : AppTheme.success.withValues(alpha: 0.12))
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _reached
                      ? (_isCurrent
                          ? color.withValues(alpha: 0.4)
                          : AppTheme.success.withValues(alpha: 0.3))
                      : AppTheme.divider,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _reached
                      ? (_isCurrent
                          ? Icons.radio_button_checked_rounded
                          : Icons.check_circle_rounded)
                      : Icons.radio_button_unchecked_rounded,
                  size: 10,
                  color: _reached
                      ? (_isCurrent ? color : AppTheme.success)
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _reached ? (_isCurrent ? 'Current' : 'Done') : 'Pending',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _reached
                          ? (_isCurrent ? color : AppTheme.success)
                          : AppTheme.textSecondary),
                ),
              ]),
            ),
            // Delete / rollback button — only shown when stage is reached
            if (_reached) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: stageNumber == 1
                    ? 'Delete entire invoice'
                    : 'Rollback to Stage ${stageNumber - 1}',
                child: InkWell(
                  onTap: onDeleteStage,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.25)),
                    ),
                    child: Icon(
                      stageNumber == 1
                          ? Icons.delete_forever_rounded
                          : Icons.undo_rounded,
                      size: 15,
                      color: AppTheme.danger,
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
        // ── Section body ────────────────────────────────────────────────────
        if (child != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), child: child)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text('Not yet reached',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic)),
            ]),
          ),
      ]),
    );
  }
}

// ─── Missing Invoice Tab ──────────────────────────────────────────────────────
// Two-phase loading:
//   Phase 1 (fast): fetch only series configs → show summary cards immediately
//   Phase 2 (lazy): user taps a company → load that company's invoices on demand
class _MissingInvoiceTab extends StatefulWidget {
  const _MissingInvoiceTab();
  @override
  State<_MissingInvoiceTab> createState() => _MissingInvoiceTabState();
}

class _MissingInvoiceTabState extends State<_MissingInvoiceTab> {
  final _fs = ApiService();
  List<InvoiceSeriesConfig> _configs = [];
  // Stores the highest invoice number seen for each config id (parallel-fetched)
  Map<String, int> _maxMap = {};
  bool _loading = true;
  String? _loadError;
  int _selectedFY = InvoiceSeriesConfig.financialYearOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  // Phase 1: fetch configs + max invoice number per company.
  // Uses the FAST getMaxInvoiceNumber (single Firestore query, limit 50)
  // instead of loading all invoice numbers. The full number set is only
  // fetched in Phase 2 when the user opens the detail sheet.
  Future<void> _loadConfigs() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // ONE round trip — returns series configs + max invoice number per series
      final data = await _fs.getSeriesConfigsWithMax(_selectedFY);

      final configs = <InvoiceSeriesConfig>[];
      final maxMap = <String, int>{};

      for (final m in data) {
        final cfg = InvoiceSeriesConfig.fromMap(m['id'] as String, m);
        configs.add(cfg);
        maxMap[cfg.id] = (m['maxNum'] as num?)?.toInt() ?? 0;
      }

      if (mounted)
        setState(() {
          _configs = configs;
          _maxMap = maxMap;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
    }
  }

  // Phase 2: load detail for one series and show bottom sheet
  Future<void> _openDetail(InvoiceSeriesConfig cfg) async {
    // Pass sibling series for same company so detail sheet can compute
    // a proper upper bound per individual series (fixes Medley 3-series bug).
    final siblings = _configs
        .where((c) => c.companyId == cfg.companyId && c.id != cfg.id)
        .toList();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MissingDetailSheet(
          fs: _fs, config: cfg, fy: _selectedFY, siblingConfigs: siblings),
    );
    // Refresh max numbers after closing (user may have added invoices)
    _loadConfigs();
  }

  // Build list grouped by company — each company shows all its series
  Widget _buildGroupedList() {
    // Group configs by companyName (fall back to companyId if name is missing)
    final grouped = <String, List<InvoiceSeriesConfig>>{};
    for (final c in _configs) {
      final key = c.companyName.isNotEmpty ? c.companyName : c.companyId;
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final companies = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      itemCount: companies.length,
      itemBuilder: (_, i) {
        final company = companies[i];
        final series = grouped[company]!;
        // Single series: show flat card with company name visible
        if (series.length == 1) {
          return _MissingSummaryCard(
            config: series.first,
            lastNumber: _maxMap[series.first.id] ?? 0,
            onTap: () => _openDetail(series.first),
            showSeriesLabel: true,
          );
        }
        // Multiple series: show a grouped company card
        return _CompanySeriesGroup(
          companyName: company,
          series: series,
          maxMap: _maxMap,
          onTap: _openDetail,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Data only goes back to FY 2025 — don't offer earlier, empty years.
    final fyStart =
        DateTime.now().year - 2 < 2025 ? 2025 : DateTime.now().year - 2;
    final fyOptions = List.generate(5, (i) => fyStart + i);
    return Column(children: [
      // FY selector
      Container(
        color: AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Financial Year',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                children: fyOptions.map((y) {
              final next = (y + 1).toString().substring(2);
              final active = y == _selectedFY;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedFY = y);
                  _loadConfigs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text('FY $y–$next',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? AppTheme.primary : Colors.white)),
                ),
              );
            }).toList()),
          ),
        ]),
      ),
      // Body
      Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? _buildError()
                  : _configs.isEmpty
                      ? _buildNoConfigs()
                      : RefreshIndicator(
                          onRefresh: _loadConfigs,
                          child: _buildGroupedList(),
                        )),
    ]);
  }

  Widget _buildError() => Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 40),
          const SizedBox(height: 12),
          const Text('Failed to load series config',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(_loadError!,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _loadConfigs,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      ));

  Widget _buildNoConfigs() => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.settings_suggest_rounded,
              size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('No sequential series configured',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Configure sequential invoice series for each company under '
            'Masters → Invoice Series to automatically track missing numbers.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
          ),
        ]),
      ));
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
class _MissingSummaryCard extends StatelessWidget {
  final InvoiceSeriesConfig config;
  final int lastNumber; // 0 = none yet
  final VoidCallback onTap;
  final bool showSeriesLabel;
  const _MissingSummaryCard({
    required this.config,
    required this.lastNumber,
    required this.onTap,
    this.showSeriesLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final first = config.formatNumber(config.startNumber);
    final last = lastNumber > 0 ? config.formatNumber(lastNumber) : null;
    final seriesLabel = config.seriesName != 'Default'
        ? '${config.fyLabel}  ·  ${config.seriesName}'
        : config.fyLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.business_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          // Text info — all inside a single Expanded so nothing can overflow
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Company name — hidden when inside a company group header
                if (showSeriesLabel)
                  Text(
                      config.companyName.isNotEmpty
                          ? config.companyName
                          : config.companyId,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                if (showSeriesLabel) const SizedBox(height: 3),
                // FY + series label
                Text(seriesLabel,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                        fontSize: showSeriesLabel ? 11 : 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary.withValues(alpha: 0.9))),
                const SizedBox(height: 5),
                // First / Last on separate lines — guarantees full visibility
                Text('First: $first',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(last != null ? 'Last:  $last' : 'Last:  —',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: last != null
                            ? AppTheme.primary.withValues(alpha: 0.85)
                            : AppTheme.textSecondary)),
              ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.primary.withValues(alpha: 0.45), size: 20),
        ]),
      ),
    );
  }
}

// ─── Company Series Group (multi-series companies) ────────────────────────────
class _CompanySeriesGroup extends StatefulWidget {
  final String companyName;
  final List<InvoiceSeriesConfig> series;
  final Map<String, int> maxMap;
  final void Function(InvoiceSeriesConfig) onTap;
  const _CompanySeriesGroup({
    required this.companyName,
    required this.series,
    required this.maxMap,
    required this.onTap,
  });
  @override
  State<_CompanySeriesGroup> createState() => _CompanySeriesGroupState();
}

class _CompanySeriesGroupState extends State<_CompanySeriesGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Company header ──
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.business_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.companyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.fade),
                    Text('${widget.series.length} series configured',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600)),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${widget.series.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ),
              const SizedBox(width: 8),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 20),
            ]),
          ),
        ),
        // ── Series rows ──
        if (_expanded)
          ...widget.series.map((cfg) {
            final lastNum = widget.maxMap[cfg.id] ?? 0;
            return Column(children: [
              const Divider(
                  height: 1,
                  color: AppTheme.divider,
                  indent: 14,
                  endIndent: 14),
              _MissingSummaryCard(
                config: cfg,
                lastNumber: lastNum,
                onTap: () => widget.onTap(cfg),
                showSeriesLabel: false,
              ),
            ]);
          }).toList(),
      ]),
    );
  }
}

// ─── Detail Bottom Sheet (loads invoices for one company on demand) ───────────
class _MissingDetailSheet extends StatefulWidget {
  final ApiService fs;
  final InvoiceSeriesConfig config;
  final int fy;

  /// Other series for the same company — used to bound this series's number
  /// range so multi-series companies (e.g. Medley with 3 series) don't bleed
  /// into each other during gap detection.
  final List<InvoiceSeriesConfig> siblingConfigs;
  const _MissingDetailSheet(
      {required this.fs,
      required this.config,
      required this.fy,
      this.siblingConfigs = const []});
  @override
  State<_MissingDetailSheet> createState() => _MissingDetailSheetState();
}

class _MissingDetailSheetState extends State<_MissingDetailSheet> {
  bool _loading = true;
  String? _error;
  String? _warning;
  List<String> _missing = [];
  int _totalMissingCount = 0;
  int _entered = 0;
  int _maxNum = 0;
  int _minNum = 0; // actual first entered invoice number

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = widget.config;

      // Compute upper bound from sibling series with same prefix
      final samePrefixSiblings = widget.siblingConfigs
          .where(
              (s) => s.prefix == cfg.prefix && s.startNumber > cfg.startNumber)
          .map((s) => s.startNumber)
          .toList();
      final upperBound = samePrefixSiblings.isEmpty
          ? null
          : (samePrefixSiblings.reduce((a, b) => a < b ? a : b) - 1);

      // Server does the gap detection — no Flutter loop needed
      final result = await widget.fs.getMissingInvoiceNumbers(
        cfg.companyId,
        widget.fy,
        cfg.prefix,
        startNumber: cfg.startNumber,
        upperBound: upperBound,
      );

      final missingNums = result['missing'] as List<int>;
      final missing = missingNums.map((n) => cfg.formatNumber(n)).toList();
      final serverWarning = result['warning'] as String?;

      if (mounted)
        setState(() {
          _missing = missing;
          _totalMissingCount = result['total'] as int;
          _entered = result['entered'] as int;
          _maxNum = result['maxNum'] as int;
          _minNum = result['minNum'] as int? ?? cfg.startNumber;
          _warning = serverWarning;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final hasMissing = _totalMissingCount > 0;
    final statusColor = hasMissing ? AppTheme.danger : AppTheme.success;
    final displayStart = _minNum > 0 ? _minNum : cfg.startNumber;
    final totalRange = _maxNum > 0 ? (_maxNum - displayStart + 1) : 0;
    final coverage = totalRange > 0 ? _entered / totalRange : 1.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2))),
          // Header
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppTheme.tabBarBg,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search_off_rounded,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        cfg.companyName.isNotEmpty
                            ? cfg.companyName
                            : cfg.companyId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.fade),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (cfg.seriesName != 'Default') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(cfg.seriesName,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(cfg.fyLabel,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9FA8DA))),
                    ]),
                  ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Close',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          // Body
          Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_error != null && _maxNum == 0)
                      ? Center(
                          child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppTheme.danger, size: 36),
                            const SizedBox(height: 10),
                            const Text('Could not load invoice data',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_error!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry')),
                          ]),
                        ))
                      : ListView(
                          controller: ctrl,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                          children: [
                            // Warning banner for bad series config
                            if (_warning != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          Colors.orange.withValues(alpha: 0.4)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(_warning!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w600))),
                                ]),
                              ),
                            ],
                            // Stats row
                            Row(children: [
                              _DetailStatTile(
                                value: '$_entered',
                                label: 'Entered',
                                color: AppTheme.success,
                                icon: Icons.check_circle_rounded,
                              ),
                              const SizedBox(width: 8),
                              _DetailStatTile(
                                value: _totalMissingCount < 0
                                    ? '0'
                                    : '$_totalMissingCount',
                                label: 'Missing',
                                color: AppTheme.danger,
                                icon: Icons.remove_circle_rounded,
                              ),
                              const SizedBox(width: 8),
                              _DetailStatTile(
                                value: '$totalRange',
                                label: 'Total Range',
                                color: AppTheme.primary,
                                icon: Icons.format_list_numbered_rounded,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            // Progress bar
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(
                                        hasMissing
                                            ? Icons.warning_amber_rounded
                                            : Icons.check_circle_rounded,
                                        size: 15,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        hasMissing
                                            ? '$_totalMissingCount invoice${_totalMissingCount > 1 ? "s" : ""} missing'
                                            : 'All invoices accounted for',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor),
                                      ),
                                      const Spacer(),
                                      Text(
                                          '${(coverage * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor)),
                                    ]),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: coverage,
                                        backgroundColor: AppTheme.danger
                                            .withValues(alpha: 0.12),
                                        color: AppTheme.success,
                                        minHeight: 8,
                                      ),
                                    ),
                                    if (_maxNum > 0) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Range: ${cfg.formatNumber(displayStart)} → ${cfg.formatNumber(_maxNum)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ]),
                            ),
                            // Missing numbers
                            if (_missing.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.danger
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Icon(Icons.search_off_rounded,
                                            color: AppTheme.danger, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(
                                                'Missing Invoice Numbers',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: AppTheme.danger))),
                                        if (_totalMissingCount > 500) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.danger
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '500+',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.danger,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ]),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: _missing
                                            .map((inv) => Container(
                                                  padding: const EdgeInsets
                                                          .symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.danger
                                                        .withValues(
                                                            alpha: 0.07),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    border: Border.all(
                                                        color: AppTheme.danger
                                                            .withValues(
                                                                alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .remove_circle_outline_rounded,
                                                            size: 11,
                                                            color: AppTheme
                                                                .danger),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(inv,
                                                            style: const TextStyle(
                                                                color: AppTheme
                                                                    .danger,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 12)),
                                                      ]),
                                                ))
                                            .toList(),
                                      ),
                                    ]),
                              ),
                            ],
                            if (!hasMissing && _maxNum > 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppTheme.success, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                    'All invoices from ${cfg.formatNumber(displayStart)} to '
                                    '${cfg.formatNumber(_maxNum)} are accounted for.',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4),
                                  )),
                                ]),
                              ),
                            ],
                            if (_maxNum == 0) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.15)),
                                ),
                                child: const Row(children: [
                                  Icon(Icons.inbox_rounded,
                                      color: AppTheme.textSecondary, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                    'No invoices have been entered yet for this series.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                        height: 1.4),
                                  )),
                                ]),
                              ),
                            ],
                          ],
                        )),
        ]),
      ),
    );
  }
}

class _DetailStatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _DetailStatTile(
      {required this.value,
      required this.label,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 18, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
        ]),
      ));
}

// ─── Ghost Invoice Finder ─────────────────────────────────────────────────────
// Finds invoices that exist in Firestore (so they block re-creation) but are
// invisible in the normal list because they lack a 'timestamp' field.
// Allows viewing full data and optionally deleting so the number can be re-used.
class _GhostInvoiceFinder extends StatefulWidget {
  const _GhostInvoiceFinder();
  @override
  State<_GhostInvoiceFinder> createState() => _GhostInvoiceFinderState();
}

class _GhostInvoiceFinderState extends State<_GhostInvoiceFinder> {
  final _fs = ApiService();
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.ghostInvoiceFinder, label: 'Find & Fix Hidden Invoices'));
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _searched = false;
    });
    try {
      final docs = <Map<String, dynamic>>[];

      // Search via API
      final r = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/invoices/master?search=${Uri.encodeComponent(query)}'),
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        for (final d in (data['data'] as List)) {
          final m = d as Map<String, dynamic>;
          final invNo = (m['invoiceNumber'] as String? ?? '').trim();
          final docId = m['id'] as String? ?? m['docId'] as String? ?? '';
          // Check exact match on invoiceNumber or doc ID segments
          bool isMatch = invNo == query;
          if (!isMatch && docId.isNotEmpty) {
            final segs = docId.split('_');
            if (segs.length >= 3) {
              final middle = segs.sublist(1, segs.length - 1).join('_');
              if (middle == query) isMatch = true;
            }
          }
          if (isMatch) docs.add({...m, 'id': docId});
        }
      }

      // Sort: ghost docs (no invoiceTimestamp) first, then newest
      docs.sort((a, b) {
        final aTs = (a['invoiceTimestamp'] ?? a['timestamp'] ?? 0) as num;
        final bTs = (b['invoiceTimestamp'] ?? b['timestamp'] ?? 0) as num;
        if (aTs == 0 && bTs != 0) return -1;
        if (bTs == 0 && aTs != 0) return 1;
        return bTs.compareTo(aTs);
      });

      setState(() {
        _results = docs;
        _searched = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _searched = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text(
          'This will permanently delete invoice "${doc['invoiceNumber']}" '
          '(Doc ID: ${doc['id']}).\n\n'
          'After deletion you can re-enter this invoice number.\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Require admin PIN
    final pinOk = await AdminPin.verify(context, action: 'delete invoice');
    if (pinOk != true) return;

    try {
      await http
          .delete(Uri.parse('${ApiService.baseUrl}/invoices/${doc['id']}'));
      Get.snackbar('Deleted',
          'Invoice "${doc['invoiceNumber']}" removed — you can now re-enter it.',
          backgroundColor: AppTheme.success, colorText: Colors.white);
      setState(() => _results.removeWhere((d) => d['id'] == doc['id']));
    } catch (e) {
      Get.snackbar('Error', 'Delete failed: $e',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Find & Fix Hidden Invoices'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(children: [
        // Explanation banner
        Container(
          width: double.infinity,
          color: const Color(0xFFFFF3CD),
          padding: const EdgeInsets.all(14),
          child: const Text(
            '⚠️  If an invoice shows "already exists" but is invisible in the list, '
            'it\'s a hidden (ghost) invoice — it was saved without a timestamp field. '
            'Search by invoice number below to find and optionally delete it so it can be re-entered.',
            style: TextStyle(
                fontSize: 12.5, color: Color(0xFF856404), height: 1.5),
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter invoice number to search…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        // Results
        Expanded(
          child: !_searched
              ? const Center(
                  child: Text('Search for an invoice number above',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : _results.isEmpty
                  ? const Center(
                      child: Text('No invoices found with that number',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final doc = _results[i];
                        final ts = (doc['invoiceTimestamp'] ??
                            doc['timestamp'] ??
                            0) as num;
                        final isGhost = ts == 0;
                        final stage = (doc['stage'] as num?)?.toInt() ?? 1;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isGhost
                                  ? AppTheme.danger.withValues(alpha: 0.5)
                                  : Colors.grey.shade200,
                              width: isGhost ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    if (isGhost) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: AppTheme.danger,
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: const Text('GHOST',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              doc['invoiceNumber'] as String? ??
                                                  '—',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15)),
                                          Builder(builder: (ctx) {
                                            // Show the invoice number extracted from doc ID
                                            final segs = (doc['id'] as String)
                                                .split('_');
                                            final fromId = segs.length >= 3
                                                ? segs
                                                    .sublist(1, segs.length - 1)
                                                    .join('_')
                                                : doc['id'];
                                            final fieldNo = doc['invoiceNumber']
                                                    as String? ??
                                                '';
                                            if (fromId != fieldNo) {
                                              return Text(
                                                  'Doc ID number: $fromId',
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.w600));
                                            }
                                            return const SizedBox.shrink();
                                          }),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppStages.color(stage)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('Stage $stage',
                                          style: TextStyle(
                                              color: AppStages.color(stage),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  _infoRow(Icons.store_rounded,
                                      doc['partyName'] as String? ?? '—'),
                                  _infoRow(Icons.business_rounded,
                                      doc['companyName'] as String? ?? '—'),
                                  _infoRow(Icons.calendar_today_rounded,
                                      doc['invoiceDate'] as String? ?? '—'),
                                  _infoRow(Icons.receipt_rounded,
                                      '₹${doc['invoiceAmount'] ?? '—'}'),
                                  _infoRow(Icons.vpn_key_rounded,
                                      'Doc ID: ${doc['id']}'),
                                  if (isGhost) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      '⚠ No timestamp — this invoice is invisible in normal lists but blocks re-entry.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _showFullData(doc),
                                          icon: const Icon(
                                              Icons.visibility_rounded,
                                              size: 14),
                                          label: const Text('View Full Data'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.primary,
                                            side: const BorderSide(
                                                color: AppTheme.primary),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            textStyle:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (AuthService.to.perms.canDelete(ScreenKeys.ghostInvoiceFinder))
                                        ElevatedButton.icon(
                                          onPressed: () => _delete(doc),
                                          icon: const Icon(Icons.delete_rounded,
                                              size: 14),
                                          label: const Text('Delete'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.danger,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            textStyle:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ]),
                                ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textPrimary))),
        ]),
      );

  void _showFullData(Map<String, dynamic> doc) {
    final entries = doc.entries
        .where((e) => e.key != 'id')
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Invoice ${doc['invoiceNumber']}'),
        content: SingleChildScrollView(
            child: SelectableText(entries,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }
}
