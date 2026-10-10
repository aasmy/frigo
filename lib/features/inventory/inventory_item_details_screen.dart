import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/receipt_repository.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/expiration_badge.dart';
import '../../shared/widgets/food_image.dart';
import '../../shared/widgets/primary_button.dart';
import 'edit_item_sheet.dart';

class InventoryItemDetailsScreen extends ConsumerWidget {
  const InventoryItemDetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(inventoryProvider);
    final item = ref.read(inventoryProvider.notifier).byId(itemId);
    final text = Theme.of(context).textTheme;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This item is no longer in your kitchen.')),
      );
    }

    final notifier = ref.read(inventoryProvider.notifier);
    final receipt =
        item.receiptId == null ? null : ref.read(receiptsProvider.notifier).byId(item.receiptId!);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.expired),
            onPressed: () async {
              final ok = await confirmDestructive(
                context,
                title: 'Delete ${item.displayName}?',
                message: 'It will be removed from your kitchen.',
              );
              if (ok) {
                notifier.removeItem(item.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
          children: [
            Center(
              child: Container(
                height: 132,
                width: 132,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardLg,
                  boxShadow: AppColors.cardShadow,
                ),
                child: FoodImage(
                  name: item.displayName,
                  category: item.category,
                  imageUrl: item.imageUrl,
                  photoPath: item.photoPath,
                  size: 132,
                  radius: 20,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(item.displayName,
                style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text('${item.category.label} · ${item.quantityLabel}',
                style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      ExpirationBadge(status: item.status),
                      const Spacer(),
                      Text(item.freshnessLabel, style: text.labelMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1),
                  _InfoRow(
                    label: 'Purchased',
                    value:
                        '${Fmt.date(item.purchaseDate)}  (${item.daysSincePurchase == 0 ? 'today' : '${item.daysSincePurchase}d ago'})',
                  ),
                  _InfoRow(
                    label: 'Estimated freshness until',
                    value: item.estimatedExpirationDate == null
                        ? 'Unknown'
                        : Fmt.date(item.estimatedExpirationDate!),
                  ),
                  _InfoRow(label: 'Storage', value: item.storageLocation.label),
                  if (receipt != null)
                    _InfoRow(
                      label: 'From receipt',
                      value: '${receipt.merchant} ›',
                      onTap: () =>
                          context.push(Routes.receiptDetails(receipt.id)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: AppRadii.cardMd,
              ),
              child: Text(
                'These are estimates, not food-safety dates. Always check before eating.',
                style: text.labelMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Update this item', style: text.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ActionChip(
                  label: 'Used some',
                  icon: Icons.remove_circle_outline,
                  onTap: () => _usedSome(context, notifier, item),
                ),
                _ActionChip(
                  label: 'Finished',
                  icon: Icons.check_circle_outline,
                  onTap: () {
                    notifier.removeItem(item.id);
                    context.pop();
                  },
                ),
                _ActionChip(
                  label: 'Threw away',
                  icon: Icons.delete_sweep_outlined,
                  onTap: () {
                    notifier.removeItem(item.id);
                    context.pop();
                  },
                ),
                if (item.storageLocation != StorageLocation.freezer)
                  _ActionChip(
                    label: 'Move to freezer',
                    icon: Icons.ac_unit,
                    onTap: () => notifier.updateItem(item.copyWith(
                      storageLocation: StorageLocation.freezer,
                      manualStatus: FreshnessStatus.frozen,
                    )),
                  ),
                _ActionChip(
                  label: 'Add to shopping list',
                  icon: Icons.add_shopping_cart_outlined,
                  onTap: () {
                    ref
                        .read(shoppingListProvider.notifier)
                        .addNeed(item.displayName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('${item.displayName} added to shopping list')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: 'Edit details',
              icon: Icons.edit_outlined,
              onPressed: () => showEditItemSheet(context, ref, item),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _usedSome(
    BuildContext context,
    InventoryNotifier notifier,
    InventoryItem item,
  ) async {
    double value = (item.quantity * 0.5);
    final result = await showModalBottomSheet<double>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How much is left?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${Fmt.quantity(value, item.unit)} of ${Fmt.quantity(item.quantity, item.unit)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Slider(
                value: value.clamp(0, item.quantity),
                max: item.quantity,
                divisions: item.quantity >= 1 ? item.quantity.round() : 10,
                onChanged: (v) => setState(() => value = v),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, value),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      if (result <= 0) {
        notifier.removeItem(item.id);
      } else {
        notifier.updateItem(item.copyWith(quantity: result));
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(label, style: text.labelMedium)),
            Text(value,
                style: text.bodyMedium?.copyWith(
                    color: onTap != null
                        ? AppColors.primary
                        : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.divider),
    );
  }
}
