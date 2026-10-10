import 'package:flutter/material.dart';

import '../../core/models/inventory_item.dart';
import '../../core/theme/app_spacing.dart';
import 'expiration_badge.dart';
import 'food_image.dart';

/// One row in the Kitchen list — photo, name, quantity + location, freshness.
class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile({super.key, required this.item, this.onTap});

  final InventoryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        child: Row(
          children: [
            FoodImage(
              name: item.displayName,
              category: item.category,
              imageUrl: item.imageUrl,
              photoPath: item.photoPath,
              size: 46,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.quantityLabel}  ·  ${item.storageLocation.label}',
                    style: text.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ExpirationBadge(item: item, dense: true),
          ],
        ),
      ),
    );
  }
}
