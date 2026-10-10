import 'package:flutter/material.dart';

import '../../core/models/recipe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// One ingredient line inside a recipe: check when owned, dash when missing,
/// with a soft "use soon" tag when relevant.
class IngredientStatusRow extends StatelessWidget {
  const IngredientStatusRow({super.key, required this.ingredient});

  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = ingredient.available;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: available ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              ingredient.name,
              style: text.bodyMedium?.copyWith(
                color:
                    available ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (ingredient.quantityLabel != null)
            Text(ingredient.quantityLabel!, style: text.labelMedium),
          if (ingredient.useSoon) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.useSoonSoft,
                borderRadius: AppRadii.pillAll,
              ),
              child: Text(
                'use soon',
                style: text.labelSmall?.copyWith(
                  color: AppColors.useSoon,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
