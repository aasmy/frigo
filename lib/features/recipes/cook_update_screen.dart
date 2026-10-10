import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/recipe.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/recipe_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/primary_button.dart';

/// "Update your kitchen?" after cooking. Forgiving — quick actions, not exact
/// measurements.
class CookUpdateScreen extends ConsumerStatefulWidget {
  const CookUpdateScreen({super.key, required this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<CookUpdateScreen> createState() => _CookUpdateScreenState();
}

class _CookUpdateScreenState extends ConsumerState<CookUpdateScreen> {
  final Map<String, ConsumptionAction> _choices = {};
  late final List<InventoryItem> _matched;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(inventoryProvider.notifier);
    final seen = <String>{};
    _matched = [];
    for (final ing in widget.recipe?.availableIngredients ?? const []) {
      final match = notifier.matching(ing.name);
      if (match.isNotEmpty && seen.add(match.first.id)) {
        _matched.add(match.first);
        _choices[match.first.id] = ConsumptionAction.usedSome;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = widget.recipe;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Recipe not available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Update your kitchen?')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text('You cooked ${r.title}', style: text.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tell us roughly what changed. Exact amounts don\'t matter.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_matched.isEmpty)
                    Text(
                      'Nothing from this recipe is tracked in your kitchen, so there\'s nothing to update.',
                      style: text.bodyMedium,
                    ),
                  for (final item in _matched) ...[
                    _ConsumptionCard(
                      item: item,
                      choice: _choices[item.id]!,
                      onChanged: (c) => setState(() => _choices[item.id] = c),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: PrimaryButton(
                label: 'Confirm',
                onPressed: () {
                  final changes = _matched
                      .map((i) => ConsumptionChange(
                            itemId: i.id,
                            action: _choices[i.id]!,
                          ))
                      .toList();
                  ref
                      .read(inventoryProvider.notifier)
                      .applyConsumption(changes);
                  ref.read(recipeHistoryProvider.notifier).record(r);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kitchen updated after ${r.title}')),
                  );
                  context.go('/home');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumptionCard extends StatelessWidget {
  const _ConsumptionCard({
    required this.item,
    required this.choice,
    required this.onChanged,
  });

  final InventoryItem item;
  final ConsumptionAction choice;
  final ValueChanged<ConsumptionAction> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const options = [
      ConsumptionAction.usedSome,
      ConsumptionAction.usedAll,
      ConsumptionAction.stillHaveIt,
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardMd,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.displayName, style: text.titleSmall)),
              Text(Fmt.quantity(item.quantity, item.unit),
                  style: text.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: choice == o,
                  onSelected: (_) => onChanged(o),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
