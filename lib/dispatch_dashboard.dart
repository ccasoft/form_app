import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/step3.dart' show Step3EditPage;
import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Dispatch Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class DispatchDashboard extends StatefulWidget {
  const DispatchDashboard({super.key});
  @override
  State<DispatchDashboard> createState() => _DispatchDashboardState();
}

class _DispatchDashboardState extends State<DispatchDashboard> {
  final ApiService _fs = ApiService();
  List<InvoiceAcknowledgementData> _all = [];
  bool _loading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.dispatchDashboard, label: 'Dispatch Dashboard'));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _fs.getAllMasterInvoices();
    if (!mounted) return;
    setState(() {
      _all = all.where((inv) => inv.stage >= 3).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _loading = false;
    });
  }

  // Effective calendar day for an invoice — prefers dispatchDate (the actual
  // dispatch event), falling back to the record's timestamp. Same resolution
  // logic as _forDate below, so the calendar's badge counts line up exactly
  // with what tapping that day will show.
  DateTime? _effectiveDay(InvoiceAcknowledgementData inv) {
    if (inv.dispatchDate != null && inv.dispatchDate!.isNotEmpty) {
      try {
        final d = DateFormat('dd/MM/yyyy').parse(inv.dispatchDate!);
        return DateTime(d.year, d.month, d.day);
      } catch (_) {}
    }
    if (inv.timestamp > 0) {
      final ts = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
      return DateTime(ts.year, ts.month, ts.day);
    }
    return null;
  }

  // day key ('yyyy-MM-dd') -> number of dispatched invoices that day, so the
  // calendar can mark which dates actually have dispatch history instead of
  // making the user click through dates at random.
  Map<String, int> _computeDayCounts() {
    final counts = <String, int>{};
    for (final inv in _all) {
      final d = _effectiveDay(inv);
      if (d == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(d);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DispatchCalendarSheet(
        initialMonth: _selectedDate ?? DateTime.now(),
        selectedDate: _selectedDate,
        dayCounts: _computeDayCounts(),
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  List<InvoiceAcknowledgementData> get _forDate {
    if (_selectedDate == null) return [];
    final d = _selectedDate!;
    return _all.where((inv) {
      if (inv.dispatchDate != null && inv.dispatchDate!.isNotEmpty) {
        try {
          final parsed = DateFormat('dd/MM/yyyy').parse(inv.dispatchDate!);
          return parsed.year == d.year &&
              parsed.month == d.month &&
              parsed.day == d.day;
        } catch (_) {}
      }
      if (inv.timestamp > 0) {
        final ts = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
        return ts.year == d.year && ts.month == d.month && ts.day == d.day;
      }
      return false;
    }).toList();
  }

  Map<String, List<InvoiceAcknowledgementData>> _groupByTrip(
      List<InvoiceAcknowledgementData> invoices) {
    final map = <String, List<InvoiceAcknowledgementData>>{};
    for (final inv in invoices) {
      final key = inv.tripNumber.isNotEmpty ? inv.tripNumber : '(No Trip)';
      map.putIfAbsent(key, () => []).add(inv);
    }
    return Map.fromEntries(map.entries.toList()
      ..sort((a, b) {
        final aMax =
            a.value.map((i) => i.timestamp).reduce((x, y) => x > y ? x : y);
        final bMax =
            b.value.map((i) => i.timestamp).reduce((x, y) => x > y ? x : y);
        return bMax.compareTo(aMax);
      }));
  }

  @override
  Widget build(BuildContext context) {
    final forDate = _forDate;
    final grouped = _groupByTrip(forDate);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.stageDispatch,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dispatch Dashboard',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text(
            _selectedDate != null
                ? '${grouped.length} trips  ·  ${forDate.length} invoices'
                : 'Select a date to view dispatches',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75), fontSize: 10),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _buildDatePicker(),
              Expanded(
                child: _selectedDate == null
                    ? _buildDatePrompt()
                    : forDate.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                              itemCount: grouped.length,
                              itemBuilder: (_, i) {
                                final trip = grouped.keys.elementAt(i);
                                final invs = grouped[trip]!;
                                return _TripCard(
                                  tripNumber: trip,
                                  invoices: invs,
                                  onEdit: () => _editTrip(trip, invs),
                                  onPrint: () => _printTrip(trip, invs),
                                  onDelete: () => _deleteTrip(trip, invs),
                                );
                              },
                            ),
                          ),
              ),
            ]),
    );
  }

  Widget _buildDatePicker() {
    final hasDate = _selectedDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: hasDate
            ? AppTheme.stageDispatch.withValues(alpha: 0.10)
            : AppTheme.stageDispatch,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasDate
                  ? AppTheme.stageDispatch.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_month_rounded,
                color: hasDate ? AppTheme.stageDispatch : Colors.white,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasDate
                    ? DateFormat('EEEE, dd MMM yyyy').format(_selectedDate!)
                    : 'Select a date',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: hasDate ? AppTheme.stageDispatch : Colors.white,
                ),
              ),
              Text(
                hasDate
                    ? 'Showing all dispatches for this day  (tap to change)'
                    : 'Tap to pick dispatch date',
                style: TextStyle(
                  fontSize: 10,
                  color: hasDate
                      ? AppTheme.stageDispatch.withValues(alpha: 0.65)
                      : Colors.white70,
                ),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: hasDate ? AppTheme.stageDispatch : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hasDate ? 'Change' : 'Pick Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: hasDate ? Colors.white : AppTheme.stageDispatch,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDatePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.stageDispatch.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 48, color: AppTheme.stageDispatch),
          ),
          const SizedBox(height: 20),
          const Text('Select a Date',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Pick a dispatch date to see all trips and invoices for that day.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickDate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.stageDispatch,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.event_rounded),
            label: const Text('Choose Date', style: TextStyle(fontSize: 15)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.local_shipping_outlined,
            size: 56, color: AppTheme.stageDispatch.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(
          'No dispatches on ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text('Try a different date',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.edit_calendar_rounded,
              size: 16, color: AppTheme.stageDispatch),
          label: const Text('Change Date',
              style: TextStyle(color: AppTheme.stageDispatch)),
        ),
      ]),
    );
  }

  Future<void> _editTrip(
      String trip, List<InvoiceAcknowledgementData> invs) async {
    final ok = await AdminPin.verify(context, action: 'edit dispatch');
    if (!ok) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          Step3EditPage(tripNumber: trip, invoices: invs, onSaved: _load),
    ));
  }

  Future<void> _deleteTrip(
      String trip, List<InvoiceAcknowledgementData> invs) async {
    final pinOk = await AdminPin.verify(context, action: 'delete dispatch');
    if (!pinOk) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.red.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.delete_forever_rounded,
                color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Delete Trip #$trip?',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will revert ${invs.length} invoice${invs.length > 1 ? "s" : ""} back to Stage 2 (Packed).',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 15, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('This cannot be undone.',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red))),
                ]),
              ),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Delete Dispatch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = invs.map((i) => i.id).where((id) => id.isNotEmpty).toList();
    final ok = await ApiService().deleteDispatch(ids);
    if (ok) {
      Get.snackbar('Deleted', 'Trip #$trip reverted to Stage 2',
          backgroundColor: Colors.red, colorText: Colors.white);
      _load();
    } else {
      Get.snackbar('Error', 'Failed to delete dispatch. Try again.');
    }
  }

  void _printTrip(String trip, List<InvoiceAcknowledgementData> invs) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _TripPrintPage(tripNumber: trip, invoices: invs),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Trip Card
// ─────────────────────────────────────────────────────────────────────────────
class _TripCard extends StatefulWidget {
  final String tripNumber;
  final List<InvoiceAcknowledgementData> invoices;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;
  const _TripCard(
      {required this.tripNumber,
      required this.invoices,
      required this.onEdit,
      required this.onPrint,
      required this.onDelete});
  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animCtrl.forward() : _animCtrl.reverse();
  }

  String get _transport => widget.invoices.first.transportName;
  String get _route => widget.invoices.first.routeName ?? '';
  String get _vehicleNo => widget.invoices.first.vehicleNumber ?? '';
  String get _openingKm => widget.invoices.first.openingKm;
  String get _tripNo => widget.invoices.first.tripNumber;
  String get _lrNumber => widget.invoices.first.lrNumber;
  String get _lrDate => widget.invoices.first.lrDate;

  String get _dispatchDate {
    final d = widget.invoices.first.dispatchDate;
    if (d != null && d.isNotEmpty) return d;
    final ts =
        widget.invoices.map((i) => i.timestamp).reduce((a, b) => a > b ? a : b);
    if (ts == 0) return '';
    return DateFormat('dd/MM/yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Set<String> get _taggedIds {
    final ids = <String>{};
    for (final inv in widget.invoices) {
      for (final id in inv.selectedInvoicesIdList) {
        if (id != inv.id) ids.add(id);
      }
    }
    return ids;
  }

  List<InvoiceAcknowledgementData> get _topLevel {
    final tagged = _taggedIds;
    return widget.invoices.where((i) => !tagged.contains(i.id)).toList();
  }

  double get _totalAmt =>
      _topLevel.fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));
  int get _pendingAck => _topLevel.where((i) => i.stage == 3).length;
  int get _acked => _topLevel.where((i) => i.stage >= 4).length;
  int get _totalCases =>
      _topLevel.fold(0, (s, i) => s + (int.tryParse(i.totalCase) ?? 0));

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.stageDispatch;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Trip #$_tripNo',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.textPrimary)),
                      if (_dispatchDate.isNotEmpty)
                        Text(_dispatchDate,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary)),
                    ])),
                _ActionBtn(Icons.edit_rounded, 'Edit', color, widget.onEdit),
                const SizedBox(width: 6),
                _ActionBtn(Icons.picture_as_pdf_rounded, 'PDF',
                    AppTheme.primary, widget.onPrint),
                const SizedBox(width: 6),
                _ActionBtn(Icons.delete_forever_rounded, 'Delete', Colors.red,
                    widget.onDelete),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary, size: 22),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (_transport.isNotEmpty)
                  _InfoPill(Icons.local_shipping_rounded, _transport, color),
                if (_route.isNotEmpty)
                  _InfoPill(Icons.route_rounded, _route, AppTheme.stageAck),
                if (_vehicleNo.isNotEmpty)
                  _InfoPill(Icons.directions_car_rounded, _vehicleNo,
                      const Color(0xFF5C6BC0)),
                if (_lrNumber.isNotEmpty)
                  _InfoPill(Icons.confirmation_number_rounded, 'LR: $_lrNumber',
                      const Color(0xFF6D4C41)),
              ]),
              const SizedBox(height: 8),
              // ── Stats row: FIX — all children are Expanded ──────────
              Row(children: [
                Expanded(
                    child: _MiniStat('${_topLevel.length}', 'Inv',
                        Icons.receipt_long_rounded, color)),
                const SizedBox(width: 4),
                Expanded(
                    child: _MiniStat('$_totalCases', 'Cases',
                        Icons.inventory_2_rounded, const Color(0xFF7B52AB))),
                const SizedBox(width: 4),
                Expanded(
                    child: _MiniStat('$_pendingAck', 'Pend',
                        Icons.hourglass_top_rounded, AppTheme.warning)),
                const SizedBox(width: 4),
                Expanded(
                    child: _MiniStat("$_acked", "Ack'd",
                        Icons.check_circle_rounded, AppTheme.success)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('₹${_fmtAmt(_totalAmt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 14)),
                ),
              ]),
            ]),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnim,
          child: Column(children: [
            const Divider(height: 1, color: AppTheme.divider),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: color),
                      SizedBox(width: 6),
                      Text('Trip Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: color)),
                    ]),
                    const SizedBox(height: 10),
                    _DetailRow('Trip Number', '#$_tripNo'),
                    if (_transport.isNotEmpty)
                      _DetailRow('Transport', _transport),
                    if (_vehicleNo.isNotEmpty)
                      _DetailRow('Vehicle No.', _vehicleNo),
                    if (_route.isNotEmpty) _DetailRow('Route', _route),
                    if (_lrNumber.isNotEmpty)
                      _DetailRow('LR Number', _lrNumber),
                    if (_lrDate.isNotEmpty) _DetailRow('LR Date', _lrDate),
                    if (_openingKm.isNotEmpty)
                      _DetailRow('Opening KM', _openingKm),
                    if (_dispatchDate.isNotEmpty)
                      _DetailRow('Dispatch Date', _dispatchDate),
                    _DetailRow(
                        'Total Amount', '₹${_totalAmt.toStringAsFixed(2)}'),
                    _DetailRow('Invoices', '${_topLevel.length}'),
                    _DetailRow('Total Cases', '$_totalCases'),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(children: const [
                Expanded(
                    flex: 3,
                    child: Text('INVOICE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 3,
                    child: Text('PARTY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5))),
                Expanded(
                    flex: 2,
                    child: Text('AMOUNT',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5))),
                SizedBox(
                    width: 42,
                    child: Text('CASES',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5))),
              ]),
            ),
            ...widget.invoices.map((inv) => _DispatchInvoiceRow(inv: inv)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: AuthService.to.perms.canUpdate(ScreenKeys.dispatchDashboard) ? widget.onEdit : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: const BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Edit Trip',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onPrint,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('PDF Report',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: AuthService.to.perms.canDelete(ScreenKeys.dispatchDashboard) ? widget.onDelete : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Dispatch',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600))),
          const Text(': ',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary))),
        ]),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

/// FIXED: Uses Expanded + Flexible internally so it never overflows a Row
class _MiniStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _MiniStat(this.value, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text('$value $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Invoice row in the card expanded view
// ─────────────────────────────────────────────────────────────────────────────
class _DispatchInvoiceRow extends StatelessWidget {
  final InvoiceAcknowledgementData inv;
  const _DispatchInvoiceRow({required this.inv});
  @override
  Widget build(BuildContext context) {
    const rowColor = AppTheme.stageDispatch;
    final tagged = inv.selectedInvoicesIdList;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: rowColor.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                  color: rowColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
              flex: 3,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.invoiceNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                    if (inv.ewayBillNumber.isNotEmpty)
                      Text('E-way: ${inv.ewayBillNumber}',
                          style: const TextStyle(
                              fontSize: 9, color: AppTheme.textSecondary)),
                  ])),
          Expanded(
              flex: 3,
              child: Text(inv.partyName,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Expanded(
              flex: 2,
              child: Text('₹${inv.invoiceAmount}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: rowColor))),
          SizedBox(
              width: 42,
              child: Text(inv.totalCase.isNotEmpty ? inv.totalCase : '-',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppTheme.textSecondary))),
        ]),
        if (tagged.length > 1) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 3, children: [
            const _TaggedLabel(),
            ...tagged.map((t) => _TaggedChip(t)),
          ]),
        ],
      ]),
    );
  }
}

class _TaggedLabel extends StatelessWidget {
  const _TaggedLabel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF37474F).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('tagged:',
            style: TextStyle(
                fontSize: 8,
                color: Color(0xFF37474F),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      );
}

class _TaggedChip extends StatelessWidget {
  final String id;
  const _TaggedChip(this.id);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.stageDispatch.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border:
              Border.all(color: AppTheme.stageDispatch.withValues(alpha: 0.25)),
        ),
        child: Text(
          id.length > 8 ? '…${id.substring(id.length - 8)}' : id,
          style: const TextStyle(
              fontSize: 8,
              color: AppTheme.stageDispatch,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace'),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PDF Print Page
//  Layout:
//    PAGE HEADER  : Company name + "DISPATCH REPORT"
//    DISPATCH BOX : Trip #, Date, Total cases, Total amount
//    TRANSPORT BOX: Transport name, LR Number, LR Date, Vehicle, Route, KM
//    ─ repeated per entry ─
//    ENTRY CARD   : Party name (header), invoice numbers (tagged together),
//                   pack/loose/total cases, LR per entry
//    FOOTER       : Grand total
// ─────────────────────────────────────────────────────────────────────────────
class _TripPrintPage extends StatelessWidget {
  final String tripNumber;
  final List<InvoiceAcknowledgementData> invoices;
  const _TripPrintPage({required this.tripNumber, required this.invoices});

  String get _transport => invoices.first.transportName;
  String get _route => invoices.first.routeName ?? '';
  String get _vehicle => invoices.first.vehicleNumber ?? '';
  String get _openingKm => invoices.first.openingKm;
  String get _lrNumber => invoices.first.lrNumber;
  String get _lrDate => invoices.first.lrDate;

  String get _dispatchDate {
    final d = invoices.first.dispatchDate;
    if (d != null && d.isNotEmpty) return d;
    final ts = invoices.map((i) => i.timestamp).reduce((a, b) => a > b ? a : b);
    if (ts == 0) return '';
    return DateFormat('dd MMM yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  /// Groups invoices by LR number (same LR + same party = one consignment).
  /// Invoices with no LR number are each their own single-invoice group.
  /// Within each company the groups are sorted by party name then LR number.
  List<List<InvoiceAcknowledgementData>> get _invoiceGroups {
    final groups = <List<InvoiceAcknowledgementData>>[];
    final used = <String>{};

    // Build LR-keyed buckets: key = "partyId||lrNumber"
    final lrBuckets = <String, List<InvoiceAcknowledgementData>>{};
    for (final inv in invoices) {
      final lr = inv.lrNumber.trim();
      if (lr.isEmpty || lr == '0') {
        // No LR — standalone group
        if (!used.contains(inv.id)) {
          used.add(inv.id);
          groups.add([inv]);
        }
        continue;
      }
      final key = '${inv.partyId}||$lr';
      lrBuckets.putIfAbsent(key, () => []).add(inv);
    }

    // Convert LR buckets → groups (sorted by invoice number within group)
    for (final bucket in lrBuckets.values) {
      if (bucket.every((i) => used.contains(i.id))) continue;
      bucket.sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
      for (final i in bucket) used.add(i.id);
      groups.add(bucket);
    }

    // Sort groups: by company name, then party name, then LR number
    groups.sort((a, b) {
      final ca = a.first.companyName.toLowerCase();
      final cb = b.first.companyName.toLowerCase();
      final cc = ca.compareTo(cb);
      if (cc != 0) return cc;
      final pa = a.first.partyName.toLowerCase();
      final pb = b.first.partyName.toLowerCase();
      final pc = pa.compareTo(pb);
      if (pc != 0) return pc;
      return a.first.lrNumber.compareTo(b.first.lrNumber);
    });

    return groups;
  }

  // Use _invoiceGroups as single source of truth for totals
  // Cases = primary invoice only per group (tagged invoices share same boxes)
  int get _totalCases => _invoiceGroups.fold(
      0, (s, g) => s + (int.tryParse(g.first.totalCase) ?? 0));

  int get _topLevelCount => _invoiceGroups.length;

  double get _totalAmt => _invoiceGroups
      .expand((g) => g)
      .fold(0.0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    // Load Noto Sans — full Unicode including ₹ and —
    final notoRegular = await PdfGoogleFonts.notoSansRegular();
    final notoBold = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: notoRegular, bold: notoBold),
    );

    // ── Palette ───────────────────────────────────────────────────────
    final teal = PdfColor.fromInt(0xFF00796B);
    final tealLight = PdfColor.fromInt(0xFFE0F2F1);
    final tealBorder = PdfColor.fromInt(0xFFB2DFDB);
    final navy = PdfColor.fromInt(0xFF1C2340);
    final amber = PdfColor.fromInt(0xFFFFF8E1);
    final amberBorder = PdfColor.fromInt(0xFFFFB300);
    final brown = PdfColor.fromInt(0xFF5D4037);
    final rowAlt = PdfColor.fromInt(0xFFF9FAFB);
    final divClr = PdfColor.fromInt(0xFFCFD8DC);
    final compHdr =
        PdfColor.fromInt(0xFF37474F); // dark slate for company header

    // ── Helpers ───────────────────────────────────────────────────────
    pw.Widget infoCell(String lbl, String val,
        {PdfColor? vc, bool bold = false}) {
      return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(lbl,
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 1),
            pw.Text(val.isNotEmpty ? val : '—',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: vc ?? navy,
                )),
          ]);
    }

    // ── Build company-wise grouped data ───────────────────────────────
    // groups = list of (group) where group = [primary, ...tagged]
    final groups = _invoiceGroups;

    // Group the invoice-groups by company name, preserving order of first appearance
    final companyOrder = <String>[];
    final companyGroups = <String, List<List<InvoiceAcknowledgementData>>>{};
    for (final group in groups) {
      final company = group.first.companyName.isNotEmpty
          ? group.first.companyName
          : '(Unknown Company)';
      if (!companyGroups.containsKey(company)) {
        companyOrder.add(company);
        companyGroups[company] = [];
      }
      companyGroups[company]!.add(group);
    }

    // Per-company totals
    double companyAmt(String c) => companyGroups[c]!
        .expand((g) => g)
        .fold(0.0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));
    // Cases = primary invoice only per group (tagged invoices share same boxes)
    int companyCases(String c) => companyGroups[c]!
        .fold(0, (s, g) => s + (int.tryParse(g.first.totalCase) ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        header: (ctx) => pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          // ── Title row ───────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DISPATCH REPORT',
                        style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                            color: teal)),
                    pw.Text('Chhattisgarh C & F Agency Pvt Ltd',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: navy)),
                  ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey600)),
                    if (ctx.pageNumber > 1)
                      pw.Text('Page ${ctx.pageNumber}',
                          style: const pw.TextStyle(
                              fontSize: 7, color: PdfColors.grey600)),
                  ]),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Divider(color: teal, thickness: 1.5),
          pw.SizedBox(height: 5),

          // ── Trip summary box ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
                color: navy, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRIP #$tripNumber',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14)),
                      if (_dispatchDate.isNotEmpty)
                        pw.Text('Dispatch Date: $_dispatchDate',
                            style: const pw.TextStyle(
                                color: PdfColor.fromInt(0xB3FFFFFF),
                                fontSize: 8)),
                    ]),
                pw.Row(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                        color: teal, borderRadius: pw.BorderRadius.circular(3)),
                    child: pw.Text('$_totalCases Cases',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            '$_topLevelCount entr${_topLevelCount == 1 ? 'y' : 'ies'}',
                            style: const pw.TextStyle(
                                color: PdfColor.fromInt(0xB3FFFFFF),
                                fontSize: 8)),
                        pw.Text('₹${_totalAmt.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10)),
                      ]),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 5),

          // ── Trip-level vehicle/route/km details (no transport here — per invoice below) ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: tealLight,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: tealBorder, width: 0.6),
            ),
            child: pw.Row(children: [
              pw.Expanded(child: infoCell('Vehicle No.', _vehicle, bold: true)),
              if (_route.isNotEmpty)
                pw.Expanded(child: infoCell('Route', _route)),
              if (_openingKm.isNotEmpty)
                pw.Expanded(child: infoCell('Opening KM', _openingKm)),
              pw.Expanded(child: infoCell('Total Invoices', '$_topLevelCount')),
              pw.Expanded(
                  child: infoCell('Total Cases', '$_totalCases',
                      vc: teal, bold: true)),
              pw.Expanded(
                  child: infoCell(
                      'Total Amount', '₹${_totalAmt.toStringAsFixed(2)}',
                      vc: navy, bold: true)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: divClr),
          pw.SizedBox(height: 4),
        ]),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          int globalSeq = 0; // running invoice sequence number

          for (final company in companyOrder) {
            final cGroups = companyGroups[company]!;
            final cAmt = companyAmt(company);
            final cCases = companyCases(company);
            final cInvCount = cGroups.length;

            // ── Company header bar ─────────────────────────────────────
            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                color: compHdr,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(company,
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12)),
                  pw.Text(
                    '$cInvCount invoice${cInvCount > 1 ? 's' : ''}  ·  $cCases cases  ·  ₹${cAmt.toStringAsFixed(2)}',
                    style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xCCFFFFFF), fontSize: 8),
                  ),
                ],
              ),
            ));

            // ── Column header row ──────────────────────────────────────
            widgets.add(pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: tealLight,
                border: pw.Border.all(color: tealBorder, width: 0.5),
              ),
              child: pw.Row(children: [
                pw.SizedBox(width: 22),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('Invoice #',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 4,
                    child: pw.Text('Party',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 3,
                    child: pw.Text('Transport',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('LR No.',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('LR Date',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('Amount',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text('E-way Bill',
                        style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: teal))),
                pw.SizedBox(width: 36),
              ]),
            ));

            // ── Invoice rows ───────────────────────────────────────────
            for (int gi = 0; gi < cGroups.length; gi++) {
              globalSeq++;
              final group = cGroups[gi];
              final primary = group.first;
              final hasTagged = group.length > 1;
              final isAlt = gi % 2 == 1;

              // Aggregate cases
              // For tagged groups the physical boxes are shared — use primary invoice cases only
              final groupTotal = int.tryParse(primary.totalCase) ?? 0;
              final groupPack = int.tryParse(primary.packCase) ?? 0;
              final groupLoose = int.tryParse(primary.looseCase) ?? 0;

              // Party transport = partyData.transportName (falls back to invoice transportName)
              final partyTransport = primary.partyData.transportName.isNotEmpty
                  ? primary.partyData.transportName
                  : primary.transportName;

              // Amount — sum all in group
              final groupAmt = group.fold(
                  0.0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

              widgets.add(pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 1),
                decoration: pw.BoxDecoration(
                  color: isAlt ? rowAlt : PdfColors.white,
                  border: pw.Border.all(color: tealBorder, width: 0.4),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // ── Main invoice row ─────────────────────────────────
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              // Sequence number badge
                              pw.Container(
                                width: 18,
                                height: 18,
                                decoration: pw.BoxDecoration(
                                    color: teal,
                                    borderRadius: pw.BorderRadius.circular(2)),
                                alignment: pw.Alignment.center,
                                child: pw.Text('$globalSeq',
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.white)),
                              ),
                              pw.SizedBox(width: 4),
                              // Invoice number(s)
                              pw.Expanded(
                                  flex: 3,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(primary.invoiceNumber,
                                          style: pw.TextStyle(
                                              fontSize: 9,
                                              fontWeight: pw.FontWeight.bold,
                                              color: hasTagged ? brown : navy)),
                                      if (hasTagged)
                                        pw.Text('+${group.length - 1} more',
                                            style: pw.TextStyle(
                                                fontSize: 7,
                                                color: amberBorder,
                                                fontWeight:
                                                    pw.FontWeight.bold)),
                                    ],
                                  )),
                              // Party
                              pw.Expanded(
                                  flex: 4,
                                  child: pw.Text(primary.partyName,
                                      style: const pw.TextStyle(fontSize: 9))),
                              // Transport (party-assigned)
                              pw.Expanded(
                                  flex: 3,
                                  child: pw.Text(partyTransport,
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.grey700))),
                              // LR Number
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text(
                                      primary.lrNumber.isNotEmpty
                                          ? primary.lrNumber
                                          : '—',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: navy))),
                              // LR Date
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text(
                                      primary.lrDate.isNotEmpty
                                          ? primary.lrDate
                                          : '—',
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.grey700))),
                              // Amount
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text(
                                      '₹${groupAmt.toStringAsFixed(0)}',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight: pw.FontWeight.bold,
                                          color: navy))),
                              // E-way bill
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text(
                                      primary.ewayBillNumber.isNotEmpty
                                          ? primary.ewayBillNumber
                                          : '—',
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColors.grey600))),
                              // Cases badge
                              pw.Container(
                                width: 36,
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 3),
                                decoration: pw.BoxDecoration(
                                    color: tealLight,
                                    borderRadius: pw.BorderRadius.circular(3)),
                                alignment: pw.Alignment.center,
                                child: pw.Text('$groupTotal cs',
                                    style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                        color: teal)),
                              ),
                            ]),
                      ),

                      // ── Tagged sub-rows (only when > 1 invoice tagged) ────
                      if (hasTagged)
                        ...() {
                          final tagWidgets = <pw.Widget>[];
                          tagWidgets.add(pw.Container(
                            padding: const pw.EdgeInsets.fromLTRB(10, 3, 10, 2),
                            color: amber,
                            child: pw.Text(
                              '${group.length} invoices tagged together — dispatched as one consignment',
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                  color: brown),
                            ),
                          ));
                          // sub-header row
                          tagWidgets.add(pw.Container(
                            padding: const pw.EdgeInsets.fromLTRB(32, 3, 10, 3),
                            color: PdfColor.fromInt(0xFFFFF3E0),
                            child: pw.Row(children: [
                              pw.Expanded(
                                  flex: 3,
                                  child: pw.Text('Invoice #',
                                      style: pw.TextStyle(
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          color: brown))),
                              pw.Expanded(
                                  flex: 4,
                                  child: pw.Text('Party',
                                      style: pw.TextStyle(
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          color: brown))),
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text('Amount',
                                      style: pw.TextStyle(
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          color: brown))),
                              pw.Expanded(
                                  flex: 2,
                                  child: pw.Text('Cases',
                                      style: pw.TextStyle(
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          color: brown))),
                              pw.Expanded(
                                  flex: 3,
                                  child: pw.Text('E-way Bill',
                                      style: pw.TextStyle(
                                          fontSize: 7,
                                          fontWeight: pw.FontWeight.bold,
                                          color: brown))),
                            ]),
                          ));
                          for (int ti = 0; ti < group.length; ti++) {
                            final inv = group[ti];
                            tagWidgets.add(pw.Container(
                              padding:
                                  const pw.EdgeInsets.fromLTRB(32, 3, 10, 3),
                              color: ti % 2 == 0
                                  ? amber
                                  : PdfColor.fromInt(0xFFFFF8DC),
                              child: pw.Row(children: [
                                pw.Expanded(
                                    flex: 3,
                                    child: pw.Text(inv.invoiceNumber,
                                        style: pw.TextStyle(
                                            fontSize: 8,
                                            fontWeight: pw.FontWeight.bold,
                                            color: navy))),
                                pw.Expanded(
                                    flex: 4,
                                    child: pw.Text(inv.partyName,
                                        style:
                                            const pw.TextStyle(fontSize: 8))),
                                pw.Expanded(
                                    flex: 2,
                                    child: pw.Text('₹${inv.invoiceAmount}',
                                        style:
                                            const pw.TextStyle(fontSize: 8))),
                                pw.Expanded(
                                    flex: 2,
                                    child: pw.Text('${inv.totalCase} cs',
                                        style: pw.TextStyle(
                                            fontSize: 8,
                                            color: teal,
                                            fontWeight: pw.FontWeight.bold))),
                                pw.Expanded(
                                    flex: 3,
                                    child: pw.Text(
                                        inv.ewayBillNumber.isNotEmpty
                                            ? inv.ewayBillNumber
                                            : '—',
                                        style: const pw.TextStyle(
                                            fontSize: 7,
                                            color: PdfColors.grey600))),
                              ]),
                            ));
                          }
                          return tagWidgets;
                        }(),
                    ]),
              ));
            }

            // ── Company sub-total ──────────────────────────────────────
            widgets.add(pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const pw.EdgeInsets.only(bottom: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFECEFF1),
                border: pw.Border.all(color: divClr, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Sub-total ($company):  ',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: compHdr)),
                    pw.Text('$cCases cases  ·  ₹${cAmt.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: teal)),
                  ]),
            ));
          }

          // ── Grand Total ─────────────────────────────────────────────
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Divider(color: teal, thickness: 1));
          widgets.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
                color: navy, borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'GRAND TOTAL  —  $_topLevelCount entr${_topLevelCount == 1 ? 'y' : 'ies'}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11)),
                pw.Text(
                    '$_totalCases cases  ·  ₹${_totalAmt.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11)),
              ],
            ),
          ));

          return widgets;
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.stageDispatch,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Trip #$tripNumber  —  PDF Preview',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const Text('Company-wise  ·  Tagged invoices grouped',
              style: TextStyle(color: Colors.white70, fontSize: 9)),
        ]),
      ),
      body: PdfPreview(
        build: _buildPdf,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: 'Trip_${tripNumber}_dispatch.pdf',
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: PdfPageFormat.a4,
        actions: const [],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom dispatch-date calendar — a month grid (not the plain Material
//  date picker) so dates that actually have dispatch history stand out
//  (colored + a count badge) from empty dates, instead of clicking through
//  days at random to find dispatch history.
// ─────────────────────────────────────────────────────────────────────────────
class _DispatchCalendarSheet extends StatefulWidget {
  final DateTime initialMonth;
  final DateTime? selectedDate;
  final Map<String, int> dayCounts; // 'yyyy-MM-dd' -> dispatch count

  const _DispatchCalendarSheet({
    required this.initialMonth,
    required this.selectedDate,
    required this.dayCounts,
  });

  @override
  State<_DispatchCalendarSheet> createState() => _DispatchCalendarSheetState();
}

class _DispatchCalendarSheetState extends State<_DispatchCalendarSheet> {
  late DateTime _month; // first day of the visible month

  // Data only goes back to 2025 — don't let the calendar navigate to
  // earlier, guaranteed-empty months.
  static final DateTime _minMonth = DateTime(2025, 1);
  late final DateTime _maxMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    if (_month.isBefore(_minMonth)) _month = _minMonth;
    if (_month.isAfter(_maxMonth)) _month = _maxMonth;
  }

  int _countFor(DateTime day) =>
      widget.dayCounts[DateFormat('yyyy-MM-dd').format(day)] ?? 0;

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Monday-first grid (weekday: Mon=1..Sun=7)
    final leadingBlanks = firstOfMonth.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final tomorrow = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1));

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
          Center(
            child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2))),
          ),
          Row(children: [
            const Icon(Icons.calendar_month_rounded,
                color: AppTheme.stageDispatch, size: 18),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Select Dispatch Date',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              onPressed: _month.isAfter(_minMonth) ? () => _changeMonth(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(DateFormat('MMMM yyyy').format(_month),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            IconButton(
              onPressed: _month.isBefore(_maxMonth) ? () => _changeMonth(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          const SizedBox(height: 4),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                    child: Center(
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary)))))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 0.95),
            itemBuilder: (_, i) {
              final dayNum = i - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(_month.year, _month.month, dayNum);
              if (day.isAfter(tomorrow)) return const SizedBox.shrink();

              final count = _countFor(day);
              final hasData = count > 0;
              final isSelected = widget.selectedDate != null &&
                  day.year == widget.selectedDate!.year &&
                  day.month == widget.selectedDate!.month &&
                  day.day == widget.selectedDate!.day;
              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;

              return Padding(
                padding: const EdgeInsets.all(2),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.stageDispatch
                          : (hasData
                              ? AppTheme.stageDispatch.withValues(alpha: 0.12)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.stageDispatch, width: 1.2)
                          : (!hasData && !isSelected
                              ? Border.all(color: AppTheme.divider)
                              : null),
                    ),
                    child: Stack(children: [
                      Center(
                        child: Text('$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  hasData ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (hasData
                                      ? AppTheme.stageDispatch
                                      : AppTheme.textSecondary.withValues(alpha: 0.6)),
                            )),
                      ),
                      if (hasData)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : AppTheme.stageDispatch,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$count',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? AppTheme.stageDispatch
                                      : Colors.white,
                                )),
                          ),
                        ),
                    ]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            _legendDot(AppTheme.stageDispatch.withValues(alpha: 0.12),
                'Has dispatches', textColor: AppTheme.stageDispatch),
            const SizedBox(width: 16),
            _legendDot(Colors.transparent, 'No dispatches', bordered: true),
          ]),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label,
      {Color? textColor, bool bordered = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: bordered ? Border.all(color: AppTheme.divider) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: textColor ?? AppTheme.textSecondary,
              fontWeight: FontWeight.w600)),
    ]);
  }
}
