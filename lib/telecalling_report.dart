// ─────────────────────────────────────────────────────────────────────────────
//  Telecalling — downloadable PDF report.
//
//  Opened from the report icon on the Telecalling screen's top panel.
//  Lets the user pick a month range (by invoice date) and which optional
//  columns to include, on top of the always-included "mandatory" columns.
//  Which columns are mandatory is admin-configurable (gear icon, admin
//  accounts only) and persisted server-side so it applies for everyone.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/data.dart';
import 'package:form_app/step1.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const _kBar = Color(0xFF0F4C75);

// ── Column catalogue ────────────────────────────────────────────────────────
class TelecallReportColumn {
  final String key;
  final String label;
  const TelecallReportColumn(this.key, this.label);
}

const List<TelecallReportColumn> kTelecallReportColumns = [
  TelecallReportColumn('companyName', 'Company'),
  TelecallReportColumn('partyName', 'Party Name'),
  TelecallReportColumn('invoiceNumber', 'Invoice Number'),
  TelecallReportColumn('invoiceDate', 'Invoice Date'),
  TelecallReportColumn('deliveryDate', 'Delivery Date'),
  TelecallReportColumn('invoiceAmount', 'Invoice Amount'),
  TelecallReportColumn('orderType', 'Order Type'),
  TelecallReportColumn('stage', 'Stage'),
  TelecallReportColumn('lrNumber', 'LR Number'),
  TelecallReportColumn('lrDate', 'LR Date'),
  TelecallReportColumn('dispatchDate', 'Dispatch Date'),
  TelecallReportColumn('transportName', 'Transport'),
  TelecallReportColumn('partyContact', 'Party Contact'),
  TelecallReportColumn('contactPersonCalled', 'Received By'),
  TelecallReportColumn('temperature', 'Temperature'),
  TelecallReportColumn('telecallStatus', 'Call Status'),
  TelecallReportColumn('callAttempts', 'Call Attempts'),
  TelecallReportColumn('lastCalledAt', 'Last Called At'),
];

// Used only until the admin saves a config of their own (or if that call fails).
const List<String> kDefaultMandatoryColumnKeys = [
  'companyName',
  'partyName',
  'invoiceNumber',
  'invoiceDate',
  'deliveryDate',
];

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(int? epochMs) => epochMs == null
    ? '-'
    : DateFormat('dd-MM-yyyy').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

String _fmtDateTime(int? epochMs) => epochMs == null
    ? '-'
    : DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(epochMs));

// invoiceDate is saved as dd-MM-yyyy (see step1.dart) but has shown up as
// dd/MM/yyyy in older records too, and some entries aren't zero-padded
// (e.g. "9-9-2026") — a strict single-format DateFormat parse silently
// fails on all of these and was the reason the report came back blank
// for every date range. Parsed manually instead so both separators and
// unpadded day/month values work.
DateTime? _parseInvoiceDate(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final parts = v.replaceAll('/', '-').split('-');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  try {
    return DateTime(year, month, day);
  } catch (_) {
    return null;
  }
}

String telecallColumnValue(String key, InvoiceData inv) {
  switch (key) {
    case 'companyName':
      return inv.companyName.isNotEmpty ? inv.companyName : '-';
    case 'partyName':
      return inv.partyData.partyName.isNotEmpty ? inv.partyData.partyName : '-';
    case 'invoiceNumber':
      return inv.invoiceNumber;
    case 'invoiceDate':
      return inv.invoiceDate.isNotEmpty ? inv.invoiceDate : '-';
    case 'deliveryDate':
      return _fmtDate(inv.telecallDeliveryTime);
    case 'invoiceAmount':
      return inv.invoiceAmount.isNotEmpty ? inv.invoiceAmount : '-';
    case 'orderType':
      return OrderTypeX.fromKey(inv.orderType).label;
    case 'stage':
      return 'Stage ${inv.stage} - ${AppStages.label(inv.stage)}';
    case 'lrNumber':
      return inv.lrNumber?.isNotEmpty == true ? inv.lrNumber! : '-';
    case 'lrDate':
      return inv.lrDate?.isNotEmpty == true ? inv.lrDate! : '-';
    case 'dispatchDate':
      return inv.dispatchDate?.isNotEmpty == true ? inv.dispatchDate! : '-';
    case 'transportName':
      return inv.transportName.isNotEmpty ? inv.transportName : '-';
    case 'partyContact':
      return inv.partyData.contactNumber1.isNotEmpty ? inv.partyData.contactNumber1 : '-';
    case 'contactPersonCalled':
      return inv.telecallContactPerson?.isNotEmpty == true ? inv.telecallContactPerson! : '-';
    case 'temperature':
      return inv.telecallTemperature?.isNotEmpty == true ? inv.telecallTemperature! : '-';
    case 'telecallStatus':
      switch (inv.telecallStatus) {
        case 'delivered':
          return 'Delivered';
        case 'not_delivered':
          return 'Not Delivered';
        default:
          return 'Calling Needed';
      }
    case 'callAttempts':
      return '${inv.telecallAttempts ?? 0}';
    case 'lastCalledAt':
      return _fmtDateTime(inv.telecallLastCalledAt);
    default:
      return '-';
  }
}

// ── Entry point — call this from the report icon ────────────────────────────
Future<void> showTelecallReportSheet(BuildContext context, List<InvoiceData> allInvoices) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TelecallReportSheet(allInvoices: allInvoices),
  );
}

// ── Report configuration sheet ───────────────────────────────────────────────
class _TelecallReportSheet extends StatefulWidget {
  final List<InvoiceData> allInvoices;
  const _TelecallReportSheet({required this.allInvoices});

  @override
  State<_TelecallReportSheet> createState() => _TelecallReportSheetState();
}

class _TelecallReportSheetState extends State<_TelecallReportSheet> {
  final _api = ApiService();

  late int _fromMonth;
  late int _fromYear;
  late int _toMonth;
  late int _toYear;

  List<String> _mandatoryKeys = List.of(kDefaultMandatoryColumnKeys);
  final Set<String> _selectedOptional = {};
  bool _loadingConfig = true;
  bool _generating = false;
  String _format = 'pdf'; // 'pdf' | 'excel'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromMonth = now.month;
    _fromYear = now.year;
    _toMonth = now.month;
    _toYear = now.year;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final saved = await _api.getTelecallReportMandatoryColumns();
      if (saved != null && saved.isNotEmpty) _mandatoryKeys = saved;
    } catch (_) {
      // Fall back to the default mandatory list — non-fatal.
    }
    if (mounted) setState(() => _loadingConfig = false);
  }

  List<TelecallReportColumn> get _optionalColumns =>
      kTelecallReportColumns.where((c) => !_mandatoryKeys.contains(c.key)).toList();

  Future<void> _openAdminConfig() async {
    final updated = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MandatoryColumnsAdminDialog(currentMandatory: _mandatoryKeys),
    );
    if (updated != null && mounted) {
      setState(() {
        _mandatoryKeys = updated;
        _selectedOptional.removeWhere((k) => _mandatoryKeys.contains(k));
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final fromDate = DateTime(_fromYear, _fromMonth, 1);
      final toDate = DateTime(_toYear, _toMonth + 1, 0); // last day of "to" month
      final filtered = widget.allInvoices.where((inv) {
        final d = _parseInvoiceDate(inv.invoiceDate);
        if (d == null) return false;
        return !d.isBefore(fromDate) && !d.isAfter(toDate);
      }).toList()
        ..sort((a, b) => (_parseInvoiceDate(a.invoiceDate) ?? DateTime(2000))
            .compareTo(_parseInvoiceDate(b.invoiceDate) ?? DateTime(2000)));

      final columnKeys = [..._mandatoryKeys, ..._selectedOptional];
      final periodLabel =
          '${_monthNames[_fromMonth - 1]} $_fromYear - ${_monthNames[_toMonth - 1]} $_toYear';
      final baseFilename = 'Telecalling_Report_${_fromYear}_${_fromMonth}_to_${_toYear}_$_toMonth';

      if (_format == 'excel') {
        final bytes = _buildTelecallReportCsv(
          invoices: filtered,
          columnKeys: columnKeys,
          periodLabel: periodLabel,
        );
        if (!mounted) return;
        Navigator.pop(context);
        // sharePdf works for any binary file — the .csv extension tells
        // the OS / share target what type it is. Excel opens CSV natively.
        await Printing.sharePdf(bytes: bytes, filename: '$baseFilename.csv');
      } else {
        final bytes = await _buildTelecallReportPdf(
          invoices: filtered,
          columnKeys: columnKeys,
          periodLabel: periodLabel,
        );
        if (!mounted) return;
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _TelecallReportPdfPreview(bytes: bytes, filename: '$baseFilename.pdf'),
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Report Failed', e.toString(),
          backgroundColor: Colors.red.shade100, colorText: Colors.red.shade900);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.to.perms.isAdmin;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetCtx, scrollController) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Expanded(
            child: _loadingConfig
                ? const Center(child: CircularProgressIndicator(color: _kBar))
                : SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: _kBar),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Telecalling Report',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                        if (isAdmin)
                          IconButton(
                            icon: const Icon(Icons.settings_rounded, size: 20, color: Color(0xFF8892B0)),
                            tooltip: 'Configure mandatory columns',
                            onPressed: _openAdminConfig,
                          ),
                      ]),
                      const SizedBox(height: 14),

                      const Text('Period (by invoice month)',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6480))),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _monthYearPicker('From', _fromMonth, _fromYear,
                                (m) => setState(() => _fromMonth = m), (y) => setState(() => _fromYear = y))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _monthYearPicker('To', _toMonth, _toYear,
                                (m) => setState(() => _toMonth = m), (y) => setState(() => _toYear = y))),
                      ]),
                      const SizedBox(height: 18),

                      const Text('File Format',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6480))),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _formatOption('pdf', 'PDF', Icons.picture_as_pdf_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _formatOption('excel', 'Excel', Icons.grid_on_rounded)),
                      ]),
                      const SizedBox(height: 18),

                      const Text('Mandatory Columns',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6480))),
                      const SizedBox(height: 2),
                      const Text('Always included in every report.',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF8892B0))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _mandatoryKeys.map((k) {
                          final col = kTelecallReportColumns.firstWhere((c) => c.key == k,
                              orElse: () => TelecallReportColumn(k, k));
                          return Chip(
                            avatar: const Icon(Icons.lock_rounded, size: 13, color: _kBar),
                            label: Text(col.label, style: const TextStyle(fontSize: 11.5)),
                            backgroundColor: _kBar.withValues(alpha: 0.08),
                            side: BorderSide(color: _kBar.withValues(alpha: 0.2)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Optional Columns',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6480))),
                      const SizedBox(height: 2),
                      const Text('Pick any extra columns you need for this report.',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF8892B0))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _optionalColumns.map((c) {
                          final sel = _selectedOptional.contains(c.key);
                          return FilterChip(
                            label: Text(c.label, style: const TextStyle(fontSize: 11.5)),
                            selected: sel,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedOptional.add(c.key);
                              } else {
                                _selectedOptional.remove(c.key);
                              }
                            }),
                            selectedColor: _kBar.withValues(alpha: 0.15),
                            checkmarkColor: _kBar,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _generating ? null : _generate,
                          icon: _generating
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf_rounded),
                          label: Text(_generating ? 'Generating…' : 'Generate ${_format == 'excel' ? 'Excel' : 'PDF'}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBar,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _formatOption(String value, String label, IconData icon) {
    final sel = _format == value;
    return GestureDetector(
      onTap: () => setState(() => _format = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? _kBar : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _kBar : const Color(0xFFDDE0EE), width: sel ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: sel ? Colors.white : const Color(0xFF8892B0)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : const Color(0xFF5A6480))),
        ]),
      ),
    );
  }

  Widget _monthYearPicker(
      String label, int month, int year, ValueChanged<int> onMonth, ValueChanged<int> onYear) {
    // Data only goes back to 2025 — don't offer earlier, empty years.
    final years = List.generate(
        (DateTime.now().year - 2025 + 1).clamp(1, 100),
        (i) => DateTime.now().year - i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDE0EE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF8892B0), fontWeight: FontWeight.w700)),
        Row(children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: month,
                isExpanded: true,
                isDense: true,
                items: List.generate(
                    12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i], style: const TextStyle(fontSize: 13)))),
                onChanged: (v) {
                  if (v != null) onMonth(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: year,
              isDense: true,
              items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                if (v != null) onYear(v);
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Admin: configure which columns are mandatory ─────────────────────────────
class _MandatoryColumnsAdminDialog extends StatefulWidget {
  final List<String> currentMandatory;
  const _MandatoryColumnsAdminDialog({required this.currentMandatory});

  @override
  State<_MandatoryColumnsAdminDialog> createState() => _MandatoryColumnsAdminDialogState();
}

class _MandatoryColumnsAdminDialogState extends State<_MandatoryColumnsAdminDialog> {
  late Set<String> _mandatory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mandatory = Set.of(widget.currentMandatory);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ok = await ApiService().saveTelecallReportMandatoryColumns(_mandatory.toList());
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, _mandatory.toList());
      } else {
        Get.snackbar('Save Failed', 'Could not save the mandatory columns configuration.',
            backgroundColor: Colors.red.shade100, colorText: Colors.red.shade900);
      }
    } catch (e) {
      Get.snackbar('Save Failed', e.toString(), backgroundColor: Colors.red.shade100, colorText: Colors.red.shade900);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Configure Mandatory Columns', style: TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Columns checked here are always included in every report and cannot be unchecked by other users.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF8892B0))),
            const SizedBox(height: 10),
            ...kTelecallReportColumns.map((c) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(c.label, style: const TextStyle(fontSize: 13)),
                  value: _mandatory.contains(c.key),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _mandatory.add(c.key);
                    } else {
                      _mandatory.remove(c.key);
                    }
                  }),
                )),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _kBar, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── PDF generation ────────────────────────────────────────────────────────────
// ── CSV ("Excel") generation ─────────────────────────────────────────────────
String _csvEscape(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

Uint8List _buildTelecallReportCsv({
  required List<InvoiceData> invoices,
  required List<String> columnKeys,
  required String periodLabel,
}) {
  final columns = kTelecallReportColumns.where((c) => columnKeys.contains(c.key)).toList();
  final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  final buffer = StringBuffer();
  buffer.write('﻿'); // UTF-8 BOM so Excel reads it correctly
  buffer.writeln(_csvEscape('Telecalling Delivery Report - $periodLabel'));
  buffer.writeln(_csvEscape('Generated: $generatedAt'));
  buffer.writeln();
  buffer.writeln(columns.map((c) => _csvEscape(c.label)).join(','));
  for (final inv in invoices) {
    buffer.writeln(columns.map((c) => _csvEscape(telecallColumnValue(c.key, inv))).join(','));
  }
  buffer.writeln();
  buffer.writeln(_csvEscape('${invoices.length} invoice(s)'));

  return Uint8List.fromList(buffer.toString().codeUnits);
}

Future<Uint8List> _buildTelecallReportPdf({
  required List<InvoiceData> invoices,
  required List<String> columnKeys,
  required String periodLabel,
}) async {
  // Unicode-capable fonts — the default Helvetica PDF font has no support
  // for the rupee symbol, em-dashes, etc.
  final fontRegular = await PdfGoogleFonts.notoSansRegular();
  final fontBold = await PdfGoogleFonts.notoSansBold();
  pw.TextStyle pStyle({double size = 7, bool bold = false, PdfColor color = PdfColors.black}) =>
      pw.TextStyle(font: bold ? fontBold : fontRegular, fontSize: size, color: color);

  final columns = kTelecallReportColumns.where((c) => columnKeys.contains(c.key)).toList();
  final pdf = pw.Document();
  const rowsPerPage = 26;
  final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  pw.Widget header(pw.Context ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text('Telecalling Delivery Report', style: pStyle(size: 13, bold: true))),
          pw.Text('$periodLabel  |  Generated $generatedAt',
              style: pStyle(size: 7, color: PdfColors.blueGrey400)),
        ]),
        pw.SizedBox(height: 6),
        pw.Divider(thickness: 0.4),
        pw.SizedBox(height: 4),
      ]);

  pw.Widget footer(pw.Context ctx) => pw.Column(children: [
        pw.Divider(thickness: 0.3),
        pw.Row(children: [
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pStyle(size: 7, color: PdfColors.blueGrey400)),
          pw.Spacer(),
          pw.Text('${invoices.length} invoice(s)', style: pStyle(size: 7, color: PdfColors.blueGrey400)),
        ]),
      ]);

  if (invoices.isEmpty) {
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        header(ctx),
        pw.Expanded(
            child: pw.Center(
                child: pw.Text('No invoices found for $periodLabel', style: pStyle(size: 12, color: PdfColors.blueGrey400)))),
        footer(ctx),
      ]),
    ));
  } else {
    for (int pageStart = 0; pageStart < invoices.length; pageStart += rowsPerPage) {
      final pageEnd = (pageStart + rowsPerPage) < invoices.length ? (pageStart + rowsPerPage) : invoices.length;
      final pageInvs = invoices.sublist(pageStart, pageEnd);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          header(ctx),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.4),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                children: columns
                    .map((c) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                          child: pw.Text(c.label, style: pStyle(bold: true, color: PdfColors.white)),
                        ))
                    .toList(),
              ),
              ...pageInvs.asMap().entries.map((e) {
                final bg = e.key % 2 == 0 ? PdfColors.white : const PdfColor.fromInt(0xFFFAFBFF);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: columns
                      .map((c) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: pw.Text(telecallColumnValue(c.key, e.value), style: pStyle()),
                          ))
                      .toList(),
                );
              }),
            ],
          ),
          pw.Spacer(),
          footer(ctx),
        ]),
      ));
    }
  }

  return pdf.save();
}

// ── PDF preview / share screen ────────────────────────────────────────────────
class _TelecallReportPdfPreview extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  const _TelecallReportPdfPreview({required this.bytes, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filename, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
        backgroundColor: _kBar,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share / Download',
            onPressed: () => Printing.sharePdf(bytes: bytes, filename: filename),
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
