import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'motion.dart';

/// Draws a tick into a filled circle — the "it worked" beat after a scan.
///
/// The circle pops first, then the stroke draws, so the eye lands on the badge
/// before the confirmation finishes.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({this.size = 88, this.color = AppColors.fresh, super.key});

  final double size;
  final Color color;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..forward();

  late final Animation<double> _pop = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _draw = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Icon(Icons.check_circle, size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Transform.scale(
        scale: _pop.value,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckPainter(progress: _draw.value, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = color);

    // Tick, as a fraction of the box so it scales with any size.
    final p1 = Offset(size.width * 0.30, size.height * 0.52);
    final p2 = Offset(size.width * 0.44, size.height * 0.66);
    final p3 = Offset(size.width * 0.71, size.height * 0.37);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    // Split the draw across the two legs by their relative length.
    final l1 = (p2 - p1).distance;
    final l2 = (p3 - p2).distance;
    final travelled = progress * (l1 + l2);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (travelled <= l1) {
      final t = l1 == 0 ? 0.0 : travelled / l1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = l2 == 0 ? 0.0 : ((travelled - l1) / l2).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
