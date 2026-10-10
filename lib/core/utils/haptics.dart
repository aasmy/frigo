import 'package:flutter/services.dart';

/// Thin wrapper so haptic intent reads clearly at call sites and is easy to
/// mute globally later.
class Haptics {
  const Haptics._();

  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();
  static void warning() => HapticFeedback.heavyImpact();
}
