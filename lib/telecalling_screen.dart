// ─────────────────────────────────────────────────────────────────────────────
//  Telecalling — receptionist delivery follow-up screen.
//
//  Shows invoices marked Cold Chain / Cool Chain / Special that have
//  reached Stage 3 (Dispatched). Each one needs a follow-up call to
//  confirm delivery:
//    • Tap an invoice  -> see Company, Party, Invoice, LR & Dispatch
//      details, then answer "Has the goods been delivered?"
//    • No  -> shows the transport's contact number (pulled from Office
//      Hub -> Transport Contacts) for a follow-up call; invoice stays
//      in "Calling Needed" and the attempt is logged.
//    • Yes -> asks who was called, the temperature goods were
//      received at, and the delivery time; invoice moves to
//      "Delivered".
//
//  Every attempt (delivered or not) is written to the backend's
//  telecalling_logs table so the full call history is kept, not just
//  the current status. See BACKEND_NOTES.md-style comment at the
//  bottom of this file for the server-side pieces this screen needs.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/data.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/step1.dart';
import 'package:form_app/telecalling_report.dart';
import 'package:form_app/user_permissions.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const _kBar = Color(0xFF0F4C75);

// ──────────────────────────────────────────────────────────────────────────────
// Controller
// ──────────────────────────────────────────────────────────────────────────────
class _TelecallingCtrl extends GetxController {
  final _api = ApiService();

  final invoices = <InvoiceData>[].obs;
  final isLoading = true.obs;
  final search = ''.obs;
  final companyFilter = ''.obs; // '' = All Companies
  final showDelivered = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      invoices.value = await _api.getTelecallingInvoices();
    } catch (e) {
      debugPrint('Telecalling load error: $e');
    }
    isLoading.value = false;
  }

  List<String> get companies {
    final names = invoices
        .map((i) => i.companyName)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<InvoiceData> get _filtered {
    final q = search.value.trim().toLowerCase();
    return invoices.where((inv) {
      final isDelivered = inv.telecallStatus == 'delivered';
      if (isDelivered && !showDelivered.value) return false;
      if (companyFilter.value.isNotEmpty &&
          inv.companyName != companyFilter.value) return false;
      if (q.isEmpty) return true;
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          inv.partyData.partyName.toLowerCase().contains(q) ||
          inv.companyName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Grouped by company for the "All Companies" view; a single-entry map
  // when a specific company is selected.
  Map<String, List<InvoiceData>> get grouped {
    final list = _filtered;
    final map = <String, List<InvoiceData>>{};
    for (final inv in list) {
      final key = inv.companyName.isEmpty ? 'Unspecified' : inv.companyName;
      map.putIfAbsent(key, () => []).add(inv);
    }
    return map;
  }

  int get totalCount => invoices.length;
  int get callingNeededCount =>
      invoices.where((i) => i.telecallStatus != 'delivered').length;
  int get notDeliveredCount =>
      invoices.where((i) => i.telecallStatus == 'not_delivered').length;
  int get deliveredCount =>
      invoices.where((i) => i.telecallStatus == 'delivered').length;

  Future<bool> submit(
    InvoiceData invoice, {
    required bool delivered,
    String? contactPerson,
    String? temperature,
    int? deliveryTime,
    String? transportNumberUsed,
    String? remarks,
  }) async {
    final ok = await _api.submitTelecallResult(
      invoice.id,
      delivered: delivered,
      calledBy: AuthService.to.currentUser?.userId ?? '',
      contactPerson: contactPerson,
      temperature: temperature,
      deliveryTime: deliveryTime,
      transportNumberUsed: transportNumberUsed,
      remarks: remarks,
    );
    if (ok) await load();
    return ok;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Screen
// ──────────────────────────────────────────────────────────────────────────────
class TelecallingScreen extends StatelessWidget {
  const TelecallingScreen({super.key});

  static const routeName = '/Telecalling';

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(_TelecallingCtrl());
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.telecalling, label: 'Telecalling'));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(context, ctrl),
      body: RefreshIndicator(
        onRefresh: ctrl.load,
        child: Column(children: [
          _SummaryBar(ctrl: ctrl),
          _FilterRow(ctrl: ctrl),
          Expanded(child: _InvoiceList(ctrl: ctrl)),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, _TelecallingCtrl ctrl) {
    return AppBar(
      backgroundColor: _kBar,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
        onPressed: () => Get.back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
          tooltip: 'Download Report',
          onPressed: () =>
              showTelecallReportSheet(context, ctrl.invoices.toList()),
        ),
      ],
      title:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Telecalling',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        Text('Cold Chain  •  Cool Chain  •  Special — delivery follow-up',
            style: TextStyle(color: Color(0xFF90CAF9), fontSize: 10)),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                onChanged: (v) => ctrl.search.value = v,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search invoice, party, company…',
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF90CAF9), size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Obx(() => GestureDetector(
                  onTap: () =>
                      ctrl.showDelivered.value = !ctrl.showDelivered.value,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: ctrl.showDelivered.value
                          ? const Color(0xFF10B981)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: ctrl.showDelivered.value
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          ctrl.showDelivered.value
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 14,
                          color: Colors.white),
                      const SizedBox(width: 5),
                      const Text('Delivered',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
          ]),
        ),
      ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final _TelecallingCtrl ctrl;
  const _SummaryBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
          color: _kBar,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Row(children: [
            _stat('Total', '${ctrl.totalCount}', const Color(0xFF90CAF9)),
            _stat('Calling Needed', '${ctrl.callingNeededCount}',
                const Color(0xFFFBBF24)),
            _stat('Not Delivered', '${ctrl.notDeliveredCount}',
                const Color(0xFFEF4444)),
            _stat(
                'Delivered', '${ctrl.deliveredCount}', const Color(0xFF6EE7B7)),
          ]),
        ));
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.7))),
        ]),
      ),
    );
  }
}

// ── Company filter row ─────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final _TelecallingCtrl ctrl;
  const _FilterRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: SizedBox(
        height: 30,
        child: Obx(() => ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All Companies', '', ctrl),
                ...ctrl.companies.map((c) => _chip(c, c, ctrl)),
              ],
            )),
      ),
    );
  }

  Widget _chip(String label, String value, _TelecallingCtrl ctrl) {
    final sel = ctrl.companyFilter.value == value;
    return GestureDetector(
      onTap: () => ctrl.companyFilter.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? _kBar : _kBar.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: sel ? _kBar : _kBar.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : _kBar)),
        ),
      ),
    );
  }
}

// ── Invoice list (grouped by company) ──────────────────────────────────────────
class _InvoiceList extends StatelessWidget {
  final _TelecallingCtrl ctrl;
  const _InvoiceList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator(color: _kBar));
      }
      final groups = ctrl.grouped;
      if (groups.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.phone_disabled_rounded,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('No invoices need follow-up',
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 4),
            Text(
                'Cold Chain, Cool Chain & Special orders appear here once dispatched',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                textAlign: TextAlign.center),
          ]),
        );
      }
      final companyNames = groups.keys.toList();
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: companyNames.length,
        itemBuilder: (ctx, gi) {
          final company = companyNames[gi];
          final list = groups[company]!;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (companyNames.length > 1 ||
                    ctrl.companyFilter.value.isEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(
                        top: gi == 0 ? 0 : 16, bottom: 8, left: 2),
                    child: Row(children: [
                      const Icon(Icons.apartment_rounded,
                          size: 14, color: _kBar),
                      const SizedBox(width: 6),
                      Text(company,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _kBar)),
                      const SizedBox(width: 6),
                      Text('(${list.length})',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8892B0))),
                    ]),
                  ),
                ],
                ...list.map((inv) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceCard(invoice: inv, ctrl: ctrl),
                    )),
              ]);
        },
      );
    });
  }
}

// ── Invoice card ──────────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final InvoiceData invoice;
  final _TelecallingCtrl ctrl;
  const _InvoiceCard({required this.invoice, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final type = OrderTypeX.fromKey(invoice.orderType);
    final status = invoice.telecallStatus ?? 'pending';
    final isDelivered = status == 'delivered';
    final isNotDelivered = status == 'not_delivered';
    final statusColor = isDelivered
        ? const Color(0xFF10B981)
        : isNotDelivered
            ? const Color(0xFFEF4444)
            : const Color(0xFFFBBF24);
    final statusLabel = isDelivered
        ? 'Delivered'
        : isNotDelivered
            ? 'Not Delivered'
            : 'Calling Needed';

    return GestureDetector(
      onTap: () => _openInvoiceDetail(context, invoice, ctrl),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: statusColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: type.color, borderRadius: BorderRadius.circular(8)),
                child: Icon(type.icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(invoice.invoiceNumber,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1C2340))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: type.color,
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(type.label,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppStages.color(invoice.stage),
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(
                              'Stage ${invoice.stage} · ${AppStages.label(invoice.stage)}',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(invoice.partyData.partyName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5A6480))),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3))),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (invoice.transportName.isNotEmpty) ...[
                  const Icon(Icons.local_shipping_rounded,
                      size: 12, color: Color(0xFF8892B0)),
                  const SizedBox(width: 4),
                  Text(invoice.transportName,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF5A6480))),
                  const SizedBox(width: 14),
                ],
                if ((invoice.dispatchDate ?? '').isNotEmpty) ...[
                  const Icon(Icons.calendar_today_rounded,
                      size: 12, color: Color(0xFF8892B0)),
                  const SizedBox(width: 4),
                  Text(invoice.dispatchDate!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF5A6480))),
                ],
              ]),
              if ((invoice.telecallAttempts ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.phone_in_talk_rounded,
                      size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text('${invoice.telecallAttempts} call attempt(s)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                  if (invoice.telecallLastCalledAt != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: Color(0xFF8892B0)),
                    const SizedBox(width: 3),
                    Text(
                        DateFormat('dd-MM-yyyy hh:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                invoice.telecallLastCalledAt!)),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF5A6480))),
                  ],
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Invoice detail sheet
// ──────────────────────────────────────────────────────────────────────────────
void _openInvoiceDetail(
    BuildContext context, InvoiceData invoice, _TelecallingCtrl ctrl) {
  final type = OrderTypeX.fromKey(invoice.orderType);
  final isDelivered = invoice.telecallStatus == 'delivered';
  final canUpdate = AuthService.to.perms.canUpdate(ScreenKeys.telecalling);
  final api = ApiService();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      // Named sheetCtx (not `context`) so it can't shadow the outer
      // screen `context` above — Yes/No below deliberately pop and then
      // reopen a new sheet/dialog using the OUTER context, because by
      // the time a follow-up sheet opens, this inner sheet's own
      // context is already being torn down and can't reliably host it.
      builder: (sheetCtx, scrollController) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: type.color,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(type.icon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(invoice.invoiceNumber,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1C2340))),
                            Text(invoice.partyData.partyName,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF5A6480))),
                          ])),
                    ]),
                    const SizedBox(height: 16),
                    _detailRow('Company', invoice.companyName),
                    _detailRow('Party Name', invoice.partyData.partyName),
                    _ContactNumbersRow(
                      label: 'Party Contact',
                      prefix: 'stockist',
                      presetName: invoice.partyData.partyName,
                      fallbackPhone: invoice.partyData.contactNumber1,
                    ),
                    _detailRow('Invoice Number', invoice.invoiceNumber),
                    _detailRow('Invoice Date', invoice.invoiceDate),
                    _detailRow(
                        'LR Number',
                        invoice.lrNumber?.isNotEmpty == true
                            ? invoice.lrNumber!
                            : '—'),
                    _detailRow(
                        'LR Date',
                        invoice.lrDate?.isNotEmpty == true
                            ? invoice.lrDate!
                            : '—'),
                    _detailRow(
                        'Dispatch Date',
                        invoice.dispatchDate?.isNotEmpty == true
                            ? invoice.dispatchDate!
                            : '—'),
                    _ContactNumbersRow(
                      label: 'Transport',
                      prefix: 'transport',
                      presetName: invoice.transportName,
                      emptyText: invoice.transportName.isEmpty
                          ? '—'
                          : invoice.transportName,
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Call History',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kBar)),
                      children: [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: api.getTelecallLogs(invoice.id),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)));
                            }
                            final logs = snap.data!;
                            if (logs.isEmpty) {
                              return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text('No calls logged yet.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8892B0))));
                            }
                            return Column(
                              children: logs.map((l) {
                                final delivered = l['delivered'] == true ||
                                    l['delivered'] == 1;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                            delivered
                                                ? Icons.check_circle_rounded
                                                : Icons.phone_missed_rounded,
                                            size: 14,
                                            color: delivered
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(
                                                '${l['calledAt'] ?? ''} — ${delivered ? 'Delivered' : 'Not delivered'}'
                                                '${(l['remarks'] ?? '').toString().isNotEmpty ? ' · ${l['remarks']}' : ''}',
                                                style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF5A6480)))),
                                      ]),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (isDelivered) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.3))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF10B981), size: 18),
                                SizedBox(width: 8),
                                Text('Delivery Confirmed',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10B981))),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                  'Received by: ${invoice.telecallContactPerson ?? '-'}',
                                  style: const TextStyle(fontSize: 12.5)),
                              Text(
                                  'Temperature: ${invoice.telecallTemperature ?? '-'}',
                                  style: const TextStyle(fontSize: 12.5)),
                              Text(
                                  'Delivered at: ${invoice.telecallDeliveryTime != null ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(invoice.telecallDeliveryTime!)) : '-'}',
                                  style: const TextStyle(fontSize: 12.5)),
                            ]),
                      ),
                    ] else ...[
                      const Text('Has the goods been delivered?',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C2340))),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: !canUpdate
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _handleDelivered(context, invoice, ctrl);
                                    },
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Yes'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: !canUpdate
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _handleNotDelivered(
                                          context, invoice, ctrl);
                                    },
                              icon: const Icon(Icons.cancel_rounded),
                              label: const Text('No'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ),
                      ]),
                      if (!canUpdate) ...[
                        const SizedBox(height: 8),
                        const Text(
                            "You don't have permission to log calls on this screen.",
                            style: TextStyle(
                                fontSize: 11.5, color: Color(0xFFEF4444))),
                      ],
                    ],
                  ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

Future<void> _dialPhone(String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) launchUrl(uri);
}

Widget _callButton(String phone) {
  return TextButton.icon(
    onPressed: () => _dialPhone(phone),
    icon: const Icon(Icons.call_rounded, size: 15),
    label: const Text('Call',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

Widget _mapContactButton(VoidCallback onTap) {
  return TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add_link_rounded, size: 15),
    label: const Text('Map Contact',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
    style: TextButton.styleFrom(
      foregroundColor: _kBar,
      backgroundColor: _kBar.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

Widget _detailRow(String label, String value, {String? phoneToCall}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8892B0)))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C2340)))),
      if (phoneToCall != null && phoneToCall.isNotEmpty)
        _callButton(phoneToCall),
    ]),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Add/edit a contact number under Office → Stockist/Transport Contacts.
// The stockist/transport name is stored as [firmName] (used for lookup);
// the "Contact Person Name" field is stored as [name] and is free to differ
// per number (e.g. the stockist's own number vs. a staff member's number).
// [existing] pass to edit or delete a saved number (its id/category/phone/
// name); omit to add a brand-new number. Multiple numbers can exist for the
// same stockist/transport — this dialog never overwrites another entry, it
// only ever touches the one it was opened for (or creates a new one), and
// whatever is saved stays until it's edited or removed here.
// ──────────────────────────────────────────────────────────────────────────────
Future<bool> _showContactDialog(
  BuildContext context, {
  required String prefix,
  required String presetName,
  required String title,
  Map<String, dynamic>? existing,
}) async {
  final api = ApiService();
  final isEdit = existing != null;
  final phoneCtrl =
      TextEditingController(text: existing?['phone']?.toString() ?? '');
  final nameCtrl =
      TextEditingController(text: existing?['name']?.toString() ?? '');
  final categoryCtrl = TextEditingController(
      text: existing?['categoryName']?.toString() ?? 'General');
  final saving = false.obs;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      content: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  presetName.isEmpty ? '(no name on this invoice)' : presetName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. General',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Contact Person Name (optional)',
                  hintText: 'e.g. Ramesh Kumar (Owner), Suresh (Staff)',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 6),
                const Text(
                    'Updating this replaces only this number — any other numbers saved for this stockist/transport are untouched.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
              ] else ...[
                const SizedBox(height: 6),
                const Text(
                    'This number stays saved against this name until you edit or remove it — add as many as you need.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
              ],
            ]),
      ),
      actions: [
        if (isEdit)
          Obx(() => TextButton(
                onPressed: saving.value
                    ? null
                    : () async {
                        saving.value = true;
                        try {
                          final ok = await api.deleteOfficeEntry(
                              prefix, existing['id'].toString());
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, ok);
                        } catch (e) {
                          Get.snackbar('Delete Failed', e.toString(),
                              backgroundColor: Colors.red.shade100,
                              colorText: Colors.red.shade900);
                          saving.value = false;
                        }
                      },
                child: const Text('Remove',
                    style: TextStyle(color: Color(0xFFEF4444))),
              )),
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        Obx(() => ElevatedButton(
              onPressed: saving.value
                  ? null
                  : () async {
                      final phone = phoneCtrl.text.trim();
                      final contactName = nameCtrl.text.trim();
                      final category = categoryCtrl.text.trim().isEmpty
                          ? 'General'
                          : categoryCtrl.text.trim();
                      if (phone.isEmpty) {
                        Get.snackbar(
                            'Phone Required', 'Enter a phone number to save.',
                            backgroundColor: Colors.red.shade100,
                            colorText: Colors.red.shade900);
                        return;
                      }
                      saving.value = true;
                      try {
                        bool ok;
                        if (isEdit) {
                          ok = await api.updateOfficeEntry(
                              prefix, existing['id'].toString(), {
                            'name': contactName,
                            'firmName': presetName,
                            'phone': phone,
                          });
                        } else {
                          final categories =
                              await api.getOfficeCategories(prefix);
                          final exists = categories.any((c) =>
                              (c['name']?.toString() ?? '').toLowerCase() ==
                              category.toLowerCase());
                          if (!exists) {
                            await api.addOfficeCategory(prefix, {
                              'name': category,
                              'color': '0xFF0D47A1',
                              'icon': '58355',
                            });
                          }
                          ok = await api
                              .addOfficeCategoryEntry(prefix, category, {
                            'name': contactName,
                            'phone': phone,
                            'firmName': presetName,
                            'city': '',
                            'email': '',
                            'notes': '',
                            'mode': '',
                            'gst': '',
                            'contactPerson': '',
                          });
                        }
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, ok);
                      } catch (e) {
                        Get.snackbar('Save Failed', e.toString(),
                            backgroundColor: Colors.red.shade100,
                            colorText: Colors.red.shade900);
                        saving.value = false;
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kBar, foregroundColor: Colors.white),
              child: saving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            )),
      ],
    ),
  );
  return result ?? false;
}

// ── One saved number: label (if any) + phone + call + edit/remap. ──
Widget _contactNumberRow(String phone, String label, VoidCallback onEdit) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Text(
          label.isEmpty ? phone : '$label · $phone',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C2340)),
        ),
      ),
      _callButton(phone),
      const SizedBox(width: 4),
      InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.edit_rounded, size: 16, color: Color(0xFF8892B0)),
        ),
      ),
    ]),
  );
}

// ── Contact numbers section — shows every saved number for a name under an
// Office Contacts directory (party → 'stockist', transport → 'transport'),
// each with its own call + edit/remap action, plus an "Add" action so more
// than one number (e.g. the stockist's own number and a staff number) can be
// kept side by side and updated independently whenever a new number comes
// in. Falls back to the invoice's own saved number when nothing is mapped
// yet, and offers "Map Contact" to save it (or a new one) in that case. ──
class _ContactNumbersRow extends StatefulWidget {
  final String label;
  final String prefix;
  final String presetName;
  final String? fallbackPhone;
  final String emptyText;
  const _ContactNumbersRow({
    required this.label,
    required this.prefix,
    required this.presetName,
    this.fallbackPhone,
    this.emptyText = 'Not on file',
  });

  @override
  State<_ContactNumbersRow> createState() => _ContactNumbersRowState();
}

class _ContactNumbersRowState extends State<_ContactNumbersRow> {
  final _api = ApiService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.findOfficeContacts(widget.prefix, widget.presetName);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = _api.findOfficeContacts(widget.prefix, widget.presetName);
    });
  }

  Future<void> _add() async {
    final saved = await _showContactDialog(
      context,
      prefix: widget.prefix,
      presetName: widget.presetName,
      title: 'Map ${widget.label}',
    );
    if (saved) _refresh();
  }

  Future<void> _edit(Map<String, dynamic> entry) async {
    final saved = await _showContactDialog(
      context,
      prefix: widget.prefix,
      presetName: widget.presetName,
      title: 'Update ${widget.label}',
      existing: entry,
    );
    if (saved) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presetName.isEmpty) {
      return _detailRow(widget.label, '—');
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final entries = snap.data ?? const [];
        final hasFallback =
            entries.isEmpty && (widget.fallbackPhone?.isNotEmpty ?? false);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8892B0))),
              ),
              InkWell(
                onTap: _add,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 15, color: Color(0xFF0D47A1)),
                    SizedBox(width: 3),
                    Text('Add number',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            if (entries.isNotEmpty)
              ...entries.map((e) => _contactNumberRow(
                    e['phone']?.toString() ?? '',
                    e['name']?.toString() ?? '',
                    () => _edit(e),
                  ))
            else if (hasFallback)
              _contactNumberRow(widget.fallbackPhone!, 'from invoice', _add)
            else
              Row(children: [
                Expanded(
                  child: Text(widget.emptyText,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C2340))),
                ),
                _mapContactButton(_add),
              ]),
          ]),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// "No" — not delivered: pull transport contact for follow-up
// ──────────────────────────────────────────────────────────────────────────────
void _handleNotDelivered(
    BuildContext context, InvoiceData invoice, _TelecallingCtrl ctrl) async {
  final api = ApiService();
  final remarksCtrl = TextEditingController();
  final saving = false.obs;
  final contactsRx = RxList<Map<String, dynamic>>(
      await api.findOfficeContacts('transport', invoice.transportName));
  final usedPhoneRx = Rxn<String>(
      contactsRx.isNotEmpty ? contactsRx.first['phone']?.toString() : null);

  Future<void> refresh() async {
    contactsRx.value =
        await api.findOfficeContacts('transport', invoice.transportName);
    usedPhoneRx.value =
        contactsRx.isNotEmpty ? contactsRx.first['phone']?.toString() : null;
  }

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: const [
        Icon(Icons.local_shipping_rounded, color: Color(0xFFEF4444)),
        SizedBox(width: 8),
        Text('Follow up with Transport', style: TextStyle(fontSize: 15)),
      ]),
      content: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                      invoice.transportName.isEmpty
                          ? 'No transport name on this invoice.'
                          : invoice.transportName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (invoice.transportName.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final saved = await _showContactDialog(
                        dialogContext,
                        prefix: 'transport',
                        presetName: invoice.transportName,
                        title: 'Map Transport Contact',
                      );
                      if (saved) await refresh();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 15, color: Color(0xFF0D47A1)),
                        SizedBox(width: 3),
                        Text('Add number',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF0D47A1),
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Obx(() {
                if (contactsRx.isEmpty) {
                  return const Text(
                      'No phone number on file in Office → Transport Contacts.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8892B0)));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: contactsRx.map((e) {
                    final phone = e['phone']?.toString() ?? '';
                    final label = e['name']?.toString() ?? '';
                    final isUsed = usedPhoneRx.value == phone;
                    return InkWell(
                      onTap: () => usedPhoneRx.value = phone,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Icon(
                              isUsed
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isUsed
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF8892B0)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                label.isEmpty ? phone : '$label · $phone',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1C2340))),
                          ),
                          _callButton(phone),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () async {
                              final saved = await _showContactDialog(
                                dialogContext,
                                prefix: 'transport',
                                presetName: invoice.transportName,
                                title: 'Update Transport Contact',
                                existing: e,
                              );
                              if (saved) await refresh();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_rounded,
                                  size: 16, color: Color(0xFF8892B0)),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 14),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Remarks (optional)',
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Text(
                  'This invoice stays in "Calling Needed" for a follow-up call.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        Obx(() => ElevatedButton(
              onPressed: saving.value
                  ? null
                  : () async {
                      saving.value = true;
                      bool ok = false;
                      String? errorMsg;
                      try {
                        ok = await ctrl.submit(invoice,
                            delivered: false,
                            transportNumberUsed: usedPhoneRx.value,
                            remarks: remarksCtrl.text.trim());
                      } catch (e) {
                        errorMsg = e.toString().replaceFirst('Exception: ', '');
                      }
                      saving.value = false;
                      if (ok) {
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        Get.snackbar('Logged',
                            'Marked not delivered — follow up with transport.',
                            backgroundColor: Colors.red.shade50,
                            colorText: Colors.red.shade800);
                      } else {
                        Get.snackbar(
                            'Save Failed',
                            errorMsg ??
                                'Could not reach the server. Check your connection and try again.',
                            backgroundColor: Colors.red.shade100,
                            colorText: Colors.red.shade900,
                            duration: const Duration(seconds: 5));
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white),
              child: saving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save — Not Delivered'),
            )),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// "Yes" — delivered: capture who was called, temperature, delivery time
// ──────────────────────────────────────────────────────────────────────────────
void _handleDelivered(
    BuildContext context, InvoiceData invoice, _TelecallingCtrl ctrl) {
  final formKey = GlobalKey<FormState>();
  final contactCtrl =
      TextEditingController(text: invoice.partyData.contactPerson);
  final tempCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  final deliveryTime = Rxn<DateTime>(DateTime.now());
  final saving = false.obs;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Form(
            key: formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('Confirm Delivery',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              Text(invoice.invoiceNumber,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF8892B0))),
              const SizedBox(height: 16),
              _sheetLabel('Person Name (whom we called)  *'),
              TextFormField(
                controller: contactCtrl,
                decoration: _sheetDecoration(
                    'e.g. Ramesh Kumar', Icons.person_outline_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _sheetLabel('Temperature Goods Were Received At  *'),
              TextFormField(
                controller: tempCtrl,
                decoration: _sheetDecoration(
                    'e.g. 2-8°C or 18°C', Icons.device_thermostat_rounded),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _sheetLabel('Time of Delivery  *'),
              Obx(() => GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                          context: sheetContext,
                          initialDate: deliveryTime.value ?? now,
                          firstDate: now.subtract(const Duration(days: 14)),
                          lastDate: now);
                      if (date == null) return;
                      if (!sheetContext.mounted) return;
                      final time = await showTimePicker(
                          context: sheetContext,
                          initialTime: TimeOfDay.fromDateTime(
                              deliveryTime.value ?? now));
                      if (time == null) return;
                      deliveryTime.value = DateTime(date.year, date.month,
                          date.day, time.hour, time.minute);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDE0EE))),
                      child: Row(children: [
                        const Icon(Icons.event_available_rounded,
                            size: 18, color: Color(0xFF8892B0)),
                        const SizedBox(width: 8),
                        Text(
                            deliveryTime.value != null
                                ? DateFormat('dd-MM-yyyy hh:mm a')
                                    .format(deliveryTime.value!)
                                : 'Pick date & time',
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  )),
              const SizedBox(height: 12),
              _sheetLabel('Remarks (optional)'),
              TextFormField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: _sheetDecoration('Any notes…', Icons.notes_rounded),
              ),
              const SizedBox(height: 20),
              Obx(() => SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              saving.value = true;
                              bool ok = false;
                              String? errorMsg;
                              try {
                                ok = await ctrl.submit(
                                  invoice,
                                  delivered: true,
                                  contactPerson: contactCtrl.text.trim(),
                                  temperature: tempCtrl.text.trim(),
                                  deliveryTime:
                                      (deliveryTime.value ?? DateTime.now())
                                          .millisecondsSinceEpoch,
                                  remarks: remarksCtrl.text.trim(),
                                );
                              } catch (e) {
                                errorMsg = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              }
                              saving.value = false;
                              if (ok) {
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                                Get.snackbar('Delivery Confirmed',
                                    '${invoice.partyData.partyName} — delivery confirmed',
                                    backgroundColor: Colors.green.shade50,
                                    colorText: Colors.green.shade800);
                              } else {
                                Get.snackbar(
                                    'Save Failed',
                                    errorMsg ??
                                        'Could not reach the server. Check your connection and try again.',
                                    backgroundColor: Colors.red.shade100,
                                    colorText: Colors.red.shade900,
                                    duration: const Duration(seconds: 5));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: saving.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white))
                          : const Text('Confirm Delivery',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  )),
            ]),
          ),
        ),
      ),
    ),
  );
}

Widget _sheetLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6480))),
    );

InputDecoration _sheetDecoration(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8892B0)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE0EE))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDDE0EE))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBar, width: 1.5)),
    );
