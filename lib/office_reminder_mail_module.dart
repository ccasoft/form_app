// ─────────────────────────────────────────────────────────────────────────────
//  Office — Reminder Mail Templates
//  Ported from reminder_mail_module.dart. Api.* -> ApiService. The
//  hardcoded PIN ("1234") secure-delete/secure-edit dialogs are
//  replaced with real canDelete/canUpdate checks. Screen guarded by
//  canView, "New Template" gated by canAdd.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

class ReminderMailModule extends StatefulWidget {
  const ReminderMailModule({super.key});

  @override
  State<ReminderMailModule> createState() => _ReminderMailModuleState();
}

class _ReminderMailModuleState extends State<ReminderMailModule> {
  final _api = ApiService();
  bool _isSearching = false;
  String _searchQuery = "";

  final Color _primaryPurple = const Color(0xFF6A1B9A);
  final Color _accentOrange = const Color(0xFFFF9800);
  final Color _bgLight = const Color(0xFFF8F9FA);

  // One distinct color per template card, cycled by list position, so the
  // template list doesn't read as one flat block of purple.
  static const List<Color> _kTemplateColors = [
    Color(0xFF6A1B9A),
    Color(0xFF1E88E5),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFF00838F),
    Color(0xFFC2185B),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        guardScreenView(ScreenKeys.officeReminderMail, label: 'Reminder Mail'));
  }

  // ---------- 1. DELETE (permission-gated, no more PIN) ----------
  void _confirmDelete(String docId, String templateName) {
    if (!AuthService.to.perms.canDelete(ScreenKeys.officeReminderMail)) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Delete Template?"),
        content: Text("Delete '$templateName'? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await _api.deleteMailTemplate(docId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok ? "Template Deleted" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- 2. ADD / EDIT TEMPLATE DIALOG ----------
  void _showTemplateForm({Map<String, dynamic>? existingData, String? docId}) {
    if (docId != null &&
        !AuthService.to.perms.canUpdate(ScreenKeys.officeReminderMail)) return;
    if (docId == null &&
        !AuthService.to.perms.canAdd(ScreenKeys.officeReminderMail)) return;

    final nameCtrl = TextEditingController(text: existingData?['templateName']);
    final subCtrl = TextEditingController(text: existingData?['subject']);
    final bodyCtrl = TextEditingController(text: existingData?['body']);
    final fieldsCtrl = TextEditingController(
        text: (existingData?['dynamicFields'] as List?)?.join(', '));

    final dropdownDefsCtrl = TextEditingController(
        text: existingData?['dropdownDefinitions'] != null
            ? _mapToString(
                Map<String, dynamic>.from(existingData!['dropdownDefinitions']))
            : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(docId == null ? "Create Template" : "Edit Template",
            style:
                TextStyle(color: _primaryPurple, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStyledField(
                  nameCtrl, "Template Name", Icons.label_important_outline),
              _buildStyledField(subCtrl, "Subject Line", Icons.subject),
              GestureDetector(
                onTap: () async {
                  final result = await _showFullScreenEditor(bodyCtrl.text);
                  if (result != null) bodyCtrl.text = result;
                },
                child: AbsorbPointer(
                  child: _buildStyledField(bodyCtrl,
                      "Message Body (Click to expand)", Icons.message_outlined,
                      maxLines: 2),
                ),
              ),
              _buildStyledField(
                  fieldsCtrl, "Dynamic Fields (Ex: Name, Amount)", Icons.code),
              Row(
                children: [
                  Expanded(
                    child: _buildStyledField(
                        dropdownDefsCtrl,
                        "Dropdown Definitions (dd1:Yes,No,Maybe | dd2:High,Medium,Low)",
                        Icons.arrow_drop_down_circle,
                        maxLines: 2),
                  ),
                  IconButton(
                      icon: Icon(Icons.help_outline, color: _primaryPurple),
                      onPressed: () => _showDropdownHelp()),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && subCtrl.text.isNotEmpty) {
                List<String> fieldList = fieldsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                Map<String, List<String>> dropdownDefs =
                    _parseDropdownDefinitions(dropdownDefsCtrl.text);

                Map<String, dynamic> data = {
                  'templateName': nameCtrl.text.trim(),
                  'subject': subCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                  'dynamicFields': fieldList,
                  'dropdownDefinitions': dropdownDefs,
                };
                if (docId == null) {
                  await _api.addMailTemplate(data);
                } else {
                  await _api.updateMailTemplate(docId, data);
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(docId == null ? "SAVE" : "UPDATE",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, List<String>> _parseDropdownDefinitions(String input) {
    Map<String, List<String>> result = {};
    if (input.trim().isEmpty) return result;

    List<String> dropdowns = input.split('|');
    for (String dropdown in dropdowns) {
      List<String> parts = dropdown.trim().split(':');
      if (parts.length == 2) {
        String key = parts[0].trim();
        List<String> options =
            parts[1].split(',').map((e) => e.trim()).toList();
        if (key.isNotEmpty && options.isNotEmpty) {
          result[key] = options;
        }
      }
    }
    return result;
  }

  String _mapToString(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '${e.key}:${(e.value as List).join(",")}')
        .join(' | ');
  }

  void _showDropdownHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dropdown Syntax Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How to define dropdowns:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Format: ddX:option1,option2,option3 | ddY:opt1,opt2'),
              const SizedBox(height: 15),
              const Text('Examples:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildExampleCard(
                  'dd1:Yes,No,Maybe', 'Simple Yes/No/Maybe dropdown'),
              _buildExampleCard('dd2:High,Medium,Low', 'Priority levels'),
              _buildExampleCard('dd1:Active,Inactive | dd2:Paid,Unpaid',
                  'Multiple dropdowns'),
              const SizedBox(height: 15),
              const Text('Usage in template:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Status: {{dd1}}\nPriority: {{dd2}}',
                    style: TextStyle(fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('GOT IT'))
        ],
      ),
    );
  }

  Widget _buildExampleCard(String syntax, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(syntax,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text(description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<String?> _showFullScreenEditor(String initialText) async {
    final bodyCtrl = TextEditingController(text: initialText);
    bool showPreview = false;

    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setEditorState) => Scaffold(
          appBar: AppBar(
            title: const Text('Edit Message Body'),
            backgroundColor: _primaryPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(showPreview ? Icons.code : Icons.preview),
                onPressed: () =>
                    setEditorState(() => showPreview = !showPreview),
                tooltip: showPreview ? 'Show HTML' : 'Show Preview',
              ),
              IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => Navigator.pop(context, bodyCtrl.text)),
            ],
          ),
          body: Column(
            children: [
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.table_chart, color: Colors.green),
                        onPressed: () =>
                            _insertTable(context, bodyCtrl, setEditorState),
                      ),
                      const Text('Table', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.text_fields, color: Colors.blue),
                        onPressed: () => _insertDynamicField(
                            context, bodyCtrl, setEditorState),
                      ),
                      const Text('Field', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down_circle,
                            color: Colors.purple),
                        onPressed: () =>
                            _insertDropdown(context, bodyCtrl, setEditorState),
                      ),
                      const Text('Dropdown', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: showPreview
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: HtmlWidget(bodyCtrl.text,
                            key: ValueKey(bodyCtrl.text)),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: bodyCtrl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                              hintText: 'Type your message... (HTML supported)',
                              border: OutlineInputBorder()),
                          onChanged: (text) {
                            if (showPreview) setEditorState(() {});
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _insertTable(BuildContext context, TextEditingController ctrl,
      [StateSetter? setState]) {
    showDialog(
      context: context,
      builder: (dialogContext) => TableEditorDialog(
        onTableCreated: (htmlTable) {
          ctrl.text += '\n$htmlTable\n';
          if (setState != null) setState(() {});
        },
      ),
    );
  }

  void _insertDynamicField(BuildContext context, TextEditingController ctrl,
      [StateSetter? setState]) {
    final fieldNameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert Dynamic Field'),
        content: TextField(
          controller: fieldNameCtrl,
          decoration: const InputDecoration(
              labelText: 'Field Name',
              hintText: 'e.g., Name, Amount, Date',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (fieldNameCtrl.text.isNotEmpty) {
                ctrl.text += '{{${fieldNameCtrl.text.trim()}}}';
                if (setState != null) setState(() {});
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('INSERT'),
          ),
        ],
      ),
    );
  }

  void _insertDropdown(BuildContext context, TextEditingController ctrl,
      [StateSetter? setState]) {
    final dropdownNumberCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Insert Dropdown'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter dropdown number (e.g., 1 for dd1, 2 for dd2)',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: dropdownNumberCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Dropdown Number',
                  hintText: 'e.g., 1, 2, 3',
                  prefixText: 'dd',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8)),
              child: const Text(
                  'Remember to define dropdown options in the Dropdown Definitions field!',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (dropdownNumberCtrl.text.isNotEmpty) {
                ctrl.text += '{{dd${dropdownNumberCtrl.text.trim()}}}';
                if (setState != null) setState(() {});
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('INSERT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledField(
      TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _primaryPurple, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  // ---------- 3. FILL / PREVIEW ----------
  void _showFillDialog(Map<String, dynamic> data) {
    final fields = List<String>.from(data['dynamicFields'] ?? []);
    final dropdownDefs =
        Map<String, dynamic>.from(data['dropdownDefinitions'] ?? {});

    final textCtrls = <String, TextEditingController>{};
    final dropdownValues = <String, String>{};

    for (var f in fields) {
      textCtrls[f] = TextEditingController();
    }

    dropdownDefs.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        dropdownValues[key] = value[0].toString();
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Fill Information"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...fields.map(
                    (f) => _buildStyledField(textCtrls[f]!, f, Icons.edit)),
                ...dropdownDefs.entries.map((entry) {
                  final ddKey = entry.key;
                  final options = List<String>.from(entry.value);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: dropdownValues[ddKey],
                      decoration: InputDecoration(
                        labelText: ddKey.toUpperCase(),
                        prefixIcon: Icon(Icons.arrow_drop_down_circle,
                            color: _primaryPurple, size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: options
                          .map((option) => DropdownMenuItem<String>(
                              value: option, child: Text(option)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => dropdownValues[ddKey] = value!),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showPreviewDialog(data, textCtrls, dropdownValues);
              },
              child: const Text("PREVIEW"),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreviewDialog(
      Map<String, dynamic> templateData,
      Map<String, TextEditingController> fieldValues,
      Map<String, String> dropdownValues) {
    String finalSubject = templateData['subject'] ?? '';
    String finalBody = templateData['body'] ?? '';

    fieldValues.forEach((key, controller) {
      finalSubject =
          finalSubject.replaceAll("{{$key}}", controller.text.trim());
      finalBody = finalBody.replaceAll("{{$key}}", controller.text.trim());
    });

    dropdownValues.forEach((key, value) {
      finalSubject = finalSubject.replaceAll("{{$key}}", value);
      finalBody = finalBody.replaceAll("{{$key}}", value);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Final Preview"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SUBJECT",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.grey)),
                Text(finalSubject,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 24),
                const Text("MESSAGE",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                HtmlWidget(finalBody),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("EDIT")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () {
              Navigator.pop(context);
              _showSourceSelectionDialog(finalSubject, finalBody);
            },
            child: const Text("PROCEED", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------- 4. CONTACTS & SENDING ----------
  void _showSourceSelectionDialog(String finalSubject, String finalBody) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Send To"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showMasterSelectionDialog(
                  'address-book', 'Address Book', finalSubject, finalBody);
            },
            child: Row(children: [
              Icon(Icons.contact_phone, color: _accentOrange),
              const SizedBox(width: 12),
              const Text('Address Book'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _showMasterSelectionDialog(
                  'transport', 'Transport Contacts', finalSubject, finalBody);
            },
            child: Row(children: [
              Icon(Icons.local_shipping, color: _accentOrange),
              const SizedBox(width: 12),
              const Text('Transport Contacts'),
            ]),
          ),
        ],
      ),
    );
  }

  void _showMasterSelectionDialog(String prefix, String sourceLabel,
      String finalSubject, String finalBody) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select $sourceLabel Category"),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: officePollingStream(() => _api.getOfficeCategories(prefix)),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  var category = snapshot.data![index];
                  return ListTile(
                    leading: Icon(Icons.folder, color: _accentOrange),
                    title: Text(category['name']),
                    onTap: () {
                      Navigator.pop(context);
                      _showRecipientDialog(
                          prefix, category['name'], finalSubject, finalBody);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRecipientDialog(
      String prefix, String masterName, String finalSubject, String finalBody) {
    final isTransport = prefix == 'transport';
    List<Map<String, dynamic>> selected = [];
    String contactSearch = "";
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
            StreamBuilder<List<Map<String, dynamic>>>(
          stream: officePollingStream(
              () => _api.getOfficeCategoryEntries(prefix, masterName)),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final filtered = snapshot.data!.where((d) {
              final searchable = isTransport
                  ? "${d['contactPerson']} ${d['name']}"
                  : "${d['firmName']} ${d['name']}";
              return searchable
                  .toLowerCase()
                  .contains(contactSearch.toLowerCase());
            }).toList();
            return AlertDialog(
              title: TextField(
                decoration: InputDecoration(
                    hintText: "Search $masterName...",
                    prefixIcon: const Icon(Icons.search)),
                onChanged: (v) => setDialogState(() => contactSearch = v),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final d = filtered[index];
                    // Transport contacts have no email field — WhatsApp
                    // still works fine off phone alone; Email sending
                    // already skips any recipient without an '@' address.
                    final contact = {
                      'name': d['name'] ?? '',
                      'email': isTransport ? '' : (d['email'] ?? ''),
                      'phone': d['phone'] ?? '',
                      'firmName': isTransport
                          ? (d['contactPerson'] ?? '')
                          : (d['firmName'] ?? ''),
                    };
                    bool isSel =
                        selected.any((e) => e['phone'] == contact['phone']);
                    return CheckboxListTile(
                      title: Text(contact['name']!),
                      subtitle: Text(isTransport
                          ? 'Contact: ${contact['firmName']}'
                          : contact['firmName']!),
                      value: isSel,
                      onChanged: (v) => setDialogState(() {
                        v!
                            ? selected.add(contact)
                            : selected.removeWhere(
                                (e) => e['phone'] == contact['phone']);
                      }),
                    );
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700]),
                  onPressed: () {
                    if (selected.isNotEmpty) {
                      Navigator.pop(context);
                      _showSendOptions(selected, finalSubject, finalBody);
                    }
                  },
                  child: Text("SEND (${selected.length})",
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSendOptions(
      List<Map<String, dynamic>> recipients, String subject, String body) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose Delivery",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (recipients.length > 1) ...[
              const SizedBox(height: 6),
              const Text(
                "WhatsApp can only prefill a draft for one contact at a time — the first selected contact will be used.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child:
                        _buildSendTile(Icons.email, "Email", Colors.blue, () {
                  Navigator.pop(sheetContext);
                  _launchEmail(recipients, subject, body);
                })),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildSendTile(
                        Icons.chat_bubble, "WhatsApp", Colors.green, () {
                  Navigator.pop(sheetContext);
                  _launchWhatsApp(recipients.first['phone'], body);
                })),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Icon(icon, color: color),
          Text(label, style: TextStyle(color: color))
        ]),
      ),
    );
  }

  // Always CC'd on every reminder email sent from this screen.
  static const String _kOfficeCc = 'ccasoft@gmail.com';

  void _launchEmail(
      List<Map<String, dynamic>> recs, String sub, String body) async {
    final emails = recs
        .map((e) => e['email'])
        .where((e) => e.toString().contains('@'))
        .join(',');
    if (emails.isEmpty) {
      _showSnack('None of the selected contacts have an email address.');
      return;
    }
    // Plain-text body: mailto bodies aren't HTML-rendered by mail apps, so
    // strip any tags from the template's rich-text content.
    final plainBody = body.replaceAll(RegExp(r'<[^>]*>'), '');
    final uri = Uri(
        scheme: 'mailto',
        path: emails,
        query: 'cc=${Uri.encodeComponent(_kOfficeCc)}'
            '&subject=${Uri.encodeComponent(sub)}'
            '&body=${Uri.encodeComponent(plainBody)}');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showSnack('No email app is set up on this device.');
      }
    } catch (_) {
      _showSnack('Could not open an email app on this device.');
    }
  }

  void _launchWhatsApp(String phone, String body) async {
    final cleanBody = body.replaceAll(RegExp(r'<[^>]*>'), '');
    var cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.isEmpty) {
      _showSnack('This contact has no phone number on file.');
      return;
    }
    if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
    final text = Uri.encodeComponent(cleanBody);
    // Try the WhatsApp app's own deep link first (opens straight into a
    // chat with the message pre-filled, not sent — the user still taps
    // Send inside WhatsApp), falling back to the wa.me web redirect,
    // which also works when WhatsApp isn't installed (opens WhatsApp Web).
    final candidates = [
      Uri.parse('whatsapp://send?phone=$cleanPhone&text=$text'),
      Uri.parse('https://wa.me/$cleanPhone?text=$text'),
    ];
    for (final url in candidates) {
      try {
        final launched =
            await launchUrl(url, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (_) {
        // try the next candidate
      }
    }
    _showSnack('Could not open WhatsApp. Is it installed on this device?');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final perms = AuthService.to.perms;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _primaryPurple,
        foregroundColor: Colors.white,
        title: _isSearching ? _buildSearchField() : _buildBrandedTitle(),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              _searchQuery = "";
            }),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: officePollingStream(() => _api.getMailTemplates()),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!
              .where((data) => (data['templateName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery))
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              var data = docs[i];
              final hasDropdowns =
                  (data['dropdownDefinitions'] as Map?)?.isNotEmpty ?? false;
              final cardColor = _kTemplateColors[i % _kTemplateColors.length];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: cardColor.withOpacity(0.1),
                      child: Icon(
                          hasDropdowns ? Icons.list_alt : Icons.description,
                          color: cardColor)),
                  title: Text(data['templateName'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['subject'], maxLines: 1),
                  trailing: (perms.canUpdate(ScreenKeys.officeReminderMail) ||
                          perms.canDelete(ScreenKeys.officeReminderMail))
                      ? PopupMenuButton(
                          onSelected: (val) {
                            if (val == 'edit')
                              _showTemplateForm(
                                  existingData: data, docId: data['id']);
                            if (val == 'delete')
                              _confirmDelete(data['id'], data['templateName']);
                          },
                          itemBuilder: (context) => [
                            if (perms.canUpdate(ScreenKeys.officeReminderMail))
                              const PopupMenuItem(
                                  value: 'edit', child: Text("Edit")),
                            if (perms.canDelete(ScreenKeys.officeReminderMail))
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text("Delete",
                                      style: TextStyle(color: Colors.red))),
                          ],
                        )
                      : null,
                  onTap: () => _showFillDialog(data),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeReminderMail)
          ? FloatingActionButton.extended(
              backgroundColor: _primaryPurple,
              onPressed: () => _showTemplateForm(),
              label: const Text("NEW TEMPLATE",
                  style: TextStyle(color: Colors.white)),
              icon: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSearchField() => TextField(
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
            hintText: "Search...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white60)),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      );

  Widget _buildBrandedTitle() => Row(
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Text('CCA',
                  style: TextStyle(
                      color: _primaryPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Chhattisgarh C & F ", style: TextStyle(fontSize: 14)),
            Text("Reminder Mail",
                style: TextStyle(fontSize: 10, color: Colors.orange)),
          ]),
        ],
      );
}

// ==================== TABLE EDITOR DIALOG (unchanged) ====================
class TableEditorDialog extends StatefulWidget {
  final Function(String) onTableCreated;

  const TableEditorDialog({Key? key, required this.onTableCreated})
      : super(key: key);

  @override
  State<TableEditorDialog> createState() => _TableEditorDialogState();
}

class _TableEditorDialogState extends State<TableEditorDialog> {
  int rows = 3;
  int cols = 3;
  List<List<TextEditingController>> cellControllers = [];
  bool isEditing = true;

  @override
  void initState() {
    super.initState();
    _initializeTable();
  }

  void _initializeTable() {
    cellControllers = List.generate(rows,
        (r) => List.generate(cols, (c) => TextEditingController(text: '')));
  }

  void _updateTableSize() {
    List<List<TextEditingController>> newControllers = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r < cellControllers.length && c < cellControllers[r].length) {
          return cellControllers[r][c];
        }
        return TextEditingController(text: '');
      }),
    );

    for (int r = 0; r < cellControllers.length; r++) {
      for (int c = 0; c < cellControllers[r].length; c++) {
        if (r >= rows || c >= cols) {
          cellControllers[r][c].dispose();
        }
      }
    }

    setState(() {
      cellControllers = newControllers;
    });
  }

  String _generateHtmlTable() {
    String html =
        '<table border="1" style="border-collapse: collapse; width: 100%;">\n';
    for (int r = 0; r < rows; r++) {
      html += '  <tr>\n';
      for (int c = 0; c < cols; c++) {
        String cellText = cellControllers[r][c].text.isEmpty
            ? '&nbsp;'
            : cellControllers[r][c].text;
        html +=
            '    <td style="border: 1px solid black; padding: 8px;">$cellText</td>\n';
      }
      html += '  </tr>\n';
    }
    html += '</table>';
    return html;
  }

  @override
  void dispose() {
    for (var row in cellControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Table Editor',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Rows: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8)),
                          controller:
                              TextEditingController(text: rows.toString()),
                          onChanged: (value) {
                            int? newRows = int.tryParse(value);
                            if (newRows != null &&
                                newRows > 0 &&
                                newRows <= 20) {
                              rows = newRows;
                              _updateTableSize();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('Cols: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8)),
                          controller:
                              TextEditingController(text: cols.toString()),
                          onChanged: (value) {
                            int? newCols = int.tryParse(value);
                            if (newCols != null &&
                                newCols > 0 &&
                                newCols <= 10) {
                              cols = newCols;
                              _updateTableSize();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => isEditing = !isEditing),
                        icon: Icon(isEditing ? Icons.visibility : Icons.edit),
                        label: Text(isEditing ? 'Preview' : 'Edit'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isEditing ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isEditing
                          ? _buildEditableTable()
                          : _buildPreviewTable(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL')),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    String htmlTable = _generateHtmlTable();
                    widget.onTableCreated(htmlTable);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('INSERT TABLE',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTable() {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: List.generate(
        rows,
        (r) => TableRow(
          children: List.generate(
            cols,
            (c) => Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 100, minHeight: 50),
              child: TextField(
                controller: cellControllers[r][c],
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(8)),
                maxLines: null,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTable() {
    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: List.generate(
        rows,
        (r) => TableRow(
          children: List.generate(
            cols,
            (c) => Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 100, minHeight: 50),
              child: Text(
                  cellControllers[r][c].text.isEmpty
                      ? ''
                      : cellControllers[r][c].text,
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ),
    );
  }
}
