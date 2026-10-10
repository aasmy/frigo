import 'package:flutter/material.dart';

/// Frigo colour system — "cool & fresh".
///
/// A crisp blue-forward palette that reads like a clean fridge: near-white cool
/// surfaces, a confident primary blue for actions, frosty blue tints for
/// containers, and clear (but not shouty) freshness colours.
class AppColors {
  const AppColors._();

  // ---- Surfaces (cool near-white) --------------------------------------
  static const Color background = Color(0xFFF4F7FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFEDF2FB);
  static const Color surfaceSunken = Color(0xFFE4EBF6);
  static const Color divider = Color(0xFFE6ECF6);
  static const Color dividerStrong = Color(0xFFD5DEEC);

  // ---- Text (cool navy / slate) ---------------------------------------
  static const Color textPrimary = Color(0xFF17263F);
  static const Color textSecondary = Color(0xFF6B7C99);
  static const Color textTertiary = Color(0xFFA2AFC6);
  static const Color textInverse = Color(0xFFF8FAFF);

  // ---- Primary (blue) — actions, active nav, links, scan --------------
  static const Color primary = Color(0xFF2E6BF0);
  static const Color primaryPressed = Color(0xFF2457C9);
  static const Color primarySoft = Color(0xFFE7F0FE);
  static const Color primarySofter = Color(0xFFF0F5FE);
  static const Color primaryBorder = Color(0xFFC9DCFB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Deep brand blue used for large headings / hero card grounds.
  static const Color ink = Color(0xFF10233F);
  static const Color onInk = Color(0xFFF3F7FF);

  // ---- Freezer accent (cooler cyan-blue) -----------------------------
  static const Color freezer = Color(0xFF2B9FD9);
  static const Color freezerSoft = Color(0xFFE4F3FB);

  // ---- Status ---------------------------------------------------------
  /// "Fresh" / plenty of time.
  static const Color fresh = Color(0xFF1E9E5A);
  static const Color freshSoft = Color(0xFFE6F6ED);

  /// Use soon (a few days).
  static const Color useSoon = Color(0xFFD98A1F);
  static const Color useSoonSoft = Color(0xFFFBEEDA);

  /// Urgent / past estimate.
  static const Color expired = Color(0xFFDA4A4A);
  static const Color expiredSoft = Color(0xFFFBE7E7);

  /// Frozen — reads as calm blue, not a warning.
  static const Color frozen = Color(0xFF2E6BF0);
  static const Color frozenSoft = Color(0xFFE7F0FE);

  static const Color unknown = Color(0xFF8A97AE);
  static const Color unknownSoft = Color(0xFFECEFF5);

  // ---- Elevation / scrim --------------------------------------------
  static const Color scrim = Color(0x66102340);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D16305C), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x141B3A6B), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(color: Color(0x332E6BF0), blurRadius: 20, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x14102340), blurRadius: 6, offset: Offset(0, 2)),
  ];
}
