import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Progressive receipt-analysis loading view. Never just a spinner — it names
/// each step so multi-second waits feel intentional.
class LoadingReceiptState extends StatelessWidget {
  const LoadingReceiptState({
    super.key,
    required this.message,
    required this.progress,
  });

  final String message;
  final double progress;

  static const _steps = [
    'Uploading receipt…',
    'Reading items…',
    'Understanding groceries…',
    'Organizing your kitchen…',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final activeIndex = _steps.indexWhere((s) => s == message);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Reading your receipt…', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This usually takes a few seconds.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress <= 0 ? null : progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceTint,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < _steps.length; i++)
            _StepRow(
              label: _steps[i],
              done: activeIndex > i || (i == _steps.length - 1 && progress >= 1),
              active: activeIndex == i,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.done, required this.active});
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.primary
        : active
            ? AppColors.textPrimary
            : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: done
                ? const Icon(Icons.check_circle, size: 20, color: AppColors.primary)
                : active
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      )
                    : const Icon(Icons.circle_outlined,
                        size: 18, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: color, fontWeight: active ? FontWeight.w600 : null),
          ),
        ],
      ),
    );
  }
}
