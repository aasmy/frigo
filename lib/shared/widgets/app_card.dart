import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../motion/motion.dart';

/// The one surface primitive. A soft warm shadow gives depth instead of a hard
/// border; set [elevated] to false for a flat hairline card (used inside lists).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.radius = AppRadii.cardLg,
    this.elevated = true,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color color;
  final BorderRadius radius;
  final bool elevated;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      enabled: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: elevated ? AppColors.cardShadow : null,
          border:
              border ??
              (elevated ? null : Border.all(color: AppColors.divider)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: AppColors.primarySoft.withValues(alpha: 0.4),
            highlightColor: AppColors.surfaceTint,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
