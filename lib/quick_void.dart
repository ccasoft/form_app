import 'package:flutter/material.dart';
import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Quick Void Invoice
//  Handles two scenarios in one flow:
//    1. Cancelled Invoice   → marks isCancelled=true, stage=5, all fields CANCELLED
//    2. Supplied to 3rd Party → stage=5, all fields marked as 3rd-party supplied
// ─────────────────────────────────────────────────────────────────────────────

enum _VoidType { cancelled, thirdParty }

class QuickVoidPage extends StatefulWidget {
  const QuickVoidPage({super.key});

  @override
  State<QuickVoidPage> createState() => _QuickVoidPageState();
}

class _QuickVoidPageState extends State<QuickVoidPage> {
  final _invoiceCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.quickVoid, label: 'Quick Void'));
  }

  bool _searching = false;
  bool _submitting = false;

  Map<String, dynamic>? _invoiceData;
  String? _invoiceDocId;
  String? _searchError;

  _VoidType? _voidType;

  static const _cancelColour = Color(0xFFB71C1C);
  static const _thirdPartyColour = Color(0xFF1565C0);

  Color get _activeColour {
    if (_voidType == _VoidType.cancelled) return _cancelColour;
    if (_voidType == _VoidType.thirdParty) return _thirdPartyColour;
    return AppTheme.stageInvoice;
  }

  // ── search ────────────────────────────────────────────────────────────────
  Future<void> _search() async {
    final raw = _invoiceCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _searching = true;
      _invoiceData = null;
      _invoiceDocId = null;
      _searchError = null;
      _voidType = null;
      _remarksCtrl.clear();
    });

    try {
      final snap = await ApiService().rawInvoiceByNumber(raw);
      if (!mounted) return;
      if (snap == null) {
        setState(() {
          _searchError = 'No invoice found with number "$raw"';
          _searching = false;
        });
      } else {
        setState(() {
          _invoiceData = snap['data'] as Map<String, dynamic>;
          _invoiceDocId = snap['id'] as String;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _searchError = 'Error: $e';
          _searching = false;
        });
    }
  }

  // ── submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_invoiceDocId == null || _voidType == null) return;
    if (_voidType == _VoidType.thirdParty && _remarksCtrl.text.trim().isEmpty) {
      Get.snackbar(
          'Remarks Required', 'Please enter 3rd party details / remarks.',
          backgroundColor: _thirdPartyColour, colorText: Colors.white);
      return;
    }

    // Step A: Admin PIN
    final pinOk = await AdminPin.verify(
      context,
      action: _voidType == _VoidType.cancelled
          ? 'cancel invoice ${_invoiceCtrl.text.trim()}'
          : 'mark invoice ${_invoiceCtrl.text.trim()} as 3rd Party',
    );
    if (!pinOk) return;

    // Step B: Final irreversibility confirmation
    final confirmed = await _irreversibleConfirmDialog();
    if (!confirmed) return;

    setState(() => _submitting = true);
    bool ok;
    try {
      if (_voidType == _VoidType.cancelled) {
        ok = await ApiService().voidInvoiceWithRemarks(
          _invoiceDocId!,
          remarks: _remarksCtrl.text.trim(),
        );
      } else {
        ok = await ApiService().thirdPartyVoidInvoice(
          _invoiceDocId!,
          remarks: _remarksCtrl.text.trim(),
        );
      }
    } catch (e) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      final label = _voidType == _VoidType.cancelled
          ? 'Cancelled'
          : 'Marked as 3rd Party';
      Get.snackbar('Done ✓', 'Invoice ${_invoiceCtrl.text.trim()} — $label',
          backgroundColor: _activeColour,
          colorText: Colors.white,
          duration: const Duration(seconds: 3));
      setState(() {
        _invoiceData = null;
        _invoiceDocId = null;
        _voidType = null;
        _searchError = null;
      });
      _invoiceCtrl.clear();
      _remarksCtrl.clear();
    } else {
      Get.snackbar('Error', 'Could not update invoice. Try again.',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  Future<bool> _irreversibleConfirmDialog() async {
    final isCancelled = _voidType == _VoidType.cancelled;
    final colour = _activeColour;
    final invoiceNo = _invoiceCtrl.text.trim();
    final actionLabel = isCancelled ? 'CANCEL' : 'MARK AS 3RD PARTY';

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: EdgeInsets.zero,
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              // Danger banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: colour,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'THIS ACTION IS IRREVERSIBLE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5),
                  ),
                ]),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice chip
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: colour.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: colour.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 14, color: colour),
                            const SizedBox(width: 6),
                            Text(invoiceNo,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: colour,
                                    fontSize: 14)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _ConfirmRow(
                        icon: Icons.done_all_rounded,
                        color: colour,
                        text:
                            'All stages (1 → 5) will be permanently cleared in one action.',
                      ),
                      const SizedBox(height: 8),
                      _ConfirmRow(
                        icon: Icons.lock_rounded,
                        color: colour,
                        text:
                            'Stages CANNOT be reverted once this button is pressed.',
                      ),
                      const SizedBox(height: 8),
                      _ConfirmRow(
                        icon: isCancelled
                            ? Icons.cancel_rounded
                            : Icons.swap_horiz_rounded,
                        color: colour,
                        text: isCancelled
                            ? 'Invoice will show as CANCELLED across all pipeline views.'
                            : 'Invoice will show as 3RD PARTY with your entered remarks.',
                      ),

                      const SizedBox(height: 18),

                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Go Back',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colour,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 18),
                    ]),
              ),
            ]),
          ),
        ) ??
        false;
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Void',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Cancel / 3rd Party — clear all stages in 1 tap',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        backgroundColor: const Color(0xFF6A1B9A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14)),
            child: const Text('Void Tool',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // Step 1: Invoice Number Search
            _card(
              color: const Color(0xFF6A1B9A),
              icon: Icons.search_rounded,
              title: 'Step 1 — Enter Invoice Number',
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: 'Invoice Number *',
                      hintText: 'e.g. INV-1001',
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      errorText: _searchError,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded, color: Colors.white),
                  ),
                ),
              ]),
            ),

            // Invoice Details Card
            if (_invoiceData != null) ...[
              const SizedBox(height: 12),
              _InvoiceInfoCard(data: _invoiceData!),
            ],

            // Step 2: Choose action
            if (_invoiceData != null) ...[
              const SizedBox(height: 12),
              _card(
                color: _activeColour,
                icon: Icons.rule_rounded,
                title: 'Step 2 — Select Void Reason',
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: _choiceTile(
                      type: _VoidType.cancelled,
                      label: 'Invoice Cancelled',
                      sublabel: 'Invoice was raised but is now cancelled',
                      icon: Icons.cancel_rounded,
                      color: _cancelColour,
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _choiceTile(
                      type: _VoidType.thirdParty,
                      label: 'Supplied to 3rd Party',
                      sublabel: 'No transaction via this pipeline',
                      icon: Icons.swap_horiz_rounded,
                      color: _thirdPartyColour,
                    )),
                  ]),
                  if (_voidType != null) ...[
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _activeColour.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _activeColour.withValues(alpha: 0.25)),
                      ),
                      child: _voidType == _VoidType.cancelled
                          ? _statusRow(Icons.cancel_rounded, _cancelColour,
                              'All stages will show CANCELLED')
                          : _statusRow(
                              Icons.swap_horiz_rounded,
                              _thirdPartyColour,
                              'All stages will show 3RD PARTY + your remarks'),
                    ),
                  ],
                ]),
              ),

              // Step 3: Remarks
              if (_voidType != null) ...[
                const SizedBox(height: 12),
                _card(
                  color: _activeColour,
                  icon: Icons.notes_rounded,
                  title: _voidType == _VoidType.thirdParty
                      ? 'Step 3 — 3rd Party Details (Required)'
                      : 'Step 3 — Remarks (Optional)',
                  child: TextField(
                    controller: _remarksCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _voidType == _VoidType.thirdParty
                          ? 'Enter 3rd party name / reason / details...'
                          : 'Enter reason for cancellation (optional)...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _activeColour, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_submitting || !AuthService.to.perms.canDelete(ScreenKeys.quickVoid)) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeColour,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _voidType == _VoidType.cancelled
                                ? Icons.cancel_rounded
                                : Icons.swap_horiz_rounded,
                            color: Colors.white,
                          ),
                    label: Text(
                      _voidType == _VoidType.cancelled
                          ? 'Mark as CANCELLED — Clear All Stages'
                          : 'Mark as 3RD PARTY — Clear All Stages',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],

            // Empty state
            if (_invoiceData == null &&
                _searchError == null &&
                !_searching) ...[
              const SizedBox(height: 40),
              Icon(Icons.receipt_long_rounded,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Enter an invoice number above and tap search.\nInvoice details will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13, height: 1.6),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _choiceTile({
    required _VoidType type,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
  }) {
    final selected = _voidType == type;
    return GestureDetector(
      onTap: () => setState(() => _voidType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color : AppTheme.divider,
              width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: selected ? Colors.white : color),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Colors.white)
            ],
          ]),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Text(sublabel,
              style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white70 : AppTheme.textSecondary,
                  height: 1.4)),
        ]),
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _card(
      {required Color color,
      required IconData icon,
      required String title,
      required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color, fontSize: 12)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(14), child: child),
      ]),
    );
  }
}

// ─── Confirm Row Widget ───────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _ConfirmRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(top: 1),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: Colors.black87, height: 1.5)),
      ),
    ]);
  }
}

// ─── Invoice Info Card ────────────────────────────────────────────────────────
class _InvoiceInfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InvoiceInfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final stage = (data['stage'] as int?) ?? 1;
    final isCancelled = (data['isCancelled'] as bool?) ?? false;
    final isThirdParty = (data['isThirdParty'] as bool?) ?? false;

    Color stageColor;
    String stageLabel;
    if (isCancelled) {
      stageColor = Colors.grey;
      stageLabel = 'Cancelled';
    } else if (isThirdParty) {
      stageColor = const Color(0xFF1565C0);
      stageLabel = '3rd Party';
    } else {
      switch (stage) {
        case 1:
          stageColor = AppTheme.stageInvoice;
          stageLabel = 'Stage 1 — Invoice';
          break;
        case 2:
          stageColor = AppTheme.stagePacking;
          stageLabel = 'Stage 2 — Packing';
          break;
        case 3:
          stageColor = AppTheme.stageDispatch;
          stageLabel = 'Stage 3 — Dispatched';
          break;
        case 4:
          stageColor = AppTheme.stageAck;
          stageLabel = 'Stage 4 — Ack';
          break;
        default:
          stageColor = AppTheme.stageCheque;
          stageLabel = 'Stage 5 — Complete';
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: stageColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: stageColor.withValues(alpha: 0.09),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            Icon(Icons.receipt_long_rounded, color: stageColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(data['invoiceNumber'] ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: stageColor,
                        fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: stageColor, borderRadius: BorderRadius.circular(20)),
              child: Text(stageLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _row(Icons.business_rounded, 'Company', data['companyName'] ?? '-'),
            const SizedBox(height: 6),
            _row(Icons.people_alt_rounded, 'Party', data['partyName'] ?? '-'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: _row(Icons.currency_rupee_rounded, 'Amount',
                      'Rs. ${data['invoiceAmount'] ?? '-'}')),
              Expanded(
                  child: _row(Icons.calendar_today_rounded, 'Date',
                      data['invoiceDate'] ?? '-')),
            ]),
            if ((data['ewayBillNumber'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              _row(Icons.document_scanner_rounded, 'E-way Bill',
                  data['ewayBillNumber'] ?? '-'),
            ],
            if (isCancelled || isThirdParty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stageColor.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: stageColor),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                    isCancelled
                        ? 'This invoice is already cancelled.'
                        : 'This invoice is already marked as 3rd Party.',
                    style: TextStyle(
                        fontSize: 11,
                        color: stageColor,
                        fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: AppTheme.textSecondary),
      const SizedBox(width: 5),
      Text('$label: ',
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}
