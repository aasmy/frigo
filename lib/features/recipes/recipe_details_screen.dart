import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/recipe.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/ingredient_status_row.dart';
import '../../shared/widgets/primary_button.dart';

class RecipeDetailsScreen extends ConsumerWidget {
  const RecipeDetailsScreen({super.key, required this.recipe});

  final Recipe? recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final r = recipe;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Recipe not available.')),
      );
    }

    final missing = r.missingIngredients;
    final useSoon = r.useSoonIngredients;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(recipe: r),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
            sliver: SliverList.list(
              children: [
                Text(r.title, style: text.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _Pill(icon: Icons.schedule, label: '${r.cookingMinutes} min'),
                    _Pill(
                      icon: Icons.check_circle_outline,
                      label:
                          '${r.availableIngredients.length}/${r.ingredients.length} ingredients',
                    ),
                    for (final t in r.tags) _Pill(label: t),
                  ],
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(r.description,
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ],
                if (useSoon.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.useSoonSoft,
                      borderRadius: AppRadii.cardMd,
                    ),
                    child: Text(
                      'Good choice — this uses ${useSoon.map((e) => e.name).join(', ')}, which should be used soon.',
                      style: text.labelMedium,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('From your kitchen', style: text.titleMedium),
                for (final ing in r.availableIngredients)
                  IngredientStatusRow(ingredient: ing),
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Missing', style: text.titleMedium),
                  for (final ing in missing) IngredientStatusRow(ingredient: ing),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'Add ${missing.length} to shopping list',
                    icon: Icons.add_shopping_cart_outlined,
                    onPressed: () {
                      for (final m in missing) {
                        ref.read(shoppingListProvider.notifier).addNeed(m.name);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Added to your shopping list')),
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('Method', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < r.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}',
                            style: text.titleSmall
                                ?.copyWith(color: AppColors.primary)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(r.steps[i], style: text.bodyMedium)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Cook this',
                  icon: Icons.local_fire_department_outlined,
                  onPressed: () =>
                      context.push(Routes.cookUpdate, extra: r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Text(recipe.heroEmoji, style: const TextStyle(fontSize: 72)),
    );
    final url = AppConfig.networkImagesEnabled ? recipe.imageUrl : null;
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round(),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({this.icon, required this.label});
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
