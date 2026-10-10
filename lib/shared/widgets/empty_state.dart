import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../motion/motion.dart';
import 'frigo_illustration.dart';
import 'primary_button.dart';

/// Calm, friendly empty state with an optional primary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.art,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  /// Preferred over [icon] when there is room: a drawn scene reads as a
  /// deliberate state rather than a screen that failed to load.
  final FrigoArt? art;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              offset: 10,
              child: art != null
                  ? FrigoIllustration(art!, height: 170)
                  : Container(
                      height: 72,
                      width: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 32, color: AppColors.primary),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              index: 1,
              child: Column(
                children: [
                  Text(title,
                      style: text.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FadeSlideIn(
                index: 2,
                child: PrimaryButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onAction,
                  expand: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
