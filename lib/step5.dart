import 'package:flutter/material.dart';
import 'package:form_app/home.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:form_app/step1.dart' show OrderTypeFlag;
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Step 5 — Cheque Collection
//  Flow: Party list (needsCheque=true) → tap party → invoices for that party
//        → fill cheque details → save
// ─────────────────────────────────────────────────────────────────────────────
class Step5 extends StatefulWidget {
  @override
  _Step5State createState() => _Step5State();
}

class _Step5State extends State<Step5> {
  final _fs = ApiService();

  List<PartyData> _parties = [];
  PartyData? _selectedParty;
  List<InvoiceData> _partyInvoices = [];
  bool _loadingParties = true;
  bool _loadingInvoices = false;

  Set<String> _selectedInvoiceIds = {}; // doc IDs
  Set<String> _selectedInvoiceNos = {}; // for display

  final _chequeNoCtrl = TextEditingController();
  final _chequeDateCtrl = TextEditingController();
  final _chequeAmtCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step5, label: 'Cheque Collection'));
    _loadParties();
  }

  @override
  void dispose() {
    _chequeNoCtrl.dispose();
    _chequeDateCtrl.dispose();
    _chequeAmtCtrl.dispose();
    _bankNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    setState(() => _loadingParties = true);
    final parties = await _fs.getPartiesNeedingCheque();
    if (mounted)
      setState(() {
        _parties = parties;
        _loadingParties = false;
      });
  }

  Future<void> _selectParty(PartyData p) async {
    setState(() {
      _selectedParty = p;
      _partyInvoices = [];
      _selectedInvoiceIds = {};
      _selectedInvoiceNos = {};
      _loadingInvoices = true;
    });
    // Get all stage-3 invoices needing cheque for this party
    final all = await _fs.getInvoicesForCheque();
    // Match by partyId; fall back to partyName if partyId is empty
    final filtered = all.where((inv) {
      if (inv.partyData.partyId.isNotEmpty && p.partyId.isNotEmpty) {
        return inv.partyData.partyId == p.partyId;
      }
      return inv.partyData.partyName.toLowerCase().trim() ==
          p.partyName.toLowerCase().trim();
    }).toList();
    if (mounted)
      setState(() {
        _partyInvoices = filtered;
        _loadingInvoices = false;
      });
  }

  void _toggleInvoice(InvoiceData inv) {
    setState(() {
      if (_selectedInvoiceIds.contains(inv.id)) {
        _selectedInvoiceIds.remove(inv.id);
        _selectedInvoiceNos.remove(inv.invoiceNumber);
      } else {
        _selectedInvoiceIds.add(inv.id);
        _selectedInvoiceNos.add(inv.invoiceNumber);
        // Auto-fill amount from first selected
        if (_selectedInvoiceIds.length == 1 && _chequeAmtCtrl.text.isEmpty) {
          _chequeAmtCtrl.text = inv.invoiceAmount;
        }
      }
    });
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try {
      initial = DateFormat('dd-MM-yyyy').parse(_chequeDateCtrl.text);
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _chequeDateCtrl.text = DateFormat('dd-MM-yyyy').format(picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedInvoiceIds.isEmpty) {
      Get.snackbar('Select Invoices', 'Please select at least one invoice.',
          backgroundColor: AppTheme.warning, colorText: Colors.white);
      return;
    }
    setState(() => _saving = true);
    final data = {
      'chequeNumber': _chequeNoCtrl.text.trim(),
      'chequeDate': _chequeDateCtrl.text.trim(),
      'chequeAmount': _chequeAmtCtrl.text.trim(),
      'bankName': _bankNameCtrl.text.trim(),
      'selectedInvoicesIdList': _selectedInvoiceIds.toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final ok = await _fs.createChequeCollection(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Saved', 'Cheque collection recorded.',
          backgroundColor: AppTheme.stageCheque, colorText: Colors.white);
      // Reset form, reload invoices for same party
      setState(() {
        _selectedInvoiceIds = {};
        _selectedInvoiceNos = {};
        _chequeNoCtrl.clear();
        _chequeDateCtrl.clear();
        _chequeAmtCtrl.clear();
        _bankNameCtrl.clear();
      });
      if (_selectedParty != null) _selectParty(_selectedParty!);
    } else {
      Get.snackbar('Error', 'Failed to save. Please try again.',
          backgroundColor: AppTheme.danger, colorText: Colors.white);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        backgroundColor: AppTheme.stageCheque,
        elevation: 0,
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cheque Collection',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text('Stage 5 · Select party then invoices',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
        actions: [
          GestureDetector(
            onTap: () => HomePage.openMasters(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_special_rounded,
                    size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('Masters',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ]),
            ),
          ),
        ],
      ),
      body: _loadingParties
          ? const Center(child: CircularProgressIndicator())
          : _parties.isEmpty
              ? _buildNoParties()
              : Row(children: [
                  // ── Left: Party sidebar ────────────────────────────────
                  _buildPartySidebar(),
                  // ── Right: Invoice + Cheque panel ──────────────────────
                  Expanded(
                      child: _selectedParty == null
                          ? _buildSelectPrompt()
                          : _buildRightPanel()),
                ]),
    );
  }

  // ── No parties placeholder ─────────────────────────────────────────────────
  Widget _buildNoParties() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: AppTheme.stageCheque.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: Icon(Icons.payments_outlined,
              size: 36, color: AppTheme.stageCheque.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        const Text('No parties configured',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text(
            'Enable "Requires Cheque Collection" on parties in Masters → Party Management.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => HomePage.openMasters(context),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open Masters'),
        ),
      ]),
    ));
  }

  // ── Party sidebar ──────────────────────────────────────────────────────────
  Widget _buildPartySidebar() {
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          color: AppTheme.stageCheque.withValues(alpha: 0.06),
          child: const Text('Parties',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.stageCheque,
                  letterSpacing: 0.5)),
        ),
        Expanded(
            child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: _parties.length,
          itemBuilder: (_, i) {
            final p = _parties[i];
            final selected = _selectedParty?.partyId == p.partyId;
            return GestureDetector(
              onTap: () => _selectParty(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.stageCheque.withValues(alpha: 0.08)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color:
                          selected ? AppTheme.stageCheque : Colors.transparent,
                      width: 3,
                    ),
                    bottom: BorderSide(color: AppTheme.divider, width: 0.5),
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.partyName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? AppTheme.stageCheque
                                : AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (p.routeName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(p.routeName,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  // ── Select prompt ──────────────────────────────────────────────────────────
  Widget _buildSelectPrompt() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.touch_app_rounded,
          size: 40, color: AppTheme.stageCheque.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      const Text('Select a party',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
      const SizedBox(height: 4),
      const Text('to view pending invoices',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
    ]));
  }

  // ── Right panel ────────────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Column(children: [
      // Party header strip
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.stageCheque.withValues(alpha: 0.06),
          border: Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppTheme.stageCheque.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.store_rounded,
                color: AppTheme.stageCheque, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_selectedParty!.partyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                if (_selectedParty!.routeName.isNotEmpty)
                  Text(_selectedParty!.routeName,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ])),
          if (_partyInvoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedInvoiceIds.isEmpty
                    ? AppTheme.surface
                    : AppTheme.stageCheque.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.stageCheque.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${_selectedInvoiceIds.length}/${_partyInvoices.length} selected',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.stageCheque,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      ),

      Expanded(
          child: _loadingInvoices
              ? const Center(child: CircularProgressIndicator())
              : _partyInvoices.isEmpty
                  ? _buildNoInvoices()
                  : Builder(
                      builder: (context) => ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(12, 12, 12,
                                MediaQuery.of(context).viewInsets.bottom + 24),
                            children: [
                              // Invoice list
                              ..._partyInvoices
                                  .map((inv) => _buildInvoiceTile(inv)),
                              // Cheque form — only show when invoices selected
                              if (_selectedInvoiceIds.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildChequeForm(),
                              ],
                            ],
                          ))),
    ]);
  }

  Widget _buildNoInvoices() {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No pending invoices\nfor ${_selectedParty!.partyName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
      ]),
    ));
  }

  // ── Invoice tile ───────────────────────────────────────────────────────────
  Widget _buildInvoiceTile(InvoiceData inv) {
    final selected = _selectedInvoiceIds.contains(inv.id);
    return GestureDetector(
      onTap: () => _toggleInvoice(inv),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.stageCheque.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.stageCheque : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selected ? AppTheme.stageCheque : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: selected
                    ? AppTheme.stageCheque
                    : AppTheme.textSecondary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
          ),
          const SizedBox(width: 12),
          // Invoice info
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected
                            ? AppTheme.stageCheque
                            : AppTheme.textPrimary,
                      )),
                  const SizedBox(width: 8),
                  if (inv.orderType.isNotEmpty)
                    OrderTypeFlag(
                        orderTypeKey: inv.orderType, avatarOnly: true),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Text(inv.companyName,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  Text('· ${inv.invoiceDate}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ]),
              ])),
          // Amount
          Text('₹${inv.invoiceAmount}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? AppTheme.stageCheque : AppTheme.success,
              )),
        ]),
      ),
    );
  }

  // ── Cheque form ────────────────────────────────────────────────────────────
  Widget _buildChequeForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stageCheque.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.stageCheque.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(
                bottom: BorderSide(
                    color: AppTheme.stageCheque.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            const Icon(Icons.payments_rounded,
                color: AppTheme.stageCheque, size: 16),
            const SizedBox(width: 8),
            const Text('Cheque Details',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.stageCheque)),
            const Spacer(),
            // Selected invoices chips
            Expanded(
                child: Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: _selectedInvoiceNos
                  .map((no) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.stageCheque.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(no,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.stageCheque,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _formField(
                      _chequeNoCtrl, 'Cheque Number', Icons.tag_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                    child: _formField(_chequeDateCtrl, 'Cheque Date',
                        Icons.calendar_today_rounded)),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _formField(
                      _chequeAmtCtrl, 'Amount', Icons.currency_rupee_rounded,
                      numeric: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _formField(_bankNameCtrl, 'Bank Name',
                      Icons.account_balance_rounded)),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_saving || !AuthService.to.perms.canUpdate(ScreenKeys.step5)) ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Record Cheque Collection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.stageCheque,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _formField(TextEditingController ctrl, String label, IconData icon,
      {bool numeric = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
    );
  }
}
