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
//  Step 3 — Dispatch (Create)
// ─────────────────────────────────────────────────────────────────────────────

enum _SortMode { route, company }

class Step3 extends StatefulWidget {
  @override
  _Step3State createState() => _Step3State();
}

class _Step3State extends State<Step3> {
  final _formKey = GlobalKey<FormState>();
  final _tripNumberCtrl = TextEditingController();
  final _openingKmCtrl = TextEditingController();
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleDetailsCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  Set<String> selectedInvoices = {};
  List<InvoiceData> invoices = [];
  List<String> selectedInvoicesIdList = [];
  Map<int, Map<int, int>> _countMap = {};
  bool isLoading = false;
  bool isSaving = false;
  Map<String, TextEditingController> ewayBillControllers = {};
  // Key to reset the Autocomplete widget (clears search box after selection)
  Key _autocompleteKey = UniqueKey();

  String? _detectedTransport;
  String? _detectedRoute;
  List<String> _suggestedTransports = [];
  List<String> _transportList = [];
  String? _selectedTransport;
  List<RouteData> _routes = [];

  // ── Route Planner ─────────────────────────────────────────────────────────
  RouteData? _plannerRoute; // null = All Routes
  bool _plannerExpanded = true; // show planner panel by default

  // ── NEW: Date filter ──────────────────────────────────────────────────────
  DateTime? _dispatchDate; // null means no date filter (show all)
  bool _dateSelected = false; // gate: must pick date before seeing invoices

  // ── Sort mode for invoice lists ───────────────────────────────────────────
  _SortMode _sortMode = _SortMode.route; // default: by route

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step3, label: 'Dispatch'));
    _autoFillTripNumber();
  }

  @override
  void dispose() {
    ewayBillControllers.values.forEach((c) => c.dispose());
    _tripNumberCtrl.dispose();
    _openingKmCtrl.dispose();
    _vehicleNumberCtrl.dispose();
    _vehicleDetailsCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoFillTripNumber() async {
    final next = await ApiService().getNextTripNumber();
    if (mounted && next.isNotEmpty) {
      _tripNumberCtrl.text = next;
    }
  }

  Future<void> _pickDispatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dispatchDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Select Dispatch Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.stageDispatch,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dispatchDate = picked;
        _dateSelected = true;
        // Reset selections when date changes
        selectedInvoices.clear();
        selectedInvoicesIdList.clear();
        ewayBillControllers.values.forEach((c) => c.dispose());
        ewayBillControllers.clear();
        _detectedTransport = null;
        _detectedRoute = null;
        _suggestedTransports = [];
      });
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final fs = ApiService();
    final List<InvoiceData> fetchedInvoices;
    if (_dispatchDate != null) {
      fetchedInvoices = await fs.getInvoicesUpToDate(_dispatchDate!);
    } else {
      fetchedInvoices = await fs.getInvoices(2);
    }
    final fetchedRoutes = await fs.getRoutes();
    final fetchedTransports = await fs.getTransport();
    final counts = await fs.getInvoiceCountMap(2);
    // Sort by stop sequence so dispatch list matches delivery order
    fetchedInvoices.sort((a, b) {
      final stopCmp = a.partyData.stopSeq.compareTo(b.partyData.stopSeq);
      if (stopCmp != 0) return stopCmp;
      final partyCmp = a.partyData.partyName.compareTo(b.partyData.partyName);
      if (partyCmp != 0) return partyCmp;
      return a.invoiceNumber.compareTo(b.invoiceNumber);
    });
    if (mounted) {
      setState(() {
        _countMap = counts;
        invoices = fetchedInvoices;
        _routes = fetchedRoutes;
        _transportList = fetchedTransports.map((t) => t.trim()).toList();
        isLoading = false;
      });
    }
  }

  void _updateFormFields() {
    if (selectedInvoices.isEmpty) {
      ewayBillControllers.values.forEach((c) => c.dispose());
      ewayBillControllers.clear();
      setState(() {
        _detectedTransport = null;
        _detectedRoute = null;
        _suggestedTransports = [];
        _selectedTransport = null;
        _vehicleNumberCtrl.clear();
      });
      return;
    }
    // Collect all selected InvoiceData objects
    final selectedData = selectedInvoices
        .map((n) => invoices
            .cast<InvoiceData?>()
            .firstWhere((d) => d?.invoiceNumber == n, orElse: () => null))
        .whereType<InvoiceData>()
        .toList();

    // Detect most common route among selected invoices
    final routeCounts = <String, int>{};
    for (final d in selectedData) {
      final r = d.routeName ?? d.partyData.routeName;
      if (r.isNotEmpty) routeCounts[r] = (routeCounts[r] ?? 0) + 1;
    }
    final dominantRoute = routeCounts.isNotEmpty
        ? (routeCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key
        : '';
    final route = _routes
        .cast<RouteData?>()
        .firstWhere((r) => r?.routeName == dominantRoute, orElse: () => null);

    // Transport — use first selected invoice's transport as hint
    final firstSelected = selectedData.isNotEmpty ? selectedData.first : null;

    setState(() {
      _detectedTransport = firstSelected?.partyData.transportName;
      _detectedRoute = dominantRoute.isNotEmpty ? dominantRoute : null;
      _suggestedTransports = route?.transportNames ?? [];
      // Auto-select transport from party default if in master list
      if (_selectedTransport == null &&
          _detectedTransport != null &&
          _transportList.contains(_detectedTransport)) {
        _selectedTransport = _detectedTransport;
      }
      if (_suggestedTransports.length == 1)
        _vehicleDetailsCtrl.text = _suggestedTransports.first;
      ewayBillControllers.keys
          .where((inv) => !selectedInvoices.contains(inv))
          .toList()
          .forEach((inv) {
        ewayBillControllers[inv]?.dispose();
        ewayBillControllers.remove(inv);
      });
      for (String invNum in selectedInvoices) {
        if (!ewayBillControllers.containsKey(invNum)) {
          final inv = invoices.firstWhere((d) => d.invoiceNumber == invNum);
          ewayBillControllers[invNum] =
              TextEditingController(text: inv.ewayBillNumber);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Dispatch',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          const Text('Chhattisgarh C & F Agency Pvt Ltd',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        backgroundColor: AppTheme.stageDispatch,
        actions: [
          GestureDetector(
            onTap: () => HomePage.openMasters(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_special_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text('Masters',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14)),
            child: const Text('Stage 3',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(children: [
        // ── Date picker banner — must select before seeing invoices ───────
        _buildDateBanner(),
        Expanded(
          child: !_dateSelected
              ? _buildDatePrompt()
              : isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) => SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(12, 12, 12,
                                MediaQuery.of(context).viewInsets.bottom + 24),
                            child: Form(
                              key: _formKey,
                              child: Column(children: [
                                _buildRoutePlanner(),
                                const SizedBox(height: 10),
                                _buildInvoiceSection(),
                                if (selectedInvoices.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Builder(builder: (ctx) {
                                    final first = invoices
                                        .cast<InvoiceData?>()
                                        .firstWhere(
                                            (d) =>
                                                d?.invoiceNumber ==
                                                selectedInvoices.first,
                                            orElse: () => null);
                                    if (first == null)
                                      return const SizedBox.shrink();
                                    return OrderTypeFlag(
                                        orderTypeKey: first.orderType,
                                        specialRemarks: first.specialRemarks);
                                  }),
                                  const SizedBox(height: 10),
                                  _buildRouteInfoCard(),
                                  const SizedBox(height: 16),
                                  _buildEwayBillSection(),
                                  const SizedBox(height: 16),
                                  _buildDispatchDetailsCard(),
                                  const SizedBox(height: 24),
                                  _buildSubmitButton(),
                                ],
                                const SizedBox(height: 24),
                              ]),
                            ),
                          )),
        ),
      ]),
    );
  }

  // ── Date banner ────────────────────────────────────────────────────────────
  Widget _buildDateBanner() {
    return GestureDetector(
      onTap: _pickDispatchDate,
      child: Container(
        color: _dateSelected
            ? AppTheme.stageDispatch.withValues(alpha: 0.12)
            : AppTheme.stageDispatch,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(Icons.event_rounded,
              color: _dateSelected ? AppTheme.stageDispatch : Colors.white,
              size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  _dateSelected
                      ? 'Dispatch Date: ${DateFormat('dd MMM yyyy').format(_dispatchDate!)}'
                      : 'Select Dispatch Date to begin',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color:
                        _dateSelected ? AppTheme.stageDispatch : Colors.white,
                  ),
                ),
                Text(
                  _dateSelected
                      ? 'Showing invoices on or before this date  (tap to change)'
                      : 'Invoices will be filtered to on or before the chosen date',
                  style: TextStyle(
                    fontSize: 10,
                    color: _dateSelected
                        ? AppTheme.stageDispatch.withValues(alpha: 0.7)
                        : Colors.white70,
                  ),
                ),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _dateSelected ? AppTheme.stageDispatch : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _dateSelected ? 'Change' : 'Pick Date',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _dateSelected ? Colors.white : AppTheme.stageDispatch,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDatePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.stageDispatch.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded,
                size: 44, color: AppTheme.stageDispatch),
          ),
          const SizedBox(height: 20),
          const Text('Select Dispatch Date First',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Choose a date to see all invoices eligible for dispatch on or before that day.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickDispatchDate,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.stageDispatch,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
            icon: const Icon(Icons.event_rounded),
            label: const Text('Select Date', style: TextStyle(fontSize: 15)),
          ),
        ]),
      ),
    );
  }

  // ── Invoice section ────────────────────────────────────────────────────────
  // ── Route Planner Panel ────────────────────────────────────────────────────
  Widget _buildRoutePlanner() {
    final color = AppTheme.stageDispatch;
    // Invoices available for this date
    final availableInvoices = invoices;

    // Which routes have at least one invoice? (for "All" count)
    final routesWithInvoices = _routes.where((r) {
      return availableInvoices.any((inv) {
        final invRoute = inv.routeName ?? inv.partyData.routeName;
        return invRoute == r.routeName;
      });
    }).toList();

    // Build stop-wise invoice groups for the selected route
    List<_StopGroup> stopGroups = [];
    if (_plannerRoute != null && _plannerRoute!.stops.isNotEmpty) {
      for (int i = 0; i < _plannerRoute!.stops.length; i++) {
        final stop = _plannerRoute!.stops[i];
        final stopInvoices = availableInvoices.where((inv) {
          final invRoute = inv.routeName ?? inv.partyData.routeName;
          return invRoute == _plannerRoute!.routeName;
        }).toList();
        // Match invoices to stop using exact stopName on party (with fuzzy fallback)
        final matched = stopInvoices.where((inv) {
          // Prefer exact stop name match from party data
          if (inv.partyData.stopName.isNotEmpty) {
            return inv.partyData.stopName.toLowerCase() == stop.toLowerCase();
          }
          // Fallback: fuzzy match on party name or address
          final party = inv.partyData.partyName.toLowerCase();
          final addr = inv.partyData.address.toLowerCase();
          final stopLower = stop.toLowerCase();
          return party.contains(stopLower) || addr.contains(stopLower);
        }).toList();
        stopGroups.add(_StopGroup(index: i, stopName: stop, invoices: matched));
      }
      // Unmatched invoices for this route (not pinned to any stop)
      final matchedIds =
          stopGroups.expand((g) => g.invoices.map((i) => i.id)).toSet();
      final unmatched = availableInvoices.where((inv) {
        final invRoute = inv.routeName ?? inv.partyData.routeName;
        return invRoute == _plannerRoute!.routeName &&
            !matchedIds.contains(inv.id);
      }).toList();
      if (unmatched.isNotEmpty) {
        stopGroups.add(_StopGroup(
            index: -1, stopName: 'Unassigned to stop', invoices: unmatched));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header — tappable to collapse
        InkWell(
          onTap: () => setState(() => _plannerExpanded = !_plannerExpanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(Icons.map_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Route Planner',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontSize: 13))),
              if (_plannerRoute != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(_plannerRoute!.routeName,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 6),
              Icon(
                  _plannerExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: color,
                  size: 20),
            ]),
          ),
        ),

        if (_plannerExpanded) ...[
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Route selector ─────────────────────────────────────
              const Text('SELECT ROUTE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  // All routes chip
                  GestureDetector(
                    onTap: () => setState(() => _plannerRoute = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _plannerRoute == null ? color : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _plannerRoute == null
                                ? color
                                : AppTheme.divider,
                            width: _plannerRoute == null ? 1.5 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.all_inclusive_rounded,
                            size: 14,
                            color:
                                _plannerRoute == null ? Colors.white : color),
                        const SizedBox(width: 5),
                        Text('All Routes',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _plannerRoute == null
                                    ? Colors.white
                                    : AppTheme.textPrimary)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _plannerRoute == null
                                ? Colors.white.withValues(alpha: 0.25)
                                : color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${routesWithInvoices.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _plannerRoute == null
                                      ? Colors.white
                                      : color)),
                        ),
                      ]),
                    ),
                  ),
                  // Individual route chips
                  ..._routes.map((r) {
                    final active = _plannerRoute?.routeId == r.routeId;
                    final count = availableInvoices.where((inv) {
                      final ir = inv.routeName ?? inv.partyData.routeName;
                      return ir == r.routeName;
                    }).length;
                    return GestureDetector(
                      onTap: () => setState(() => _plannerRoute = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? color : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: active ? color : AppTheme.divider,
                              width: active ? 1.5 : 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.route_rounded,
                              size: 14, color: active ? Colors.white : color),
                          const SizedBox(width: 5),
                          Text(r.routeName,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : AppTheme.textPrimary)),
                          if (count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: active
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$count',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: active ? Colors.white : color)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Content area ───────────────────────────────────────
              if (_plannerRoute == null) ...[
                // All Routes — flat list grouped by route name
                ..._routes.map((r) {
                  final rInvoices = availableInvoices.where((inv) {
                    final ir = inv.routeName ?? inv.partyData.routeName;
                    return ir == r.routeName;
                  }).toList();
                  if (rInvoices.isEmpty) return const SizedBox.shrink();
                  return _RouteGroup(
                    route: r,
                    invoices: rInvoices,
                    color: color,
                    onTapInvoice: (inv) => _addInvoiceFromPlanner(inv),
                    selectedInvoices: selectedInvoices,
                  );
                }),
                if (availableInvoices.every((inv) {
                  final ir = inv.routeName ?? inv.partyData.routeName;
                  return ir.isEmpty;
                }))
                  _emptyPlanner('No invoices have routes assigned yet'),
              ] else ...[
                // Single Route — show stops with invoices under each
                if (_plannerRoute!.stops.isEmpty)
                  _emptyPlanner(
                      'This route has no stops defined. Edit the route in Masters → Routes to add stops.')
                else
                  ...stopGroups.map((sg) => _StopGroupWidget(
                        group: sg,
                        color: color,
                        onTapInvoice: (inv) => _addInvoiceFromPlanner(inv),
                        selectedInvoices: selectedInvoices,
                      )),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  void _addInvoiceFromPlanner(InvoiceData inv) {
    setState(() {
      if (selectedInvoices.contains(inv.invoiceNumber)) {
        // Deselect: remove this invoice and any linked invoices
        selectedInvoices.remove(inv.invoiceNumber);
        selectedInvoicesIdList.remove(inv.id);
        for (var id in inv.selectedInvoicesIdList) {
          final linked = invoices
              .cast<InvoiceData?>()
              .firstWhere((d) => d?.id == id, orElse: () => null);
          if (linked != null) {
            selectedInvoices.remove(linked.invoiceNumber);
            selectedInvoicesIdList.remove(linked.id);
          }
        }
      } else {
        // Select: add this invoice and any linked invoices
        selectedInvoices.add(inv.invoiceNumber);
        selectedInvoicesIdList.add(inv.id);
        for (var id in inv.selectedInvoicesIdList) {
          final linked = invoices
              .cast<InvoiceData?>()
              .firstWhere((d) => d?.id == id, orElse: () => null);
          if (linked != null) {
            selectedInvoices.add(linked.invoiceNumber);
            selectedInvoicesIdList.add(linked.id);
          }
        }
      }
      _updateFormFields();
      _autocompleteKey = UniqueKey();
    });
  }

  Widget _emptyPlanner(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4))),
        ]),
      );

  // ── Sorted invoice list based on current sort mode ───────────────────────
  List<InvoiceData> _sortedInvoices() {
    final list = List<InvoiceData>.from(invoices);
    if (_sortMode == _SortMode.company) {
      list.sort((a, b) {
        final c =
            a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
        if (c != 0) return c;
        return a.invoiceNumber
            .toLowerCase()
            .compareTo(b.invoiceNumber.toLowerCase());
      });
    } else {
      list.sort((a, b) {
        final rA = (a.routeName ?? a.partyData.routeName).toLowerCase();
        final rB = (b.routeName ?? b.partyData.routeName).toLowerCase();
        final c = rA.compareTo(rB);
        if (c != 0) return c;
        return a.invoiceNumber
            .toLowerCase()
            .compareTo(b.invoiceNumber.toLowerCase());
      });
    }
    return list;
  }

  Widget _buildInvoiceSection() {
    final sorted = _sortedInvoices();
    // Group label → invoices for the browse list (only unselected)
    final unselected = sorted
        .where((d) => !selectedInvoices.contains(d.invoiceNumber))
        .toList();
    Map<String, List<InvoiceData>> grouped = {};
    for (final inv in unselected) {
      final key = _sortMode == _SortMode.company
          ? (inv.companyName.isNotEmpty ? inv.companyName : 'No Company')
          : ((inv.routeName ?? inv.partyData.routeName).isNotEmpty
              ? (inv.routeName ?? inv.partyData.routeName)
              : 'No Route');
      grouped.putIfAbsent(key, () => []).add(inv);
    }
    final groupKeys = grouped.keys.toList()..sort();

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
        // ── Header with sort toggle ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.stageDispatch.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded,
                color: AppTheme.stageDispatch, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Select Invoices (${invoices.length} available)',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.stageDispatch,
                  fontSize: 13,
                  letterSpacing: 0.5),
            )),
            // Sort toggle chips
            _SortChip(
              label: 'Route',
              icon: Icons.route_rounded,
              active: _sortMode == _SortMode.route,
              color: AppTheme.stageDispatch,
              onTap: () => setState(() => _sortMode = _SortMode.route),
            ),
            const SizedBox(width: 6),
            _SortChip(
              label: 'Company',
              icon: Icons.business_rounded,
              active: _sortMode == _SortMode.company,
              color: AppTheme.stageDispatch,
              onTap: () => setState(() => _sortMode = _SortMode.company),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Search autocomplete
            Autocomplete<InvoiceData>(
              key: _autocompleteKey,
              optionsBuilder: (tv) {
                return invoices.where((d) {
                  if (selectedInvoices.contains(d.invoiceNumber)) return false;
                  if (tv.text.isEmpty) return true;
                  return d.invoiceNumber
                          .toLowerCase()
                          .contains(tv.text.toLowerCase()) ||
                      d.partyData.partyName
                          .toLowerCase()
                          .contains(tv.text.toLowerCase()) ||
                      d.companyName
                          .toLowerCase()
                          .contains(tv.text.toLowerCase()) ||
                      (d.routeName ?? d.partyData.routeName)
                          .toLowerCase()
                          .contains(tv.text.toLowerCase());
                });
              },
              displayStringForOption: (o) => o.invoiceNumber,
              fieldViewBuilder: (ctx, tc, fn, onSubmit) => TextFormField(
                controller: tc,
                focusNode: fn,
                decoration: const InputDecoration(
                  labelText: 'Search & Select Invoice',
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Type invoice number, party, company or route...',
                ),
              ),
              onSelected: (inv) {
                setState(() {
                  selectedInvoices.add(inv.invoiceNumber);
                  selectedInvoicesIdList.add(inv.id);
                  for (var id in inv.selectedInvoicesIdList) {
                    final linked = invoices
                        .cast<InvoiceData?>()
                        .firstWhere((d) => d?.id == id, orElse: () => null);
                    if (linked != null) {
                      selectedInvoices.add(linked.invoiceNumber);
                      selectedInvoicesIdList.add(linked.id);
                    }
                  }
                  _updateFormFields();
                  _autocompleteKey = UniqueKey();
                });
              },
            ),

            // ── Grouped browse list ────────────────────────────────────
            if (unselected.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                Icon(
                  _sortMode == _SortMode.route
                      ? Icons.route_rounded
                      : Icons.business_rounded,
                  size: 12,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  _sortMode == _SortMode.route
                      ? 'Grouped by Route'
                      : 'Grouped by Company',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text('${unselected.length} available',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 8),
              ...groupKeys.map((groupKey) {
                final groupInvoices = grouped[groupKey]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.stageDispatch.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(children: [
                            Icon(
                              _sortMode == _SortMode.route
                                  ? Icons.route_rounded
                                  : Icons.business_rounded,
                              size: 12,
                              color: AppTheme.stageDispatch,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(groupKey,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.stageDispatch),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppTheme.stageDispatch,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('${groupInvoices.length}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 5),
                        ...groupInvoices.map((inv) => _PlannerInvoiceTile(
                              inv: inv,
                              color: AppTheme.stageDispatch,
                              selected:
                                  selectedInvoices.contains(inv.invoiceNumber),
                              onTap: () => _addInvoiceFromPlanner(inv),
                              indent: false,
                            )),
                      ]),
                );
              }),
            ],

            // ── Selected chips ─────────────────────────────────────────
            if (selectedInvoices.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('Selected (${selectedInvoices.length})',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.stageDispatch)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: selectedInvoices.map((inv) {
                  final data = invoices.cast<InvoiceData?>().firstWhere(
                      (d) => d?.invoiceNumber == inv,
                      orElse: () => null);
                  return Chip(
                    avatar: data != null
                        ? OrderTypeFlag(
                            orderTypeKey: data.orderType, avatarOnly: true)
                        : const Icon(Icons.receipt_outlined, size: 14),
                    label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(inv,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if (data != null)
                            Text(
                                '₹${data.invoiceAmount} · ${data.partyData.partyName}',
                                style: const TextStyle(fontSize: 10)),
                        ]),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        selectedInvoices.remove(inv);
                        final d = invoices.cast<InvoiceData?>().firstWhere(
                            (d) => d?.invoiceNumber == inv,
                            orElse: () => null);
                        if (d != null) {
                          selectedInvoicesIdList.remove(d.id);
                          for (var lid in d.selectedInvoicesIdList) {
                            final linked = invoices
                                .cast<InvoiceData?>()
                                .firstWhere((inv) => inv?.id == lid,
                                    orElse: () => null);
                            if (linked != null) {
                              selectedInvoices.remove(linked.invoiceNumber);
                              selectedInvoicesIdList.remove(linked.id);
                            }
                          }
                        }
                        _updateFormFields();
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.stageDispatch.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.stageDispatch.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.route_rounded,
              color: AppTheme.stageDispatch, size: 18),
          const SizedBox(width: 8),
          const Text('Route & Transport Info',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.stageDispatch)),
        ]),
        const SizedBox(height: 10),
        if (_detectedRoute != null)
          _InfoChip(
              icon: Icons.route_rounded,
              label: 'Route: $_detectedRoute',
              color: AppTheme.stageDispatch),
        const SizedBox(height: 6),
        if (_detectedTransport != null)
          _InfoChip(
              icon: Icons.local_shipping_rounded,
              label: 'Default Transport: $_detectedTransport',
              color: AppTheme.stagePacking),
        // Transport chips removed — now using master transport dropdown
      ]),
    );
  }

  Widget _buildEwayBillSection() {
    return _SectionCard(
      title: 'E-way Bill Numbers',
      icon: Icons.document_scanner_rounded,
      color: AppTheme.stageDispatch,
      children: [
        ...selectedInvoices.map((inv) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: ewayBillControllers[inv],
                decoration: InputDecoration(
                    labelText: 'E-way Bill · $inv',
                    prefixIcon:
                        const Icon(Icons.document_scanner_rounded, size: 18)),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
            )),
      ],
    );
  }

  Widget _buildDispatchDetailsCard() {
    return _SectionCard(
      title: 'Dispatch Details',
      icon: Icons.local_shipping_rounded,
      color: AppTheme.stageDispatch,
      children: [
        DropdownButtonFormField<String>(
          value: _transportList.contains(_selectedTransport)
              ? _selectedTransport
              : null,
          decoration: const InputDecoration(
            labelText: 'Transport *',
            prefixIcon: Icon(Icons.local_shipping_rounded),
          ),
          isExpanded: true,
          hint: const Text('Select transport'),
          items: _transportList
              .map((t) => DropdownMenuItem(
                  value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) => setState(() => _selectedTransport = val),
          validator: (val) => val == null ? 'Please select transport' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _vehicleNumberCtrl,
          decoration: const InputDecoration(
              labelText: 'Vehicle Number', prefixIcon: Icon(Icons.pin_rounded)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextFormField(
            controller: _tripNumberCtrl,
            decoration: const InputDecoration(
                labelText: 'Trip Number *',
                prefixIcon: Icon(Icons.tag_rounded)),
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          )),
          const SizedBox(width: 12),
          Expanded(
              child: TextFormField(
            controller: _openingKmCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Opening KM *',
                prefixIcon: Icon(Icons.speed_rounded)),
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          )),
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _remarksCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Remarks', prefixIcon: Icon(Icons.notes_rounded)),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.stageDispatch,
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: (isSaving || !AuthService.to.perms.canUpdate(ScreenKeys.step3)) ? null : _submit,
        icon: isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.local_shipping_rounded),
        label: const Text('Submit Dispatch', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedInvoices.isEmpty) {
      Get.snackbar('Error', 'Please select at least one invoice');
      return;
    }
    setState(() => isSaving = true);

    Map<String, String> ewayBillMap = {};
    for (String inv in selectedInvoices) {
      final invData = invoices.firstWhere((d) => d.invoiceNumber == inv);
      ewayBillMap[invData.id] = ewayBillControllers[inv]?.text ?? '';
    }

    final data = {
      'tripNumber': _tripNumberCtrl.text.trim(),
      'openingKm': _openingKmCtrl.text.trim(),
      'transportName': _selectedTransport ?? '',
      'vehicleNumber': _vehicleNumberCtrl.text.trim(),
      'routeName': _detectedRoute ?? '',
      'remarks': _remarksCtrl.text.trim(),
      'dispatchDate': _dispatchDate != null
          ? DateFormat('dd/MM/yyyy').format(_dispatchDate!)
          : '',
      'ewayBillNumbers': ewayBillMap,
      'selectedInvoicesIdList': selectedInvoicesIdList,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final success = await ApiService().createDispatch(data);
    setState(() => isSaving = false);

    if (success) {
      Get.snackbar('Dispatched!', 'Dispatch recorded successfully',
          backgroundColor: AppTheme.stageDispatch, colorText: Colors.white);
      setState(() {
        selectedInvoices.clear();
        selectedInvoicesIdList.clear();
        ewayBillControllers.values.forEach((c) => c.dispose());
        ewayBillControllers.clear();
        _tripNumberCtrl.clear();
        _openingKmCtrl.clear();
        _vehicleDetailsCtrl.clear();
        _vehicleNumberCtrl.clear();
        _remarksCtrl.clear();
        _detectedRoute = null;
        _detectedTransport = null;
        _suggestedTransports = [];
      });
      _autoFillTripNumber();
      _fetchData();
    } else {
      Get.snackbar('Error', 'Failed to save dispatch');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 3 Edit Page — edit an existing dispatched trip
// ─────────────────────────────────────────────────────────────────────────────
class Step3EditPage extends StatefulWidget {
  final String tripNumber;
  final List<InvoiceAcknowledgementData> invoices;
  final VoidCallback? onSaved;
  const Step3EditPage(
      {super.key,
      required this.tripNumber,
      required this.invoices,
      this.onSaved});
  @override
  State<Step3EditPage> createState() => _Step3EditPageState();
}

class _Step3EditPageState extends State<Step3EditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tripNumberCtrl;
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _openingKmCtrl;
  late final TextEditingController _remarksCtrl;
  String? _selectedTransport;
  List<String> _transportList = [];
  DateTime? _dispatchDate;
  bool _saving = false;

  // ── Add Invoice to Trip ────────────────────────────────────────────────────
  List<InvoiceData> _stage2Invoices = [];
  List<String> _selectedToAdd = []; // IDs of stage-2 invoices to add
  bool _loadingStage2 = false;
  bool _addMode = false; // toggle the add-invoices panel

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step3, label: 'Dispatch'));
    final first = widget.invoices.first;
    _tripNumberCtrl = TextEditingController(text: widget.tripNumber);
    _vehicleCtrl = TextEditingController(text: first.vehicleNumber ?? '');
    _selectedTransport =
        first.transportName.isNotEmpty ? first.transportName : null;
    _loadTransports();
    _openingKmCtrl = TextEditingController(text: first.openingKm);
    _remarksCtrl = TextEditingController();
    _dispatchDate = first.timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(first.timestamp)
        : DateTime.now();
  }

  Future<void> _loadTransports() async {
    final t = await ApiService().getTransport();
    if (mounted)
      setState(() {
        _transportList = t.map((s) => s.trim()).toList();
        // Keep selected if valid, else try to match
        if (_selectedTransport != null &&
            !_transportList.contains(_selectedTransport)) {
          _selectedTransport = null;
        }
      });
  }

  @override
  void dispose() {
    _tripNumberCtrl.dispose();
    _vehicleCtrl.dispose();
    _openingKmCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dispatchDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Edit Dispatch Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
              primary: AppTheme.stageDispatch, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dispatchDate = picked);
  }

  /// Fetch all stage-2 invoices for adding to this trip.
  Future<void> _loadStage2() async {
    setState(() {
      _loadingStage2 = true;
      _addMode = true;
    });
    final list = await ApiService().getInvoices(2);
    // Exclude invoices that are already in this trip
    final existingIds = widget.invoices.map((i) => i.id).toSet();
    if (!mounted) return;
    final filtered =
        list.where((inv) => !existingIds.contains(inv.id)).toList();
    // Sort company-wise for fast alignment
    filtered.sort((a, b) {
      final cmp =
          a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
      if (cmp != 0) return cmp;
      return a.invoiceNumber
          .toLowerCase()
          .compareTo(b.invoiceNumber.toLowerCase());
    });
    setState(() {
      _stage2Invoices = filtered;
      _loadingStage2 = false;
    });
  }

  /// Add selected stage-2 invoices to this trip.
  Future<void> _addInvoicesToTrip() async {
    if (_selectedToAdd.isEmpty) return;
    setState(() => _saving = true);
    final tripData = {
      'tripNumber': _tripNumberCtrl.text.trim(),
      'transportName': _selectedTransport ?? '',
      'vehicleNumber': _vehicleCtrl.text.trim(),
      'openingKm': _openingKmCtrl.text.trim(),
      'dispatchDate': _dispatchDate != null
          ? DateFormat('dd/MM/yyyy').format(_dispatchDate!)
          : '',
      'selectedInvoicesIdList': _selectedToAdd,
    };
    final ok = await ApiService().createDispatch(tripData);
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar(
        'Added!',
        '${_selectedToAdd.length} invoice${_selectedToAdd.length > 1 ? "s" : ""} added to Trip #${_tripNumberCtrl.text.trim()}',
        backgroundColor: AppTheme.stageDispatch,
        colorText: Colors.white,
      );
      setState(() {
        _selectedToAdd.clear();
        _addMode = false;
      });
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } else {
      Get.snackbar('Error', 'Failed to add invoices to trip. Try again.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ids =
        widget.invoices.map((i) => i.id).where((id) => id.isNotEmpty).toList();
    final data = {
      'tripNumber': _tripNumberCtrl.text.trim(),
      'transportName': _selectedTransport ?? '',
      'vehicleNumber': _vehicleCtrl.text.trim(),
      'openingKm': _openingKmCtrl.text.trim(),
      'dispatchDate': _dispatchDate != null
          ? DateFormat('dd/MM/yyyy').format(_dispatchDate!)
          : '',
    };
    final ok = await ApiService().updateDispatch(ids, data);
    setState(() => _saving = false);
    if (ok) {
      Get.snackbar('Updated!', 'Dispatch trip updated successfully',
          backgroundColor: AppTheme.stageDispatch, colorText: Colors.white);
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } else {
      Get.snackbar('Error', 'Failed to update dispatch');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.stageDispatch,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Dispatch',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text('Trip #${widget.tripNumber}',
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: (_saving || !AuthService.to.perms.canUpdate(ScreenKeys.step3)) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
            label: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Current invoices summary ──────────────────────────────────
            _SectionCard(
              title: 'Invoices in this Trip (${widget.invoices.length})',
              icon: Icons.receipt_long_rounded,
              color: AppTheme.primary,
              children: widget.invoices
                  .map((inv) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                              width: 3,
                              height: 28,
                              decoration: BoxDecoration(
                                  color: AppStages.color(inv.stage),
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(inv.invoiceNumber,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12))),
                          Expanded(
                              child: Text(inv.partyName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('₹${inv.invoiceAmount}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                              inv.totalCase.isNotEmpty
                                  ? '${inv.totalCase} cases'
                                  : '',
                              style: const TextStyle(
                                  fontSize: 10, color: AppTheme.textSecondary)),
                        ]),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),

            // ── ADD INVOICES BUTTON ───────────────────────────────────────
            if (!_addMode)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadStage2,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.stageDispatch,
                    side: const BorderSide(color: AppTheme.stageDispatch),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Add Invoices to This Trip',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),

            // ── ADD INVOICES PANEL ────────────────────────────────────────
            if (_addMode) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.stageDispatch.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.stageDispatch.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.stageDispatch.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.add_circle_outline_rounded,
                              color: AppTheme.stageDispatch, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('Add Stage-2 Invoices to Trip',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.stageDispatch,
                                    fontSize: 13,
                                    letterSpacing: 0.5)),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _addMode = false;
                              _selectedToAdd.clear();
                            }),
                            child: const Icon(Icons.close_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                        ]),
                      ),
                      if (_loadingStage2)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_stage2Invoices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text('No packed invoices available to add.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${_stage2Invoices.length} packed invoice${_stage2Invoices.length > 1 ? "s" : ""} available — sorted by company:',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                                const SizedBox(height: 8),
                                // Group invoices by company and show company header
                                ...() {
                                  final widgets = <Widget>[];
                                  String? lastCompany;
                                  for (final inv in _stage2Invoices) {
                                    // Company group header
                                    if (inv.companyName != lastCompany) {
                                      lastCompany = inv.companyName;
                                      widgets.add(Padding(
                                        padding: const EdgeInsets.only(
                                            top: 10, bottom: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.stageDispatch
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(inv.companyName,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.stageDispatch,
                                                letterSpacing: 0.3,
                                              )),
                                        ),
                                      ));
                                    }
                                    final selected =
                                        _selectedToAdd.contains(inv.id);
                                    widgets.add(GestureDetector(
                                      onTap: () => setState(() {
                                        if (selected)
                                          _selectedToAdd.remove(inv.id);
                                        else
                                          _selectedToAdd.add(inv.id);
                                      }),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.stageDispatch
                                                  .withValues(alpha: 0.10)
                                              : const Color(0xFFF5F6FA),
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          border: Border.all(
                                              color: selected
                                                  ? AppTheme.stageDispatch
                                                  : AppTheme.divider,
                                              width: selected ? 1.5 : 1),
                                        ),
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Icon(
                                                selected
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                        .radio_button_unchecked_rounded,
                                                color: selected
                                                    ? AppTheme.stageDispatch
                                                    : AppTheme.textSecondary,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              // Invoice number — full length, no truncation (mandatory)
                                              Text(inv.invoiceNumber,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                      color: selected
                                                          ? AppTheme
                                                              .stageDispatch
                                                          : AppTheme
                                                              .textPrimary)),
                                              const SizedBox(width: 8),
                                              // Party name — flexible, ellipsis
                                              Expanded(
                                                  child: Text(
                                                      inv.partyData.partyName,
                                                      maxLines: 1,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme
                                                              .textSecondary),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              const SizedBox(width: 6),
                                              // Amount — right-aligned
                                              Text('₹${inv.invoiceAmount}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11)),
                                            ]),
                                      ),
                                    ));
                                  }
                                  return widgets;
                                }(),
                              ]),
                        ),
                      if (_selectedToAdd.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.stageDispatch,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: (_saving || !AuthService.to.perms.canUpdate(ScreenKeys.step3)) ? null : _addInvoicesToTrip,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.add_circle_rounded,
                                      size: 18),
                              label: Text(
                                  'Add ${_selectedToAdd.length} Invoice${_selectedToAdd.length > 1 ? "s" : ""} to Trip',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                          ),
                        ),
                    ]),
              ),
            ],

            const SizedBox(height: 14),
            // ── Editable fields ───────────────────────────────────────────
            _SectionCard(
              title: 'Edit Dispatch Details',
              icon: Icons.edit_rounded,
              color: AppTheme.stageDispatch,
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_rounded,
                          color: AppTheme.stageDispatch, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Dispatch Date',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                            Text(
                              _dispatchDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(_dispatchDate!)
                                  : 'Tap to select date',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                            ),
                          ])),
                      const Icon(Icons.edit_calendar_rounded,
                          color: AppTheme.stageDispatch, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tripNumberCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Trip Number *',
                      prefixIcon: Icon(Icons.tag_rounded)),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _transportList.contains(_selectedTransport)
                      ? _selectedTransport
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Transport *',
                    prefixIcon: Icon(Icons.local_shipping_rounded),
                  ),
                  isExpanded: true,
                  hint: const Text('Select transport'),
                  items: _transportList.isEmpty
                      ? [
                          DropdownMenuItem(
                              value: _selectedTransport ?? '',
                              child: Text(_selectedTransport ?? 'Loading...'))
                        ]
                      : _transportList
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, overflow: TextOverflow.ellipsis)))
                          .toList(),
                  onChanged: (val) => setState(() => _selectedTransport = val),
                  validator: (v) =>
                      v == null ? 'Please select transport' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Number',
                      prefixIcon: Icon(Icons.pin_rounded)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _openingKmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Opening KM',
                      prefixIcon: Icon(Icons.speed_rounded)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.stageDispatch,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: (_saving || !AuthService.to.perms.canUpdate(ScreenKeys.step3)) ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label:
                    const Text('Save Changes', style: TextStyle(fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.children});
  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                    letterSpacing: 0.5)),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool tappable;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.color,
      this.tappable = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: tappable ? color : color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Route Planner Helper Models & Widgets ─────────────────────────────────────

// ── Sort chip toggle ──────────────────────────────────────────────────────────
class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? color : AppTheme.divider,
              width: active ? 1.5 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppTheme.textPrimary)),
        ]),
      ),
    );
  }
}

class _StopGroup {
  final int index; // -1 = unassigned
  final String stopName;
  final List<InvoiceData> invoices;
  const _StopGroup(
      {required this.index, required this.stopName, required this.invoices});
}

class _StopGroupWidget extends StatelessWidget {
  final _StopGroup group;
  final Color color;
  final void Function(InvoiceData) onTapInvoice;
  final Set<String> selectedInvoices;
  const _StopGroupWidget(
      {required this.group,
      required this.color,
      required this.onTapInvoice,
      required this.selectedInvoices});

  @override
  Widget build(BuildContext context) {
    final isUnassigned = group.index == -1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Stop header
        Row(children: [
          if (!isUnassigned) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                  child: Text('${group.index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(Icons.help_outline_rounded,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text(group.stopName,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isUnassigned
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${group.invoices.length}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 6),
        if (group.invoices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 4),
            child: Text('No invoices at this stop',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6))),
          )
        else
          ...group.invoices.map((inv) => _PlannerInvoiceTile(
                inv: inv,
                color: color,
                selected: selectedInvoices.contains(inv.invoiceNumber),
                onTap: () => onTapInvoice(inv),
                indent: !isUnassigned,
              )),
        const Divider(height: 1, color: AppTheme.divider),
      ]),
    );
  }
}

class _RouteGroup extends StatelessWidget {
  final RouteData route;
  final List<InvoiceData> invoices;
  final Color color;
  final void Function(InvoiceData) onTapInvoice;
  final Set<String> selectedInvoices;
  const _RouteGroup(
      {required this.route,
      required this.invoices,
      required this.color,
      required this.onTapInvoice,
      required this.selectedInvoices});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.route_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
              child: Text(route.routeName,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${invoices.length}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
        const SizedBox(height: 6),
        ...invoices.map((inv) => _PlannerInvoiceTile(
              inv: inv,
              color: color,
              selected: selectedInvoices.contains(inv.invoiceNumber),
              onTap: () => onTapInvoice(inv),
              indent: true,
            )),
        const Divider(height: 1, color: AppTheme.divider),
      ]),
    );
  }
}

class _PlannerInvoiceTile extends StatelessWidget {
  final InvoiceData inv;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool indent;
  const _PlannerInvoiceTile(
      {required this.inv,
      required this.color,
      required this.selected,
      required this.onTap,
      this.indent = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 34 : 0, bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : AppTheme.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text(inv.invoiceNumber,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? color : AppTheme.textPrimary)),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(inv.partyData.partyName,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  Text('₹${inv.invoiceAmount}  ·  ${inv.companyName}',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ])),
            if (selected)
              Icon(Icons.remove_circle_rounded, color: color, size: 18)
            else
              Icon(Icons.add_circle_outline_rounded,
                  color: color.withValues(alpha: 0.5), size: 18),
          ]),
        ),
      ),
    );
  }
}
