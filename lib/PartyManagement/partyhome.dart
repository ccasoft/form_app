import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/PartyManagement/createParty.dart';
import 'package:get/get.dart';

class PartyHome extends StatefulWidget {
  const PartyHome({super.key});

  @override
  State<PartyHome> createState() => _PartyHomeState();
}

class _PartyHomeState extends State<PartyHome> {
  final ApiService _firebaseService = ApiService();
  List<PartyData> _allParties = [];
  List<PartyData> _filtered = [];
  Map<String, String> _companyNameMap = {}; // companyId -> companyName
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.party, label: 'Party'));
    _loadParties();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    setState(() => _isLoading = true);
    final parties = await _firebaseService.getParties();
    final companies = await _firebaseService.getCompanies();
    setState(() {
      _allParties = parties;
      _filtered = parties;
      _companyNameMap = {for (final c in companies) c.companyId: c.companyName};
      _isLoading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allParties.where((p) {
        return p.partyName.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.transportName.toLowerCase().contains(q) ||
            p.routeName.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadParties),
        ],
      ),
      floatingActionButton: !AuthService.to.perms.canAdd(ScreenKeys.party)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Get.to(() => const CreateParty());
                if (result == true) _loadParties();
              },
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Party',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
      body: Column(
        children: [
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search parties, routes, transport...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No parties found',
                        style: TextStyle(
                            fontSize: 16, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final party = _filtered[i];
                  return _PartyCard(
                    party: party,
                    companyNameMap: _companyNameMap,
                    onEdit: !AuthService.to.perms.canUpdate(ScreenKeys.party)
                        ? null
                        : () async {
                            final ok = await AdminPin.verify(context,
                                action: 'edit party');
                            if (!ok) return;
                            final result = await Get.to(
                                () => const CreateParty(),
                                arguments: {
                                  'isEditing': true,
                                  'partyId': party.partyId,
                                  'partyName': party.partyName,
                                  'address': party.address,
                                  'contactNumber1': party.contactNumber1,
                                  'contactNumber2': party.contactNumber2,
                                  'contactPerson': party.contactPerson,
                                  'transportName': party.transportName,
                                  'routeName': party.routeName,
                                  'companyIds': party.companyIds,
                                  'needsCheque': party.needsCheque,
                                });
                            if (result == true) _loadParties();
                          },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  final PartyData party;
  final Map<String, String> companyNameMap;
  final VoidCallback? onEdit;
  const _PartyCard(
      {required this.party,
      required this.companyNameMap,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    party.partyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: AppTheme.primary, size: 20),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on_rounded, text: party.address),
            if (party.contactPerson.isNotEmpty)
              _InfoRow(icon: Icons.person_rounded, text: party.contactPerson),
            if (party.contactNumber1.isNotEmpty)
              _InfoRow(icon: Icons.phone_rounded, text: party.contactNumber1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (party.transportName.isNotEmpty)
                  _Badge(
                    icon: Icons.local_shipping_rounded,
                    label: party.transportName,
                    color: AppTheme.stagePacking,
                  ),
                if (party.routeName.isNotEmpty)
                  _Badge(
                    icon: Icons.route_rounded,
                    label: party.routeName,
                    color: const Color(0xFFE65100),
                  ),
                if (party.needsCheque)
                  _Badge(
                    icon: Icons.payments_rounded,
                    label: 'Cheque',
                    color: AppTheme.stageCheque,
                  ),
                ...party.companyIds.map((id) {
                  final name = companyNameMap[id];
                  if (name == null) return const SizedBox.shrink();
                  return _Badge(
                    icon: Icons.business_rounded,
                    label: name,
                    color: const Color(0xFF1565C0),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
