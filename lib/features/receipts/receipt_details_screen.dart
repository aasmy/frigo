import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/receipt_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/confirm_dialog.dart';

class ReceiptDetailsScreen extends ConsumerWidget {
  const ReceiptDetailsScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(receiptsProvider);
    final receipt = ref.read(receiptsProvider.notifier).byId(receiptId);
    final text = Theme.of(context).textTheme;

    if (receipt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This receipt was deleted.')),
      );
    }

    final image = receipt.imagePath;
    final hasImage = image != null && File(image).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(receipt.merchant),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.expired),
            onPressed: () async {
              final ok = await confirmDestructive(
                context,
                title: 'Delete this receipt?',
                message:
                    'The receipt image and its extracted data will be removed. Items already in your kitchen stay.',
              );
              if (ok) {
                ref.read(receiptsProvider.notifier).delete(receipt.id);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: AppRadii.cardLg,
                image: hasImage
                    ? DecorationImage(
                        image: FileImage(File(image)), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: hasImage
                  ? null
                  : const Icon(Icons.receipt_long_outlined,
                      size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('${receipt.merchant} · ${Fmt.date(receipt.purchaseDate)}',
                style: text.titleMedium),
            if (receipt.total != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                    'Approx. total \$${receipt.total!.toStringAsFixed(2)}',
                    style: text.labelMedium),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('Purchased items', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardLg,
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < receipt.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  receipt.items[i].normalizedName,
                                  style: text.bodyMedium?.copyWith(
                                    color: receipt.items[i].isFood
                                        ? AppColors.textPrimary
                                        : AppColors.textTertiary,
                                  ),
                                ),
                                Text(
                                  '${receipt.items[i].quantityLabel}'
                                  '${receipt.items[i].isFood ? '' : '  ·  non-food'}',
                                  style: text.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          if (receipt.items[i].price != null)
                            Text('\$${receipt.items[i].price!.toStringAsFixed(2)}',
                                style: text.labelMedium),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Receipt images are used only to pull out grocery items. You can delete them any time.',
              style: text.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
