// ─────────────────────────────────────────────────────────────────────────────
//  Office Hub — "Main Menu", matching the reference screenshot:
//  dark teal app bar with a circular "CCA" avatar + "Main Menu"
//  subtitle + exit icon, and 8 solid-colour square tiles below:
//
//    Transport (blue) · Address Book (green)
//    Registers (purple) · LR Register (brown)*
//    Reminders (indigo) · Passwords (red)
//    OTP Approvals (orange) · Admin Console (teal)
//
//  * LR Register isn't a separate module in the codebase — it looks
//    like it should be a specific named register (the way "maintenance"
//    or "25-26 inward expiry" are user-created registers in your
//    Registers screen), not new code. Routed to the same Registers
//    module for now; flag if you want a dedicated shortcut instead.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/area_selector_screen.dart';
import 'package:form_app/office_address_book_module.dart';
import 'package:form_app/office_password_module.dart';
import 'package:form_app/office_transport_contacts_module.dart';
import 'package:form_app/office_registers.dart';
import 'package:form_app/office_reminder_mail_module.dart';
import 'package:form_app/office_otp_approvals_screen.dart';
import 'package:form_app/office_admin_console_screen.dart';
import 'package:form_app/auth_service.dart';
import 'package:form_app/user_permissions.dart';

const Color _kAppBarTeal = Color(0xFF0D5C63);

class OfficeHubScreen extends StatelessWidget {
  const OfficeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perms = AuthService.to.perms;
    final isAdmin = perms.isAdmin;

    final tiles = <_MenuTile>[
      if (perms.canView(ScreenKeys.officeTransportContacts))
        _MenuTile(
          title: 'Transport Contact',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF1E88E5),
          onTap: () => Get.to(() => const TransportContactsModule()),
        ),
      if (perms.canView(ScreenKeys.officeAddressBook))
        _MenuTile(
          title: 'Address Book',
          icon: Icons.contact_phone_rounded,
          color: const Color(0xFF2E7D32),
          onTap: () => Get.to(() => const AddressBookModule()),
        ),
      if (perms.canView(ScreenKeys.officeRegisters)) ...[
        _MenuTile(
          title: 'General Register',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF7B1FA2),
          onTap: () => Get.to(() => const RegisterModule()),
        ),
        _MenuTile(
          title: 'LR Register',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF6D4C41),
          onTap: () => Get.to(() => const RegisterModule()),
        ),
      ],
      if (perms.canView(ScreenKeys.officeReminderMail))
        _MenuTile(
          title: 'Mail Reminders',
          icon: Icons.mail_rounded,
          color: const Color(0xFF3949AB),
          onTap: () => Get.to(() => const ReminderMailModule()),
        ),
      if (perms.canView(ScreenKeys.officePasswords))
        _MenuTile(
          title: 'Passwords',
          icon: Icons.vpn_key_rounded,
          color: const Color(0xFFD32F2F),
          onTap: () => Get.to(() => const PasswordModule()),
        ),
      // OTP Approvals has no dedicated screen-key: the screen itself
      // branches by isAdmin (full queue) vs. staff (own request
      // history only), so it stays open to every logged-in user.
      _MenuTile(
        title: 'OTP Approvals',
        icon: Icons.shield_rounded,
        color: const Color(0xFFEF6C00),
        onTap: () => Get.to(() => const OtpApprovalsScreen()),
      ),
      // Admin Console (manage users, audit log, license admin) is an
      // admin-only tool, not covered by a per-user screen permission.
      if (isAdmin)
        _MenuTile(
          title: 'Admin Console',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF00695C),
          onTap: () => Get.to(() => const AdminConsoleScreen()),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _kAppBarTeal,
        elevation: 0,
        titleSpacing: 8,
        leading: null,
        leadingWidth: 0,
        title: Row(children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white,
            child: Text('CCA',
                style: TextStyle(
                    color: _kAppBarTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 10)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Chhattisgarh C & F Agency Pvt Ltd',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Main Menu',
                    style: TextStyle(
                        color: Color(0xFFF5A623),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
        actions: [
          // Switch back to the main app — mirrors the swap icon on the
          // main Home screen that brought the user here. Without this,
          // Office Administration was a one-way door (Get.off replaces
          // the route, so there's no back button either). Navigates by
          // the '/' named route (registered in main.dart as HomePage)
          // rather than importing home.dart directly, since home.dart
          // already imports this file (for its own switch-to-Office
          // icon) and a direct two-way class import between them was
          // causing the web build to fail.
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            tooltip: 'Switch to Main Menu',
            onPressed: () => Get.offNamed('/'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () => confirmLogout(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: tiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You don\'t have access to any Office modules yet.\nAsk an admin to grant permissions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF7C8A97)),
                ),
              ),
            )
          : GridView.count(
              padding: const EdgeInsets.all(14),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: tiles.map((t) => _MenuTileWidget(tile: t)).toList(),
            ),
    );
  }
}

class _MenuTile {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuTile(
      {required this.title,
      required this.icon,
      required this.color,
      required this.onTap});
}

class _MenuTileWidget extends StatelessWidget {
  final _MenuTile tile;
  const _MenuTileWidget({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tile.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: tile.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tile.icon, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(tile.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
