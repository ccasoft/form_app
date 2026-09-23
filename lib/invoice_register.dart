// ─────────────────────────────────────────────────────────────────────────────
//  Invoice Register  —  Company-wise, Series-wise register with PDF & CSV export
//  Shows all invoice details grouped by Company → Series, sorted by invoice
//  number. Designed for verification against original hardcopy invoices.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/invoice_series_config.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/year_month_filter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── Entry point widget ───────────────────────────────────────────────────────
class InvoiceRegister extends StatefulWidget {
  const InvoiceRegister({super.key});
  @override
  State<InvoiceRegister> createState() => _InvoiceRegisterState();
}

class _InvoiceRegisterState extends State<InvoiceRegister> {
  final _fs = ApiService();

  int _selectedFY = InvoiceSeriesConfig.financialYearOf(DateTime.now());
  // Calendar year for YearMonthFilter (e.g. 2025 for FY 2025-26)
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month; // default: current month
  String? _selectedCompanyId;

  bool _loading = true;
  bool _exporting = false;
  String? _error;
  List<InvoiceSeriesConfig> _allConfigs = [];
  // All invoices fetched for the FY (unfiltered by month)
  final Map<String, List<InvoiceAcknowledgementData>> _invoiceMap = {};
  // Count map for YearMonthFilter dot indicators: { year: { month: count } }
  Map<int, Map<int, int>> _countMap = {};

  List<_CompanyInfo> get _companies {
    final seen = <String, _CompanyInfo>{};
    for (final cfg in _allConfigs) {
      seen.putIfAbsent(
          cfg.companyId,
          () => _CompanyInfo(
              id: cfg.companyId,
              name: cfg.companyName.isNotEmpty
                  ? cfg.companyName
                  : cfg.companyId));
    }
    return seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.invoiceRegister, label: 'Invoice Register'));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _invoiceMap.clear();
    });
    try {
      final allConfigs = await _fs.getSeriesConfigs();
      final fyConfigs =
          allConfigs.where((c) => c.financialYear == _selectedFY).toList();

      final companyIds = _selectedCompanyId != null
          ? [_selectedCompanyId!]
          : fyConfigs.map((c) => c.companyId).toSet().toList();

      // Fetch ALL invoices for the FY (month filter applied client-side below)
      final entries = await Future.wait(companyIds.map((cid) async {
        final invs = await _fs.getInvoicesForRegister(cid, _selectedFY);
        return MapEntry(cid, invs);
      }));

      final map = <String, List<InvoiceAcknowledgementData>>{};
      for (final e in entries) {
        map[e.key] = e.value;
      }

      // Build count map for YearMonthFilter dot indicators
      // Uses timestamp to determine calendar year + month of each invoice
      final countMap = <int, Map<int, int>>{};
      for (final invList in map.values) {
        for (final inv in invList) {
          if (inv.timestamp <= 0) continue;
          final dt = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
          countMap.putIfAbsent(dt.year, () => {});
          countMap[dt.year]![dt.month] =
              (countMap[dt.year]![dt.month] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _allConfigs = fyConfigs;
          _invoiceMap
            ..clear()
            ..addAll(map);
          _countMap = countMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  /// Returns true if this invoice matches the selected month filter.
  /// Month filter uses the invoice's timestamp (calendar month).
  bool _matchesMonth(InvoiceAcknowledgementData inv) {
    if (_selectedMonth == null) return true; // all months
    if (inv.timestamp > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(inv.timestamp);
      return dt.month == _selectedMonth && dt.year == _selectedYear;
    }
    // Fallback: parse invoiceDate string — supports both dd/MM/yyyy and dd-MM-yyyy
    final raw = inv.invoiceDate.replaceAll('-', '/');
    final parts = raw.split('/');
    if (parts.length == 3) {
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (m != null && y != null) {
        return m == _selectedMonth && y == _selectedYear;
      }
    }
    // Last resort: check invoiceYear / invoiceMonth fields via companyName hack
    // (these are not available on InvoiceAcknowledgementData, so return true
    // to avoid incorrectly hiding invoices)
    return true;
  }

  /// Returns series-filtered + month-filtered, sorted invoices for a given config
  List<InvoiceAcknowledgementData> _seriesInvoices(
      InvoiceSeriesConfig cfg, List<InvoiceAcknowledgementData> allInvoices) {
    final siblingStarts = _allConfigs
        .where((s) =>
            s.companyId == cfg.companyId &&
            s.id != cfg.id &&
            s.prefix == cfg.prefix &&
            s.startNumber > cfg.startNumber)
        .map((s) => s.startNumber)
        .toList();
    final upperBound = siblingStarts.isEmpty
        ? null
        : siblingStarts.reduce((a, b) => a < b ? a : b) - 1;

    return allInvoices.where((inv) {
      // Series range filter
      final invNo = inv.invoiceNumber.trim();
      if (cfg.prefix.isNotEmpty && !invNo.startsWith(cfg.prefix)) return false;
      final n = cfg.parseNumber(invNo);
      if (n == null) return false;
      if (n < cfg.startNumber) return false;
      if (upperBound != null && n > upperBound) return false;
      // Month filter
      if (!_matchesMonth(inv)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final na = cfg.parseNumber(a.invoiceNumber) ?? 0;
        final nb = cfg.parseNumber(b.invoiceNumber) ?? 0;
        return na.compareTo(nb);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Invoice Register'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF',
              onPressed: _loading ? null : _exportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.table_view_rounded),
              tooltip: 'Export CSV / Excel',
              onPressed: _loading ? null : _exportCsv,
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(children: [
        _buildFilterBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildRegister(),
        ),
      ]),
    );
  }

  Widget _buildFilterBar() {
    return Column(children: [
      // ── Year + Month filter (reuses existing YearMonthFilter widget) ──
      YearMonthFilter(
        color: AppTheme.primary,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        countMap: _countMap,
        onYearChanged: (y) {
          // Derive FY from calendar year: Apr–Dec → same year starts FY,
          // Jan–Mar → previous year starts FY.
          // When user picks a year we set FY = that year (i.e. FY y – y+1).
          setState(() {
            _selectedYear = y;
            _selectedFY = y; // treat picked year as FY start
            _selectedMonth = null;
            _selectedCompanyId = null;
          });
          _load();
        },
        onMonthChanged: (m) {
          // Month filter is purely client-side — no Firebase reload needed.
          setState(() => _selectedMonth = m);
        },
      ),
      // ── Company filter ──
      Container(
        color: AppTheme.primary,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Company',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _companyChip(null, 'All Companies'),
              ..._companies.map((c) => _companyChip(c.id, c.name)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _companyChip(String? id, String label) {
    final active = _selectedCompanyId == id;
    return GestureDetector(
      onTap: () {
        if (_selectedCompanyId != id) {
          setState(() => _selectedCompanyId = id);
          _load();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  active ? Colors.white : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.primary : Colors.white)),
      ),
    );
  }

  Widget _buildRegister() {
    final companiesToShow = _selectedCompanyId != null
        ? _companies.where((c) => c.id == _selectedCompanyId).toList()
        : _companies;

    if (companiesToShow.isEmpty) {
      return _buildEmpty(
          'No companies found for this FY.\nConfigure series first.');
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
        itemCount: companiesToShow.length,
        itemBuilder: (_, i) {
          final company = companiesToShow[i];
          final configs = _allConfigs
              .where((c) => c.companyId == company.id)
              .toList()
            ..sort((a, b) => a.seriesName.compareTo(b.seriesName));
          final invoices = _invoiceMap[company.id] ?? [];
          return _CompanyRegisterSection(
            company: company,
            configs: configs,
            invoices: invoices,
            fy: _selectedFY,
            seriesInvoicesBuilder: _seriesInvoices,
          );
        },
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.danger, size: 40),
            const SizedBox(height: 12),
            const Text('Failed to load register',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      );

  Widget _buildEmpty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_rounded,
                size: 52, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
          ]),
        ),
      );

  // ─── PDF Export ────────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      // Load Unicode-capable fonts (Noto Sans covers all Indian/Latin chars).
      // The default Helvetica PDF font has NO Unicode support — any em-dash,
      // en-dash, rupee symbol etc. would render as blank boxes.
      final fontRegular = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      // Base styles reused throughout the PDF
      pw.TextStyle pStyle({
        double size = 6.5,
        bool bold = false,
        PdfColor color = PdfColors.black,
      }) =>
          pw.TextStyle(
            font: bold ? fontBold : fontRegular,
            fontBold: fontBold,
            fontSize: size,
            color: color,
          );

      // Helper: sanitise a cell value — replace Unicode dashes with ASCII
      // so even if a fallback font is missing the glyph, it still renders.
      String s(String v) => v
          .replaceAll('—', '-') // em dash
          .replaceAll('–', '-') // en dash
          .replaceAll('‒', '-') // figure dash
          .replaceAll('―', '-'); // horizontal bar

      final pdf = pw.Document();
      final fyNext = (_selectedFY + 1).toString().substring(2);
      final fyLabel = 'FY $_selectedFY-$fyNext';
      final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final companiesToShow = _selectedCompanyId != null
          ? _companies.where((c) => c.id == _selectedCompanyId).toList()
          : _companies;

      for (final company in companiesToShow) {
        final configs = _allConfigs
            .where((c) => c.companyId == company.id)
            .toList()
          ..sort((a, b) => a.seriesName.compareTo(b.seriesName));
        final allInvoices = _invoiceMap[company.id] ?? [];

        for (final cfg in configs) {
          final invList = _seriesInvoices(cfg, allInvoices);
          if (invList.isEmpty) continue;

          final seriesLabel =
              cfg.seriesName != 'Default' ? cfg.seriesName : 'Default Series';
          const rowsPerPage = 35;

          for (int pageStart = 0;
              pageStart < invList.length;
              pageStart += rowsPerPage) {
            final pageInvs = invList.sublist(
                pageStart,
                (pageStart + rowsPerPage) < invList.length
                    ? (pageStart + rowsPerPage)
                    : invList.length);
            final isLastChunk = (pageStart + rowsPerPage) >= invList.length;

            pdf.addPage(pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(16),
              build: (ctx) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(s(company.name),
                                      style: pStyle(size: 12, bold: true)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                      '$fyLabel  |  Series: $seriesLabel'
                                      '${cfg.prefix.isNotEmpty ? "  |  Prefix: ${cfg.prefix}" : ""}',
                                      style: pStyle(
                                          size: 7.5,
                                          color: PdfColors.blueGrey700)),
                                ]),
                          ),
                          pw.Text('Invoice Register   |   $now',
                              style: pStyle(
                                  size: 7, color: PdfColors.blueGrey400)),
                        ]),
                    pw.SizedBox(height: 5),
                    pw.Divider(thickness: 0.4),
                    pw.SizedBox(height: 3),
                    // Table
                    pw.Table(
                      border: pw.TableBorder.all(
                          color: PdfColors.blueGrey100, width: 0.4),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(20),
                        1: const pw.FixedColumnWidth(58),
                        2: const pw.FixedColumnWidth(44),
                        3: const pw.FlexColumnWidth(2.2),
                        4: const pw.FixedColumnWidth(52),
                        5: const pw.FixedColumnWidth(24),
                        6: const pw.FixedColumnWidth(24),
                        7: const pw.FixedColumnWidth(26),
                        8: const pw.FixedColumnWidth(54),
                        9: const pw.FixedColumnWidth(44),
                        10: const pw.FlexColumnWidth(1.4),
                        11: const pw.FixedColumnWidth(28),
                        12: const pw.FlexColumnWidth(1.8),
                      },
                      children: [
                        // Header row — bold white on indigo
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                              color: PdfColors.indigo700),
                          children: [
                            '#',
                            'Invoice No.',
                            'Date',
                            'Party Name',
                            'Amount',
                            'Pack',
                            'Loose',
                            'Cases',
                            'LR Number',
                            'Dispatch Dt.',
                            'Transport',
                            'Stage',
                            'E-Way Bill'
                          ]
                              .map((h) => pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 3, vertical: 4),
                                    child: pw.Text(h,
                                        style: pStyle(
                                            bold: true,
                                            color: PdfColors.white)),
                                  ))
                              .toList(),
                        ),
                        // Data rows
                        ...pageInvs.asMap().entries.map((e) {
                          final idx = pageStart + e.key;
                          final inv = e.value;
                          final cancelled = inv.isCancelled;
                          final bg = cancelled
                              ? PdfColors.grey200
                              : idx % 2 == 0
                                  ? PdfColors.white
                                  : const PdfColor.fromInt(0xFFFAFBFF);
                          final tc =
                              cancelled ? PdfColors.grey600 : PdfColors.black;
                          final dispDate =
                              s(inv.dispatchDate?.isNotEmpty == true
                                  ? inv.dispatchDate!
                                  : inv.lrDate.isNotEmpty
                                      ? inv.lrDate
                                      : '-');

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: bg),
                            children: [
                              '${idx + 1}',
                              s(inv.invoiceNumber),
                              s(inv.invoiceDate),
                              s(inv.partyName),
                              cancelled ? '-' : s(inv.invoiceAmount),
                              s(inv.packCase.isEmpty ? '-' : inv.packCase),
                              s(inv.looseCase.isEmpty ? '-' : inv.looseCase),
                              s(inv.totalCase.isEmpty ? '-' : inv.totalCase),
                              s(inv.lrNumber.isEmpty ? '-' : inv.lrNumber),
                              dispDate,
                              s(inv.transportName.isEmpty
                                  ? '-'
                                  : inv.transportName),
                              cancelled ? 'VOID' : _shortStage(inv.stage),
                              s(inv.ewayBillNumber.isEmpty
                                  ? '-'
                                  : inv.ewayBillNumber),
                            ]
                                .map((cell) => pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 3),
                                      child: pw.Text(cell,
                                          style: pStyle(color: tc)),
                                    ))
                                .toList(),
                          );
                        }),
                        // Totals row on last chunk
                        if (isLastChunk)
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColors.green50),
                            children: [
                              '',
                              'TOTAL (${invList.length})',
                              '',
                              '',
                              _sumAmt(invList),
                              _sumField(invList, (i) => i.packCase),
                              _sumField(invList, (i) => i.looseCase),
                              _sumField(invList, (i) => i.totalCase),
                              '',
                              '',
                              '',
                              '',
                              '',
                            ]
                                .map((cell) => pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 4),
                                      child: pw.Text(s(cell),
                                          style: pStyle(
                                              bold: true,
                                              color: PdfColors.green800)),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                    pw.Spacer(),
                    pw.Divider(thickness: 0.3),
                    pw.Row(children: [
                      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                          style: pStyle(size: 7, color: PdfColors.blueGrey400)),
                      pw.Spacer(),
                      pw.Text(
                          s('${company.name}  |  $seriesLabel  |  $fyLabel  |  ${invList.length} entries'),
                          style: pStyle(size: 7, color: PdfColors.blueGrey400)),
                    ]),
                  ]),
            ));
          }
        }
      }

      final bytes = await pdf.save();
      final compName = _selectedCompanyId != null
          ? _companies
              .firstWhere((c) => c.id == _selectedCompanyId,
                  orElse: () => const _CompanyInfo(id: '', name: 'All'))
              .name
          : 'All';
      final filename = 'InvoiceRegister_${_selectedFY}_$compName.pdf';

      if (mounted) setState(() => _exporting = false);

      // Open an in-app PDF preview (print / download available from preview toolbar)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(
            bytes: bytes,
            filename: filename,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Get.snackbar('PDF Export Failed', e.toString(),
            backgroundColor: AppTheme.danger, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── CSV Export ─────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final fyNext = (_selectedFY + 1).toString().substring(2);
      final fyLabel = 'FY $_selectedFY–$fyNext';
      final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final buffer = StringBuffer();
      buffer.write('\uFEFF'); // UTF-8 BOM for Excel
      buffer.writeln('Invoice Register — $fyLabel');
      buffer.writeln('Generated: $now');
      buffer.writeln();
      buffer.writeln(
          'Company,Series,#,Invoice No.,Date,Party Name,Amount,Pack,Loose,Total Cases,LR Number,Dispatch Date,Transport,Stage,E-Way Bill,Status');

      final companiesToShow = _selectedCompanyId != null
          ? _companies.where((c) => c.id == _selectedCompanyId).toList()
          : _companies;

      for (final company in companiesToShow) {
        final configs = _allConfigs
            .where((c) => c.companyId == company.id)
            .toList()
          ..sort((a, b) => a.seriesName.compareTo(b.seriesName));
        final allInvoices = _invoiceMap[company.id] ?? [];

        for (final cfg in configs) {
          final invList = _seriesInvoices(cfg, allInvoices);
          final sl = cfg.seriesName != 'Default' ? cfg.seriesName : 'Default';

          for (int i = 0; i < invList.length; i++) {
            final inv = invList[i];
            final cancelled = inv.isCancelled;
            final dispDate = inv.dispatchDate?.isNotEmpty == true
                ? inv.dispatchDate!
                : inv.lrDate;
            buffer.writeln([
              _e(company.name),
              _e(sl),
              '${i + 1}',
              _e(inv.invoiceNumber),
              _e(inv.invoiceDate),
              _e(inv.partyName),
              cancelled ? '' : inv.invoiceAmount,
              inv.packCase,
              inv.looseCase,
              inv.totalCase,
              _e(inv.lrNumber),
              _e(dispDate),
              _e(inv.transportName),
              cancelled ? 'CANCELLED' : AppStages.label(inv.stage),
              _e(inv.ewayBillNumber),
              cancelled ? 'CANCELLED' : 'Active',
            ].join(','));
          }

          if (invList.isNotEmpty) {
            buffer.writeln([
              _e(company.name),
              _e('$sl TOTAL'),
              '${invList.length}',
              '',
              '',
              '',
              _sumAmt(invList),
              _sumField(invList, (i) => i.packCase),
              _sumField(invList, (i) => i.looseCase),
              _sumField(invList, (i) => i.totalCase),
              '',
              '',
              '',
              '',
              '',
              '',
            ].join(','));
            buffer.writeln();
          }
        }
      }

      final bytes = Uint8List.fromList(buffer.toString().codeUnits);
      final compName = _selectedCompanyId != null
          ? _companies
              .firstWhere((c) => c.id == _selectedCompanyId,
                  orElse: () => const _CompanyInfo(id: '', name: 'All'))
              .name
          : 'All';

      // sharePdf works for any binary file — filename extension (.csv)
      // tells the OS / share target what type it is.
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'InvoiceRegister_${_selectedFY}_$compName.csv',
      );
    } catch (e) {
      if (mounted) {
        Get.snackbar('CSV Export Failed', e.toString(),
            backgroundColor: AppTheme.danger, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _e(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _sumAmt(List<InvoiceAcknowledgementData> invs) => _fmt(invs
      .fold<double>(0, (s, i) => s + (double.tryParse(i.invoiceAmount) ?? 0)));

  String _sumField(List<InvoiceAcknowledgementData> invs,
          String Function(InvoiceAcknowledgementData) getter) =>
      '${invs.fold<int>(0, (s, i) => s + (int.tryParse(getter(i)) ?? 0))}';

  String _shortStage(int s) {
    switch (s) {
      case 1:
        return 'INV';
      case 2:
        return 'PACK';
      case 3:
        return 'DISP';
      case 4:
        return 'ACK';
      case 5:
        return 'DONE';
      default:
        return '?';
    }
  }
}

// ─── Company-level section ────────────────────────────────────────────────────
class _CompanyRegisterSection extends StatefulWidget {
  final _CompanyInfo company;
  final List<InvoiceSeriesConfig> configs;
  final List<InvoiceAcknowledgementData> invoices;
  final int fy;
  final List<InvoiceAcknowledgementData> Function(
          InvoiceSeriesConfig, List<InvoiceAcknowledgementData>)
      seriesInvoicesBuilder;

  const _CompanyRegisterSection({
    required this.company,
    required this.configs,
    required this.invoices,
    required this.fy,
    required this.seriesInvoicesBuilder,
  });

  @override
  State<_CompanyRegisterSection> createState() =>
      _CompanyRegisterSectionState();
}

class _CompanyRegisterSectionState extends State<_CompanyRegisterSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final fyNext = (widget.fy + 1).toString().substring(2);
    final fyLabel = 'FY ${widget.fy}–$fyNext';
    final totalInvoices = widget.invoices.length;
    final totalAmount = widget.invoices.fold<double>(
        0, (s, inv) => s + (double.tryParse(inv.invoiceAmount) ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Company header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: _expanded ? Radius.zero : const Radius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: _expanded ? Radius.zero : const Radius.circular(16),
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
                    color: AppTheme.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          '$fyLabel  ·  $totalInvoices invoices  ·  ₹${_fmt(totalAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              const SizedBox(width: 8),
              Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 22),
            ]),
          ),
        ),
        // Series sections
        if (_expanded) ...[
          if (widget.configs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No series configured for this company in $fyLabel.',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            )
          else
            ...widget.configs.map((cfg) {
              final seriesInvs =
                  widget.seriesInvoicesBuilder(cfg, widget.invoices);
              return _SeriesRegisterTable(config: cfg, invoices: seriesInvs);
            }).toList(),
        ],
      ]),
    );
  }
}

// ─── Per-series table ─────────────────────────────────────────────────────────
class _SeriesRegisterTable extends StatelessWidget {
  final InvoiceSeriesConfig config;
  final List<InvoiceAcknowledgementData> invoices;

  const _SeriesRegisterTable({required this.config, required this.invoices});

  // Fixed pixel widths — consistent column layout
  static const List<double> _colW = [
    28, // #
    76, // Invoice No
    54, // Date
    134, // Party Name
    70, // Amount
    36, // Pack
    36, // Loose
    36, // Total
    82, // LR No
    60, // Dispatch
    82, // Transport
    42, // Stage
    92, // E-way
  ];

  static const List<String> _headers = [
    '#',
    'Invoice No.',
    'Date',
    'Party Name',
    'Amount (₹)',
    'Pack',
    'Loose',
    'Cases',
    'LR Number',
    'Disp. Date',
    'Transport',
    'Stage',
    'E-Way Bill'
  ];

  static const List<TextAlign> _aligns = [
    TextAlign.center,
    TextAlign.left,
    TextAlign.left,
    TextAlign.left,
    TextAlign.right,
    TextAlign.center,
    TextAlign.center,
    TextAlign.center,
    TextAlign.left,
    TextAlign.left,
    TextAlign.left,
    TextAlign.center,
    TextAlign.left,
  ];

  @override
  Widget build(BuildContext context) {
    final seriesLabel =
        config.seriesName != 'Default' ? config.seriesName : 'Default Series';
    final totalAmt = invoices.fold<double>(
        0, (s, inv) => s + (double.tryParse(inv.invoiceAmount) ?? 0));
    final totalPack = invoices.fold<int>(
        0, (s, inv) => s + (int.tryParse(inv.packCase) ?? 0));
    final totalLoose = invoices.fold<int>(
        0, (s, inv) => s + (int.tryParse(inv.looseCase) ?? 0));
    final totalCase = invoices.fold<int>(
        0, (s, inv) => s + (int.tryParse(inv.totalCase) ?? 0));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 1, color: AppTheme.divider),
      // Series header — Flexible + Flexible on chip avoids overflow on narrow screens
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        child: Row(children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.layers_rounded,
                    size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(seriesLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: AppTheme.primary)),
                ),
                if (config.prefix.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('(${config.prefix})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Text('${invoices.length} inv',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('₹${_fmt(totalAmt)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success)),
        ]),
      ),

      if (invoices.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Row(children: [
              Icon(Icons.inbox_rounded,
                  size: 16, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Text('No invoices entered yet for this series.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
        )
      else ...[
        // Horizontally scrollable table so narrow devices don't overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              _HeaderRow(headers: _headers, colWidths: _colW, aligns: _aligns),
              // Invoice rows
              ...invoices.asMap().entries.map((e) => _InvoiceRow(
                  invoice: e.value,
                  index: e.key,
                  config: config,
                  colWidths: _colW,
                  aligns: _aligns)),
              // Totals row
              _TotalsRow(
                colWidths: _colW,
                aligns: _aligns,
                count: invoices.length,
                totalAmt: totalAmt,
                pack: totalPack,
                loose: totalLoose,
                total: totalCase,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

// ─── Table sub-widgets ────────────────────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final List<String> headers;
  final List<double> colWidths;
  final List<TextAlign> aligns;
  const _HeaderRow(
      {required this.headers, required this.colWidths, required this.aligns});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEF0FF),
      child: Row(
        children: List.generate(
            headers.length,
            (i) => SizedBox(
                  width: colWidths[i],
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: i == 0 ? 4 : 6, vertical: 7),
                    child: Text(headers[i],
                        textAlign: aligns[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: 0.1)),
                  ),
                )),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final List<double> colWidths;
  final List<TextAlign> aligns;
  final int count;
  final double totalAmt;
  final int pack, loose, total;

  const _TotalsRow({
    required this.colWidths,
    required this.aligns,
    required this.count,
    required this.totalAmt,
    required this.pack,
    required this.loose,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cells = [
      '',
      'TOTAL ($count)',
      '',
      '',
      _fmt(totalAmt),
      '$pack',
      '$loose',
      '$total',
      '',
      '',
      '',
      '',
      '',
    ];
    return Container(
      color: const Color(0xFFE8F5E9),
      child: Row(
        children: List.generate(
            cells.length,
            (i) => SizedBox(
                  width: colWidths[i],
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: i == 0 ? 4 : 6, vertical: 7),
                    child: Text(cells[i],
                        textAlign: aligns[i],
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.success)),
                  ),
                )),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final InvoiceAcknowledgementData invoice;
  final int index;
  final InvoiceSeriesConfig config;
  final List<double> colWidths;
  final List<TextAlign> aligns;

  const _InvoiceRow({
    required this.invoice,
    required this.index,
    required this.config,
    required this.colWidths,
    required this.aligns,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled = invoice.isCancelled;
    final even = index % 2 == 0;
    final stageColor =
        cancelled ? Colors.grey.shade400 : AppStages.color(invoice.stage);
    final dispDate = invoice.dispatchDate?.isNotEmpty == true
        ? invoice.dispatchDate!
        : invoice.lrDate.isNotEmpty
            ? invoice.lrDate
            : '—';

    // Values for each column in order
    final vals = [
      '${index + 1}',
      invoice.invoiceNumber,
      invoice.invoiceDate,
      invoice.partyName,
      cancelled ? '—' : invoice.invoiceAmount,
      invoice.packCase.isEmpty ? '—' : invoice.packCase,
      invoice.looseCase.isEmpty ? '—' : invoice.looseCase,
      invoice.totalCase.isEmpty ? '—' : invoice.totalCase,
      invoice.lrNumber.isEmpty ? '—' : invoice.lrNumber,
      dispDate,
      invoice.transportName.isEmpty ? '—' : invoice.transportName,
      '__STAGE__',
      invoice.ewayBillNumber.isEmpty ? '—' : invoice.ewayBillNumber,
    ];

    return Container(
      decoration: BoxDecoration(
        color: cancelled
            ? const Color(0xFFF5F5F5)
            : even
                ? Colors.white
                : const Color(0xFFFAFBFF),
        border: const Border(
            bottom: BorderSide(color: Color(0xFFEEF0F8), width: 0.7)),
      ),
      child: Row(
        children: List.generate(vals.length, (i) {
          if (vals[i] == '__STAGE__') {
            return SizedBox(
              width: colWidths[i],
              child: Center(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    cancelled ? 'VOID' : _shortStage(invoice.stage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: stageColor,
                        letterSpacing: 0.2),
                  ),
                ),
              ),
            );
          }

          Color textColor;
          FontWeight fw;
          TextDecoration? dec;
          if (cancelled) {
            textColor = Colors.grey.shade500;
            fw = i == 1 ? FontWeight.w700 : FontWeight.w500;
            dec = i == 1 ? TextDecoration.lineThrough : null;
          } else if (i == 1) {
            textColor = AppTheme.primary;
            fw = FontWeight.w700;
            dec = null;
          } else if (i == 4) {
            textColor = AppTheme.success;
            fw = FontWeight.w700;
            dec = null;
          } else if (i == 7) {
            textColor = AppTheme.textPrimary;
            fw = FontWeight.w700;
            dec = null;
          } else {
            textColor = AppTheme.textPrimary;
            fw = FontWeight.w500;
            dec = null;
          }

          return SizedBox(
            width: colWidths[i],
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: i == 0 ? 4 : 6, vertical: 6),
              child: Text(vals[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: aligns[i],
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: fw,
                      color: textColor,
                      decoration: dec)),
            ),
          );
        }),
      ),
    );
  }

  String _shortStage(int s) {
    switch (s) {
      case 1:
        return 'INV';
      case 2:
        return 'PACK';
      case 3:
        return 'DISP';
      case 4:
        return 'ACK';
      case 5:
        return 'DONE';
      default:
        return '?';
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _CompanyInfo {
  final String id;
  final String name;
  const _CompanyInfo({required this.id, required this.name});
}

String _fmt(double v) => NumberFormat('#,##,##0.00', 'en_IN').format(v);

// ─── PDF Preview Screen ────────────────────────────────────────────────────────
// Opens the generated PDF bytes in an in-app viewer with print/download toolbar.
class _PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  const _PdfPreviewScreen({required this.bytes, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filename,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share / Download',
            onPressed: () =>
                Printing.sharePdf(bytes: bytes, filename: filename),
          ),
        ],
      ),
      body: PdfPreview(
        maxPageWidth: 1200,
        build: (_) => bytes,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: filename,
      ),
    );
  }
}
