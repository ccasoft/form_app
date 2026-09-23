// ─────────────────────────────────────────────────────────────────────────────
//  Global Area Switcher — a small floating button available on every
//  screen in the app, offering "switch to Activity Manager / Office
//  Administration" and "Log out" without needing to add this to each
//  individual screen file. Wired once, in main.dart, via
//  GetMaterialApp's `builder` parameter — it wraps whatever screen is
//  currently showing.
//
//  Hidden on the login and area-selector screens (both are already
//  about logging in/choosing an area) and whenever no one is signed
//  in. Detecting "which screen is this" globally is done via a tiny
//  NavigatorObserver — most navigation in this app is unnamed
//  (Get.to(() => Widget())), so this only ever needs to recognize the
//  two named routes it should hide on; everything else is "show it".
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/home.dart';
import 'package:form_app/office_hub_screen.dart';
import 'package:form_app/auth_service.dart';

class RouteNameTracker extends GetObserver {
  static final Rx<String?> current = Rx<String?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    current.value = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    current.value = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }
}

class GlobalAreaSwitcherOverlay extends StatelessWidget {
  final Widget child;
  const GlobalAreaSwitcherOverlay({super.key, required this.child});

  void _openMenu() {
    final perms = AuthService.to.perms;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in_rounded,
                  color: Color(0xFF4C63B6)),
              title: const Text('Activity Manager',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Invoice to Acknowledgement'),
              onTap: () {
                Get.back();
                Get.offAll(() => const HomePage());
              },
            ),
            if (perms.canAccessOffice)
              ListTile(
                leading: const Icon(Icons.business_center_rounded,
                    color: Color(0xFF6A1B9A)),
                title: const Text('Office Administration',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Licenses, documents, passwords & more'),
                onTap: () {
                  Get.back();
                  Get.offAll(() => const OfficeHubScreen());
                },
              ),
            const Divider(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
              title: const Text('Log out',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFFE53935))),
              onTap: () {
                Get.back();
                _confirmLogout();
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmLogout() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
          "You'll need to sign in again to continue using the app.",
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6B87)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF5A6B87), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              AuthService.to.logout();
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Log Out',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      Obx(() {
        final route = RouteNameTracker.current.value;
        final hiddenHere = route == '/login' || route == '/select';
        final loggedIn = AuthService.to.currentUser != null;
        if (hiddenHere || !loggedIn) return const SizedBox.shrink();

        return Positioned(
          left: 12,
          bottom:
              90, // clears the bottom nav bar used on the Activity Manager tabs
          child: SafeArea(
            // No Tooltip here: like showDialog/showModalBottomSheet
            // before it, Tooltip needs an Overlay ancestor internally
            // (it renders its hover/long-press bubble via its own
            // OverlayEntry), and this button sits outside the
            // Navigator's Overlay by design. It threw on build, not
            // on tap, which is why it showed red immediately on every
            // screen rather than only when tapped.
            child: Material(
              color: const Color(0xFF1C2340),
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openMenu(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child:
                      Icon(Icons.apps_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        );
      }),
    ]);
  }
}
