import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_app/app_theme.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/user_permissions.dart';
import 'package:form_app/CompanyManagement/companyhome.dart';
import 'package:form_app/PartyManagement/partyhome.dart';
import 'package:form_app/RouteManagement/routehome.dart';
import 'package:form_app/TransportManagement/transportmanagement.dart';
import 'package:form_app/invoiceMasterManagement.dart';
import 'package:form_app/invoice_series_management.dart';
import 'package:form_app/admin_users_screen.dart';
import 'package:form_app/telecalling_screen.dart';
import 'package:form_app/pipeline_dashboard.dart';
import 'package:form_app/dispatch_dashboard.dart';
import 'package:form_app/step1.dart';
import 'package:form_app/quick_void.dart';
import 'package:form_app/step2.dart';
import 'package:form_app/garage_slip_pending.dart';
import 'package:form_app/step3.dart';
import 'package:form_app/step4.dart';
import 'package:form_app/step5.dart';
import 'package:form_app/cheque_collection.dart';
import 'package:form_app/office_hub_screen.dart';
import 'package:form_app/office_models.dart' show APP_PRIMARY_COLOR;
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// ─── NAV ITEM MODEL ───────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  const _NavItem(this.label, this.icon, this.activeIcon, this.tooltip);
}

const _navItems = [
  _NavItem('Home',      Icons.home_outlined,            Icons.home_rounded,            'Home — quick actions & overview'),
  _NavItem('Pipeline',  Icons.account_tree_outlined,    Icons.account_tree_rounded,    'Work Pipeline — invoices in progress by stage'),
  _NavItem('Dashboard', Icons.bar_chart_outlined,       Icons.bar_chart_rounded,       'Pipeline Dashboard — stage-wise counts'),
  _NavItem('Dispatch',  Icons.local_shipping_outlined,  Icons.local_shipping_rounded,  'Dispatch Dashboard'),
  _NavItem('Invoice',   Icons.manage_search_outlined,   Icons.manage_search_rounded,   'Invoice Master — search & manage invoices'),
  _NavItem('Cheque',    Icons.payments_outlined,        Icons.payments_rounded,        'Cheque Collection'),
];

// ─── HOME PAGE ────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static void openMasters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MastersSheet(),
    );
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void _onNavTap(int index) => setState(() => _currentIndex = index);

  /// Shows logout / exit options in a bottom sheet
  void _showUserMenu(BuildContext context) {
    final user  = AuthService.to.currentUser;
    final perms = AuthService.to.perms;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1C2340),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // User info
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Color(perms.color).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Color(perms.color).withValues(alpha: 0.4)),
              ),
              child: Center(child: Icon(Icons.account_circle_rounded,
                  color: Color(perms.color), size: 28)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name.isNotEmpty ? user.name : user.userId,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(perms.color).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(perms.displayName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ])),
          ]),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          // Access summary
          _UserAccessRow(perms: perms),
          const SizedBox(height: 20),
          // Logout
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Tooltip(
              message: 'Sign out of this account',
              child: ElevatedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C63B6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Exit app
          SizedBox(
            width: double.infinity,
            height: 46,
            child: Tooltip(
              message: kIsWeb ? 'Close this browser tab' : 'Close the app',
              child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (kIsWeb) {
                  Get.snackbar('Exit', 'Close this browser tab to exit.',
                      backgroundColor: const Color(0xFF1C2340),
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                } else {
                  SystemNavigator.pop();
                }
              },
              icon: const Icon(Icons.exit_to_app_rounded, size: 18),
              label: const Text('Exit App', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ),
            ),
          ),
        ]),
        ),
      ),
    );
  }

  /// Confirms before actually logging out — closes the user-menu sheet
  /// first, then shows a plain yes/no dialog. Logout only happens if
  /// the user explicitly confirms.
  void _confirmLogout(BuildContext sheetContext) {
    Navigator.pop(sheetContext); // close the bottom sheet first
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
          'You\'ll need to sign in again to continue using the app.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6B87)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A6B87), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              AuthService.to.logout();
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:  return const _HomeTab();
      case 1:  return const _WorkingPipelineTab();
      case 2:  return const PipelineDashboard();
      case 3:  return const DispatchDashboard();
      case 4:  return const InvoiceMasterManagement();
      case 5:  return const ChequeCollection();
      default: return const _HomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final titles = ['Chhattisgarh C & F Agency Pvt Ltd', 'Work Pipeline', 'Dashboard', 'Dispatch', 'Invoice Master', 'Cheque Collection'];
    // Below this width, the 3 action badges (user, Masters, Office)
    // at their normal icon+text size leave almost no room for the
    // title — collapse them to icon-only so the title reliably has
    // space, instead of only ever shrinking the title's own side.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2340),
        elevation: 0,
        toolbarHeight: 56,
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: const Color(0xFF4C63B6), borderRadius: BorderRadius.circular(9)),
            child: const Center(child: Text('CG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5))),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(titles[_currentIndex], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(DateFormat('EEE, dd MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Color(0xFF8892B0), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        actions: [
          // ── Area toggle: the only thing left in the title bar
          // besides the title itself. A direct switch, not a menu —
          // there are only two areas, so a tap just flips to the
          // other one. Hidden entirely if this user has no office
          // access, since there'd be nothing to switch to.
          Obx(() {
            if (!AuthService.to.perms.canAccessOffice) return const SizedBox.shrink();
            return IconButton(
              onPressed: () => Get.off(() => const OfficeHubScreen()),
              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              tooltip: 'Switch to Office Administration',
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: _buildBody()),
      ),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        _BottomBadgesStrip(),
        _BottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
      ]),
    );
  }
}

/// User badge + Masters badge, relocated here from the app bar (which
/// was getting crowded — three badges plus the title left very
/// little room and could overflow on narrow screens). A thin strip
/// pinned just above the bottom nav bar.
class _BottomBadgesStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C2340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // ── User badge (role chip) ──────────────────────────────────
        Obx(() {
          final user = AuthService.to.currentUser;
          final perms = AuthService.to.perms;
          if (user == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _showUserMenuFrom(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color(perms.color).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(perms.color).withValues(alpha: 0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_circle_rounded, size: 13, color: Color(perms.color).withValues(alpha: 0.9)),
                const SizedBox(width: 5),
                Text(perms.displayName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          );
        }),
        // ── Masters button (admin only) ─────────────────────────────
        Obx(() {
          if (!AuthService.to.perms.canAccessMasters) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => HomePage.openMasters(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF4C63B6).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4C63B6).withValues(alpha: 0.6)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_special_rounded, size: 13, color: Colors.white),
                SizedBox(width: 5),
                Text('Masters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  // Delegates to the same account-menu bottom sheet _HomePageState
  // already builds, reached via the nearest _HomePageState ancestor
  // so its logout/exit logic doesn't need duplicating here.
  void _showUserMenuFrom(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    state?._showUserMenu(context);
  }
}

// ─── BOTTOM NAV ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C2340),
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isActive = currentIndex == i;
              return Expanded(
                child: Tooltip(
                  message: item.tooltip,
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF4C63B6).withValues(alpha: 0.30) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 20,
                        color: isActive ? const Color(0xFF7B93FF) : const Color(0xFF8892B0),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(item.label, style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? const Color(0xFF7B93FF) : const Color(0xFF8892B0),
                      letterSpacing: 0.2,
                    )),
                  ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── HOME TAB ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C2340), Color(0xFF2D3A6B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFF1C2340).withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 7))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4C63B6).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7B93FF).withValues(alpha: 0.4)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 7, color: Color(0xFF7BFFB0)),
                SizedBox(width: 5),
                Text('Live System', style: TextStyle(fontSize: 10, color: Color(0xFF7B93FF), fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 14),
            Builder(builder: (context) {
              final name = AuthService.to.currentUser?.name;
              final hour = DateTime.now().hour;
              final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
              return Text(
                (name != null && name.isNotEmpty) ? '$greeting, $name 👋' : '$greeting 👋',
                style: const TextStyle(color: Color(0xFFB9C2E8), fontSize: 14, fontWeight: FontWeight.w600),
              );
            }),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Chhattisgarh C & F Agency',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('From invoice to cheque — every step, tracked.',
                style: TextStyle(color: Color(0xFF8892B0), fontSize: 13, fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              _QuickStat(icon: Icons.receipt_long_rounded,   label: 'Invoices', color: const Color(0xFF4C63B6)),
              const SizedBox(width: 8),
              _QuickStat(icon: Icons.local_shipping_rounded, label: 'Dispatch', color: const Color(0xFF00ACC1)),
              const SizedBox(width: 8),
              _QuickStat(icon: Icons.payments_rounded,       label: 'Cheques',  color: const Color(0xFF4CAF50)),
            ]),
          ]),
        ),
        const SizedBox(height: 24),

        const _SectionLabel('QUICK ACTIONS'),
        const SizedBox(height: 10),
        Builder(builder: (ctx) {
          final perms = AuthService.to.perms;
          return Column(children: [
            Row(children: [
              Expanded(child: _QuickAction(
                icon: Icons.add_circle_outline_rounded, label: 'New Invoice',
                color: AppTheme.stageInvoice, locked: !perms.canView(ScreenKeys.step1),
                tooltip: 'Create a new invoice (Stage 1)',
                onTap: () => Get.to(() => Step1()))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(
                icon: Icons.inventory_2_rounded, label: 'Packing',
                color: AppTheme.stagePacking, locked: !perms.canView(ScreenKeys.step2),
                tooltip: 'Pack pending invoices (Stage 2)',
                onTap: () => Get.to(() => Step2()))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _QuickAction(
                icon: Icons.local_shipping_rounded, label: 'Dispatch',
                color: AppTheme.stageDispatch, locked: !perms.canView(ScreenKeys.step3),
                tooltip: 'Dispatch packed invoices (Stage 3)',
                onTap: () => Get.to(() => Step3()))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(
                icon: Icons.task_alt_rounded, label: 'Acknowledgement',
                color: AppTheme.stageAck, locked: !perms.canView(ScreenKeys.step4),
                tooltip: 'Record delivery acknowledgement (Stage 4)',
                onTap: () => Get.to(() => Step4()))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _QuickAction(
                icon: Icons.payments_rounded, label: 'Cheque Collection',
                color: AppTheme.stageCheque, locked: !perms.canView(ScreenKeys.step5),
                tooltip: 'Collect cheque payments (Stage 5)',
                onTap: () => Get.to(() => const ChequeCollection()))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(
                icon: Icons.phone_in_talk_rounded, label: 'Telecalling',
                color: const Color(0xFF0F4C75),
                locked: !perms.canView(ScreenKeys.telecalling),
                tooltip: 'Log follow-up calls with parties',
                onTap: () => Get.toNamed(TelecallingScreen.routeName))),
            ]),
          ]);
        }),
        const SizedBox(height: 24),

        const _SectionLabel('ADDITIONAL FEATURES'),
        const SizedBox(height: 10),
        Builder(builder: (ctx) {
          final perms = AuthService.to.perms;
          return Row(children: [
            Expanded(child: _QuickAction(
              icon: Icons.receipt_long_rounded, label: 'Garage Slip',
              color: const Color(0xFFE65100), locked: !perms.canView(ScreenKeys.garageSlipPending),
              tooltip: 'Assign garage slips to dispatched invoices',
              onTap: () => Get.to(() => const GarageSlipPendingPage()))),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(
              icon: Icons.block_rounded, label: 'Quick Void',
              color: const Color(0xFF6A1B9A), locked: !perms.canView(ScreenKeys.quickVoid),
              tooltip: 'Cancel or void an existing invoice',
              onTap: () => Get.to(() => const QuickVoidPage()))),
          ]);
        }),
        const SizedBox(height: 24),

        const _SectionLabel('5-STAGE WORKFLOW'),
        const SizedBox(height: 10),
        ..._buildPipelineList(),
      ]),
    );
  }

  List<Widget> _buildPipelineList() {
    final stages = [
      (1, 'Invoice Preparation', AppTheme.stageInvoice,  Icons.receipt_long_rounded),
      (2, 'Packing',             AppTheme.stagePacking,  Icons.inventory_2_rounded),
      (3, 'Dispatch',            AppTheme.stageDispatch, Icons.local_shipping_rounded),
      (4, 'Acknowledgement',     AppTheme.stageAck,      Icons.task_alt_rounded),
      (5, 'Cheque Collection',   AppTheme.stageCheque,   Icons.payments_rounded),
    ];
    final out = <Widget>[];
    for (var i = 0; i < stages.length; i++) {
      final s = stages[i];
      out.add(_PipelineSummaryRow(step: s.$1, title: s.$2, color: s.$3, icon: s.$4));
      if (i < stages.length - 1) {
        out.add(Padding(
          padding: const EdgeInsets.only(left: 19),
          child: Container(width: 2, height: 10, color: const Color(0xFFDDE0EE)),
        ));
      }
    }
    return out;
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QuickStat({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.9)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.95), fontWeight: FontWeight.w600)),
    ]),
  ));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8892B0), letterSpacing: 1.0));
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool locked; // true = this role cannot edit this step
  final String? tooltip;

  const _QuickAction({
    required this.icon, required this.label, required this.color,
    required this.onTap, this.locked = false, this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = locked ? const Color(0xFF9CA3AF) : color;
    return Tooltip(
      message: tooltip ?? (locked ? '$label — view only' : label),
      child: GestureDetector(
      onTap: onTap, // always navigate — they can still VIEW
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(
              color: effectiveColor.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: locked ? 0.07 : 0.12),
              borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: effectiveColor, size: 17)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: locked ? const Color(0xFF9CA3AF) : const Color(0xFF1C2340))),
              if (locked) ...[
                const SizedBox(height: 2),
                Row(children: const [
                  Icon(Icons.visibility_rounded, size: 9, color: Color(0xFFB0BAD0)),
                  SizedBox(width: 3),
                  Text('View Only', style: TextStyle(fontSize: 9,
                      color: Color(0xFFB0BAD0), fontWeight: FontWeight.w600)),
                ]),
              ],
            ],
          )),
          Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              size: 16, color: effectiveColor.withValues(alpha: 0.4)),
        ]),
      ),
      ),
    );
  }
}

class _PipelineSummaryRow extends StatelessWidget {
  final int step; final String title; final Color color; final IconData icon;
  const _PipelineSummaryRow({required this.step, required this.title, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)))),
      const SizedBox(width: 10),
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1C2340))),
    ]),
  );
}

// ─── WORKING PIPELINE TAB ─────────────────────────────────────────────────────
class _WorkingPipelineTab extends StatefulWidget {
  const _WorkingPipelineTab();
  @override
  State<_WorkingPipelineTab> createState() => _WorkingPipelineTabState();
}

class _WorkingPipelineTabState extends State<_WorkingPipelineTab> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  final _chipScrollCtrl = ScrollController();
  final List<GlobalKey> _chipKeys = List.generate(5, (_) => GlobalKey());
  int _activePage = 0;

  static const _steps = [
    _StepInfo(1, 'Invoice Preparation', 'Create & record new invoices',  AppTheme.stageInvoice,  Icons.receipt_long_rounded),
    _StepInfo(2, 'Packing',             'Record packing cases & LR',     AppTheme.stagePacking,  Icons.inventory_2_rounded),
    _StepInfo(3, 'Dispatch',            'Assign vehicle based on route',  AppTheme.stageDispatch, Icons.local_shipping_rounded),
    _StepInfo(4, 'Acknowledgement',     'Confirm delivery receipt',       AppTheme.stageAck,      Icons.task_alt_rounded),
    _StepInfo(5, 'Cheque Collection',   'Record payment cheque details',  AppTheme.stageCheque,   Icons.payments_rounded),
  ];

  @override
  void dispose() { _pageCtrl.dispose(); _chipScrollCtrl.dispose(); super.dispose(); }

  /// Scrolls the horizontal chip row so the chip at [index] is fully
  /// visible — used whenever the active stage changes, regardless of
  /// whether that happened via tapping a chip, a dot, or swiping the
  /// page cards, so the selector never gets stuck showing a chip
  /// that's off-screen with no way to reach the ones beyond it.
  void _ensureChipVisible(int index) {
    final ctx = _chipKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5);
  }

  void _goToPage(int index) {
    _pageCtrl.animateToPage(index, duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    _ensureChipVisible(index);
  }

  void _openStep(int index) {
    // All roles can navigate (view). Editing is blocked inside each screen.
    switch (index) {
      case 0: Get.to(() => Step1()); break;
      case 1: Get.to(() => Step2()); break;
      case 2: Get.to(() => Step3()); break;
      case 3: Get.to(() => Step4()); break;
      case 4: Get.to(() => const ChequeCollection()); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Stage pill selector ────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SELECT STAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8892B0), letterSpacing: 1.0)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            controller: _chipScrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_steps.length, (i) {
                final s = _steps[i];
                final isActive = _activePage == i;
                return GestureDetector(
                  key: _chipKeys[i],
                  onTap: () => _goToPage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? s.color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? s.color : const Color(0xFFDDE0EE)),
                      boxShadow: isActive ? [BoxShadow(color: s.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white.withValues(alpha: 0.25) : s.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${s.step}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? Colors.white : s.color))),
                      ),
                      const SizedBox(width: 6),
                      Text(s.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF1C2340))),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // ── Dot indicators (tappable — jump straight to that stage) ────────
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_steps.length, (i) {
        final isActive = _activePage == i;
        return GestureDetector(
          onTap: () => _goToPage(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8), // bigger tap target than the dot itself
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 6, height: 6,
              decoration: BoxDecoration(
                color: isActive ? _steps[i].color : const Color(0xFFD0D5E8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      })),
      const SizedBox(height: 12),
      // ── Page cards ────────────────────────────────────────────────────
      Expanded(
        child: PageView.builder(
          controller: _pageCtrl,
          itemCount: _steps.length,
          onPageChanged: (i) {
            setState(() => _activePage = i);
            _ensureChipVisible(i);
          },
          itemBuilder: (ctx, i) {
            final isActive = _activePage == i;
            return AnimatedScale(
              scale: isActive ? 1.0 : 0.94,
              duration: const Duration(milliseconds: 250),
              child: _PipelinePageCard(step: _steps[i], isActive: isActive, onOpen: () => _openStep(i)),
            );
          },
        ),
      ),
    ]);
  }
}

class _StepInfo {
  final int step; final String title, description; final Color color; final IconData icon;
  const _StepInfo(this.step, this.title, this.description, this.color, this.icon);
}

// Stage detail descriptions
String _stageDesc(int step) {
  switch (step) {
    case 1: return 'Enter invoice details including party info, invoice number, amount, e-way bill, and validity dates for new orders.';
    case 2: return 'Record packing — LR number, LR date, trip number, pack cases, loose cases, and opening KM for the shipment.';
    case 3: return 'Assign vehicle to the shipment based on route, confirm dispatch date and transport details for delivery.';
    case 4: return 'Record acknowledgement from the party for Local (Raipur) and Upcountry invoices. Once acknowledged, cheque collection completes it to Stage 5.';
    case 5: return 'Record cheque payment for parties that require cheque collection. Tracked independently from Stage 1 — appears in Cheque Collection screen as soon as invoice is created.';
    default: return '';
  }
}

class _PipelinePageCard extends StatelessWidget {
  final _StepInfo step;
  final bool isActive;
  final VoidCallback onOpen;
  const _PipelinePageCard({required this.step, required this.isActive, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: step.color.withValues(alpha: isActive ? 0.35 : 0.15), width: isActive ? 1.5 : 1),
        boxShadow: [
          if (isActive) BoxShadow(color: step.color.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [step.color.withValues(alpha: 0.09), step.color.withValues(alpha: 0.03)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: step.color,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: step.color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(child: Text('${step.step}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: step.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('STAGE ${step.step} OF 5', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: step.color, letterSpacing: 0.8)),
              ),
              const SizedBox(height: 8),
              Text(step.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1C2340), letterSpacing: -0.3, height: 1.1)),
            ])),
          ]),
        ),
        // Body
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(step.icon, size: 14, color: step.color),
              const SizedBox(width: 6),
              Text(step.description, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: step.color)),
            ]),
            const SizedBox(height: 12),
            Text(_stageDesc(step.step), style: const TextStyle(fontSize: 13, color: Color(0xFF5A6480), height: 1.6)),
            const Spacer(),
            // Progress bar
            Row(children: List.generate(5, (i) => Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                decoration: BoxDecoration(
                  color: i < step.step ? step.color : const Color(0xFFE0E4EF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ))),
            const SizedBox(height: 4),
            Text('Step ${step.step} of 5', style: const TextStyle(fontSize: 10, color: Color(0xFF8892B0))),
          ]),
        )),
        // CTA button
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: GestureDetector(
            onTap: onOpen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: step.color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: step.color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Open Stage ${step.step}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Icon(step.icon, color: Colors.white, size: 15),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── USER ACCESS ROW ─────────────────────────────────────────────────────────
class _UserAccessRow extends StatelessWidget {
  final UserPermissions perms;
  const _UserAccessRow({required this.perms});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (1, 'Invoice',  perms.canEditStep1),
      (2, 'Packing',  perms.canEditStep2),
      (3, 'Dispatch', perms.canEditStep3),
      (4, 'Ack.',     perms.canEditStep4),
      (5, 'Cheque',   perms.canEditStep5),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your Access',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF8892B0), letterSpacing: 0.5)),
      const SizedBox(height: 8),
      Row(children: steps.map((s) {
        final canEdit = s.$3;
        return Expanded(child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: canEdit
                ? const Color(0xFF4C63B6).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: canEdit
                ? const Color(0xFF4C63B6).withValues(alpha: 0.4)
                : Colors.white12),
          ),
          child: Column(children: [
            Text('${s.$1}', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: canEdit ? const Color(0xFF7B93FF) : Colors.white30)),
            const SizedBox(height: 2),
            Icon(canEdit ? Icons.edit_rounded : Icons.visibility_rounded,
                size: 10, color: canEdit ? const Color(0xFF7B93FF) : Colors.white30),
            const SizedBox(height: 2),
            Text(s.$2, style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w600,
                color: canEdit ? const Color(0xFF8892B0) : Colors.white24)),
          ]),
        ));
      }).toList()),
    ]);
  }
}

// ─── MASTERS SHEET ────────────────────────────────────────────────────────────
class _MastersSheet extends StatelessWidget {
  const _MastersSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD0D5E8), borderRadius: BorderRadius.circular(2))),
          Container(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFF1C2340), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: const Color(0xFF4C63B6).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.folder_special_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Masters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                Text('Manage all master data', style: TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
              ])),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4C63B6).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF4C63B6).withValues(alpha: 0.6)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.close_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              _MasterTile('Party',          'Add, edit & manage all parties',                      Icons.people_alt_rounded,          const Color(0xFF1E88E5), badge: 'Most Used', onTap: () { Navigator.pop(context); Get.to(() => const PartyHome()); }),
              const SizedBox(height: 10),
              _MasterTile('Company',        'Manage all companies',                                 Icons.business_rounded,            const Color(0xFF43A047), onTap: () { Navigator.pop(context); Get.to(() => const CompanyHome()); }),
              const SizedBox(height: 10),
              _MasterTile('Transport',      'Manage transport names',                               Icons.local_shipping_rounded,      const Color(0xFFAB47BC), onTap: () { Navigator.pop(context); Get.to(() => const Transportmanagement()); }),
              const SizedBox(height: 10),
              _MasterTile('Routes',         'Define routes & assign transports',                    Icons.route_rounded,               const Color(0xFFEF6C00), onTap: () { Navigator.pop(context); Get.to(() => const RouteHome()); }),
              const SizedBox(height: 10),
              _MasterTile('Invoice Series', 'Configure per-company invoice numbering & FY series',  Icons.format_list_numbered_rounded, const Color(0xFF1E88E5), onTap: () { Navigator.pop(context); Get.to(() => const InvoiceSeriesManagement()); }),
              const SizedBox(height: 10),
              _MasterTile('Manage Users',  'Add, edit & disable app_users accounts',               Icons.manage_accounts_rounded,      const Color(0xFFE53935), badge: 'Admin', onTap: () { Navigator.pop(context); Get.toNamed(AdminUsersScreen.routeName); }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C63B6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4C63B6).withValues(alpha: 0.15)),
                ),
                child: const Row(children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF4C63B6), size: 17),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'After adding master data, press "Close" to return and continue your workflow.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5A6480), height: 1.5),
                  )),
                ]),
              ),
            ],
          )),
        ]),
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final String title, subtitle; final IconData icon; final Color color;
  final VoidCallback onTap; final String? badge;
  const _MasterTile(this.title, this.subtitle, this.icon, this.color, {required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1C2340))),
            if (badge != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(badge!, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8892B0))),
        ])),
        Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 22),
      ]),
    ),
  );
}