// ─────────────────────────────────────────────────────────────────────────────
//  Office — Register entries (within one register), with monthly PDF export.
//  Ported from register_entries_view.dart. Api.* -> ApiService, the
//  hardcoded "1234" PIN delete replaced with canDelete, Add gated by
//  canAdd. Only reachable through office_registers.dart, which
//  already guards entry.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

class RegisterEntriesView extends StatefulWidget {
  final String registerId;
  final Map<String, dynamic> regData;
  const RegisterEntriesView({super.key, required this.registerId, required this.regData});

  @override
  State<RegisterEntriesView> createState() => _RegisterEntriesViewState();
}

class _RegisterEntriesViewState extends State<RegisterEntriesView> {
  final _api = ApiService();
  final Map<String, dynamic> _entryValues = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (var h in widget.regData['columnHeadings']) {
      _controllers[h] = TextEditingController();
    }
  }

  void _performAutoFill(Map<String, dynamic> contact) {
    for (String h in widget.regData['columnHeadings']) {
      String key = h.toLowerCase();
      if (key.contains('phone')) _updateField(h, contact['phone']);
      if (key.contains('firm')) _updateField(h, contact['firmName']);
      if (key.contains('city') || key.contains('address')) _updateField(h, contact['city']);
    }
  }

  void _updateField(String h, dynamic v) {
    if (v != null) {
      _entryValues[h] = v.toString();
      _controllers[h]?.text = v.toString();
    }
  }

  Future<void> _showMonthYearPicker() async {
    int selYear = DateTime.now().year;
    int selMonth = DateTime.now().month;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setSt) => AlertDialog(
                title: const Text("Monthly Report"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButton<int>(
                      value: selYear,
                      isExpanded: true,
                      items: List.generate(
                              (DateTime.now().year - 2025 + 1).clamp(1, 100),
                              (i) => DateTime.now().year - i)
                          .map((y) => DropdownMenuItem(value: y, child: Text("Year $y")))
                          .toList(),
                      onChanged: (v) => setSt(() => selYear = v!)),
                  DropdownButton<int>(
                      value: selMonth,
                      isExpanded: true,
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text("Month $m")))
                          .toList(),
                      onChanged: (v) => setSt(() => selMonth = v!)),
                ]),
                actions: [
                  ElevatedButton(onPressed: () => _generatePDF(selYear, selMonth), child: const Text("GENERATE")),
                ],
              )),
    );
  }

  Future<void> _generatePDF(int y, int m) async {
    DateTime start = DateTime(y, m, 1);
    DateTime end = DateTime(y, m + 1, 0, 23, 59, 59);

    final allEntries = await _api.getRegisterEntries(widget.registerId);
    final entries = allEntries.where((data) {
      final created = DateTime.tryParse(data['createdAt']?.toString() ?? '');
      if (created == null) return false;
      return !created.isBefore(start) && !created.isAfter(end);
    }).toList();

    final pdf = pw.Document();
    final heads = List<String>.from(widget.regData['columnHeadings']);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (ctx) => [
        pw.Header(level: 0, text: "${widget.regData['registerName']} - $m/$y"),
        pw.TableHelper.fromTextArray(
          headers: ["TrackID", ...heads],
          data: entries.map((data) {
            return [data['trackingID'], ...heads.map((h) => data[h] ?? '')];
          }).toList(),
        ),
      ],
    ));

    final file = File("${(await getTemporaryDirectory()).path}/report.pdf");
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)]);
  }

  void _confirmDelete(String id) {
    if (!AuthService.to.perms.canDelete(ScreenKeys.officeRegisters)) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await _api.deleteRegisterEntry(widget.registerId, id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? "Entry deleted" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heads = List<String>.from(widget.regData['columnHeadings']);
    final perms = AuthService.to.perms;
    return Scaffold(
      appBar: AppBar(title: Text(widget.regData['registerName']), actions: [
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: _showMonthYearPicker),
      ]),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: officePollingStream(() async {
          final list = await _api.getRegisterEntries(widget.registerId);
          list.sort((a, b) {
            final ad = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(0);
            final bd = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(0);
            return bd.compareTo(ad);
          });
          return list;
        }),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                  child: DataTable(
                columns: [
                  const DataColumn(label: Text("ID")),
                  ...heads.map((h) => DataColumn(label: Text(h))),
                  const DataColumn(label: Text("Action")),
                ],
                rows: snapshot.data!.map((data) {
                  return DataRow(cells: [
                    DataCell(Text(data['trackingID'] ?? '', style: const TextStyle(fontSize: 10))),
                    ...heads.map((h) => DataCell(Text(data[h]?.toString() ?? ''))),
                    DataCell(perms.canDelete(ScreenKeys.officeRegisters)
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(data['id']))
                        : const SizedBox.shrink()),
                  ]);
                }).toList(),
              )));
        },
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeRegisters)
          ? FloatingActionButton(onPressed: _showAddEntryDialog, child: const Icon(Icons.add))
          : null,
    );
  }

  void _showAddEntryDialog() {
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, setSt) => AlertDialog(
                  title: const Text("New Entry"),
                  content: SingleChildScrollView(
                      child: Column(
                          children: List.generate(widget.regData['columnHeadings'].length, (i) {
                    String h = widget.regData['columnHeadings'][i];
                    String t = widget.regData['columnTypes'][i];
                    if (t == 'Sequence') {
                      return ListTile(title: Text("$h: ${(widget.regData['entryCount'] ?? 0) + 1}"));
                    }
                    if (t == 'App Contact') {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: officePollingStream(() {
                          final categoryName = widget.regData['columnCategories'][i];
                          return _api.getOfficeCategoryEntries('address-book', categoryName);
                        }),
                        builder: (context, snap) => DropdownButtonFormField<String>(
                          items: snap.hasData
                              ? snap.data!.map((d) => DropdownMenuItem(value: d['name'].toString(), child: Text(d['name']))).toList()
                              : [],
                          onChanged: (v) {
                            var contact = snap.data!.firstWhere((d) => d['name'] == v);
                            _entryValues[h] = v;
                            _performAutoFill(contact);
                            setSt(() {});
                          },
                          decoration: InputDecoration(labelText: h),
                        ),
                      );
                    }
                    return TextField(
                        controller: _controllers[h],
                        decoration: InputDecoration(labelText: h),
                        onChanged: (v) => _entryValues[h] = v);
                  }))),
                  actions: [
                    ElevatedButton(
                        onPressed: () async {
                          _entryValues['trackingID'] =
                              DateTime.now().millisecondsSinceEpoch.toString().substring(8);
                          // The API creates the entry and increments the
                          // register's entry_count server-side in one call.
                          await _api.addRegisterEntry(widget.registerId, _entryValues);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text("SAVE"))
                  ],
                )));
  }
}
