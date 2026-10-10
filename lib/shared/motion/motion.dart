import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Frigo's motion toolkit.
///
/// Three rules the whole app follows:
/// 1. Motion explains a change — it never decorates one.
/// 2. Entrances come from where the content belongs, and are short.
/// 3. Everything respects the platform's "reduce motion" setting, so the app
///    stays fully usable with animations switched off.

/// True when the platform asks for reduced motion.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and lifts a widget into place once, on first build.
///
/// [index] staggers a list so rows arrive in sequence instead of snapping in
/// as one block — the cheapest way to make a screen feel alive.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = AppMotion.slow,
    this.stagger = const Duration(milliseconds: 45),
    this.maxStagger = 8,
    super.key,
  });

  final Widget child;
  final int index;

  /// Vertical distance travelled, in logical pixels.
  final double offset;
  final Duration duration;
  final Duration stagger;

  /// Rows past this index all start together, so a long list never feels slow.
  final int maxStagger;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: AppMotion.enter,
  );

  /// Held so it can be cancelled: scrolling away from a long staggered list
  /// mid-entrance would otherwise leave one pending timer per disposed row.
  Timer? _delay;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;

    // MediaQuery is only safe to read from here on, which is also the first
    // point where we know whether to animate at all.
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }

    final steps = widget.index.clamp(0, widget.maxStagger);
    final delay = widget.stagger * steps;
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Opacity(
          opacity: _t.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - _t.value)),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Shrinks slightly while pressed, so cards feel physical.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down && !reduceMotion(context) ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Adds a press-scale to a widget that already handles its own taps.
///
/// Uses [Listener] rather than a gesture detector so it never competes with an
/// inner `InkWell` in the gesture arena — the ripple and the scale both happen.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    required this.child,
    this.enabled = true,
    this.scale = 0.98,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reduceMotion(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}

/// Counts up to [value] instead of snapping, so a number that changed is
/// obvious without the user having to remember the old one.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter(
    this.value, {
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 650),
    super.key,
  });

  final int value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text('$value$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppMotion.enter,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Cross-fades between states without the layout jumping.
class SwapFade extends StatelessWidget {
  const SwapFade({required this.child, this.duration, super.key});

  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration ?? AppMotion.base,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
