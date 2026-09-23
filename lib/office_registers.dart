// ─────────────────────────────────────────────────────────────────────────────
//  Office — Registers
//
//  Matches the reference screenshot: colour-coded circle avatar per
//  register (first letter of its name), an entry-count pill next to
//  the title, a delete action, dark teal app bar with a list icon that
//  opens "Manage Dropdown Lists".
//
//  New column type "Dropdown" added (alongside the original Text /
//  Sequence / Date / App Contact), bound to a reusable named list from
//  office_dropdown_lists_manager.dart — that's the genuinely new part;
//  everything else here already existed, just re-skinned.
//
//  ⚠ Two backend assumptions, both flagged where used:
//   - Entry counts read `data['entryCount']` from getRegisters(); if
//     the backend doesn't return that field yet, counts show as 0.
//   - Deleting a register calls a new deleteRegister() method that
//     mirrors this API's existing REST pattern but was never called
//     before — verify DELETE /api/registers/:id actually exists.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/office_register_entries_view.dart';
import 'package:form_app/office_dropdown_lists_manager.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const Color _kRegistersTeal = Color(0xFF0D5C63);

const List<Color> _kAvatarColors = [
  Color(0xFF0D5C63), Color(0xFF1E88E5), Color(0xFF7B1FA2),
  Color(0xFF2E7D32), Color(0xFFEF6C00), Color(0xFF6D4C41),
];

class RegisterModule extends StatefulWidget {
  const RegisterModule({super.key});

  @override
  State<RegisterModule> createState() => _RegisterModuleState();
}

class _RegisterModuleState extends State<RegisterModule> {
  final _api = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _columnCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officeRegisters, label: 'Registers'));
  }

  void _showCreateRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Register Setup"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Register Name")),
            TextField(
                controller: _columnCountController,
                decoration: const InputDecoration(labelText: "Number of Columns"),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              int count = int.tryParse(_columnCountController.text) ?? 0;
              if (_nameController.text.isNotEmpty && count > 0) {
                Navigator.pop(context);
                _showColumnConfigDialog(_nameController.text, count);
              }
            },
            child: const Text("NEXT"),
          )
        ],
      ),
    );
  }

  void _showColumnConfigDialog(String regName, int count) {
    List<TextEditingController> headCtrls = List.generate(count, (i) => TextEditingController());
    List<String> types = List.generate(count, (i) => 'Text');
    // Reused for both "App Contact" (an address-book category name) and
    // the new "Dropdown" type (a dropdown-list name).
    List<String?> selectedCats = List.generate(count, (i) => null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Configure Columns"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: count,
              itemBuilder: (context, i) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(controller: headCtrls[i], decoration: InputDecoration(labelText: "Heading ${i + 1}")),
                      DropdownButton<String>(
                        value: types[i],
                        isExpanded: true,
                        items: ['Text', 'Sequence', 'Date', 'App Contact', 'Dropdown']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() { types[i] = v!; selectedCats[i] = null; });
                        },
                      ),
                      if (types[i] == 'App Contact')
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: officePollingStream(() => _api.getOfficeCategories('address-book')),
                          builder: (context, snap) {
                            if (!snap.hasData) return const LinearProgressIndicator();
                            return DropdownButton<String>(
                              hint: const Text("Select Address Category"),
                              value: selectedCats[i],
                              isExpanded: true,
                              items: snap.data!
                                  .map((d) => DropdownMenuItem(value: d['name'].toString(), child: Text(d['name'])))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => selectedCats[i] = v),
                            );
                          },
                        ),
                      if (types[i] == 'Dropdown')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                selectedCats[i] == null
                                    ? 'No dropdown list chosen'
                                    : 'List: ${selectedCats[i]}',
                                style: TextStyle(
                                    color: selectedCats[i] == null ? Colors.black45 : Colors.black87,
                                    fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await pickDropdownList(context);
                                if (picked != null) setDialogState(() => selectedCats[i] = picked);
                              },
                              child: const Text('Choose'),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _api.addRegister({
                  'registerName': regName,
                  'columnHeadings': headCtrls.map((c) => c.text).toList(),
                  'columnTypes': types,
                  'columnCategories': selectedCats,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("FINISH"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> data) async {
    final id = data['id']?.toString();
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this register?'),
        content: Text('"${data['registerName']}" and all its entries will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _api.deleteRegister(id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _kRegistersTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: Row(children: [
          const CircleAvatar(
            radius: 15, backgroundColor: Colors.white,
            child: Text('CCA', style: TextStyle(color: _kRegistersTeal, fontWeight: FontWeight.w800, fontSize: 9)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Chhattisgarh C & F Agency',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Manage Dropdown Lists',
            onPressed: () => showDropdownListsManager(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: officePollingStream(() => _api.getRegisters()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final registers = snapshot.data!;
          if (registers.isEmpty) {
            return const Center(child: Text('No registers yet.', style: TextStyle(color: Colors.black45)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: registers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = registers[i];
              final name = data['registerName']?.toString() ?? '';
              final headings = (data['columnHeadings'] as List? ?? []);
              final custom = headings.length;
              // Two implicit columns (UID, SR No.) plus the custom ones,
              // matching the reference's "N Columns (UID, SR No. + M
              // custom)" wording — assumption: the backend always adds
              // these two, since they aren't in columnHeadings itself.
              final totalCols = custom + 2;
              final entries = (data['entryCount'] as num?)?.toInt() ?? 0;
              final avatarColor = _kAvatarColors[i % _kAvatarColors.length];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (c) => RegisterEntriesView(registerId: data['id'], regData: data))),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: avatarColor,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (entries > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('$entries',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 3),
                          Text('$totalCols Columns (UID, SR No. + $custom custom)',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C8A97))),
                          Text('$entries Entries',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF9AA5AD))),
                        ],
                      ),
                    ),
                    if (perms.canDelete(ScreenKeys.officeRegisters))
                      IconButton(
                        icon: Icon(Icons.delete, color: entries > 0 ? Colors.red[300] : Colors.red),
                        onPressed: () => _delete(data),
                      ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA5AD)),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeRegisters)
          ? FloatingActionButton(
              backgroundColor: _kRegistersTeal,
              onPressed: _showCreateRegisterDialog,
              child: const Icon(Icons.add, color: Colors.white))
          : null,
    );
  }
}
