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

    // Every tile is always shown to every logged-in user now — access is
    // checked at tap time (see _MenuTileWidget) instead of hiding tiles
    // the user isn't permitted to see. That way a locked tile is still
    // visible (so people know the module exists and who to ask), but
    // tapping it shows a clear "no permission" message instead of
    // opening the screen.
    final tiles = <_MenuTile>[
      _MenuTile(
        title: 'Transport Contact',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF1E88E5),
        locked: !perms.canView(ScreenKeys.officeTransportContacts),
        onTap: () => Get.to(() => const TransportContactsModule()),
        anim: _IconAnim.pulse,
      ),
      _MenuTile(
        title: 'Address Book',
        icon: Icons.contact_phone_rounded,
        color: const Color(0xFF2E7D32),
        locked: !perms.canView(ScreenKeys.officeAddressBook),
        onTap: () => Get.to(() => const AddressBookModule()),
        anim: _IconAnim.wiggle,
      ),
      _MenuTile(
        title: 'General Register',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF7B1FA2),
        locked: !perms.canView(ScreenKeys.officeRegisters),
        onTap: () => Get.to(() => const RegisterModule()),
        anim: _IconAnim.float,
      ),
      _MenuTile(
        title: 'LR Register',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF6D4C41),
        locked: !perms.canView(ScreenKeys.officeRegisters),
        onTap: () => Get.to(() => const RegisterModule()),
        anim: _IconAnim.float,
      ),
      _MenuTile(
        title: 'Mail Reminders',
        icon: Icons.mail_rounded,
        color: const Color(0xFF3949AB),
        locked: !perms.canView(ScreenKeys.officeReminderMail),
        onTap: () => Get.to(() => const ReminderMailModule()),
        anim: _IconAnim.bounce,
      ),
      _MenuTile(
        title: 'Passwords',
        icon: Icons.vpn_key_rounded,
        color: const Color(0xFFD32F2F),
        locked: !perms.canView(ScreenKeys.officePasswords),
        onTap: () => Get.to(() => const PasswordModule()),
        anim: _IconAnim.glow,
      ),
      // OTP Approvals has no dedicated screen-key: the screen itself
      // branches by isAdmin (full queue) vs. staff (own request
      // history only), so it stays open to every logged-in user.
      _MenuTile(
        title: 'OTP Approvals',
        icon: Icons.shield_rounded,
        color: const Color(0xFFEF6C00),
        locked: false,
        onTap: () => Get.to(() => const OtpApprovalsScreen()),
        anim: _IconAnim.spin,
      ),
      // Admin Console (manage users, audit log, license admin) is an
      // admin-only tool, not covered by a per-user screen permission.
      _MenuTile(
        title: 'Admin Console',
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF00695C),
        locked: !isAdmin,
        onTap: () => Get.to(() => const AdminConsoleScreen()),
        anim: _IconAnim.fadePulse,
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
      body: GridView.count(
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

// Which idle animation a tile's icon plays. Chosen per-tile (see the
// `tiles` list above) — kept as a simple enum + AnimationController
// implementation rather than a third-party package (flutter_animate etc.)
// since this project's pubspec isn't available here to add a dependency.
enum _IconAnim { pulse, wiggle, float, bounce, glow, spin, fadePulse }

class _MenuTile {
  final String title;
  final IconData icon;
  final Color color;
  final bool locked;
  final VoidCallback onTap;
  final _IconAnim? anim;
  _MenuTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.locked = false,
    this.anim,
  });
}

class _MenuTileWidget extends StatelessWidget {
  final _MenuTile tile;
  const _MenuTileWidget({required this.tile});

  void _handleTap(BuildContext context) {
    if (tile.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "No permission — you can't access '${tile.title}'. Ask an admin to grant it."),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    tile.onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Locked tiles stay visible (so people know the module exists and
    // who to ask) but read as dimmed/greyed with a lock badge, and tapping
    // shows the "no permission" message instead of opening the screen.
    final color = tile.locked ? Colors.blueGrey.shade300 : tile.color;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _handleTap(context),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  tile.anim != null
                      ? _AnimatedTileIcon(icon: tile.icon, anim: tile.anim!)
                      : Icon(tile.icon, color: Colors.white, size: 36),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(tile.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            if (tile.locked)
              const Positioned(
                top: 8,
                right: 8,
                child:
                    Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

// Plays one continuous idle animation on a tile's icon — no extra package
// (e.g. flutter_animate) needed, just a single AnimationController driven
// 0→1 (repeating, reversed for everything except Spin) and reinterpreted
// per style in build(). Each tile picks its style via `_MenuTile.anim`.
class _AnimatedTileIcon extends StatefulWidget {
  final IconData icon;
  final _IconAnim anim;
  const _AnimatedTileIcon({required this.icon, required this.anim});

  @override
  State<_AnimatedTileIcon> createState() => _AnimatedTileIconState();
}

class _AnimatedTileIconState extends State<_AnimatedTileIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Duration get _duration {
    switch (widget.anim) {
      case _IconAnim.pulse:
        return const Duration(milliseconds: 1100);
      case _IconAnim.wiggle:
        return const Duration(milliseconds: 800);
      case _IconAnim.float:
        return const Duration(milliseconds: 1500);
      case _IconAnim.bounce:
        return const Duration(milliseconds: 900);
      case _IconAnim.glow:
        return const Duration(milliseconds: 1200);
      case _IconAnim.spin:
        return const Duration(milliseconds: 3500);
      case _IconAnim.fadePulse:
        return const Duration(milliseconds: 1300);
    }
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _duration);
    if (widget.anim == _IconAnim.spin) {
      _c.repeat();
    } else {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: Colors.white, size: 36);
    return AnimatedBuilder(
      animation: _c,
      child: icon,
      builder: (context, child) {
        final t = _c.value;
        switch (widget.anim) {
          case _IconAnim.pulse:
            return Transform.scale(scale: 1.0 + 0.12 * t, child: child);
          case _IconAnim.wiggle:
            return Transform.rotate(angle: (t * 2 - 1) * 0.14, child: child);
          case _IconAnim.float:
            return Transform.translate(offset: Offset(0, -6 * t), child: child);
          case _IconAnim.bounce:
            return Transform.translate(
              offset: Offset(0, -10 * Curves.easeOut.transform(t)),
              child: child,
            );
          case _IconAnim.glow:
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.55 * t),
                    blurRadius: 4 + 16 * t,
                    spreadRadius: 1 + 5 * t,
                  ),
                ],
              ),
              child: child,
            );
          case _IconAnim.spin:
            return Transform.rotate(angle: t * 2 * 3.1415926535, child: child);
          case _IconAnim.fadePulse:
            return Opacity(
              opacity: 1.0 - 0.5 * t,
              child: Transform.scale(scale: 1.0 - 0.1 * t, child: child),
            );
        }
      },
    );
  }
}
