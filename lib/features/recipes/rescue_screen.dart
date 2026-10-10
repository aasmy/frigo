import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/repositories/recipe_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/recipe_card.dart';

/// Rescue Mode — recipes tuned to use up whatever is closest to spoiling.
class RescueScreen extends ConsumerWidget {
  const RescueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rescueRecipesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Rescue my food')),
      body: SafeArea(
        child: async.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              RecipeCardSkeleton(),
              SizedBox(height: AppSpacing.sm),
              RecipeCardSkeleton(),
              SizedBox(height: AppSpacing.sm),
              RecipeCardSkeleton(),
            ],
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (result) {
            if (result.atRisk.isEmpty) {
              return const EmptyState(
                art: FrigoArt.emptyRecipes,
                icon: Icons.spa_outlined,
                title: 'Nothing at risk right now',
                message: 'Your kitchen looks fresh. Check back in a day or two.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                Text("Let's save these before they go bad.",
                    style: text.headlineMedium),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.useSoonSoft,
                    borderRadius: AppRadii.cardMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Use first', style: text.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      for (final item in result.atRisk)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                height: 6,
                                width: 6,
                                decoration: BoxDecoration(
                                  color: item.status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                  child: Text(item.displayName,
                                      style: text.bodyMedium)),
                              Text(item.freshnessLabel, style: text.labelSmall),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Recipes to use them up', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (result.recipes.isEmpty)
                  Text(
                    "We couldn't build a recipe around these right now.",
                    style: text.bodyMedium,
                  ),
                for (final r in result.recipes) ...[
                  RecipeCard(
                    recipe: r,
                    onTap: () => context
                        .push(Routes.recipeDetails(r.id), extra: r),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
