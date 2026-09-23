import 'package:form_app/admin_pin.dart';
import 'package:form_app/permission_guard.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/data.dart';
import 'package:form_app/api_service.dart';
import 'package:get/get.dart';

class RouteHome extends StatefulWidget {
  const RouteHome({super.key});
  @override
  State<RouteHome> createState() => _RouteHomeState();
}

class _RouteHomeState extends State<RouteHome> {
  final ApiService _fs = ApiService();
  List<RouteData> _routes = [];
  List<String> _transports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => guardScreenView(ScreenKeys.route, label: 'Routes'));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final routes = await _fs.getRoutes();
    final transports = await _fs.getTransport();
    setState(() {
      _routes = routes;
      _transports = transports;
      _isLoading = false;
    });
  }

  void _showRouteDialog({RouteData? route}) {
    final nameCtrl = TextEditingController(text: route?.routeName ?? '');
    final descCtrl = TextEditingController(text: route?.description ?? '');
    List<String> selectedTransports = List.from(route?.transportNames ?? []);
    // Dynamic stops list — starts with existing stops or one empty entry
    List<TextEditingController> stopCtrls = (route?.stops ?? []).isNotEmpty
        ? route!.stops.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.stageAck,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.route_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                    route != null ? 'Edit Route' : 'New Route',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ]),
              ),

              Expanded(
                  child: SingleChildScrollView(
                controller: sc,
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic info
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Route Name *',
                          prefixIcon: Icon(Icons.route_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Delivery Stops ─────────────────────────────────────
                      _sectionLabel(
                        'Delivery Stops',
                        Icons.location_on_rounded,
                        AppTheme.stageAck,
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.stageAck.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.stageAck.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              size: 14, color: AppTheme.stageAck),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text(
                            'Tap + between stops to insert a new stop at that position. '
                            'Drag ≡ to reorder. Tap 🗑 to delete.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                height: 1.4),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 12),

                      // ── Dynamic stops with insert buttons ──────────────────
                      ...() {
                        final widgets = <Widget>[];

                        for (int i = 0; i < stopCtrls.length; i++) {
                          // Stop row
                          widgets.add(_StopRow(
                            key: ValueKey('stop_$i'),
                            index: i,
                            controller: stopCtrls[i],
                            totalStops: stopCtrls.length,
                            onChanged: () => setSheet(() {}),
                            onDelete: stopCtrls.length > 1
                                ? () => setSheet(() {
                                      stopCtrls[i].dispose();
                                      stopCtrls.removeAt(i);
                                    })
                                : null,
                            onMoveUp: i > 0
                                ? () => setSheet(() {
                                      final tmp = stopCtrls[i - 1];
                                      stopCtrls[i - 1] = stopCtrls[i];
                                      stopCtrls[i] = tmp;
                                    })
                                : null,
                            onMoveDown: i < stopCtrls.length - 1
                                ? () => setSheet(() {
                                      final tmp = stopCtrls[i + 1];
                                      stopCtrls[i + 1] = stopCtrls[i];
                                      stopCtrls[i] = tmp;
                                    })
                                : null,
                          ));

                          // Insert button BETWEEN stops (and after the last one)
                          widgets.add(_InsertStopButton(
                            label: i < stopCtrls.length - 1
                                ? 'Insert stop between ${i + 1} and ${i + 2}'
                                : 'Add stop at end',
                            onTap: () => setSheet(() {
                              stopCtrls.insert(i + 1, TextEditingController());
                            }),
                          ));
                        }
                        return widgets;
                      }(),

                      const SizedBox(height: 20),

                      // ── Transport assign ────────────────────────────────────
                      _sectionLabel(
                        'Assign Transports',
                        Icons.local_shipping_rounded,
                        AppTheme.stageDispatch,
                      ),
                      ..._transports.map((t) => CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title:
                                Text(t, style: const TextStyle(fontSize: 14)),
                            value: selectedTransports.contains(t),
                            activeColor: AppTheme.primary,
                            onChanged: (val) => setSheet(() {
                              if (val == true)
                                selectedTransports.add(t);
                              else
                                selectedTransports.remove(t);
                            }),
                          )),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.stageAck,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) {
                              Get.snackbar('Error', 'Route name is required');
                              return;
                            }
                            Navigator.pop(ctx);
                            final stops = stopCtrls
                                .map((c) => c.text.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            final data = {
                              'routeId': route?.routeId ?? '',
                              'routeName': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'transportNames': selectedTransports,
                              'stops': stops,
                            };
                            bool success;
                            if (route != null) {
                              success =
                                  await _fs.updateRoute(route.routeId, data);
                            } else {
                              success = await _fs.createRoute(data);
                            }
                            if (success) {
                              _loadData();
                              Get.snackbar(
                                'Success',
                                route == null
                                    ? 'Route created'
                                    : 'Route updated',
                                backgroundColor: AppTheme.stageAck,
                                colorText: Colors.white,
                              );
                            } else {
                              Get.snackbar('Error', 'Failed to save route');
                            }
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            route != null ? 'Update Route' : 'Save Route',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRoute(RouteData route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Route'),
        content: Text('Delete "${route.routeName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _fs.deleteRoute(route.routeId);
      _loadData();
      Get.snackbar('Deleted', 'Route deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.stageAck,
        title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Route Management',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              Text('Routes with ordered delivery stops',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: AuthService.to.perms.canAdd(ScreenKeys.route)
          ? FloatingActionButton.extended(
              onPressed: () => _showRouteDialog(),
              backgroundColor: AppTheme.stageAck,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Route',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route_rounded,
                            size: 64,
                            color: AppTheme.stageAck.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No routes defined',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            )),
                        const SizedBox(height: 8),
                        const Text(
                          'Add routes with delivery stops to plan dispatch order',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ]),
                ))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: _routes.length,
                  itemBuilder: (ctx, i) => _RouteCard(
                    route: _routes[i],
                    onEdit: !AuthService.to.perms.canUpdate(ScreenKeys.route)
                        ? null
                        : () async {
                            final ok = await AdminPin.verify(context,
                                action: 'edit route');
                            if (!ok) return;
                            _showRouteDialog(route: _routes[i]);
                          },
                    onDelete: !AuthService.to.perms.canDelete(ScreenKeys.route)
                        ? null
                        : () async {
                            final ok = await AdminPin.verify(context,
                                action: 'delete route');
                            if (!ok) return;
                            _deleteRoute(_routes[i]);
                          },
                  ),
                ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.4,
              )),
        ]),
      );
}

// ── Stop Row Widget ───────────────────────────────────────────────────────────
class _StopRow extends StatelessWidget {
  final int index;
  final int totalStops;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _StopRow({
    Key? key,
    required this.index,
    required this.totalStops,
    required this.controller,
    required this.onChanged,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageAck;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        // Stop number badge
        Container(
          width: 36,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(10)),
          ),
          child: Center(
              child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          )),
        ),
        // Text field
        Expanded(
            child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            hintText: 'Stop name (e.g. Medical Complex Gate ${index + 1})',
            hintStyle:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        )),
        // Up/Down/Delete actions
        Column(mainAxisSize: MainAxisSize.min, children: [
          if (onMoveUp != null)
            GestureDetector(
              onTap: onMoveUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 18, color: color.withValues(alpha: 0.7)),
              ),
            ),
          if (onMoveDown != null)
            GestureDetector(
              onTap: onMoveDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: color.withValues(alpha: 0.7)),
              ),
            ),
        ]),
        // Delete button
        if (onDelete != null)
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 36,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(10)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppTheme.danger),
            ),
          ),
      ]),
    );
  }
}

// ── Insert Stop Button ────────────────────────────────────────────────────────
class _InsertStopButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InsertStopButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Container(
                  height: 1, color: AppTheme.stageAck.withValues(alpha: 0.15))),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.stageAck.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.stageAck.withValues(alpha: 0.3),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 13, color: AppTheme.stageAck),
              const SizedBox(width: 4),
              Text('Insert here',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.stageAck,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
          Expanded(
              child: Container(
                  height: 1, color: AppTheme.stageAck.withValues(alpha: 0.15))),
        ]),
      ),
    );
  }
}

// ── Route Card ────────────────────────────────────────────────────────────────
class _RouteCard extends StatefulWidget {
  final RouteData route;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _RouteCard({
    required this.route,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.stageAck;
    final stops = widget.route.stops;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: stops.isNotEmpty
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.route_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.route.routeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        )),
                    if (widget.route.description.isNotEmpty)
                      Text(widget.route.description,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          )),
                  ],
                )),
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      color: AppTheme.primary, size: 18),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.danger, size: 18),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (stops.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Pill(
                    Icons.location_on_rounded,
                    '${stops.length} stop${stops.length == 1 ? '' : 's'}',
                    color),
                const SizedBox(width: 6),
                if (widget.route.transportNames.isNotEmpty)
                  _Pill(
                    Icons.local_shipping_rounded,
                    '${widget.route.transportNames.length} transport${widget.route.transportNames.length == 1 ? '' : 's'}',
                    AppTheme.stageDispatch,
                  ),
              ]),
            ]),
          ),
        ),

        // Expanded stops list
        if (_expanded && stops.isNotEmpty) ...[
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DELIVERY ORDER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.6,
                  )),
              const SizedBox(height: 8),
              ...stops.asMap().entries.map((e) {
                final isLast = e.key == stops.length - 1;
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                          child: Center(
                              child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          )),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 28,
                            color: color.withValues(alpha: 0.3),
                          ),
                      ]),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Padding(
                        padding:
                            EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
                        child: Text(e.value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            )),
                      )),
                    ]);
              }),
            ]),
          ),
        ],

        // Transports strip
        if (widget.route.transportNames.isNotEmpty) ...[
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.route.transportNames
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.stageDispatch.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                AppTheme.stageDispatch.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_shipping_rounded,
                              size: 11, color: AppTheme.stageDispatch),
                          const SizedBox(width: 4),
                          Text(t,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.stageDispatch,
                                fontWeight: FontWeight.w600,
                              )),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              )),
        ]),
      );
}
