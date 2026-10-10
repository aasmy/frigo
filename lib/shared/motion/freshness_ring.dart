import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'motion.dart';

/// A ring that sweeps to its value on first paint, and re-sweeps when the
/// kitchen changes. Shows at a glance how much of the kitchen is still fresh.
class FreshnessRing extends StatelessWidget {
  const FreshnessRing({
    required this.fresh,
    required this.useSoon,
    required this.expired,
    this.size = 92,
    this.stroke = 10,
    this.child,
    super.key,
  });

  final int fresh;
  final int useSoon;
  final int expired;
  final double size;
  final double stroke;
  final Widget? child;

  int get total => fresh + useSoon + expired;

  @override
  Widget build(BuildContext context) {
    final target = total == 0 ? 0.0 : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion(context) ? target : 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fresh: fresh,
            useSoon: useSoon,
            expired: expired,
            stroke: stroke,
            progress: t,
          ),
          child: Center(child: child),
        ),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fresh,
    required this.useSoon,
    required this.expired,
    required this.stroke,
    required this.progress,
  });

  final int fresh;
  final int useSoon;
  final int expired;
  final double stroke;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.surfaceSunken;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = fresh + useSoon + expired;
    if (total == 0) return;

    // Expired first, so the thing that needs attention starts at 12 o'clock.
    const start = -math.pi / 2;
    const full = math.pi * 2;
    // A small gap between segments keeps the counts readable when one is tiny.
    const gap = 0.05;
    var angle = start;

    for (final seg in [
      (expired, AppColors.expired),
      (useSoon, AppColors.useSoon),
      (fresh, AppColors.fresh),
    ]) {
      final (count, color) = seg;
      if (count == 0) continue;
      final sweep = (count / total) * full * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
          rect, angle + gap / 2, math.max(0, sweep - gap), false, paint);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.fresh != fresh ||
      old.useSoon != useSoon ||
      old.expired != expired;
}
