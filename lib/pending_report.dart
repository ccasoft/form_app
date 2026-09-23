import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Pending Report — Stage-wise pending invoice report
//  Filters: Company dropdown + invoice date range (from / to)
//  Shows: All 5 stages, each expandable, full invoice details per row
// ─────────────────────────────────────────────────────────────────────────────

class PendingReport extends StatefulWidget {
  const PendingReport({super.key});
  @override
  State<PendingReport> createState() => _PendingReportState();
}

class _PendingReportState extends State<PendingReport> {
  final _fs = ApiService();

  // ── Filter state ──────────────────────────────────────────────────────────
  List<CompanyData> _companies = [];
  String? _selCompanyId;
  DateTime? _fromDate;
  DateTime? _toDate;

  // ── Data state ────────────────────────────────────────────────────────────
  List<InvoiceAcknowledgementData> _invoices = [];
  bool _loading = true;
  bool _companiesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadReport();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadCompanies() async {
    final companies = await _fs.getCompanies();
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _companiesLoaded = true;
    });
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    List<InvoiceAcknowledgementData> invoices;
    if (_fromDate != null && _toDate != null) {
      invoices = await _fs.getMasterInvoicesByDateRange(_fromDate!, _toDate!);
    } else {
      invoices = await _fs.getAllMasterInvoices();
    }
    if (!mounted) return;
    setState(() {
      _invoices = invoices;
      _loading = false;
    });
  }

  // ── Filtered list (company + already date-filtered from server) ────────────
  List<InvoiceAcknowledgementData> get _filtered {
    var list = _invoices.where((i) => !i.isCancelled).toList();
    if (_selCompanyId != null) {
      final name = _companies
          .firstWhere((c) => c.companyId == _selCompanyId,
              orElse: () => CompanyData(
                  companyId: '', companyName: '', address: '', gstNumber: ''))
          .companyName;
      list = list.where((i) => i.companyName == name).toList();
    }
    return list;
  }

  List<InvoiceAcknowledgementData> _forStage(int stage) =>
      _filtered.where((i) => i.stage == stage).toList()
        ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

  double _totalAmt(List<InvoiceAcknowledgementData> list) =>
      list.fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
          child: child!),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
    });
    _loadReport();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
          child: child!),
    );
    if (picked == null) return;
    setState(() => _toDate = picked);
    _loadReport();
  }

  void _clearDates() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadReport();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.length;
    final totalAmt = _totalAmt(filtered);

    return Column(children: [
      // ── Header bar ────────────────────────────────────────────────────────
      Container(
        color: AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pending Report',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(
              _loading
                  ? 'Loading...'
                  : '$total invoices · ${_fmt(totalAmt)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ),

      // ── Filter bar ────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          // Company dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.divider),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selCompanyId,
                isExpanded: true,
                isDense: true,
                hint: const Text('All Companies',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Companies',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13))),
                  ..._companies.map((c) => DropdownMenuItem<String?>(
                      value: c.companyId,
                      child: Text(c.companyName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.fade))),
                ],
                onChanged: (v) => setState(() => _selCompanyId = v),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Date range row
          Row(children: [
            Expanded(child: _datePill('From', _fromDate, _pickFrom)),
            const SizedBox(width: 8),
            Expanded(child: _datePill('To', _toDate, _pickTo)),
            if (_fromDate != null || _toDate != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearDates,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200)),
                  child: Icon(Icons.close_rounded,
                      size: 17, color: Colors.red.shade400),
                ),
              ),
            ],
            const SizedBox(width: 8),
            // Refresh button
            GestureDetector(
              onTap: _loadReport,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3))),
                child: const Icon(Icons.refresh_rounded,
                    size: 17, color: AppTheme.primary),
              ),
            ),
          ]),
        ]),
      ),
      const Divider(height: 1, color: AppTheme.divider),

      // ── Body ──────────────────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                      children: [
                        // Summary strip
                        _summaryStrip(filtered),
                        const SizedBox(height: 12),
                        // One expandable card per stage
                        ...List.generate(5, (i) {
                          final stage = i + 1;
                          final stageInvs = _forStage(stage);
                          return _StageReportCard(
                            stage: stage,
                            invoices: stageInvs,
                            fmtAmt: _fmt,
                          );
                        }),
                      ],
                    ),
                  ),
      ),
    ]);
  }

  Widget _datePill(String label, DateTime? date, VoidCallback onTap) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasDate
              ? AppTheme.primary.withValues(alpha: 0.07)
              : Colors.white,
          border: Border.all(
              color: hasDate ? AppTheme.primary : AppTheme.divider,
              width: hasDate ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 14,
              color: hasDate ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              hasDate ? DateFormat('dd MMM yyyy').format(date) : label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      hasDate ? FontWeight.w700 : FontWeight.w500,
                  color:
                      hasDate ? AppTheme.primary : AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryStrip(List<InvoiceAcknowledgementData> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: List.generate(5, (i) {
          final s = i + 1;
          final c = _forStage(s).length;
          final color = AppStages.color(s);
          final labels = ['Invoice', 'Packing', 'Dispatch', 'Ack', 'Done'];
          return Expanded(
            child: Column(children: [
              Text('$c',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: c > 0 ? color : AppTheme.divider)),
              Text(labels[i],
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: c > 0 ? color : AppTheme.divider)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_rounded,
              size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          const Text('No invoices found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('Try changing the filters',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stage Report Card — collapsible, shows all invoices for one stage
// ─────────────────────────────────────────────────────────────────────────────

class _StageReportCard extends StatefulWidget {
  final int stage;
  final List<InvoiceAcknowledgementData> invoices;
  final String Function(double) fmtAmt;

  const _StageReportCard({
    required this.stage,
    required this.invoices,
    required this.fmtAmt,
  });

  @override
  State<_StageReportCard> createState() => _StageReportCardState();
}

class _StageReportCardState extends State<_StageReportCard> {
  bool _expanded = true;

  Color get _color => AppStages.color(widget.stage);
  IconData get _icon => AppStages.icon(widget.stage);
  String get _label => AppStages.label(widget.stage);

  double get _total => widget.invoices
      .fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  @override
  Widget build(BuildContext context) {
    if (widget.invoices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.divider)),
              child: Icon(_icon, color: AppTheme.divider, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Stage ${widget.stage} · $_label',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textSecondary)),
                const Text('No pending invoices',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('0',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary)),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                  color: _color.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Column(children: [
          // ── Stage header ─────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom:
                    _expanded ? Radius.zero : const Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(12),
                    bottom: _expanded
                        ? Radius.zero
                        : const Radius.circular(12)),
              ),
              child: Row(children: [
                // Stage icon badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: _color.withValues(alpha: 0.35))),
                  child: Icon(_icon, color: _color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Stage ${widget.stage} · $_label',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: _color)),
                    Text(widget.fmtAmt(_total),
                        style: TextStyle(
                            fontSize: 11,
                            color: _color.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _color.withValues(alpha: 0.3))),
                  child: Text('${widget.invoices.length}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _color)),
                ),
                const SizedBox(width: 8),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _color,
                    size: 20),
              ]),
            ),
          ),

          // ── Invoice rows ─────────────────────────────────────────────────
          if (_expanded) ...[
            // Column headers
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(children: [
                _hdr('Invoice / Party', flex: 3),
                _hdr('Date', flex: 2),
                _hdr('Amount', flex: 2, right: true),
              ]),
            ),
            const Divider(height: 1, color: AppTheme.divider, indent: 14, endIndent: 14),
            ...widget.invoices.map((inv) => _InvoiceDetailRow(
                inv: inv, color: _color, fmtAmt: widget.fmtAmt)),
            const SizedBox(height: 6),
          ],
        ]),
      ),
    );
  }

  Widget _hdr(String text, {int flex = 1, bool right = false}) => Expanded(
        flex: flex,
        child: Text(text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Invoice Detail Row — expandable to show LR, vehicle, dispatch, route
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceDetailRow extends StatefulWidget {
  final InvoiceAcknowledgementData inv;
  final Color color;
  final String Function(double) fmtAmt;

  const _InvoiceDetailRow({
    required this.inv,
    required this.color,
    required this.fmtAmt,
  });

  @override
  State<_InvoiceDetailRow> createState() => _InvoiceDetailRowState();
}

class _InvoiceDetailRowState extends State<_InvoiceDetailRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final color = widget.color;
    final amt = double.tryParse(inv.invoiceAmount) ?? 0;

    return Column(children: [
      // ── Summary row (always visible) ───────────────────────────────────
      InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Left accent bar
            Container(
                width: 3,
                height: 38,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            // Invoice + party
            Expanded(
              flex: 3,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Flexible(
                    child: Text(inv.invoiceNumber,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (inv.orderType.isNotEmpty &&
                      inv.orderType != 'regular') ...[
                    const SizedBox(width: 5),
                    _OrderBadge(inv.orderType),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(inv.partyName,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(inv.companyName,
                    style: TextStyle(
                        fontSize: 9,
                        color: color.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(inv.invoiceDate,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ),
            // Amount
            Expanded(
              flex: 2,
              child: Text(widget.fmtAmt(amt),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: color)),
            ),
            const SizedBox(width: 6),
            Icon(
                _open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppTheme.textSecondary),
          ]),
        ),
      ),

      // ── Detail panel (expanded) ────────────────────────────────────────
      if (_open)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            // Row 1: LR + Vehicle
            Row(children: [
              _detail('LR Number',
                  inv.lrNumber.isNotEmpty ? inv.lrNumber : '—'),
              _detail('LR Date',
                  inv.lrDate.isNotEmpty ? inv.lrDate : '—'),
              _detail('Vehicle',
                  inv.vehicleNumber?.isNotEmpty == true
                      ? inv.vehicleNumber!
                      : '—'),
            ]),
            const SizedBox(height: 8),
            // Row 2: Dispatch + Route + Trip
            Row(children: [
              _detail('Dispatch Date',
                  inv.dispatchDate?.isNotEmpty == true
                      ? inv.dispatchDate!
                      : '—'),
              _detail('Route',
                  inv.routeName?.isNotEmpty == true
                      ? inv.routeName!
                      : '—'),
              _detail('Trip No.',
                  inv.tripNumber.isNotEmpty ? inv.tripNumber : '—'),
            ]),
            const SizedBox(height: 8),
            // Row 3: Cases + Eway
            Row(children: [
              _detail('Pack / Loose / Total',
                  '${inv.packCase.isNotEmpty ? inv.packCase : "0"} / '
                  '${inv.looseCase.isNotEmpty ? inv.looseCase : "0"} / '
                  '${inv.totalCase.isNotEmpty ? inv.totalCase : "0"}'),
              _detail('Eway Bill',
                  inv.ewayBillNumber.isNotEmpty ? inv.ewayBillNumber : '—'),
              _detail('Transport',
                  inv.transportName.isNotEmpty ? inv.transportName : '—'),
            ]),
          ]),
        ),

      const Divider(
          height: 1, color: AppTheme.divider, indent: 14, endIndent: 14),
    ]);
  }

  Widget _detail(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Order badge (reused from pipeline_dashboard pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderBadge extends StatelessWidget {
  final String orderType;
  const _OrderBadge(this.orderType);

  Color get _c {
    switch (orderType) {
      case 'cold_chain': return const Color(0xFFC62828);
      case 'cool_chain': return const Color(0xFFE65100);
      case 'special':    return const Color(0xFFD4882A);
      default:           return AppTheme.success;
    }
  }

  String get _l {
    switch (orderType) {
      case 'cold_chain': return 'Cold';
      case 'cool_chain': return 'Cool';
      case 'special':    return 'Special';
      default:           return 'Reg';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: _c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _c.withValues(alpha: 0.4))),
        child: Text(_l,
            style: TextStyle(
                fontSize: 8, color: _c, fontWeight: FontWeight.bold)),
      );
}
