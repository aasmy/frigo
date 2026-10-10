import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A single shimmering placeholder block.
///
/// Skeletons beat spinners for waits longer than a moment: they show the shape
/// of what is coming, so the screen does not visibly re-flow when it arrives.
class Skeleton extends StatelessWidget {
  const Skeleton({
    required this.height,
    this.width,
    this.radius = 8,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Placeholder in the shape of a [RecipeCard].
class RecipeCardSkeleton extends StatelessWidget {
  const RecipeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardLg,
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            _Block(height: 64, width: 64, radius: 16),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(height: 14, widthFactor: 0.75),
                  SizedBox(height: AppSpacing.sm),
                  _Block(height: 11, widthFactor: 0.95),
                  SizedBox(height: AppSpacing.xs),
                  _Block(height: 11, widthFactor: 0.45),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder in the shape of an inventory row.
class ItemTileSkeleton extends StatelessWidget {
  const ItemTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: const [
            _Block(height: 44, width: 44, radius: 12),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(height: 13, widthFactor: 0.55),
                  SizedBox(height: AppSpacing.xs),
                  _Block(height: 10, widthFactor: 0.3),
                ],
              ),
            ),
            _Block(height: 20, width: 56, radius: 10),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.height,
    this.width,
    this.widthFactor,
    this.radius = 6,
  });

  final double height;
  final double? width;
  final double? widthFactor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (widthFactor == null) return box;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}

/// Sweeps a soft highlight across whatever it wraps.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // Slide a highlight band from left to right, off-screen at both ends.
          final dx = (_c.value * 2.5) - 1.0;
          return LinearGradient(
            begin: Alignment(dx - 0.6, 0),
            end: Alignment(dx + 0.6, 0),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x99FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}
