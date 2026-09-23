// ─────────────────────────────────────────────────────────────────────────────
//  Office — Transport Contacts
//  Ported from transport_module.dart. Renamed TransportModule ->
//  TransportContactsModule throughout — this is a callable phone
//  directory of drivers/operators, distinct from the existing
//  Transport MASTER (TransportManagement/transportmanagement.dart)
//  used for invoice dispatch assignment. Same word, different thing.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/office_transport_contacts_data_list.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';

const String _kPrefix = 'transport';

class TransportContactsModule extends StatefulWidget {
  const TransportContactsModule({super.key});
  @override
  State<TransportContactsModule> createState() => _TransportContactsModuleState();
}

class _TransportContactsModuleState extends State<TransportContactsModule> {
  final _api = ApiService();
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officeTransportContacts, label: 'Transport Contacts'));
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+91$cleanNumber';
    }
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _nameToIcon(dynamic iconData) {
    if (iconData == null) return Icons.local_shipping;
    String data = iconData.toString();

    if (data == 'local') return Icons.location_city;
    if (data == 'upcountry') return Icons.terrain;
    if (data == 'courier') return Icons.bolt;
    if (data == 'interstate') return Icons.map;

    const Map<String, IconData> iconMap = {
      '58355': Icons.local_shipping,
      '58135': Icons.location_city,
      '58711': Icons.terrain,
      '62023': Icons.bolt,
      '58151': Icons.map,
      '58343': Icons.flight,
      '58341': Icons.directions_boat,
      '58351': Icons.train,
    };

    return iconMap[data] ?? Icons.local_shipping;
  }

  // Fallback palette, cycled by list position, for categories/entries with
  // no stored (or unrecognized) color, so the list doesn't collapse into
  // one flat color when most real data predates any color picker.
  static const List<Color> _kFallbackPalette = [
    Color(0xFF1E88E5), Color(0xFF2E7D32), Color(0xFF7B1FA2),
    Color(0xFFEF6C00), Color(0xFFC2185B), Color(0xFF00838F),
    Color(0xFF6D4C41), Color(0xFF3949AB),
  ];

  List<Color> _getGradient(dynamic colorData, [int index = 0]) {
    if (colorData == null) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.2)!];
    }
    try {
      String colorStr = colorData.toString();
      if (colorStr == 'local') {
        return [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
      }
      if (colorStr == 'upcountry') {
        return [const Color(0xFF1B5E20), const Color(0xFF388E3C)];
      }
      if (colorStr == 'courier') {
        return [const Color(0xFFE65100), const Color(0xFFF57C00)];
      }
      if (colorStr == 'interstate') {
        return [const Color(0xFF4A148C), const Color(0xFF7B1FA2)];
      }

      Color baseColor = Color(int.parse(colorStr));
      return [baseColor, Color.lerp(baseColor, Colors.black, 0.2)!];
    } catch (e) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.2)!];
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, String categoryName) async {
    if (!AuthService.to.perms.canDelete(ScreenKeys.officeTransportContacts)) return;
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
              "This category has transporters in it. Please delete all entries first."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"))
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
              child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final ok = await _api.deleteOfficeCategory(_kPrefix, docId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? "Deleted Successfully" : "Delete failed")));
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchAllTransporters(
      String query) async {
    if (query.isEmpty) return [];
    List<Map<String, dynamic>> results = [];
    final categories = await _api.getOfficeCategories(_kPrefix);

    for (var category in categories) {
      final categoryName = category['name'];
      final entries = await _api.getOfficeCategoryEntries(_kPrefix, categoryName);
      for (var data in entries) {
        final searchString =
            "${data['name']} ${data['gst']} ${data['contactPerson']} ${data['phone']}"
                .toLowerCase();
        if (searchString.contains(query.toLowerCase())) {
          results.add({
            'category': categoryName,
            'categoryColor': category['color'],
            'categoryIcon': category['icon'],
            'data': data
          });
        }
      }
    }
    return results;
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF0D47A1);
    IconData selectedIcon = Icons.local_shipping;

    final List<IconData> availableIcons = [
      Icons.local_shipping,
      Icons.location_city,
      Icons.terrain,
      Icons.bolt,
      Icons.map,
      Icons.flight,
      Icons.directions_boat,
      Icons.train,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("New Category",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: "Category Name",
                        border: OutlineInputBorder())),
                const SizedBox(height: 20),
                const Text("Select Icon:",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: availableIcons
                      .map((icon) => IconButton(
                          icon: Icon(icon,
                              color: selectedIcon == icon
                                  ? Colors.blue
                                  : Colors.grey),
                          onPressed: () =>
                              setDialogState(() => selectedIcon = icon)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                const Text("Select Color:",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    const Color(0xFF0D47A1),
                    const Color(0xFF1B5E20),
                    const Color(0xFFE65100),
                    const Color(0xFF4A148C)
                  ]
                      .map((c) => GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = c),
                            child: CircleAvatar(
                                backgroundColor: c,
                                radius: 15,
                                child: selectedColor == c
                                    ? const Icon(Icons.check,
                                        size: 15, color: Colors.white)
                                    : null),
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
                if (nameController.text.isNotEmpty) {
                  final result = await _api.addOfficeCategory(_kPrefix, {
                    'name': nameController.text,
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

  @override
  Widget build(BuildContext context) {
    const Color headerColor = Color(0xFF0D5C63); // was 0xFFB33939 — unified teal app bar
    final perms = AuthService.to.perms;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 8,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    hintText: "Search transporters...",
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
                          'Transport Contacts',
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
              future: _searchAllTransporters(_searchQuery),
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
                      child: Text("Found ${results.length} matches",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: headerColor.withOpacity(0.8))),
                    ),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text("No transporters found"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final data = results[i]['data'];
                                final colors =
                                    _getGradient(results[i]['categoryColor'], i);
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
                                          child: Icon(Icons.local_shipping,
                                              color: colors[0], size: 26)),
                                      title: Text(data['name'] ?? 'No Name',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                            'Category: ${results[i]['category']}',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'GST: ${data['gst'] ?? 'N/A'}'),
                                              Text(
                                                  'Contact: ${data['contactPerson'] ?? 'N/A'}'),
                                              Text(
                                                  'Phone: ${data['phone'] ?? 'N/A'}'),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                      icon: const Icon(
                                                          Icons.call,
                                                          color: Colors.green),
                                                      onPressed: () =>
                                                          _makeCall(
                                                              data['phone'] ??
                                                                  '')),
                                                  IconButton(
                                                      icon: const Icon(
                                                          Icons.message,
                                                          color: Colors.blue),
                                                      onPressed: () =>
                                                          _openWhatsApp(
                                                              data['phone'] ??
                                                                  '')),
                                                ],
                                              )
                                            ],
                                          ),
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
                      child: Text("No categories yet. Tap + to create one."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.3),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i];
                    String name = data['name'] ?? "Unknown";
                    List<Color> colors = _getGradient(data['color'], i);
                    IconData icon = _nameToIcon(data['icon']);

                    return GestureDetector(
                      onLongPress: perms.canDelete(ScreenKeys.officeTransportContacts)
                          ? () => _confirmDelete(context, data['id'], name)
                          : null,
                      child: InkWell(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TransportContactsDataList(
                                    category: ModuleItem(
                                        name: name,
                                        gradient: colors,
                                        icon: icon)))),
                        child: Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: colors),
                              borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: Colors.white, size: 30),
                              const SizedBox(height: 8),
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              StreamBuilder<int>(
                                stream: officePollingStream(() async {
                                  final entries = await _api.getOfficeCategoryEntries(_kPrefix, name);
                                  return entries.length;
                                }),
                                builder: (context, countSnapshot) {
                                  int count = countSnapshot.data ?? 0;
                                  return Text('$count Transporters',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 10));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: perms.canAdd(ScreenKeys.officeTransportContacts)
          ? FloatingActionButton(
              backgroundColor: headerColor,
              onPressed: () => _showAddCategoryDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
