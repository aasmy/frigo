import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/recipe.dart';
import '../../core/models/user_preferences.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/repositories/recipe_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/recipe_card.dart';
import '../../shared/widgets/skeleton.dart';

enum _RecipeFilter {
  all('All'),
  quick('30 min or less'),
  vegetarian('Vegetarian'),
  highProtein('High protein');

  const _RecipeFilter(this.label);
  final String label;

  bool matches(Recipe r) => switch (this) {
        _RecipeFilter.all => true,
        _RecipeFilter.quick => r.cookingMinutes <= 30,
        _RecipeFilter.vegetarian =>
          r.tags.any((t) => t.toLowerCase().contains('vegetarian')),
        _RecipeFilter.highProtein =>
          r.tags.any((t) => t.toLowerCase().contains('protein')),
      };
}

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  _RecipeFilter _filter = _RecipeFilter.all;

  Future<void> _pickDiet() async {
    final current = ref.read(preferencesProvider).diet;
    final chosen = await showModalBottomSheet<DietPreference>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text('Diet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final d in DietPreference.values)
              ListTile(
                title: Text(d.label),
                trailing: d == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, d),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != current) {
      ref.read(preferencesProvider.notifier).update((p) => p.copyWith(diet: chosen));
      ref.invalidate(recipeSuggestionsProvider);
      ref.invalidate(discoverMoreProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recipeSuggestionsProvider);
    final diet = ref.watch(preferencesProvider).diet;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text('Recipes for you', style: text.headlineLarge)),
                  _DietChip(diet: diet, onTap: _pickDiet),
                  const SizedBox(width: AppSpacing.sm),
                  _RoundIcon(
                    icon: Icons.refresh,
                    onTap: () {
                      ref.invalidate(recipeSuggestionsProvider);
                      ref.invalidate(discoverMoreProvider);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: AppSpacing.screenH,
                itemCount: _RecipeFilter.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final f = _RecipeFilter.values[i];
                  final selected = f == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: AppRadii.pillAll,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: text.labelMedium?.copyWith(
                          color: selected
                              ? AppColors.onPrimary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: AppSpacing.screenH,
              child: Material(
                color: AppColors.useSoonSoft,
                borderRadius: AppRadii.cardMd,
                child: InkWell(
                  borderRadius: AppRadii.cardMd,
                  onTap: () => context.push(Routes.rescue),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.eco_outlined,
                            color: AppColors.useSoon),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rescue my food', style: text.titleSmall),
                              Text('Cook what needs using first',
                                  style: text.labelMedium),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.useSoon),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: async.when(
                loading: () => ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    RecipeCardSkeleton(),
                    SizedBox(height: AppSpacing.sm),
                    RecipeCardSkeleton(),
                    SizedBox(height: AppSpacing.sm),
                    RecipeCardSkeleton(),
                  ],
                ),
                error: (e, _) => EmptyState(
                  art: FrigoArt.emptyRecipes,
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Nothing to suggest yet',
                  message: '$e',
                  actionLabel: 'Scan a receipt',
                  onAction: () => context.push(Routes.scan),
                ),
                data: (all) {
                  final recipes = all.where(_filter.matches).toList();
                  if (all.isEmpty) {
                    return EmptyState(
                      art: FrigoArt.emptyRecipes,
                      icon: Icons.restaurant_menu_outlined,
                      title: 'No recipes yet',
                      message:
                          "Add some groceries first and we'll find something to cook.",
                      actionLabel: 'Scan a receipt',
                      actionIcon: Icons.document_scanner_outlined,
                      onAction: () => context.push(Routes.scan),
                    );
                  }
                  if (recipes.isEmpty) {
                    return const EmptyState(
                      art: FrigoArt.emptyRecipes,
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matches for this filter',
                      message: 'Try a different filter above.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(recipeSuggestionsProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                      children: [
                        RecipeHeroCard(
                          recipe: recipes.first,
                          onTap: () => context.push(
                              Routes.recipeDetails(recipes.first.id),
                              extra: recipes.first),
                          onCook: () => context.push(
                              Routes.recipeDetails(recipes.first.id),
                              extra: recipes.first),
                        ),
                        if (recipes.length > 1) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text('More ideas', style: text.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          for (final (i, r) in recipes.skip(1).indexed) ...[
                            FadeSlideIn(
                              index: i,
                              child: RecipeCard(
                                recipe: r,
                                onTap: () => context.push(
                                    Routes.recipeDetails(r.id),
                                    extra: r),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        const _DiscoverMore(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A browsable feed of real recipes from TheMealDB, respecting the diet chip.
class _DiscoverMore extends ConsumerWidget {
  const _DiscoverMore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(discoverMoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Discover more', style: text.titleMedium)),
            Text('from thousands of recipes', style: text.labelSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...async.when(
          loading: () => const [
            RecipeCardSkeleton(),
            SizedBox(height: AppSpacing.sm),
            RecipeCardSkeleton(),
          ],
          error: (e, _) => [
            Text('Couldn\'t load more right now.', style: text.labelMedium),
          ],
          data: (recipes) => [
            for (final r in recipes) ...[
              RecipeCard(
                recipe: r,
                onTap: () =>
                    context.push(Routes.recipeDetails(r.id), extra: r),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: async.isLoading ? 'Loading…' : 'Load more recipes',
              icon: Icons.add,
              onPressed: async.isLoading
                  ? null
                  : () => ref.read(discoverMoreProvider.notifier).loadMore(),
            ),
          ],
        ),
      ],
    );
  }
}

class _DietChip extends StatelessWidget {
  const _DietChip({required this.diet, required this.onTap});
  final DietPreference diet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = diet == DietPreference.none ? 'Any diet' : diet.label;
    return Material(
      color: AppColors.primarySoft,
      borderRadius: AppRadii.pillAll,
      child: InkWell(
        borderRadius: AppRadii.pillAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.cardSm,
        side: BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: AppRadii.cardSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 21, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
