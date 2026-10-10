import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/receipt_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/frigo_illustration.dart';

class ReceiptHistoryScreen extends ConsumerWidget {
  const ReceiptHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt history')),
      body: SafeArea(
        child: receipts.isEmpty
            ? EmptyState(
                art: FrigoArt.emptyKitchen,
                icon: Icons.receipt_long_outlined,
                title: 'No receipts yet',
                message:
                    'Scanned receipts show up here so you can look back at any shop.',
                actionLabel: 'Scan a receipt',
                actionIcon: Icons.document_scanner_outlined,
                onAction: () => context.push(Routes.scan),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: receipts.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final r = receipts[i];
                  return Material(
                    color: AppColors.surface,
                    borderRadius: AppRadii.cardLg,
                    child: InkWell(
                      borderRadius: AppRadii.cardLg,
                      onTap: () => context.push(Routes.receiptDetails(r.id)),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.cardLg,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceTint,
                                  borderRadius: AppRadii.cardMd,
                                ),
                                child: const Icon(Icons.storefront_outlined,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.merchant, style: text.titleSmall),
                                    Text(
                                      '${Fmt.shortDate(r.purchaseDate)}  ·  ${r.foodItemCount} food item${r.foodItemCount == 1 ? '' : 's'}',
                                      style: text.labelMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
