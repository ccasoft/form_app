import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Garage Slip Pending — update LR numbers for packing done with garage slip
// ─────────────────────────────────────────────────────────────────────────────

class GarageSlipPendingPage extends StatefulWidget {
  const GarageSlipPendingPage({super.key});

  @override
  State<GarageSlipPendingPage> createState() => _GarageSlipPendingPageState();
}

class _GarageSlipPendingPageState extends State<GarageSlipPendingPage> {
  static const _color = Color(0xFFE65100); // deep orange — distinct from other stages

  List<Map<String, dynamic>> _allGroups = [];
  List<Map<String, dynamic>> _filteredGroups = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.garageSlipPending, label: 'Garage Slip Pending'));
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final groups = await ApiService().getGarageSlipPending();
    if (!mounted) return;
    setState(() {
      _allGroups = groups;
      _filteredGroups = List.from(groups);
      _loading = false;
    });
  }

  void _runSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredGroups = List.from(_allGroups);
      } else {
        _filteredGroups = _allGroups.where((g) {
          final garage = (g['garageSlip'] as String).toLowerCase();
          if (garage.contains(query)) return true;
          final invs = g['invoices'] as List<InvoiceData>;
          return invs.any((inv) =>
              inv.invoiceNumber.toLowerCase().contains(query) ||
              inv.partyData.partyName.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  Future<void> _showUpdateLRSheet(Map<String, dynamic> group) async {
    final ok = await AdminPin.verify(context, action: 'update LR number');
    if (!ok) return;
    final garageSlip = group['garageSlip'] as String;
    final invs = group['invoices'] as List<InvoiceData>;
    final lrCtrl = TextEditingController();
    final lrDateCtrl = TextEditingController(
        text: DateFormat('dd-MM-yyyy').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.09),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_rounded, size: 13, color: _color),
                        const SizedBox(width: 5),
                        Text(garageSlip,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _color,
                                fontSize: 13)),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Update LR Number',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _color,
                            fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Invoices summary ──────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.inventory_2_rounded,
                                    size: 13, color: _color),
                                const SizedBox(width: 6),
                                Text(
                                  '${invs.length} invoice${invs.length > 1 ? "s" : ""} will be updated',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _color),
                                ),
                                const Spacer(),
                                Text(
                                  '${group['totalCase']} cases',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: invs
                                    .map((inv) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _color.withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(inv.invoiceNumber,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _color)),
                                              Text(inv.partyData.partyName,
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      color: AppTheme
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                              if ((group['transportName'] as String)
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Icon(Icons.local_shipping_rounded,
                                      size: 11, color: Color(0xFFAB47BC)),
                                  const SizedBox(width: 4),
                                  Text(group['transportName'],
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFAB47BC),
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── LR Number ─────────────────────────────────
                        TextFormField(
                          controller: lrCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'LR Number *',
                            prefixIcon:
                                const Icon(Icons.pin_rounded, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                        // ── LR Date ───────────────────────────────────
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 1)),
                              builder: (c, child) => Theme(
                                data: Theme.of(c).copyWith(
                                  colorScheme: ColorScheme.light(
                                      primary: _color,
                                      onPrimary: Colors.white),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setModal(() {
                                selectedDate = picked;
                                lrDateCtrl.text =
                                    DateFormat('dd-MM-yyyy').format(picked);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: lrDateCtrl,
                              decoration: InputDecoration(
                                labelText: 'LR Date',
                                prefixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Save button ───────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _color,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: (saving || !AuthService.to.perms.canUpdate(ScreenKeys.garageSlipPending))
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate())
                                      return;
                                    setModal(() => saving = true);
                                    final ok = await ApiService()
                                        .updateLRByGarageSlip(
                                      garageSlip: garageSlip,
                                      lrNumber: lrCtrl.text.trim(),
                                      lrDate: lrDateCtrl.text.trim(),
                                    );
                                    setModal(() => saving = false);
                                    if (ok) {
                                      Navigator.pop(ctx);
                                      Get.snackbar(
                                        'LR Updated!',
                                        'LR ${lrCtrl.text.trim()} assigned to ${invs.length} invoice${invs.length > 1 ? "s" : ""}',
                                        backgroundColor: _color,
                                        colorText: Colors.white,
                                      );
                                      _fetchData(); // refresh — group disappears
                                    } else {
                                      Get.snackbar('Error',
                                          'Failed to update. Please try again.');
                                    }
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              'Assign LR to ${invs.length} invoice${invs.length > 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    lrCtrl.dispose();
    lrDateCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: _color,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Garage Slip Pending',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Awaiting LR number from transport',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14)),
            child: Text(
              '${_allGroups.length} pending',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by Garage Slip No., Invoice, Party...',
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _runSearch('');
                        })
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: _color, width: 1.5),
                ),
              ),
              onChanged: _runSearch,
            ),
          ),

          // ── Info banner ─────────────────────────────────────────────
          if (!_loading && _allGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _color.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: _color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap any entry to assign an LR number. '
                      'Once updated, it will be removed from this list.',
                      style: TextStyle(
                          fontSize: 11, color: _color.withValues(alpha: 0.85)),
                    ),
                  ),
                ]),
              ),
            ),

          // ── List ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _color),
                        const SizedBox(height: 12),
                        const Text('Loading...',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                  )
                : _allGroups.isEmpty
                    ? _buildEmptyState()
                    : _filteredGroups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                Text(
                                  'No results for "${_searchCtrl.text}"',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: _color,
                            onRefresh: _fetchData,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: _filteredGroups.length,
                              itemBuilder: (ctx, i) =>
                                  _GroupCard(
                                    group: _filteredGroups[i],
                                    color: _color,
                                    onTap: () => _showUpdateLRSheet(
                                        _filteredGroups[i]),
                                  ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text('All Clear!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text(
              'No garage slips are pending an LR number.\nAll packing entries have been updated.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final Color color;
  final VoidCallback onTap;

  const _GroupCard(
      {required this.group, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final garageSlip = group['garageSlip'] as String;
    final invs = group['invoices'] as List<InvoiceData>;
    final transport = group['transportName'] as String? ?? '';
    final ts = group['packagingTimestamp'] as int;
    final packDate = ts > 0
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.fromMillisecondsSinceEpoch(ts))
        : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_rounded, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Garage Slip: $garageSlip',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tap to Update LR',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),

            // ── Card body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta info row
                  Row(children: [
                    _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: packDate,
                        color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    _MetaChip(
                        icon: Icons.inventory_2_rounded,
                        label: '${group['totalCase']} cases',
                        color: AppTheme.stagePacking),
                    if (transport.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _MetaChip(
                          icon: Icons.local_shipping_rounded,
                          label: transport,
                          color: const Color(0xFFAB47BC)),
                    ],
                  ]),
                  const SizedBox(height: 10),

                  // Invoice chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: invs
                        .map((inv) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(inv.invoiceNumber,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: color)),
                                  Text(
                                    '${inv.partyData.partyName}  ·  ${inv.companyName}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
