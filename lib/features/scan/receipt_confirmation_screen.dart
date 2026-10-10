import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/receipt_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/ai/ai_health.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/receipt_item_row.dart';
import 'controller/scan_controller.dart';

/// Editable review of what the AI pulled off the receipt. Nothing enters the
/// kitchen until the user taps the button at the bottom.
class ReceiptConfirmationScreen extends ConsumerWidget {
  const ReceiptConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    if (state is! ScanReview) return const SizedBox.shrink();

    final controller = ref.read(scanControllerProvider.notifier);
    final draft = state.draft;
    final foodRows = draft.items.where((i) => i.isFood).toList();
    final nonFoodRows = draft.items.where((i) => !i.isFood).toList();
    final addCount = foodRows.where((i) => i.included).length;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (draft.imagePath != null && File(draft.imagePath!).existsSync())
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: ClipRRect(
                    borderRadius: AppRadii.cardMd,
                    child: Image.file(
                      File(draft.imagePath!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                    AppSpacing.lg, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detected items · $addCount',
                        style: text.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () => _editMerchant(context, controller, draft.merchant),
                      child: Row(
                        children: [
                          Text(
                            '${draft.merchant}  ·  ${Fmt.date(draft.purchaseDate)}',
                            style: text.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined,
                              size: 14, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Falling back to the offline parser is silent by design; say so
              // here, because the user is about to trust this list.
              if (AiHealth.instance.degraded &&
                  AiHealth.instance.lastFailedTask == AiTask.receipt)
                _OfflineBanner(onRetry: controller.retry),
              if (state.duplicates.isNotEmpty)
                _DuplicateBanner(duplicates: state.duplicates),
              const SizedBox(height: AppSpacing.sm),
              _RowGroup(
                rows: foodRows,
                onChanged: controller.updateItem,
                onDelete: controller.removeItem,
              ),
              if (nonFoodRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
                  child: Text('Not added — looks non-food',
                      style: text.labelMedium),
                ),
                _RowGroup(
                  rows: nonFoodRows,
                  onChanged: controller.updateItem,
                  onDelete: controller.removeItem,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
        _BottomBar(
          label: 'Add $addCount ${addCount == 1 ? 'item' : 'items'} to Kitchen',
          enabled: addCount > 0,
          onPressed: () => controller.confirm(),
        ),
      ],
    );
  }

  Future<void> _editMerchant(
    BuildContext context,
    ScanController controller,
    String current,
  ) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Store'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Store name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) controller.setMerchant(result);
  }
}

class _RowGroup extends StatelessWidget {
  const _RowGroup({
    required this.rows,
    required this.onChanged,
    required this.onDelete,
  });

  final List<ReceiptItem> rows;
  final ValueChanged<ReceiptItem> onChanged;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppSpacing.screenH,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardLg,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.lg),
            ReceiptItemRow(
              item: rows[i],
              onChanged: onChanged,
              onDelete: () => onDelete(rows[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.useSoonSoft,
        borderRadius: AppRadii.cardMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 18, color: AppColors.useSoon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Read offline — ${AiHealth.shortReason(AiHealth.instance.lastError)}. '
              'Names may need a tweak.',
              style: text.labelMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DuplicateBanner extends StatelessWidget {
  const _DuplicateBanner({required this.duplicates});
  final List<DuplicateWarning> duplicates;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: AppSpacing.screenH,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.useSoonSoft,
        borderRadius: AppRadii.cardMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.useSoon),
              const SizedBox(width: AppSpacing.sm),
              Text('Already in your kitchen', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final d in duplicates)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${d.name} — ${d.existingSummary.toLowerCase()}',
                  style: text.labelMedium),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text('That\'s fine — just so you know.', style: text.labelSmall),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: PrimaryButton(
        label: label,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
