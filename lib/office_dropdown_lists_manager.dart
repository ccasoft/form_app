// ─────────────────────────────────────────────────────────────────────────────
//  Manage Dropdown Lists
//
//  Reusable, named option lists (e.g. "fresh / expiry", "company name")
//  that a Register column can be bound to, so the same set of options
//  doesn't have to be retyped for every register. This is genuinely new
//  — the original app only had free-typed dropdown definitions baked
//  into each Reminder Mail template, not a shared, reusable list.
//
//  Storage: generic office category/entry API, prefix 'dropdown-lists',
//  category 'lists'. Entry shape: { name, options: [String, ...] }.
//
//  ⚠ Same backend assumption as elsewhere in this app: relies on the
//  backend accepting a new generic prefix. Verify before relying on it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String kDropdownListsPrefix = 'dropdown-lists';
const String kDropdownListsCategory = 'lists';

const Color _kTeal = Color(0xFF0D5C63);

/// Opens the "Manage Dropdown Lists" dialog. Call this from anywhere a
/// user should be able to view/create/edit/delete the reusable lists.
Future<void> showDropdownListsManager(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _DropdownListsManagerDialog(),
  );
}

/// Lets the caller pick one existing dropdown list by name (used when
/// configuring a Register column of type "Dropdown"). Returns the
/// chosen list's name, or null if cancelled.
Future<String?> pickDropdownList(BuildContext context) async {
  final api = ApiService();
  final lists = await api.getOfficeCategoryEntries(kDropdownListsPrefix, kDropdownListsCategory);
  if (!context.mounted) return null;

  if (lists.isEmpty) {
    final create = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No dropdown lists yet'),
        content: const Text('Create one first, then come back and pick it here.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('CREATE ONE')),
        ],
      ),
    );
    if (create == true && context.mounted) {
      await showDropdownListsManager(context);
    }
    return null;
  }

  return showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('Choose a dropdown list'),
      children: lists.map((l) {
        final name = l['name']?.toString() ?? '';
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, name),
          child: Text(name),
        );
      }).toList(),
    ),
  );
}

class _DropdownListsManagerDialog extends StatefulWidget {
  const _DropdownListsManagerDialog();

  @override
  State<_DropdownListsManagerDialog> createState() => _DropdownListsManagerDialogState();
}

class _DropdownListsManagerDialogState extends State<_DropdownListsManagerDialog> {
  final _api = ApiService();

  Future<void> _createOrEdit({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final options = <TextEditingController>[
      ...(existing?['options'] as List? ?? []).map((o) => TextEditingController(text: o.toString())),
    ];
    if (options.isEmpty) options.add(TextEditingController());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create New Dropdown List' : 'Edit Dropdown List'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'List Name'),
                ),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerLeft, child: Text('Options:')),
                ...options.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: e.value,
                            decoration: InputDecoration(labelText: 'Option ${e.key + 1}'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: options.length > 1
                              ? () => setDialogState(() => options.removeAt(e.key))
                              : null,
                        ),
                      ]),
                    )),
                TextButton.icon(
                  onPressed: () => setDialogState(() => options.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kTeal, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameCtrl.text.trim();
    final opts = options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (name.isEmpty || opts.isEmpty) return;

    if (existing == null) {
      await _api.addOfficeCategoryEntry(kDropdownListsPrefix, kDropdownListsCategory, {
        'name': name,
        'options': opts,
      });
    } else {
      final id = existing['id']?.toString();
      if (id != null) {
        await _api.updateOfficeEntry(kDropdownListsPrefix, id, {...existing, 'name': name, 'options': opts});
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final id = entry['id']?.toString();
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this dropdown list?'),
        content: Text('"${entry['name']}" will be removed. Registers already using it keep their saved values.'),
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
    if (confirm != true) return;
    await _api.deleteOfficeEntry(kDropdownListsPrefix, id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: _kTeal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              const Icon(Icons.list_alt_rounded, color: Colors.white),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Manage Dropdown Lists',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _createOrEdit(),
                    icon: const Icon(Icons.add_circle_rounded),
                    label: const Text('Create New Dropdown List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Existing Dropdown Lists:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: officePollingStream(
                      () => _api.getOfficeCategoryEntries(kDropdownListsPrefix, kDropdownListsCategory)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                          padding: EdgeInsets.all(12), child: LinearProgressIndicator());
                    }
                    final lists = snapshot.data!;
                    if (lists.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('None yet.', style: TextStyle(color: Colors.black45)),
                      );
                    }
                    return Column(
                      children: lists.map((l) {
                        final count = (l['options'] as List? ?? []).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              Container(
                                width: 30, height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: _kTeal, borderRadius: BorderRadius.circular(8)),
                                child: Text('$count',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l['name']?.toString() ?? '')),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Color(0xFF1E88E5)),
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE3F2FD)),
                                onPressed: () => _createOrEdit(existing: l),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFEBEE)),
                                onPressed: () => _delete(l),
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
