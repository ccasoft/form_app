// ─────────────────────────────────────────────────────────────────────────────
//  Office — Address Book
//  Ported from the standalone CCA Admin Console (address_book_module.dart).
//  Changes from the original: Api.* calls -> ApiService, pollingStream ->
//  officePollingStream, PIN-based delete confirm -> real permission check
//  (canDelete), screen entry guarded by canView.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:form_app/office_address_data_list.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String _kPrefix = 'address-book';

class AddressBookModule extends StatefulWidget {
  const AddressBookModule({super.key});

  @override
  State<AddressBookModule> createState() => _AddressBookModuleState();
}

class _AddressBookModuleState extends State<AddressBookModule> {
  final _api = ApiService();
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officeAddressBook, label: 'Address Book'));
  }

  Future<List<Map<String, dynamic>>> _searchAllContacts(String query) async {
    if (query.isEmpty) return [];
    List<Map<String, dynamic>> results = [];

    final categories = await _api.getOfficeCategories(_kPrefix);

    for (var category in categories) {
      final categoryName = category['name'];
      final entries = await _api.getOfficeCategoryEntries(_kPrefix, categoryName);

      for (var data in entries) {
        final searchString =
            "${data['name']} ${data['phone']} ${data['firmName']} ${data['email']} ${data['city']}"
                .toLowerCase();

        if (searchString.contains(query.toLowerCase())) {
          results.add({
            'category': categoryName,
            'categoryColor': category['color'],
            'categoryIcon': category['icon'],
            'data': data,
            'entryId': data['id'],
          });
        }
      }
    }
    return results;
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length == 10) cleanNumber = '91$cleanNumber';
    final Uri whatsappUri = Uri.parse("https://wa.me/$cleanNumber");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmDelete(
      BuildContext context, String docId, String categoryName) async {
    if (!AuthService.to.perms.canDelete(ScreenKeys.officeAddressBook)) return;
    final entries = await _api.getOfficeCategoryEntries(_kPrefix, categoryName);

    if (entries.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Cannot Delete",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
              "This category has contacts in it. Please delete all entries first before deleting the category."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete '$categoryName'?",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await _api.deleteOfficeCategory(_kPrefix, docId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? "Deleted Successfully" : "Delete failed")),
                );
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _nameToIcon(dynamic iconData) {
    if (iconData == null) return Icons.folder_open_outlined;
    String data = iconData.toString();

    if (data == 'folder') return Icons.folder_open_outlined;
    if (data == 'staff' || data == 'security') return Icons.badge_outlined;
    if (data == 'transport') return Icons.local_shipping_outlined;

    const Map<String, IconData> iconMap = {
      '57943': Icons.folder_open_outlined,
      '57555': Icons.badge_outlined,
      '58651': Icons.local_shipping_outlined,
      '58657': Icons.storefront_outlined,
      '57552': Icons.business_outlined,
      '57698': Icons.cleaning_services_outlined,
      '59543': Icons.lock_outline,
      '59389': Icons.person_outline,
      '58102': Icons.groups_outlined,
      '57429': Icons.account_balance_outlined,
      '57497': Icons.build_outlined,
      '57394': Icons.assignment_ind_outlined,
    };

    return iconMap[data] ?? Icons.folder_open_outlined;
  }

  // Fallback palette, cycled by list position, for categories/entries that
  // have no stored color yet (most existing data predates the color
  // picker) — without this every card fell back to the same dark navy,
  // which is what read as "flat color" across the whole list.
  static const List<Color> _kFallbackPalette = [
    Color(0xFF1E88E5), Color(0xFF2E7D32), Color(0xFF7B1FA2),
    Color(0xFFEF6C00), Color(0xFFC2185B), Color(0xFF00838F),
    Color(0xFF6D4C41), Color(0xFF3949AB),
  ];

  List<Color> _getGlossyGradient(dynamic colorData, [int index = 0]) {
    if (colorData == null) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.3)!];
    }
    try {
      Color baseColor = Color(int.parse(colorData.toString()));
      return [baseColor, Color.lerp(baseColor, Colors.black, 0.4)!];
    } catch (e) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.3)!];
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerColor = Color(0xFF0D5C63); // was 0xFFE6A500 — unified teal app bar
    final perms = AuthService.to.perms;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 8,
        foregroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: "Search contacts...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white60)),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'CCA',
                      style: TextStyle(
                        color: headerColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chhattisgarh C & F Agency Pvt Ltd',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Address Directory',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orangeAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              _searchQuery = "";
              _searchController.clear();
            }),
          )
        ],
      ),
      body: _isSearching && _searchQuery.isNotEmpty
          ? FutureBuilder<List<Map<String, dynamic>>>(
              future: _searchAllContacts(_searchQuery),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = snapshot.data!;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.1),
                        border: Border(
                            bottom: BorderSide(
                                color: headerColor.withOpacity(0.3))),
                      ),
                      width: double.infinity,
                      child: Text(
                        "Found ${results.length} contact${results.length != 1 ? 's' : ''}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: headerColor.withOpacity(0.8)),
                      ),
                    ),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text("No contacts found"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final result = results[i];
                                final data = result['data'];
                                final colors =
                                    _getGlossyGradient(result['categoryColor'], i);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                              colors[0].withOpacity(0.15),
                                          child: Icon(Icons.person,
                                              color: colors[0], size: 26)),
                                      title: Text(
                                          (data['name'] ?? 'Unknown')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                "${data['phone'] ?? ''} • ${data['firmName'] ?? ''}",
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color:
                                                    colors[0].withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                  "Category: ${result['category']}",
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: colors[0],
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      childrenPadding: const EdgeInsets.all(16),
                                      children: [
                                        const Divider(),
                                        _detailRow(Icons.business, "Company",
                                            data['firmName']),
                                        _detailRow(Icons.location_on, "Address",
                                            data['city']),
                                        _detailRow(Icons.email, "Email",
                                            data['email']),
                                        _detailRow(Icons.notes, "Notes",
                                            data['notes']),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _actionIcon(
                                                Icons.call,
                                                "Call",
                                                Colors.green,
                                                () => _makeCall(
                                                    data['phone'] ?? '')),
                                            _actionIcon(
                                                Icons.chat,
                                                "WhatsApp",
                                                Colors.blue,
                                                () => _openWhatsApp(
                                                    data['phone'] ?? '')),
                                            _actionIcon(Icons.copy, "Copy",
                                                Colors.blueGrey, () {
                                              Clipboard.setData(ClipboardData(
                                                  text:
                                                      "${data['name']}\n${data['phone']}\n${data['firmName']}"));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Copied to Clipboard")));
                                            }),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: officePollingStream(() => _api.getOfficeCategories(_kPrefix)),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No categories yet. Tap + to create one."),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i];
                    String name = data['name'] ?? "Unknown";
                    List<Color> colors = _getGlossyGradient(data['color'], i);
                    IconData icon = _nameToIcon(data['icon']);

                    return GestureDetector(
                      onLongPress: perms.canDelete(ScreenKeys.officeAddressBook)
                          ? () => _confirmDelete(context, data['id'], name)
                          : null,
                      child: InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddressDataList(
                                    category: ModuleItem(
                                        name: name,
                                        gradient: colors,
                                        icon: icon)))),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: colors),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                  color: colors[0].withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                  top: -15,
                                  left: -15,
                                  child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.06))),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(icon, color: Colors.white, size: 40),
                                    const SizedBox(height: 10),
                                    Text(name.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 0.8)),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: StreamBuilder<int>(
                                  stream: officePollingStream(() async {
                                    final entries = await _api.getOfficeCategoryEntries(_kPrefix, name);
                                    return entries.length;
                                  }),
                                  builder: (context, snap) {
                                    int count = snap.data ?? 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text('$count',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    );
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeAddressBook)
          ? FloatingActionButton(
              backgroundColor: headerColor,
              onPressed: () => _showAddCategoryDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic val) {
    if (val == null || val.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
            child: Text(val.toString(),
                style: const TextStyle(fontSize: 13, color: Colors.black87))),
      ]),
    );
  }

  Widget _actionIcon(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF2C3E50);
    IconData selectedIcon = Icons.folder_open_outlined;

    final List<IconData> availableIcons = [
      Icons.folder_open_outlined,
      Icons.badge_outlined,
      Icons.local_shipping_outlined,
      Icons.storefront_outlined,
      Icons.business_outlined,
      Icons.cleaning_services_outlined,
      Icons.lock_outline,
      Icons.person_outline,
      Icons.groups_outlined,
      Icons.account_balance_outlined,
      Icons.build_outlined,
      Icons.assignment_ind_outlined,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Section",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: "Section Name", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                const Text("Select Icon:",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  width: double.maxFinite,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: availableIcons.length,
                    itemBuilder: (context, index) {
                      bool isSel = selectedIcon == availableIcons[index];
                      return GestureDetector(
                        onTap: () => setDialogState(
                            () => selectedIcon = availableIcons[index]),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSel ? selectedColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(availableIcons[index],
                              color: isSel ? Colors.white : Colors.blueGrey),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Select Theme Color:",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    const Color(0xFF2C3E50),
                    const Color(0xFF1E3799),
                    const Color(0xFFB33939),
                    const Color(0xFF218C74),
                    const Color(0xFF82589F),
                    const Color(0xFFE67E22)
                  ]
                      .map((c) => GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = c),
                            child: CircleAvatar(
                              backgroundColor: c,
                              radius: 18,
                              child: selectedColor == c
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  final result = await _api.addOfficeCategory(_kPrefix, {
                    'name': nameController.text.trim(),
                    'color': selectedColor.value.toString(),
                    'icon': selectedIcon.codePoint.toString(),
                  });

                  if (result['success'] == false) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? result['error'] ?? 'Could not create category'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                  if (mounted) Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a category name"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child:
                  const Text("CREATE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
