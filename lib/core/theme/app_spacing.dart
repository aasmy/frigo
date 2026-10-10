import 'package:flutter/widgets.dart';

/// Constrained spacing + radius scale. Everything snaps to these values so the
/// vertical rhythm stays even and the app feels considered.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard screen horizontal padding.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets screen = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
}

class AppRadii {
  const AppRadii._();

  static const Radius xs = Radius.circular(8);
  static const Radius sm = Radius.circular(12);
  static const Radius md = Radius.circular(16);
  static const Radius lg = Radius.circular(20);
  static const Radius xl = Radius.circular(28);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius cardSm = BorderRadius.all(sm);
  static const BorderRadius cardMd = BorderRadius.all(md);
  static const BorderRadius cardLg = BorderRadius.all(lg);
  static const BorderRadius cardXl = BorderRadius.all(xl);
  static const BorderRadius pillAll = BorderRadius.all(pill);
}

/// Shared motion tokens so transitions feel like one system.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;
}
