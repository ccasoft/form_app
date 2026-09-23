// ─────────────────────────────────────────────────────────────────────────────
//  Office — Passwords
//  Ported from password_module.dart. Same conversions as Address Book:
//  Api.* -> ApiService, pollingStream -> officePollingStream, PIN-based
//  delete -> canDelete, screen entry guarded by canView.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/office_models.dart';
import 'package:form_app/office_password_data_list.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/office_polling_stream.dart';
import 'package:form_app/office_password_otp_gate.dart';

const String _kPrefix = 'passwords';

class PasswordModule extends StatefulWidget {
  const PasswordModule({super.key});

  @override
  State<PasswordModule> createState() => _PasswordModuleState();
}

class _PasswordModuleState extends State<PasswordModule> {
  final _api = ApiService();
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.officePasswords, label: 'Passwords'));
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, String categoryName) async {
    if (!AuthService.to.perms.canDelete(ScreenKeys.officePasswords)) return;
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
              "This category has passwords in it. Please delete all entries first before deleting the category."),
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
    if (iconData == null) return Icons.vpn_key;
    String data = iconData.toString();

    if (data == 'software') return Icons.computer;
    if (data == 'email') return Icons.email;
    if (data == 'gst') return Icons.receipt_long;
    if (data == 'bank') return Icons.account_balance;

    const Map<String, IconData> iconMap = {
      '58835': Icons.lock,
      '58344': Icons.lock,
      '59640': Icons.vpn_key,
      '57399': Icons.account_balance,
      '58356': Icons.credit_card,
      '57680': Icons.business,
      '57421': Icons.computer,
      '57704': Icons.email,
      '59203': Icons.receipt_long,
    };

    return iconMap[data] ?? Icons.vpn_key;
  }

  // Fallback palette, cycled by list position, for categories/entries with
  // no stored (or unrecognized) color, so the list doesn't collapse into
  // one flat color when most real data predates any color picker.
  static const List<Color> _kFallbackPalette = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF7B1FA2),
    Color(0xFFE65100), Color(0xFFC2185B), Color(0xFF00838F),
  ];

  List<Color> _getGradient(dynamic colorData, [int index = 0]) {
    if (colorData == null) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.2)!];
    }
    try {
      String colorStr = colorData.toString();
      if (colorStr == 'software') {
        return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
      }
      if (colorStr == 'email') {
        return [const Color(0xFFE65100), const Color(0xFFF57C00)];
      }
      if (colorStr == 'gst') {
        return [const Color(0xFF1B5E20), const Color(0xFF388E3C)];
      }

      Color baseColor = Color(int.parse(colorStr));
      return [baseColor, Color.lerp(baseColor, Colors.black, 0.2)!];
    } catch (e) {
      final base = _kFallbackPalette[index % _kFallbackPalette.length];
      return [base, Color.lerp(base, Colors.black, 0.2)!];
    }
  }

  Future<List<Map<String, dynamic>>> _searchAllPasswords(String query) async {
    if (query.isEmpty) return [];
    List<Map<String, dynamic>> results = [];

    final categories = await _api.getOfficeCategories(_kPrefix);

    for (var category in categories) {
      final categoryName = category['name'];
      final entries = await _api.getOfficeCategoryEntries(_kPrefix, categoryName);

      for (var data in entries) {
        final searchString =
            "${data['serviceName']} ${data['username']} ${data['provider']} ${data['company']}"
                .toLowerCase();

        if (searchString.contains(query.toLowerCase())) {
          results.add({
            'category': categoryName,
            'categoryColor': category['color'],
            'categoryIcon': category['icon'],
            'data': data,
          });
        }
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    const Color headerColor = Color(0xFF1565C0);
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
                    hintText: "Search passwords...",
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
                          'Password Manager',
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
              future: _searchAllPasswords(_searchQuery),
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
                      child: Text("Found ${results.length} results",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: headerColor.withOpacity(0.8))),
                    ),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text("No passwords found"))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final result = results[i];
                                final data = result['data'];
                                final colors =
                                    _getGradient(result['categoryColor'], i);

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
                                          child: Icon(Icons.vpn_key,
                                              color: colors[0], size: 26)),
                                      title: Text(
                                          data['serviceName'] ??
                                              'Unknown Service',
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
                                                'User: ${data['username'] ?? 'N/A'}',
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
                                                  'Category: ${result['category']}',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: colors[0],
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Divider(),
                                              _SearchResultPassword(
                                                  password:
                                                      data['password'] ?? ''),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Company: ${data['company'] ?? 'N/A'}'),
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
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: 1.1),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    var data = docs[i];
                    String name = data['name'] ?? "Unknown";
                    List<Color> colors = _getGradient(data['color'], i);
                    IconData icon = _nameToIcon(data['icon']);

                    return GestureDetector(
                      onLongPress: perms.canDelete(ScreenKeys.officePasswords)
                          ? () => _confirmDelete(context, data['id'], name)
                          : null,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PasswordDataList(
                              category: ModuleItem(
                                  name: name, gradient: colors, icon: icon),
                            ),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: colors),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: Colors.white, size: 35),
                              const SizedBox(height: 8),
                              Text(name.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                              StreamBuilder<int>(
                                stream: officePollingStream(() async {
                                  final entries = await _api.getOfficeCategoryEntries(_kPrefix, name);
                                  return entries.length;
                                }),
                                builder: (context, countSnapshot) {
                                  int count = countSnapshot.data ?? 0;
                                  return Text('$count Entries',
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
      floatingActionButton: perms.canAdd(ScreenKeys.officePasswords)
          ? FloatingActionButton(
              backgroundColor: headerColor,
              onPressed: () => _showAddCategoryDialog(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF1565C0);
    IconData selectedIcon = Icons.vpn_key;

    final List<IconData> availableIcons = [
      Icons.vpn_key,
      Icons.computer,
      Icons.email,
      Icons.receipt_long,
      Icons.account_balance,
      Icons.credit_card,
      Icons.business,
      Icons.lock,
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
                                setDialogState(() => selectedIcon = icon),
                          ))
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
                    const Color(0xFF1565C0),
                    const Color(0xFFE65100),
                    const Color(0xFF1B5E20),
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
}

// ── Password line in a search result — masked until OTP-unlocked ──────────────
class _SearchResultPassword extends StatefulWidget {
  final String password;
  const _SearchResultPassword({required this.password});

  @override
  State<_SearchResultPassword> createState() => _SearchResultPasswordState();
}

class _SearchResultPasswordState extends State<_SearchResultPassword> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text('Password: ${_revealed ? widget.password : '••••••••'}'),
      ),
      if (!_revealed)
        TextButton(
          onPressed: () async {
            final unlocked = await requestPasswordOtpUnlock(context);
            if (unlocked && mounted) setState(() => _revealed = true);
          },
          child: const Text('View', style: TextStyle(fontSize: 12)),
        ),
    ]);
  }
}
