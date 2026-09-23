import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/invoice_series_config.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Pipeline Dashboard — Two Toggle Screens
//
//  Screen 1 (All Time): Stage counts, pie-style bars, company breakdown,
//                        local/outstation split, party breakdown, cheque stats
//  Screen 2 (Filtered): Year/Month/Week/Day filter + detail breakdown
// ─────────────────────────────────────────────────────────────────────────────
class PipelineDashboard extends StatefulWidget {
  const PipelineDashboard({super.key});
  @override
  State<PipelineDashboard> createState() => _PipelineDashboardState();
}

class _PipelineDashboardState extends State<PipelineDashboard>
    with SingleTickerProviderStateMixin {
  final _fs = ApiService();
  late final TabController _tabCtrl;

  // ── Dashboard tab (Screen 1) — year/month filter, default = current month
  // (kept narrow on purpose so the page opens fast; "All Time" is one tap
  // away via the global selection bar). ───────────────────────────────────
  List<InvoiceAcknowledgementData> _allInvoices = [];
  bool _allLoading = true;
  int? _dashYear = DateTime.now().year;
  int? _dashMonth = DateTime.now().month;
  String _viewMode = 'company'; // Company Wise section: 'company' | 'party'

  // Stage Distribution drill-down: tap a stage → companies → parties → invoices
  int? _dashDrillStage;
  String? _dashDrillCompany;
  String? _dashDrillParty;

  List<CompanyData> _companies = [];

  // Stage 6 (Telecalling) — orthogonal to the 1-5 `stage` field: only
  // invoices at stage >= 3 whose orderType needs a delivery-confirmation
  // call. Loaded separately and filtered by the same year/month as the
  // rest of the Dashboard tab.
  List<InvoiceData> _telecallInvoices = [];
  bool _telecallLoading = true;

  // ── Cheque stats (global, all-time — unaffected by the dashboard filter)
  int _chequePending = 0;
  int _chequeCollected = 0;
  Map<int, int> _chequePendingByStage = {};

  // ── Pulse tab (Screen 2) — its own independent all-time dataset, loaded
  // lazily the first time the tab is opened (keeps the Dashboard tab's
  // initial page-open fast). ────────────────────────────────────────────────
  bool _pulseInitialized = false;
  List<InvoiceAcknowledgementData> _pulseInvoices = [];
  bool _pulseInvoicesLoading = true;
  bool _pulseLoading = true;
  int _pulseFY = InvoiceSeriesConfig.financialYearOf(DateTime.now());
  int? _pulseYear = DateTime.now().year;
  int? _pulseMonth = DateTime.now().month;
  String _pulseScope = 'global'; // 'global' | 'company'
  String? _pulseFocusCompany; // company NAME used for company-scope funnel
  int? _pulseStageFilter; // tapped gauge stage, or null

  List<InvoiceSeriesConfig> _pulseSeries = [];
  Map<String, int> _pulseMissingByCompany = {}; // companyId -> total missing
  Map<String, List<InvoiceSeriesConfig>> _pulseSeriesByCompany = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(
        ScreenKeys.pipelineDashboard,
        label: 'Pipeline Dashboard'));
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    _loadAll();
    _loadCompanies();
    _loadChequeStats();
    _loadTelecalling();
  }

  void _onTabChanged() {
    if (_tabCtrl.index == 1 && !_pulseInitialized) {
      _pulseInitialized = true;
      _loadPulseInvoices();
      _loadPulse();
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────────────

  // Server-side scoped by the Dashboard tab's global selection bar (year /
  // month, default = current month) so the page opens fast — pass both null
  // for "All Time" to fetch full history.
  Future<void> _loadAll() async {
    setState(() => _allLoading = true);
    final all =
        await _fs.getAllMasterInvoices(year: _dashYear, month: _dashMonth);
    if (!mounted) return;
    setState(() {
      _allInvoices = all;
      _allLoading = false;
    });
  }

  Future<void> _loadCompanies() async {
    final companies = await _fs.getCompanies();
    if (!mounted) return;
    setState(() => _companies = companies);
  }

  // Pulse tab keeps its own full all-time dataset, independent of the
  // Dashboard tab's (possibly narrower) selected period.
  Future<void> _loadPulseInvoices() async {
    setState(() => _pulseInvoicesLoading = true);
    final all = await _fs.getAllMasterInvoices();
    if (!mounted) return;
    setState(() {
      _pulseInvoices = all;
      _pulseInvoicesLoading = false;
    });
  }

  // Stage 6 (Telecalling) — fetched once; the count/pending-vs-done split
  // shown on the dashboard is derived by filtering client-side to whatever
  // year/month is currently selected (same as the rest of the Dashboard tab).
  Future<void> _loadTelecalling() async {
    setState(() => _telecallLoading = true);
    final data = await _fs.getTelecallingInvoices();
    if (!mounted) return;
    setState(() {
      _telecallInvoices = data;
      _telecallLoading = false;
    });
  }

  List<InvoiceData> get _telecallPool {
    if (_dashYear == null) return _telecallInvoices;
    return _telecallInvoices.where((inv) {
      if (inv.timestamp <= 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
      if (d.year != _dashYear) return false;
      if (_dashMonth != null && d.month != _dashMonth) return false;
      return true;
    }).toList();
  }

  Future<void> _loadChequeStats() async {
    final stats = await _fs.getChequeStats();
    if (!mounted) return;
    setState(() {
      _chequePending = stats['pending'] as int? ?? 0;
      _chequeCollected = stats['collected'] as int? ?? 0;
      _chequePendingByStage = (stats['pendingByStage'] as Map<int, int>?) ?? {};
    });
  }

  // Phase 1: series configs + max invoice number per series (fast).
  // Phase 2: gap-detect the actual missing count per series in parallel —
  // heavier than the lazy pattern used in Invoice Master (which only loads
  // on tap), but company count is small enough that doing it up front is
  // fine and lets the dashboard show real counts, not just a placeholder.
  Future<void> _loadPulse() async {
    setState(() => _pulseLoading = true);
    try {
      final data = await _fs.getSeriesConfigsWithMax(_pulseFY);
      final configs = data
          .map((m) => InvoiceSeriesConfig.fromMap(m['id'] as String, m))
          .toList();

      final missingBySeries = <String, int>{};
      await Future.wait(configs.map((cfg) async {
        final siblingStarts = configs
            .where((c) =>
                c.companyId == cfg.companyId &&
                c.prefix == cfg.prefix &&
                c.startNumber > cfg.startNumber)
            .map((c) => c.startNumber)
            .toList();
        final upperBound = siblingStarts.isEmpty
            ? null
            : (siblingStarts.reduce((a, b) => a < b ? a : b) - 1);
        try {
          final res = await _fs.getMissingInvoiceNumbers(
              cfg.companyId, _pulseFY, cfg.prefix,
              startNumber: cfg.startNumber, upperBound: upperBound);
          missingBySeries[cfg.id] = (res['total'] as int?) ?? 0;
        } catch (_) {
          missingBySeries[cfg.id] = 0;
        }
      }));

      final missingByCompany = <String, int>{};
      final seriesByCompany = <String, List<InvoiceSeriesConfig>>{};
      for (final cfg in configs) {
        missingByCompany[cfg.companyId] =
            (missingByCompany[cfg.companyId] ?? 0) +
                (missingBySeries[cfg.id] ?? 0);
        seriesByCompany.putIfAbsent(cfg.companyId, () => []).add(cfg);
      }

      if (!mounted) return;
      setState(() {
        _pulseSeries = configs;
        _pulseMissingByCompany = missingByCompany;
        _pulseSeriesByCompany = seriesByCompany;
        _pulseLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _pulseLoading = false);
    }
  }

  List<InvoiceAcknowledgementData> get _pulsePool {
    if (_pulseYear == null) return _pulseInvoices;
    return _pulseInvoices.where((inv) {
      if (inv.timestamp <= 0) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
      if (d.year != _pulseYear) return false;
      if (_pulseMonth != null && d.month != _pulseMonth) return false;
      return true;
    }).toList();
  }

  String? _companyIdForName(String name) {
    for (final c in _companies) {
      if (c.companyName == name) return c.companyId;
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  double _totalAmount(List<InvoiceAcknowledgementData> list) =>
      list.fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  Map<String, List<InvoiceAcknowledgementData>> _groupByCompany(
      List<InvoiceAcknowledgementData> list) {
    final map = <String, List<InvoiceAcknowledgementData>>{};
    for (final inv in list) map.putIfAbsent(inv.companyName, () => []).add(inv);
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  Map<String, List<InvoiceAcknowledgementData>> _groupByParty(
      List<InvoiceAcknowledgementData> list) {
    final map = <String, List<InvoiceAcknowledgementData>>{};
    for (final inv in list) map.putIfAbsent(inv.partyName, () => []).add(inv);
    return Map.fromEntries(map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Toggle bar
      Container(
        color: AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TabBar(
          controller: _tabCtrl,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: '📊  Dashboard'),
            Tab(text: '⚡  Pulse'),
          ],
        ),
      ),
      Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
        _buildDashboardTab(),
        _buildPulseTab(),
      ])),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCREEN 1 — Dashboard (year/month filter, default = current month)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardTab() {
    if (_allLoading) return const Center(child: CircularProgressIndicator());
    final stageCounts = <int, int>{
      for (int s = 1; s <= 5; s++)
        s: _allInvoices.where((i) => i.stage == s).length,
    };
    final total = stageCounts.values.fold(0, (s, v) => s + v);

    // Stage 6 — Telecalling (orthogonal bucket, see _telecallPool).
    final telecallPool = _telecallPool;
    final telecallTotal = telecallPool.length;
    final telecallDelivered =
        telecallPool.where((i) => i.telecallStatus == 'delivered').length;
    final telecallPending = telecallTotal - telecallDelivered;
    // Data only goes back to 2025 — don't offer earlier, empty years.
    final years = List.generate(math.max(1, DateTime.now().year - 2025 + 1),
        (i) => DateTime.now().year - i);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadAll(), _loadChequeStats(), _loadTelecalling()]);
      },
      child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 40),
          children: [
            // ── Global Selection Bar ─────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader(
                      'Global Selection', Icons.tune_rounded, AppTheme.primary,
                      subtitle: _dashYear == null
                          ? 'All time'
                          : (_dashMonth == null
                              ? '$_dashYear (full year)'
                              : DateFormat('MMMM yyyy')
                                  .format(DateTime(_dashYear!, _dashMonth!)))),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _pulseChip('All Time', _dashYear == null, () {
                        setState(() {
                          _dashYear = null;
                          _dashMonth = null;
                        });
                        _loadAll();
                      }),
                      ...years.map((y) => _pulseChip('$y', _dashYear == y, () {
                            setState(() {
                              _dashYear = y;
                              _dashMonth = null;
                            });
                            _loadAll();
                          })),
                    ]),
                  ),
                  if (_dashYear != null) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _pulseChip('All months', _dashMonth == null, () {
                          setState(() => _dashMonth = null);
                          _loadAll();
                        }),
                        ...List.generate(12, (i) {
                          final m = i + 1;
                          return _pulseChip(
                              DateFormat('MMM').format(DateTime(2000, m)),
                              _dashMonth == m, () {
                            setState(() => _dashMonth = m);
                            _loadAll();
                          });
                        }),
                      ]),
                    ),
                  ],
                ])),
            const SizedBox(height: 10),

            // ── Stage Overview ─────────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Pipeline Overview', Icons.insights_rounded,
                      AppTheme.primary,
                      subtitle: '$total total invoices'),
                  const SizedBox(height: 12),

                  // 6 stage boxes (S1-S5 = invoice pipeline, S6 = Telecalling —
                  // a separate bucket; its % shown is "% delivered-confirmed")
                  Row(
                      children: List.generate(6, (i) {
                    final s = i + 1;
                    final isTelecall = s == 6;
                    final c =
                        isTelecall ? telecallTotal : (stageCounts[s] ?? 0);
                    final color = AppStages.color(s);
                    final pct = isTelecall
                        ? (telecallTotal > 0
                            ? telecallDelivered / telecallTotal
                            : 0.0)
                        : (total > 0 ? c / total : 0.0);
                    return Expanded(
                        child: Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 5 : 0),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(children: [
                            Icon(AppStages.icon(s), color: color, size: 14),
                            const SizedBox(height: 4),
                            Text('$c',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: color)),
                            Text('S$s',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: color.withValues(alpha: 0.8))),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        // Mini progress bar
                        ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: color.withValues(alpha: 0.1),
                                color: color,
                                minHeight: 4)),
                        Text('${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 9,
                                color: color.withValues(alpha: 0.7))),
                      ]),
                    ));
                  })),

                  const SizedBox(height: 12),

                  // Stage names row
                  Row(
                      children: List.generate(6, (i) {
                    final s = i + 1;
                    final color = AppStages.color(s);
                    final labels = [
                      'Invoice',
                      'Packing',
                      'Dispatch',
                      'Ack',
                      'Done',
                      'Telecall',
                    ];
                    return Expanded(
                        child: Text(labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w600)));
                  })),
                ])),

            const SizedBox(height: 10),

            // ── Horizontal bar chart by stage ──────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Stage Distribution', Icons.bar_chart_rounded,
                      AppTheme.primary,
                      subtitle:
                          'tap a stage to see companies · parties · invoices'),
                  const SizedBox(height: 10),
                  ...List.generate(6, (i) {
                    final s = i + 1;
                    final isTelecall = s == 6;
                    final c =
                        isTelecall ? telecallTotal : (stageCounts[s] ?? 0);
                    final color = AppStages.color(s);
                    final pct = isTelecall
                        ? (telecallTotal > 0
                            ? telecallDelivered / telecallTotal
                            : 0.0)
                        : (total > 0 ? c / total : 0.0);
                    final labels = [
                      'Invoice Prepared',
                      'Packed',
                      'Dispatched',
                      'Acknowledged',
                      'Completed',
                      'Telecalling',
                    ];
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (_dashDrillStage == s) {
                          _dashDrillStage = null;
                        } else {
                          _dashDrillStage = s;
                        }
                        _dashDrillCompany = null;
                        _dashDrillParty = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          SizedBox(
                              width: 80,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(labels[i],
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textSecondary)),
                                    if (isTelecall)
                                      Text('$telecallPending pending',
                                          style: TextStyle(
                                              fontSize: 8.5,
                                              color:
                                                  color.withValues(alpha: 0.8),
                                              fontWeight: FontWeight.w600)),
                                  ])),
                          Expanded(
                              child: Stack(children: [
                            Container(
                                height: 22,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(5),
                                    border: _dashDrillStage == s
                                        ? Border.all(color: color, width: 1.5)
                                        : null)),
                            FractionallySizedBox(
                                widthFactor: pct.clamp(0.01, 1.0),
                                child: Container(
                                    height: 22,
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.7),
                                        borderRadius:
                                            BorderRadius.circular(5)))),
                            Positioned.fill(
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text('$c',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white))))),
                          ])),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 32,
                              child: Text('${(pct * 100).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                      fontWeight: FontWeight.w700))),
                          Icon(
                              _dashDrillStage == s
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppTheme.textSecondary),
                        ]),
                      ),
                    );
                  }),
                  _buildStageDrillPanel(),
                ])),

            const SizedBox(height: 10),

            // ── Company-wise breakdown (+ Party Wise toggle) ────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: _cardHeader('Company Wise',
                            Icons.business_rounded, const Color(0xFF5C6BC0),
                            subtitle:
                                'tap a stage or party row inside a card for full details')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _toggleBtn('company', Icons.business_rounded, 'Company'),
                    const SizedBox(width: 8),
                    _toggleBtn('party', Icons.store_rounded, 'Party'),
                  ]),
                  const SizedBox(height: 10),
                  if (_viewMode == 'company')
                    ...() {
                      final groups = _groupByCompany(_allInvoices);
                      if (groups.isEmpty) {
                        return [
                          const Text('No data',
                              style: TextStyle(color: AppTheme.textSecondary))
                        ];
                      }
                      return groups.entries
                          .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CompanyCard(
                                  companyName: e.key, invoices: e.value)))
                          .toList();
                    }()
                  else
                    ...() {
                      final groups = _groupByParty(_allInvoices);
                      if (groups.isEmpty) {
                        return [
                          const Text('No data',
                              style: TextStyle(color: AppTheme.textSecondary))
                        ];
                      }
                      return groups.entries
                          .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GlobalPartyCard(
                                  partyName: e.key, invoices: e.value)))
                          .toList();
                    }(),
                ])),

            const SizedBox(height: 10),

            // ── Local vs Outstation ────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Local vs Outstation', Icons.map_rounded,
                      const Color(0xFF00897B)),
                  const SizedBox(height: 12),
                  Builder(builder: (_) {
                    final local = _allInvoices
                        .where((i) =>
                            i.routeName?.toLowerCase().contains('local') ??
                            false)
                        .toList();
                    final outstation = _allInvoices
                        .where((i) =>
                            !(i.routeName?.toLowerCase().contains('local') ??
                                false) &&
                            i.routeName != null &&
                            i.routeName!.isNotEmpty)
                        .toList();
                    final other = _allInvoices
                        .where(
                            (i) => i.routeName == null || i.routeName!.isEmpty)
                        .toList();
                    final tAmt = _totalAmount(_allInvoices);

                    Widget split(String label,
                        List<InvoiceAcknowledgementData> invs, Color color) {
                      final amt = _totalAmount(invs);
                      final pct = _allInvoices.isNotEmpty
                          ? invs.length / _allInvoices.length
                          : 0.0;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              const Spacer(),
                              Text('${invs.length}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: color)),
                              Text('  (${(pct * 100).toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondary)),
                            ]),
                            const SizedBox(height: 4),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor:
                                        color.withValues(alpha: 0.08),
                                    color: color,
                                    minHeight: 8)),
                            const SizedBox(height: 2),
                            Text('₹${_fmt(amt)}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: color.withValues(alpha: 0.8))),
                            const SizedBox(height: 10),
                          ]);
                    }

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          split('Local', local, const Color(0xFF43A047)),
                          split('Outstation', outstation,
                              const Color(0xFFF57C00)),
                          if (other.isNotEmpty)
                            split(
                                'Route Not Set', other, AppTheme.textSecondary),
                        ]);
                  }),
                ])),

            const SizedBox(height: 10),

            // ── Top Parties ────────────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Top Parties by Invoice Count',
                      Icons.store_rounded, AppTheme.stageAck),
                  const SizedBox(height: 10),
                  Builder(builder: (_) {
                    final groups = _groupByParty(_allInvoices);
                    final top = groups.entries.take(10).toList();
                    if (top.isEmpty)
                      return const Text('No data',
                          style: TextStyle(color: AppTheme.textSecondary));
                    final max = top.first.value.length;
                    return Column(
                        children: top.asMap().entries.map((e) {
                      final rank = e.key + 1;
                      final name = e.value.key;
                      final invs = e.value.value;
                      final pct = max > 0 ? invs.length / max : 0.0;
                      final amt = _totalAmount(invs);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          SizedBox(
                              width: 20,
                              child: Text('$rank',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: rank <= 3
                                          ? AppTheme.stageAck
                                          : AppTheme.textSecondary))),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis)),
                                  Text('${invs.length}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.stageAck)),
                                ]),
                                const SizedBox(height: 3),
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                        value: pct,
                                        backgroundColor: AppTheme.stageAck
                                            .withValues(alpha: 0.08),
                                        color: AppTheme.stageAck
                                            .withValues(alpha: 0.5),
                                        minHeight: 5)),
                                Text('₹${_fmt(amt)}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSecondary)),
                              ])),
                        ]),
                      );
                    }).toList());
                  }),
                ])),

            const SizedBox(height: 10),

            // ── Cheque Collection ──────────────────────────────────────────────
            _buildChequeCard(),
          ]),
    );
  }

  Widget _buildChequeCard() {
    final total = _chequePending + _chequeCollected;
    final pct = total > 0 ? _chequeCollected / total : 0.0;
    return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _cardHeader(
          'Cheque Collection', Icons.payments_rounded, AppTheme.stageCheque),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _statBox('Pending', '$_chequePending',
                Icons.hourglass_top_rounded, AppTheme.warning)),
        const SizedBox(width: 8),
        Expanded(
            child: _statBox('Collected', '$_chequeCollected',
                Icons.check_circle_rounded, AppTheme.success)),
        const SizedBox(width: 8),
        Expanded(
            child: _statBox('Total', '$total', Icons.receipt_long_rounded,
                AppTheme.stageCheque)),
      ]),
      if (total > 0) ...[
        const SizedBox(height: 12),
        Row(children: [
          Text('${(pct * 100).toStringAsFixed(0)}% collected',
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$_chequeCollected of $total',
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                color: AppTheme.success,
                minHeight: 8)),
        if (_chequePendingByStage.values.any((c) => c > 0)) ...[
          const SizedBox(height: 12),
          const Text('PENDING BY STAGE',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.6)),
          const SizedBox(height: 7),
          Row(
              children: [1, 2, 3, 4].map((s) {
            final c = _chequePendingByStage[s] ?? 0;
            final color = AppStages.color(s);
            final labels = ['Invoice', 'Packing', 'Dispatch', 'Ack'];
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color:
                      c > 0 ? color.withValues(alpha: 0.10) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: c > 0
                          ? color.withValues(alpha: 0.3)
                          : AppTheme.divider),
                ),
                child: Column(children: [
                  Text('$c',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: c > 0 ? color : AppTheme.divider)),
                  Text(labels[s - 1],
                      style: TextStyle(
                          fontSize: 8,
                          color: c > 0 ? color : AppTheme.divider,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ));
          }).toList()),
        ],
      ],
    ]));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SCREEN 2 — Pulse
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPulseTab() {
    if (_pulseInvoicesLoading)
      return const Center(child: CircularProgressIndicator());

    final pool = _pulsePool;
    final total = pool.length;

    final stageReached = <int, int>{
      for (int s = 1; s <= 5; s++) s: pool.where((i) => i.stage >= s).length,
    };

    final funnelPool = _pulseScope == 'company' && _pulseFocusCompany != null
        ? pool.where((i) => i.companyName == _pulseFocusCompany).toList()
        : pool;
    final funnelTotal = funnelPool.length;
    final levels = <double>[1.0];
    for (int s = 1; s <= 5; s++) {
      final r = funnelPool.where((i) => i.stage >= s).length;
      levels.add(funnelTotal > 0 ? r / funnelTotal : 0.0);
    }
    final funnelCounts = List.generate(
        5, (i) => funnelPool.where((inv) => inv.stage >= i + 1).length);

    final companyGroups = _groupByCompany(_pulseStageFilter != null
        ? pool.where((i) => i.stage >= _pulseStageFilter!).toList()
        : pool);
    final companyTotal = companyGroups.values.fold(0, (s, l) => s + l.length);

    final years = _pulseInvoices
        .where((i) => i.timestamp > 0)
        .map((i) => DateTime.fromMillisecondsSinceEpoch(i.timestamp).year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_loadPulseInvoices(), _loadPulse()]);
      },
      child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 40),
          children: [
            // ── Global selection bar ─────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader(
                      'Global Selection', Icons.tune_rounded, AppTheme.primary,
                      subtitle: _pulseYear == null
                          ? 'All time'
                          : (_pulseMonth == null
                              ? '$_pulseYear (full year)'
                              : DateFormat('MMMM yyyy').format(
                                  DateTime(_pulseYear!, _pulseMonth!)))),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _pulseChip(
                          'All Time',
                          _pulseYear == null,
                          () => setState(() {
                                _pulseYear = null;
                                _pulseMonth = null;
                              })),
                      ...years.map((y) => _pulseChip(
                          '$y',
                          _pulseYear == y,
                          () => setState(() {
                                _pulseYear = y;
                                _pulseMonth = null;
                              }))),
                    ]),
                  ),
                  if (_pulseYear != null) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _pulseChip('All months', _pulseMonth == null,
                            () => setState(() => _pulseMonth = null)),
                        ...List.generate(12, (i) {
                          final m = i + 1;
                          return _pulseChip(
                              DateFormat('MMM').format(DateTime(2000, m)),
                              _pulseMonth == m,
                              () => setState(() => _pulseMonth = m));
                        }),
                      ]),
                    ),
                  ],
                ])),
            const SizedBox(height: 10),

            // ── Stage gauges ──────────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader(
                      'Stage Pulse', Icons.speed_rounded, AppTheme.primary,
                      subtitle:
                          '$total total invoices  ·  tap a stage to filter company breakdown'),
                  const SizedBox(height: 10),
                  Row(
                      children: List.generate(5, (i) {
                    final s = i + 1;
                    return Expanded(
                        child: Padding(
                      padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      child: _StageGauge(
                        stage: s,
                        reached: stageReached[s] ?? 0,
                        total: total,
                        color: AppStages.color(s),
                        active: _pulseStageFilter == s,
                        onTap: () => setState(() => _pulseStageFilter =
                            _pulseStageFilter == s ? null : s),
                      ),
                    ));
                  })),
                ])),
            const SizedBox(height: 10),

            // ── Funnel ────────────────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: _cardHeader('Logistics Pipeline',
                            Icons.filter_alt_rounded, const Color(0xFF5C6BC0))),
                    Text('Global',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _pulseScope == 'global'
                                ? AppTheme.primary
                                : AppTheme.textSecondary)),
                    Switch(
                        value: _pulseScope == 'company',
                        activeColor: AppTheme.primary,
                        onChanged: (v) => setState(
                            () => _pulseScope = v ? 'company' : 'global')),
                    Text('Company',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _pulseScope == 'company'
                                ? AppTheme.primary
                                : AppTheme.textSecondary)),
                  ]),
                  if (_pulseScope == 'company') ...[
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                      value: _pulseFocusCompany,
                      isDense: true,
                      hint: const Text('Select a company',
                          style: TextStyle(fontSize: 12)),
                      items: _companies
                          .map((c) => DropdownMenuItem<String?>(
                              value: c.companyName,
                              child: Text(c.companyName,
                                  style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() => _pulseFocusCompany = v),
                    )),
                  ],
                  const SizedBox(height: 10),
                  if (_pulseScope == 'company' && _pulseFocusCompany == null)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: Text(
                                'Select a company to see its own pipeline.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12))))
                  else
                    SizedBox(
                        height: 210,
                        width: double.infinity,
                        child: CustomPaint(
                            painter: _FunnelPainter(
                                levels: levels,
                                colors: List.generate(
                                    5, (i) => AppStages.color(i + 1)),
                                counts: funnelCounts))),
                ])),
            const SizedBox(height: 10),

            // ── Pie chart ─────────────────────────────────────────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Invoices by Company', Icons.pie_chart_rounded,
                      const Color(0xFF00897B)),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    SizedBox(
                        width: 110,
                        height: 110,
                        child: companyGroups.isEmpty
                            ? const SizedBox.shrink()
                            : CustomPaint(
                                painter: _PieChartPainter(
                                    values: companyGroups.values
                                        .map((l) => l.length.toDouble())
                                        .toList(),
                                    colors: List.generate(companyGroups.length,
                                        (i) => _pulsePalette(i))))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: companyGroups.isEmpty
                            ? const Text('No data',
                                style: TextStyle(color: AppTheme.textSecondary))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: companyGroups.entries
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((e) {
                                  final idx = e.key;
                                  final name = e.value.key;
                                  final count = e.value.value.length;
                                  final pct = companyTotal > 0
                                      ? (count / companyTotal * 100)
                                      : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                              color: _pulsePalette(idx),
                                              borderRadius:
                                                  BorderRadius.circular(3))),
                                      const SizedBox(width: 7),
                                      Expanded(
                                          child: Text(name,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis)),
                                      Text('${pct.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textSecondary)),
                                    ]),
                                  );
                                }).toList())),
                  ]),
                ])),
            const SizedBox(height: 10),

            // ── Company-wise breakdown + missing invoice counts ────────────────
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _cardHeader('Company Wise', Icons.business_rounded,
                      const Color(0xFF5C6BC0),
                      subtitle: _pulseStageFilter != null
                          ? 'Showing invoices that reached S$_pulseStageFilter'
                          : null),
                  const SizedBox(height: 10),
                  if (companyGroups.isEmpty)
                    const Text('No data',
                        style: TextStyle(color: AppTheme.textSecondary))
                  else
                    ...companyGroups.entries.map((e) {
                      final companyId = _companyIdForName(e.key);
                      final missing = companyId != null
                          ? _pulseMissingByCompany[companyId]
                          : null;
                      final series = companyId != null
                          ? (_pulseSeriesByCompany[companyId] ?? [])
                          : <InvoiceSeriesConfig>[];
                      return _PulseCompanyCard(
                        companyName: e.key,
                        invoices: e.value,
                        missingCount: missing,
                        isLoadingMissing: _pulseLoading,
                        onTapMissing: series.isEmpty
                            ? null
                            : () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _PulseMissingSheet(
                                    fs: _fs,
                                    companyName: e.key,
                                    fy: _pulseFY,
                                    series: series)),
                        onTapInvoice: _showInvoiceDetail,
                      );
                    }),
                ])),
          ]),
    );
  }

  Color _pulsePalette(int i) {
    const p = [
      Color(0xFF4E8FCB),
      Color(0xFFE08A3E),
      Color(0xFF3FA97A),
      Color(0xFFC99A2E),
      Color(0xFFD97AA0),
      Color(0xFF5C6BC0),
      Color(0xFF00897B),
      Color(0xFF8E24AA),
    ];
    return p[i % p.length];
  }

  Widget _pulseChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: active ? AppTheme.primary : AppTheme.divider),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : AppTheme.textPrimary)),
        ),
      );

  void _showInvoiceDetail(InvoiceAcknowledgementData inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(18),
              children: [
                Row(children: [
                  Expanded(
                      child: Text(inv.invoiceNumber,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                Text('${inv.companyName} → ${inv.partyName}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                Wrap(spacing: 16, runSpacing: 12, children: [
                  _kv('Stage', 'S${inv.stage} · ${AppStages.label(inv.stage)}',
                      color: AppStages.color(inv.stage)),
                  _kv('Invoice value', '₹${inv.invoiceAmount}'),
                  _kv('Invoice date', inv.invoiceDate),
                  if (inv.lrNumber.isNotEmpty) _kv('LR number', inv.lrNumber),
                  if (inv.transportName.isNotEmpty)
                    _kv('Transport', inv.transportName),
                  if ((inv.vehicleNumber ?? '').isNotEmpty)
                    _kv('Vehicle', inv.vehicleNumber!),
                  if ((inv.routeName ?? '').isNotEmpty)
                    _kv('Route', inv.routeName!),
                  if ((inv.chequeNumber ?? '').isNotEmpty)
                    _kv('Cheque',
                        '${inv.chequeNumber} (${inv.chequeDate ?? ''})'),
                ]),
              ]),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {Color? color}) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppTheme.textPrimary)),
        ]),
      );

  // ══════════════════════════════════════════════════════════════════════════
  //  Dashboard tab — Stage Distribution drill-down (stage → company → party
  //  → full invoice details)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStageDrillPanel() {
    if (_dashDrillStage == null) return const SizedBox.shrink();
    if (_dashDrillStage == 6) return _buildTelecallDrillPanel();
    final stagePool =
        _allInvoices.where((i) => i.stage == _dashDrillStage).toList();

    final crumbs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _drillCrumb(
            'S$_dashDrillStage · ${AppStages.label(_dashDrillStage!)}',
            _dashDrillCompany == null,
            () => setState(() {
                  _dashDrillCompany = null;
                  _dashDrillParty = null;
                })),
        if (_dashDrillCompany != null) ...[
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppTheme.textSecondary),
          _drillCrumb(_dashDrillCompany!, _dashDrillParty == null,
              () => setState(() => _dashDrillParty = null)),
        ],
        if (_dashDrillParty != null) ...[
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppTheme.textSecondary),
          _drillCrumb(_dashDrillParty!, true, () {}),
        ],
      ]),
    );

    Widget body;
    if (_dashDrillCompany == null) {
      final groups = _groupByCompany(stagePool);
      body = groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No invoices in this stage.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: groups.entries
                  .map((e) => _drillRow(e.key, '${e.value.length} invoices',
                      () => setState(() => _dashDrillCompany = e.key)))
                  .toList());
    } else if (_dashDrillParty == null) {
      final companyPool =
          stagePool.where((i) => i.companyName == _dashDrillCompany).toList();
      final groups = _groupByParty(companyPool);
      body = groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No parties in this stage.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: groups.entries
                  .map((e) => _drillRow(e.key, '${e.value.length} invoices',
                      () => setState(() => _dashDrillParty = e.key)))
                  .toList());
    } else {
      final invs = stagePool
          .where((i) =>
              i.companyName == _dashDrillCompany &&
              i.partyName == _dashDrillParty)
          .toList();
      body = invs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No invoices found.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: invs
                  .map((inv) => GestureDetector(
                      onTap: () => _showInvoiceDetail(inv),
                      child: _InvoiceRow(
                          inv: inv, color: AppStages.color(inv.stage))))
                  .toList());
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        crumbs,
        const SizedBox(height: 8),
        body,
      ]),
    );
  }

  // Stage 6 (Telecalling) uses a different model (`InvoiceData`, from
  // getTelecallingInvoices()) than the 1-5 stage drill-down above
  // (`InvoiceAcknowledgementData`), so it gets its own small
  // company → party → invoice drill implementation rather than reusing
  // _groupByCompany/_groupByParty/_InvoiceRow.
  Widget _buildTelecallDrillPanel() {
    final stagePool = _telecallPool;

    final crumbs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _drillCrumb(
            'S6 · Telecalling',
            _dashDrillCompany == null,
            () => setState(() {
                  _dashDrillCompany = null;
                  _dashDrillParty = null;
                })),
        if (_dashDrillCompany != null) ...[
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppTheme.textSecondary),
          _drillCrumb(_dashDrillCompany!, _dashDrillParty == null,
              () => setState(() => _dashDrillParty = null)),
        ],
        if (_dashDrillParty != null) ...[
          const Icon(Icons.chevron_right_rounded,
              size: 14, color: AppTheme.textSecondary),
          _drillCrumb(_dashDrillParty!, true, () {}),
        ],
      ]),
    );

    Map<String, List<InvoiceData>> groupByCompany(List<InvoiceData> list) {
      final map = <String, List<InvoiceData>>{};
      for (final inv in list) {
        map.putIfAbsent(inv.companyName, () => []).add(inv);
      }
      return Map.fromEntries(
          map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    }

    Map<String, List<InvoiceData>> groupByParty(List<InvoiceData> list) {
      final map = <String, List<InvoiceData>>{};
      for (final inv in list) {
        map.putIfAbsent(inv.partyData.partyName, () => []).add(inv);
      }
      return Map.fromEntries(map.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length)));
    }

    Widget body;
    if (_dashDrillCompany == null) {
      final groups = groupByCompany(stagePool);
      body = groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No telecalling-eligible invoices.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: groups.entries
                  .map((e) => _drillRow(e.key, '${e.value.length} invoices',
                      () => setState(() => _dashDrillCompany = e.key)))
                  .toList());
    } else if (_dashDrillParty == null) {
      final companyPool =
          stagePool.where((i) => i.companyName == _dashDrillCompany).toList();
      final groups = groupByParty(companyPool);
      body = groups.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No parties in this bucket.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: groups.entries
                  .map((e) => _drillRow(e.key, '${e.value.length} invoices',
                      () => setState(() => _dashDrillParty = e.key)))
                  .toList());
    } else {
      final invs = stagePool
          .where((i) =>
              i.companyName == _dashDrillCompany &&
              i.partyData.partyName == _dashDrillParty)
          .toList();
      body = invs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No invoices found.',
                  style: TextStyle(color: AppTheme.textSecondary)))
          : Column(
              children: invs
                  .map((inv) => GestureDetector(
                      onTap: () => _showTelecallDetail(inv),
                      child: _TelecallInvoiceRow(inv: inv)))
                  .toList());
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        crumbs,
        const SizedBox(height: 8),
        body,
      ]),
    );
  }

  void _showTelecallDetail(InvoiceData inv) {
    final status = inv.telecallStatus ?? 'pending';
    final statusColor = status == 'delivered'
        ? AppTheme.stageCheque
        : (status == 'not_delivered' ? Colors.red : AppTheme.stageTelecall);
    final statusLabel = status == 'delivered'
        ? 'Delivered'
        : (status == 'not_delivered' ? 'Not delivered' : 'Pending call');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(18),
              children: [
                Row(children: [
                  Expanded(
                      child: Text(inv.invoiceNumber,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                Text('${inv.companyName} → ${inv.partyData.partyName}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                Wrap(spacing: 16, runSpacing: 12, children: [
                  _kv('Telecall status', statusLabel, color: statusColor),
                  _kv('Invoice value', '₹${inv.invoiceAmount}'),
                  _kv('Invoice date', inv.invoiceDate),
                  _kv('Order type', inv.orderType),
                  if ((inv.telecallAttempts ?? 0) > 0)
                    _kv('Attempts', '${inv.telecallAttempts}'),
                  if ((inv.telecallContactPerson ?? '').isNotEmpty)
                    _kv('Contact person', inv.telecallContactPerson!),
                  if ((inv.telecallTemperature ?? '').isNotEmpty)
                    _kv('Temperature', inv.telecallTemperature!),
                  if ((inv.routeName ?? '').isNotEmpty)
                    _kv('Route', inv.routeName!),
                ]),
              ]),
        ),
      ),
    );
  }

  Widget _drillCrumb(String label, bool current, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        current ? AppTheme.primary : AppTheme.textSecondary))),
      );

  Widget _drillRow(String label, String sub, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppTheme.divider)),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12))),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppTheme.textSecondary),
          ]),
        ),
      );

  Widget _toggleBtn(String mode, IconData icon, String label) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppTheme.primary : AppTheme.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14, color: active ? Colors.white : AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  // ── Small reusables ───────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: child,
      );

  Widget _cardHeader(String title, IconData icon, Color color,
          {String? subtitle}) =>
      Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          if (subtitle != null)
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
        ])),
      ]);

  Widget _statBox(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _statBox2(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Column(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      );

  Widget _vDiv() => Container(width: 1, height: 32, color: AppTheme.divider);
}

class _CompanyCard extends StatefulWidget {
  final String companyName;
  final List<InvoiceAcknowledgementData> invoices;
  const _CompanyCard({required this.companyName, required this.invoices});
  @override
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard> {
  bool _expanded = true;
  bool _showParties = false;

  int get _total => widget.invoices.length;
  int get _completed => widget.invoices.where((i) => i.stage == 5).length;
  int get _pending => _total - _completed;
  double get _amount => widget.invoices
      .fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));
  int _sc(int s) => widget.invoices.where((i) => i.stage == s).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: _expanded ? Radius.zero : const Radius.circular(14)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.business_rounded,
                        color: AppTheme.primary, size: 16)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(widget.companyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.fade)),
                _MC('$_total', Icons.receipt_long_rounded, AppTheme.primary),
                const SizedBox(width: 5),
                _MC('$_pending', Icons.hourglass_top_rounded, AppTheme.warning),
                const SizedBox(width: 5),
                _MC('$_completed', Icons.check_circle_rounded,
                    AppTheme.success),
                const SizedBox(width: 8),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20),
              ]),
              const SizedBox(height: 8),
              Row(
                  children: List.generate(5, (i) {
                final s = i + 1;
                final c = _sc(s);
                final color = AppStages.color(s);
                return Expanded(
                    child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: c > 0
                        ? color.withValues(alpha: 0.12)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: c > 0
                            ? color.withValues(alpha: 0.35)
                            : AppTheme.divider),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$c',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c > 0 ? color : AppTheme.divider)),
                    Text('S$s',
                        style: TextStyle(
                            fontSize: 8,
                            color: c > 0
                                ? color.withValues(alpha: 0.8)
                                : AppTheme.divider)),
                  ]),
                ));
              })),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.currency_rupee_rounded,
                    size: 12, color: AppTheme.textSecondary),
                Text(_fmtA(_amount),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                    '${_total > 0 ? ((_completed / _total) * 100).toStringAsFixed(0) : 0}% complete',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: _total > 0 ? _completed / _total : 0,
                      backgroundColor: AppTheme.surface,
                      color: AppTheme.success,
                      minHeight: 5)),
            ]),
          ),
        ),
        if (_expanded) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(children: [
                GestureDetector(
                    onTap: () => setState(() => _showParties = false),
                    child: _TabPill('Stage View', !_showParties)),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: () => setState(() => _showParties = true),
                    child: _TabPill('Party View', _showParties)),
              ])),
          if (_showParties)
            _PartyBreakdown(invoices: widget.invoices)
          else
            _StageBreakdown(invoices: widget.invoices),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }

  String _fmtA(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Stage Breakdown ───────────────────────────────────────────────────────────
class _StageBreakdown extends StatelessWidget {
  final List<InvoiceAcknowledgementData> invoices;
  const _StageBreakdown({required this.invoices});

  @override
  Widget build(BuildContext context) => Column(
          children: List.generate(5, (i) {
        final s = i + 1;
        final sl = invoices.where((inv) => inv.stage == s).toList();
        if (sl.isEmpty) return const SizedBox.shrink();
        return _ExpandableStageRow(
            stage: s,
            color: AppStages.color(s),
            label: AppStages.label(s),
            invoices: sl);
      }));
}

class _ExpandableStageRow extends StatefulWidget {
  final int stage;
  final Color color;
  final String label;
  final List<InvoiceAcknowledgementData> invoices;
  const _ExpandableStageRow(
      {required this.stage,
      required this.color,
      required this.label,
      required this.invoices});
  @override
  State<_ExpandableStageRow> createState() => _ExpandableStageRowState();
}

class _ExpandableStageRowState extends State<_ExpandableStageRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(children: [
        const Divider(
            height: 1, color: AppTheme.divider, indent: 14, endIndent: 14),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: widget.color.withValues(alpha: 0.3))),
                    child: Center(
                        child: Text('${widget.stage}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.color)))),
                const SizedBox(width: 10),
                Icon(AppStages.icon(widget.stage),
                    color: widget.color, size: 15),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(widget.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${widget.invoices.length}',
                        style: TextStyle(
                            fontSize: 11,
                            color: widget.color,
                            fontWeight: FontWeight.w800))),
                const SizedBox(width: 6),
                Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 18),
              ])),
        ),
        if (_open)
          Column(
              children: widget.invoices
                  .map((inv) => _InvoiceRow(inv: inv, color: widget.color))
                  .toList()),
      ]);
}

// ── Party Breakdown ───────────────────────────────────────────────────────────
class _PartyBreakdown extends StatelessWidget {
  final List<InvoiceAcknowledgementData> invoices;
  const _PartyBreakdown({required this.invoices});

  Map<String, List<InvoiceAcknowledgementData>> get _byParty {
    final m = <String, List<InvoiceAcknowledgementData>>{};
    for (final i in invoices) m.putIfAbsent(i.partyName, () => []).add(i);
    return Map.fromEntries(
        m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) => Column(
      children: _byParty.entries
          .map((e) => _PartyRow(partyName: e.key, invoices: e.value))
          .toList());
}

class _PartyRow extends StatefulWidget {
  final String partyName;
  final List<InvoiceAcknowledgementData> invoices;
  const _PartyRow({required this.partyName, required this.invoices});
  @override
  State<_PartyRow> createState() => _PartyRowState();
}

class _PartyRowState extends State<_PartyRow> {
  bool _open = false;
  int _sc(int s) => widget.invoices.where((i) => i.stage == s).length;
  int get _pending => widget.invoices.where((i) => i.stage < 5).length;
  int get _done => widget.invoices.where((i) => i.stage == 5).length;

  @override
  Widget build(BuildContext context) => Column(children: [
        const Divider(
            height: 1, color: AppTheme.divider, indent: 14, endIndent: 14),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: const Color(0xFF2A6EBB)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7)),
                          child: const Icon(Icons.people_alt_rounded,
                              color: Color(0xFF2A6EBB), size: 14)),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Text(widget.partyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.fade)),
                      _MC('${widget.invoices.length}',
                          Icons.receipt_long_rounded, AppTheme.primary),
                      const SizedBox(width: 5),
                      _MC('$_pending', Icons.hourglass_top_rounded,
                          AppTheme.warning),
                      const SizedBox(width: 5),
                      _MC('$_done', Icons.check_circle_rounded,
                          AppTheme.success),
                      const SizedBox(width: 6),
                      Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                          size: 18),
                    ]),
                    const SizedBox(height: 7),
                    Row(
                        children: List.generate(5, (i) {
                      final s = i + 1;
                      final c = _sc(s);
                      final color = AppStages.color(s);
                      return Expanded(
                          child: Container(
                        margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                            color: c > 0
                                ? color.withValues(alpha: 0.12)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: c > 0
                                    ? color.withValues(alpha: 0.3)
                                    : AppTheme.divider)),
                        child: Center(
                            child: Text('$c',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: c > 0 ? color : AppTheme.divider))),
                      ));
                    })),
                  ])),
        ),
        if (_open)
          Column(
              children: widget.invoices
                  .map((inv) =>
                      _InvoiceRow(inv: inv, color: AppStages.color(inv.stage)))
                  .toList()),
      ]);
}

// ── Global Party Card ─────────────────────────────────────────────────────────
class _GlobalPartyCard extends StatefulWidget {
  final String partyName;
  final List<InvoiceAcknowledgementData> invoices;
  const _GlobalPartyCard({required this.partyName, required this.invoices});
  @override
  State<_GlobalPartyCard> createState() => _GlobalPartyCardState();
}

class _GlobalPartyCardState extends State<_GlobalPartyCard> {
  bool _exp = false;
  int _sc(int s) => widget.invoices.where((i) => i.stage == s).length;
  int get _pending => widget.invoices.where((i) => i.stage < 5).length;
  int get _done => widget.invoices.where((i) => i.stage == 5).length;
  double get _amt => widget.invoices
      .fold(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  @override
  Widget build(BuildContext context) {
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
          ]),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _exp = !_exp),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                              color: const Color(0xFF2A6EBB)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.people_alt_rounded,
                              color: Color(0xFF2A6EBB), size: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(widget.partyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.fade),
                            Text(widget.invoices.first.companyName,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.fade),
                          ])),
                      _MC('${widget.invoices.length}',
                          Icons.receipt_long_rounded, AppTheme.primary),
                      const SizedBox(width: 5),
                      _MC('$_pending', Icons.hourglass_top_rounded,
                          AppTheme.warning),
                      const SizedBox(width: 5),
                      _MC('$_done', Icons.check_circle_rounded,
                          AppTheme.success),
                      const SizedBox(width: 6),
                      Icon(
                          _exp
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.textSecondary,
                          size: 18),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                        children: List.generate(5, (i) {
                      final s = i + 1;
                      final c = _sc(s);
                      final color = AppStages.color(s);
                      return Expanded(
                          child: Container(
                        margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                            color: c > 0
                                ? color.withValues(alpha: 0.12)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: c > 0
                                    ? color.withValues(alpha: 0.3)
                                    : AppTheme.divider)),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$c',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: c > 0 ? color : AppTheme.divider)),
                          Text('S$s',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: c > 0
                                      ? color.withValues(alpha: 0.7)
                                      : AppTheme.divider)),
                        ]),
                      ));
                    })),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.currency_rupee_rounded,
                          size: 12, color: AppTheme.textSecondary),
                      Text(_fmtA(_amt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                              width: 80,
                              child: LinearProgressIndicator(
                                  value: widget.invoices.isNotEmpty
                                      ? _done / widget.invoices.length
                                      : 0,
                                  backgroundColor: AppTheme.surface,
                                  color: AppTheme.success,
                                  minHeight: 5))),
                      const SizedBox(width: 6),
                      Text(
                          '${widget.invoices.isNotEmpty ? ((_done / widget.invoices.length) * 100).toStringAsFixed(0) : 0}%',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary)),
                    ]),
                  ])),
        ),
        if (_exp) ...[
          const Divider(height: 1, color: AppTheme.divider),
          ...widget.invoices.map((inv) =>
              _InvoiceRow(inv: inv, color: AppStages.color(inv.stage))),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }

  String _fmtA(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Invoice Row ───────────────────────────────────────────────────────────────
class _InvoiceRow extends StatelessWidget {
  final InvoiceAcknowledgementData inv;
  final Color color;
  const _InvoiceRow({required this.inv, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Row(children: [
        Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(inv.invoiceNumber,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 7),
            if (inv.orderType.isNotEmpty && inv.orderType != 'regular')
              _OrderBadge(inv.orderType),
          ]),
          const SizedBox(height: 2),
          Text(inv.partyName,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.fade),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${inv.invoiceAmount}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 11, color: color)),
          Text(inv.invoiceDate,
              style:
                  const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }
}

// Row for the Stage 6 (Telecalling) drill-down leaf list — mirrors
// _InvoiceRow's look, but built for InvoiceData (telecallStatus etc.)
// rather than InvoiceAcknowledgementData.
class _TelecallInvoiceRow extends StatelessWidget {
  final InvoiceData inv;
  const _TelecallInvoiceRow({required this.inv});

  @override
  Widget build(BuildContext context) {
    final status = inv.telecallStatus ?? 'pending';
    final color = status == 'delivered'
        ? AppTheme.stageCheque
        : (status == 'not_delivered' ? Colors.red : AppTheme.stageTelecall);
    final statusLabel = status == 'delivered'
        ? 'Delivered'
        : (status == 'not_delivered' ? 'Not delivered' : 'Pending');
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.18))),
      child: Row(children: [
        Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inv.invoiceNumber,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 2),
          Text(inv.partyData.partyName,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.fade),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(statusLabel,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 11, color: color)),
          Text(inv.invoiceDate,
              style:
                  const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }
}

// ── Shared tiny widgets ───────────────────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  const _TabPill(this.label, this.active);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.textSecondary)),
      );
}

class _MC extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MC(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _OrderBadge extends StatelessWidget {
  final String orderType;
  const _OrderBadge(this.orderType);
  Color get _c {
    switch (orderType) {
      case 'cold_chain':
        return const Color(0xFFC62828);
      case 'cool_chain':
        return const Color(0xFFE65100);
      case 'special':
        return const Color(0xFFD4882A);
      default:
        return AppTheme.success;
    }
  }

  String get _l {
    switch (orderType) {
      case 'cold_chain':
        return 'Cold';
      case 'cool_chain':
        return 'Cool';
      case 'special':
        return 'Special';
      default:
        return 'Reg';
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
            style:
                TextStyle(fontSize: 8, color: _c, fontWeight: FontWeight.bold)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(Icons.inbox_rounded,
                size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('No invoices found',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const Text('Try a different date or week',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ])));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulse tab — circular stage gauge
// ─────────────────────────────────────────────────────────────────────────────
class _StageGauge extends StatelessWidget {
  final int stage;
  final int reached;
  final int total;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _StageGauge({
    required this.stage,
    required this.reached,
    required this.total,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? reached / total : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? color : AppTheme.divider,
              width: active ? 1.6 : 1),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('S$stage · ${AppStages.label(stage)}',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _ArcGaugePainter(pct: pct, color: color),
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text('$reached',
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600)),
              ])),
            ),
          ),
          const SizedBox(height: 4),
          Icon(
              active
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: color.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double pct;
  final Color color;
  _ArcGaugePainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final bg = Paint()
      ..color = AppTheme.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);
    final clamped = pct.clamp(0.0, 1.0);
    final sweep = 2 * math.pi * clamped;
    if (sweep > 0) {
      final fg = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) =>
      old.pct != pct || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulse tab — funnel painter (trapezoid stack, mirrors the stage strip's
//  "reached at least this stage" percentages)
// ─────────────────────────────────────────────────────────────────────────────
class _FunnelPainter extends CustomPainter {
  final List<double> levels; // length 6: levels[0]=1.0, levels[1..5]=fractions
  final List<Color> colors; // length 5
  final List<int> counts; // length 5
  _FunnelPainter(
      {required this.levels, required this.colors, required this.counts});

  @override
  void paint(Canvas canvas, Size size) {
    final n = colors.length;
    final maxW = size.width * 0.86;
    final cx = size.width / 2;
    const gap = 5.0;
    final bandH = (size.height - 8 - gap * (n - 1)) / n;
    const minW = 42.0;
    double y0 = 4;
    for (int i = 0; i < n; i++) {
      final topFrac = levels[i];
      final botFrac = levels[i + 1];
      final isLast = i == n - 1;
      final topW = math.max(minW, topFrac * maxW);
      final botW = isLast
          ? math.max(12.0, botFrac * maxW * 0.5)
          : math.max(minW, botFrac * maxW);
      final y1 = y0 + bandH;
      final path = Path()
        ..moveTo(cx - topW / 2, y0)
        ..lineTo(cx + topW / 2, y0)
        ..lineTo(cx + botW / 2, y1)
        ..lineTo(cx - botW / 2, y1)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);

      final pctLabel = (levels[i + 1] * 100).round();
      final tp = TextPainter(
        text: TextSpan(
            text: 'S${i + 1}  $pctLabel%  ·  ${counts[i]}',
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: math.max(topW, botW));
      tp.paint(
          canvas, Offset(cx - tp.width / 2, y0 + bandH / 2 - tp.height / 2));

      y0 = y1 + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _FunnelPainter old) =>
      old.levels != levels || old.counts != counts;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulse tab — simple pie chart painter (company share of invoices)
// ─────────────────────────────────────────────────────────────────────────────
class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    double start = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep <= 0) continue;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
          sweep, true, Paint()..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      old.values != values || old.colors != colors;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulse tab — company card with a company-wise missing invoice count badge
// ─────────────────────────────────────────────────────────────────────────────
class _PulseCompanyCard extends StatefulWidget {
  final String companyName;
  final List<InvoiceAcknowledgementData> invoices;
  final int? missingCount; // null = no series configured for this company
  final bool isLoadingMissing;
  final VoidCallback? onTapMissing;
  final void Function(InvoiceAcknowledgementData) onTapInvoice;
  const _PulseCompanyCard({
    required this.companyName,
    required this.invoices,
    required this.missingCount,
    required this.isLoadingMissing,
    required this.onTapMissing,
    required this.onTapInvoice,
  });
  @override
  State<_PulseCompanyCard> createState() => _PulseCompanyCardState();
}

class _PulseCompanyCardState extends State<_PulseCompanyCard> {
  bool _expanded = false;
  int _sc(int s) => widget.invoices.where((i) => i.stage == s).length;
  double get _amt => widget.invoices
      .fold(0.0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0));

  String _fmtA(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final missing = widget.missingCount;
    final missingKnown = !widget.isLoadingMissing && missing != null;
    final missingColor = !missingKnown
        ? AppTheme.textSecondary
        : (missing! > 0 ? AppTheme.danger : AppTheme.success);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(widget.companyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.fade)),
                Text('${widget.invoices.length} inv  ·  ₹${_fmtA(_amt)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(width: 6),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20),
              ]),
              const SizedBox(height: 8),
              Row(
                  children: List.generate(5, (i) {
                final s = i + 1;
                final c = _sc(s);
                final color = AppStages.color(s);
                return Expanded(
                    child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: c > 0
                        ? color.withValues(alpha: 0.12)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: c > 0
                            ? color.withValues(alpha: 0.35)
                            : AppTheme.divider),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$c',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c > 0 ? color : AppTheme.divider)),
                    Text('S$s',
                        style: TextStyle(
                            fontSize: 8,
                            color: c > 0
                                ? color.withValues(alpha: 0.8)
                                : AppTheme.divider)),
                  ]),
                ));
              })),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onTapMissing,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: !missingKnown
                        ? AppTheme.surface
                        : (missing! > 0
                            ? AppTheme.danger.withValues(alpha: 0.08)
                            : AppTheme.success.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: !missingKnown
                            ? AppTheme.divider
                            : (missing! > 0
                                ? AppTheme.danger.withValues(alpha: 0.3)
                                : AppTheme.success.withValues(alpha: 0.3))),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off_rounded,
                        size: 13, color: missingColor),
                    const SizedBox(width: 5),
                    Text(
                      widget.isLoadingMissing
                          ? 'Checking missing invoices…'
                          : missing == null
                              ? 'No series configured'
                              : '$missing missing invoice${missing == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: missingColor),
                    ),
                    if (widget.onTapMissing != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 14, color: AppTheme.textSecondary),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
              child: Column(
                  children: widget.invoices
                      .map((inv) => GestureDetector(
                          onTap: () => widget.onTapInvoice(inv),
                          child: _InvoiceRow(
                              inv: inv, color: AppStages.color(inv.stage))))
                      .toList())),
          const SizedBox(height: 6),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulse tab — missing invoice detail sheet (company-wise). Same server-side
//  gap-detection call used by Invoice Master's Missing Invoice tab.
// ─────────────────────────────────────────────────────────────────────────────
class _PulseMissingSheet extends StatefulWidget {
  final ApiService fs;
  final String companyName;
  final int fy;
  final List<InvoiceSeriesConfig> series;
  const _PulseMissingSheet({
    required this.fs,
    required this.companyName,
    required this.fy,
    required this.series,
  });
  @override
  State<_PulseMissingSheet> createState() => _PulseMissingSheetState();
}

class _PulseMissingSheetState extends State<_PulseMissingSheet> {
  InvoiceSeriesConfig? _selected;
  bool _loading = false;
  String? _error;
  List<String> _missing = [];
  int _total = 0;
  int _entered = 0;
  int _maxNum = 0;
  int _minNum = 0;

  @override
  void initState() {
    super.initState();
    if (widget.series.length == 1) {
      _selected = widget.series.first;
      _load();
    }
  }

  Future<void> _load() async {
    final cfg = _selected;
    if (cfg == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final siblingStarts = widget.series
          .where((c) =>
              c.id != cfg.id &&
              c.prefix == cfg.prefix &&
              c.startNumber > cfg.startNumber)
          .map((c) => c.startNumber)
          .toList();
      final upperBound = siblingStarts.isEmpty
          ? null
          : (siblingStarts.reduce((a, b) => a < b ? a : b) - 1);
      final res = await widget.fs.getMissingInvoiceNumbers(
          cfg.companyId, widget.fy, cfg.prefix,
          startNumber: cfg.startNumber, upperBound: upperBound);
      final nums = res['missing'] as List<int>;
      if (!mounted) return;
      setState(() {
        _missing = nums.map((n) => cfg.formatNumber(n)).toList();
        _total = res['total'] as int;
        _entered = res['entered'] as int;
        _maxNum = res['maxNum'] as int;
        _minNum = res['minNum'] as int? ?? cfg.startNumber;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(children: [
                const Icon(Icons.search_off_rounded,
                    color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('${widget.companyName} — Missing Invoices',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14))),
              ])),
          if (_selected == null)
            Expanded(
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    controller: ctrl,
                    children: widget.series
                        .map((s) => ListTile(
                              title: Text(s.seriesName == 'Default'
                                  ? s.fyLabel
                                  : '${s.seriesName} · ${s.fyLabel}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                setState(() => _selected = s);
                                _load();
                              },
                            ))
                        .toList()))
          else
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(_error!,
                                style: const TextStyle(color: AppTheme.danger)))
                        : _buildList(ctrl)),
        ]),
      ),
    );
  }

  Widget _buildList(ScrollController ctrl) {
    if (_missing.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 40),
                const SizedBox(height: 10),
                Text(
                    'All invoices from ${_selected!.formatNumber(_minNum)} to '
                    '${_selected!.formatNumber(_maxNum)} are accounted for.',
                    textAlign: TextAlign.center),
              ])));
    }
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        controller: ctrl,
        children: [
          Text(
              '$_total missing out of ${_entered + _total} expected  ·  range '
              '${_selected!.formatNumber(_minNum)}–${_selected!.formatNumber(_maxNum)}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _missing
                  .map((n) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.3))),
                        child: Text(n,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.danger)),
                      ))
                  .toList()),
        ]);
  }
}
