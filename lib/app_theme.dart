import 'package:flutter/material.dart';

class AppTheme {
  // ── Sky Blue & Cream Design System ────────────────────────────────────────
  // Brand blues
  static const Color primary =
      Color(0xFF4FA3D1); // Login screen blue — the app's base colour
  static const Color primaryLight =
      Color(0xFFA8D8EF); // Soft sky (gradients, tints)
  static const Color primaryDark = Color(0xFF2E7DA8); // Deep sky (headings)
  static const Color appBarBg =
      Color(0xFF4FA3D1); // App bar — same base blue app-wide
  static const Color tabBarBg = Color(0xFF4FA3D1);
  static const Color mastersBtnBg = Color(0xFF4FA3D1);
  static const Color mastersBtnText = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFF2E7DA8);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color danger = Color(0xFFE53935);

  // Category accent colors (used by Office Admin Console / OTP Approvals
  // status badges) — aliases of the existing success/warning tones so
  // they stay visually consistent with the rest of the app.
  static const Color catGreen = success;
  static const Color catAmber = warning;
  static const Color catPurple = Color(0xFF9C27B0);

  // Generic page background / vivid app-bar accent used by a couple of
  // standalone Office utility screens (distinct from the app-wide
  // appBarBg, which stays reserved for the main navigation chrome).
  static const Color pageBg = Color(0xFFF4F6F8);
  static const Color bannerVivid = Color(0xFF0D5C63);

  // Neutrals — light grey/white glossy cards (unified with Office Console)
  static const Color surface =
      Color(0xFFE7ECEF); // Scaffold background (fallback, off-gradient)
  static const Color cream = Color(
      0xFFF6F9FB); // Card surface — used on Login, Area Selector & Office Hub
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF263238); // Dark slate
  static const Color textSecondary = Color(0xFF78909C);
  static const Color divider = Color(0xFFE0DCD0);

  // ── Sky gradient (login / splash / hero backgrounds) ──────────────────────
  static const Color skyTop = Color(0xFF9FD3EE);
  static const Color skyMid = Color(0xFFC7E6F5);
  static const Color skyBottom = Color(0xFFF3EEE3);

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, skyBottom],
    stops: [0.0, 0.45, 1.0],
  );

  // ── Unified App Gradient — login blue, fading to grey (global theme) ───────
  // This is the ONE background gradient used app-wide: Login, Area
  // Selector, and Office Hub all use AppTheme.appGradient. Anchored on
  // `primary` (the login screen's blue) at the top, fading to light grey
  // by the bottom, roughly 70% blue / 30% grey.
  static const Color appBlueTop =
      primary; // login screen's blue, reused as the base
  static const Color appBlueMid = Color(0xFF8EC7E6); // lighter blend
  static const Color appGrayBottom = Color(0xFFE7ECEF); // fades into light grey

  static const LinearGradient appGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [appBlueTop, appBlueMid, appGrayBottom],
    stops: [0.0, 0.7, 1.0],
  );

  // ── Office Console accents — shiny navy + glossy card surfaces ─────────────
  // Card surfaces (module tiles, panels) app-wide use these light,
  // glossy grey/white tones; icons and text on them use officeNavy.
  static const Color officeNavy = Color(0xFF15304A); // shiny black-navy accent
  static const Color officeNavySoft = Color(0xFF3E6A8C);
  static const Color officeCardTop =
      Color(0xFFF6F9FB); // card gradient (glossy)
  static const Color officeCardBottom = Color(0xFFDBE2E9);
  static const Color officeHexLine =
      Color(0xFFAEBBC6); // background hex texture

  // Back-compat alias — same gradient, old name. Prefer appGradient.
  static const LinearGradient officeGradient = appGradient;

  static BoxDecoration officeCardDecoration({double radius = 20}) =>
      BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [officeCardTop, officeCardBottom],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
              color: Colors.white.withValues(alpha: 0.75),
              blurRadius: 10,
              offset: const Offset(-5, -5)),
          BoxShadow(
              color: officeNavy.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(6, 6)),
        ],
      );

  // Plain white card decoration with a soft drop shadow — used by the
  // Office Admin Console's stat cards and action rows (lighter-weight
  // than officeCardDecoration's glossy gradient style).
  static BoxDecoration cleanCardDecoration({double radius = 12}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── Stage Colors ──────────────────────────────────────────────────────────
  static const Color stageInvoice = Color(0xFF2979FF);
  static const Color stagePacking = Color(0xFF9C27B0);
  static const Color stageDispatch = Color(0xFF00ACC1);
  static const Color stageAck = Color(0xFFEF6C00);
  static const Color stageCheque = Color(0xFF2E7D32);
  static const Color stageTelecall = Color(0xFF0F4C75);

  static Color stageBg(int stage) {
    switch (stage) {
      case 1:
        return const Color(0xFFE3F2FD);
      case 2:
        return const Color(0xFFF3E5F5);
      case 3:
        return const Color(0xFFE0F7FA);
      case 4:
        return const Color(0xFFFFF3E0);
      case 5:
        return const Color(0xFFE8F5E9);
      default:
        return surface;
    }
  }

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(primary: primary, secondary: accent, surface: surface),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: danger)),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        prefixIconColor: textSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE6F2FA),
        labelStyle: const TextStyle(
            color: primaryDark, fontWeight: FontWeight.w500, fontSize: 12),
        deleteIconColor: primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme:
          const DividerThemeData(color: divider, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F4F6B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class AppStages {
  static const int invoice = 1,
      packing = 2,
      dispatch = 3,
      inProgress = 4,
      complete = 5;
  // Stage 3 = Dispatched (pending Ack and/or Cheque)
  // Stage 4 = legacy/unused (kept for backwards-compat)
  // Stage 5 = Complete (both Ack and Cheque done)

  static String label(int stage) {
    switch (stage) {
      case 1:
        return 'Invoice';
      case 2:
        return 'Packing';
      case 3:
        return 'Dispatched';
      case 4:
        return 'Acknowledged';
      case 5:
        return 'Complete';
      case 6:
        return 'Telecalling';
      default:
        return 'Unknown';
    }
  }

  static Color color(int stage) {
    switch (stage) {
      case 1:
        return AppTheme.stageInvoice;
      case 2:
        return AppTheme.stagePacking;
      case 3:
        return AppTheme.stageDispatch;
      case 4:
        return AppTheme.stageAck;
      case 5:
        return AppTheme.stageCheque;
      case 6:
        return AppTheme.stageTelecall;
      default:
        return Colors.grey;
    }
  }

  static IconData icon(int stage) {
    switch (stage) {
      case 1:
        return Icons.receipt_long_rounded;
      case 2:
        return Icons.inventory_2_rounded;
      case 3:
        return Icons.local_shipping_rounded;
      case 4:
        return Icons.task_alt_rounded;
      case 5:
        return Icons.check_circle_rounded;
      case 6:
        return Icons.phone_in_talk_rounded;
      default:
        return Icons.circle;
    }
  }
}
