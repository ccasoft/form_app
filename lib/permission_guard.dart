// ─────────────────────────────────────────────────────────────────────────────
//  Screen access guard — call from initState() (or build() for a
//  StatelessWidget) on every screen that should be permission-gated.
//
//  Usage (StatefulWidget):
//    @override
//    void initState() {
//      super.initState();
//      WidgetsBinding.instance.addPostFrameCallback((_) => guardScreenView(ScreenKeys.step2));
//      ...
//    }
//
//  Hiding the entry tile on home.dart is only a UI nicety — on Flutter
//  Web a route can still be reached directly (typed URL, stale link,
//  browser history), so every screen needs its own guard, not just a
//  hidden button leading to it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:form_app/auth_service.dart';

/// Returns true if the current user can view [screenKey]. If not, bounces
/// them back to home with a snackbar. Call inside a post-frame callback.
bool guardScreenView(String screenKey, {String label = 'this screen'}) {
  if (AuthService.to.perms.canView(screenKey)) return true;
  Get.offAllNamed('/');
  Get.snackbar('Not Allowed', "You don't have access to $label.",
      backgroundColor: Colors.orange.shade50,
      colorText: Colors.orange.shade800,
      snackPosition: SnackPosition.BOTTOM);
  return false;
}
