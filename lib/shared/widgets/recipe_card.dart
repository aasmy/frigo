import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/models/recipe.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// Shared photo box with an illustrated fallback.
class _RecipePhoto extends StatelessWidget {
  const _RecipePhoto({
    required this.recipe,
    required this.height,
    this.width = double.infinity,
    this.radius = const BorderRadius.vertical(top: Radius.circular(20)),
  });

  final Recipe recipe;
  final double height;
  final double width;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Text(recipe.heroEmoji,
          style: TextStyle(fontSize: height * 0.34)),
    );
    final url =
        AppConfig.networkImagesEnabled ? recipe.imageUrl : null;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: width,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: AppMotion.base,
                // Cards are at most screen-width; never decode larger.
                memCacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Large hero recipe card for the top suggestion.
class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({
    super.key,
    required this.recipe,
    required this.onCook,
    this.onTap,
  });

  final Recipe recipe;
  final VoidCallback onCook;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final missing = recipe.missingIngredients;
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _RecipePhoto(recipe: recipe, height: 150),
              Positioned(
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.pillAll,
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('${recipe.cookingMinutes} min',
                          style: text.labelSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Uses ${recipe.availableIngredients.length} things you already have'
                  '${missing.isEmpty ? '' : ' · missing ${missing.length}'}',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                _AvailabilityBar(ratio: recipe.availabilityRatio),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onCook,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 50),
                    ),
                    child: const Text('Cook this'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact recipe row for secondary suggestions and the Recipes list.
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          _RecipePhoto(
            recipe: recipe,
            height: 64,
            width: 64,
            radius: AppRadii.cardSm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${recipe.cookingMinutes} min  ·  ${recipe.availabilityPercent}% ready'
                  '${recipe.missingIngredients.isEmpty ? '' : '  ·  need ${recipe.missingIngredients.length}'}',
                  style: text.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBar extends StatelessWidget {
  const _AvailabilityBar({required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 7,
              backgroundColor: AppColors.surfaceSunken,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('${(ratio * 100).round()}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
