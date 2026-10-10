import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/recipe.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/repositories/recipe_repository.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/motion/freshness_ring.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/food_image.dart';
import '../../shared/widgets/recipe_card.dart';
import '../../shared/widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final useSoon = ref.watch(useSoonProvider);
    final prefs = ref.watch(preferencesProvider);
    final recipesAsync = ref.watch(recipeSuggestionsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(recipeSuggestionsProvider),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            children: [
              _Header(name: prefs.displayName),
              if (inventory.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyState(
                    art: FrigoArt.emptyKitchen,
                    icon: Icons.receipt_long_outlined,
                    title: 'Your kitchen is empty here.',
                    message:
                        "Scan your first grocery receipt and we'll organize everything.",
                    actionLabel: 'Scan Receipt',
                    actionIcon: Icons.document_scanner_outlined,
                    onAction: () => context.push(Routes.scan),
                  ),
                )
              else ...[
                if (useSoon.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Use soon',
                    actionLabel: 'See all',
                    onAction: () => context.go(Routes.kitchen),
                  ),
                  _UseSoonStrip(items: useSoon.take(8).toList()),
                ],
                SectionHeader(
                  title: 'What to cook tonight?',
                  actionLabel: 'All recipes',
                  onAction: () => context.go(Routes.recipes),
                ),
                Padding(
                  padding: AppSpacing.screenH,
                  child: recipesAsync.when(
                    loading: () => const _RecipesLoading(),
                    error: (e, _) =>
                        AppCard(child: Text('$e', style: text.bodyMedium)),
                    data: (recipes) => _RecipeSuggestions(recipes: recipes),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: AppSpacing.screenH,
                  child: _KitchenSummary(inventory: inventory),
                ),
                const SizedBox(height: AppSpacing.md),
                const Padding(
                  padding: AppSpacing.screenH,
                  child: _ShoppingCard(),
                ),
                if (useSoon.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: AppSpacing.screenH,
                    child: _RescueBanner(count: useSoon.length),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final who = (name != null && name!.trim().isNotEmpty) ? ', ${name!}' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.date(DateTime.now()).toUpperCase(),
                  style: text.labelSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('${Fmt.greeting()}$who 👋', style: text.headlineLarge),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _HeaderButton(
            icon: Icons.auto_awesome_outlined,
            tint: AppColors.primary,
            onTap: () => context.push(Routes.assistant),
          ),
          const SizedBox(width: AppSpacing.sm),
          _HeaderButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.go(Routes.settings),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.tint = AppColors.textSecondary,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color tint;

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
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22, color: tint),
        ),
      ),
    );
  }
}

class _UseSoonStrip extends StatelessWidget {
  const _UseSoonStrip({required this.items});
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screenH,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final item = items[i];
          return FadeSlideIn(
            index: i,
            offset: 0,
            child: PressableScale(
              onTap: () => context.push(Routes.itemDetails(item.id)),
              child: Container(
                // Wide enough for two lines of a real grocery name — "Baby
                // Spinach" and "Chicken Breast" were both being cut off.
                width: 132,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardLg,
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FoodImage(
                      name: item.displayName,
                      category: item.category,
                      imageUrl: item.imageUrl,
                      photoPath: item.photoPath,
                      size: 46,
                    ),
                    const Spacer(),
                    Text(
                      item.displayName,
                      style: text.labelLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.daysLeftLabel,
                      style: text.labelSmall?.copyWith(
                        color: item.status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecipeSuggestions extends StatelessWidget {
  const _RecipeSuggestions({required this.recipes});
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const AppCard(
        child: Text(
          "Add a few more groceries and we'll find something to cook.",
        ),
      );
    }
    final hero = recipes.first;
    final rest = recipes.skip(1).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecipeHeroCard(
          recipe: hero,
          onTap: () => context.push(Routes.recipeDetails(hero.id), extra: hero),
          onCook: () =>
              context.push(Routes.recipeDetails(hero.id), extra: hero),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('More ideas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final r in rest) ...[
            RecipeCard(
              recipe: r,
              onTap: () => context.push(Routes.recipeDetails(r.id), extra: r),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _RecipesLoading extends StatelessWidget {
  const _RecipesLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        RecipeCardSkeleton(),
        SizedBox(height: AppSpacing.sm),
        RecipeCardSkeleton(),
      ],
    );
  }
}

class _KitchenSummary extends StatelessWidget {
  const _KitchenSummary({required this.inventory});
  final List<InventoryItem> inventory;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    var fresh = 0, soon = 0, gone = 0;
    for (final i in inventory) {
      switch (i.status) {
        case FreshnessStatus.expired:
          gone++;
        case FreshnessStatus.useSoon:
          soon++;
        case FreshnessStatus.fresh:
        case FreshnessStatus.frozen:
        case FreshnessStatus.unknown:
          fresh++;
      }
    }

    return AppCard(
      child: Row(
        children: [
          // The ring sweeps on arrival, so the split is read as a quantity
          // rather than three numbers that have to be compared.
          FreshnessRing(
            fresh: fresh,
            useSoon: soon,
            expired: gone,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCounter(inventory.length, style: text.titleLarge),
                Text('items', style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kitchen summary', style: text.titleSmall),
                const SizedBox(height: AppSpacing.md),
                _Legend(color: AppColors.fresh, label: 'Fresh', count: fresh),
                const SizedBox(height: AppSpacing.xs),
                _Legend(
                  color: AppColors.useSoon,
                  label: 'Use soon',
                  count: soon,
                ),
                const SizedBox(height: AppSpacing.xs),
                _Legend(
                  color: AppColors.expired,
                  label: 'Past estimate',
                  count: gone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: text.bodyMedium)),
        AnimatedCounter(count, style: text.titleSmall),
      ],
    );
  }
}

class _ShoppingCard extends ConsumerWidget {
  const _ShoppingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final need = ref.watch(shoppingNeedCountProvider);
    final smart = ref.watch(shoppingSuggestionsProvider);

    return AppCard(
      onTap: () => context.push(Routes.shoppingList),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Shopping list', style: text.titleSmall)),
              Text(
                need == 0 ? 'Nothing to buy' : '$need to buy',
                style: text.labelMedium,
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
          if (smart.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Suggested: ${smart.take(3).map((s) => s.name).join(', ')}',
              style: text.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _RescueBanner extends StatelessWidget {
  const _RescueBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.useSoonSoft,
      elevated: false,
      onTap: () => context.push(Routes.rescue),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: AppColors.useSoon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rescue my food', style: text.titleSmall),
                Text(
                  '$count item${count == 1 ? '' : 's'} should be used first',
                  style: text.labelMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.useSoon),
        ],
      ),
    );
  }
}
