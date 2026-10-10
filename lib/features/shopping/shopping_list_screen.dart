import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/shopping_list_item.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/services/shopping/shopping_suggestions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/frigo_illustration.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    ref.read(shoppingListProvider.notifier).addNeed(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(shoppingListProvider);
    final notifier = ref.read(shoppingListProvider.notifier);
    final need = notifier.section(ShoppingSection.need);
    final suggested = notifier.section(ShoppingSection.suggested);
    final bought = notifier.section(ShoppingSection.recentlyBought);
    final smart = ref.watch(shoppingSuggestionsProvider);
    final text = Theme.of(context).textTheme;
    final hasAnything = need.isNotEmpty ||
        suggested.isNotEmpty ||
        bought.isNotEmpty ||
        smart.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          if (need.any((e) => e.completed))
            TextButton(
              onPressed: notifier.clearCompleted,
              child: const Text('Clear done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: 'Add an item',
                  prefixIcon: const Icon(Icons.add),
                  suffixIcon: TextButton(onPressed: _add, child: const Text('Add')),
                ),
              ),
            ),
            Expanded(
              child: !hasAnything
                  ? EmptyState(
                      art: FrigoArt.emptyShopping,
                      icon: Icons.shopping_cart_outlined,
                      title: 'Your list is empty',
                      message:
                          'Add items above, send missing recipe ingredients from a recipe, or scan a receipt to keep your kitchen up to date.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                          AppSpacing.lg, AppSpacing.xxxl),
                      children: [
                        if (need.isNotEmpty) ...[
                          _Header('Need'),
                          for (final i in need)
                            _ShoppingRow(
                              item: i,
                              onToggle: () => notifier.toggleComplete(i.id),
                              onRemove: () => notifier.remove(i.id),
                            ),
                        ],
                        if (smart.isNotEmpty) ...[
                          _Header('Suggested for you'),
                          for (final s in smart)
                            _SmartRow(
                              suggestion: s,
                              onAdd: () => notifier.addNeed(s.name),
                            ),
                        ],
                        if (suggested.isNotEmpty) ...[
                          _Header('From recipes'),
                          for (final i in suggested)
                            _SuggestedRow(
                              item: i,
                              onAdd: () => notifier.promote(i.id),
                              onDismiss: () => notifier.remove(i.id),
                            ),
                        ],
                        if (bought.isNotEmpty) ...[
                          _Header('Recently bought'),
                          for (final i in bought)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm),
                              child: Text(i.name,
                                  style: text.bodyMedium?.copyWith(
                                      color: AppColors.textTertiary)),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, AppSpacing.sm),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({
    required this.item,
    required this.onToggle,
    required this.onRemove,
  });

  final ShoppingListItem item;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.expiredSoft,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(Icons.delete_outline, color: AppColors.expired),
      ),
      child: InkWell(
        onTap: () {
          Haptics.tap();
          onToggle();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                item.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: item.completed
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.quantityLabel == null
                      ? item.name
                      : '${item.name}  ·  ${item.quantityLabel}',
                  style: text.bodyLarge?.copyWith(
                    decoration:
                        item.completed ? TextDecoration.lineThrough : null,
                    color: item.completed
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartRow extends StatelessWidget {
  const _SmartRow({required this.suggestion, required this.onAdd});
  final ShoppingSuggestion suggestion;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: AppRadii.cardMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline,
              size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.name, style: text.titleSmall),
                Text(suggestion.reason, style: text.labelSmall),
              ],
            ),
          ),
          FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({
    required this.item,
    required this.onAdd,
    required this.onDismiss,
  });

  final ShoppingListItem item;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: AppRadii.cardMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.titleSmall),
                if (item.reason != null)
                  Text(item.reason!, style: text.labelSmall),
              ],
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add')),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.xs),
              child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
