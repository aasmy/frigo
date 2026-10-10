import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/inventory_item_tile.dart';
import '../../shared/widgets/kitchen_search_bar.dart';
import '../../shared/widgets/swipe_actions.dart';
import 'edit_item_sheet.dart';

/// "My Kitchen" — grouped by where things live, the way you'd actually look
/// for them. Search flips to a flat result list.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  final _search = TextEditingController();
  final _expanded = <StorageLocation>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _rank(FreshnessStatus s) => switch (s) {
        FreshnessStatus.expired => 0,
        FreshnessStatus.useSoon => 1,
        FreshnessStatus.fresh => 2,
        FreshnessStatus.unknown => 3,
        FreshnessStatus.frozen => 4,
      };

  void _edit(InventoryItem i) => showEditItemSheet(context, ref, i);

  Future<void> _delete(InventoryItem i) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${i.displayName}?',
      message: 'It will be removed from your kitchen.',
    );
    if (ok) ref.read(inventoryProvider.notifier).removeItem(i.id);
  }

  List<InventoryItem> _sorted(Iterable<InventoryItem> items) {
    final list = items.toList()
      ..sort((a, b) {
        final r = _rank(a.status).compareTo(_rank(b.status));
        return r != 0
            ? r
            : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(inventoryProvider);
    final text = Theme.of(context).textTheme;
    final query = _search.text.trim().toLowerCase();

    final fresh = all.where((i) => i.status == FreshnessStatus.fresh).length;
    final soon = all
        .where((i) =>
            i.status == FreshnessStatus.useSoon ||
            i.status == FreshnessStatus.expired)
        .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Kitchen', style: text.headlineLarge),
                        if (all.isNotEmpty)
                          Text(
                              '${all.length} items · $fresh fresh · $soon to use soon',
                              style: text.labelMedium),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.shopping_cart_outlined,
                    badge: ref.watch(shoppingNeedCountProvider),
                    onTap: () => context.push(Routes.shoppingList),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _RoundIconButton(
                    icon: Icons.history,
                    onTap: () => context.push(Routes.receiptHistory),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _RoundIconButton(
                    icon: Icons.add,
                    filled: true,
                    onTap: () => context.push(Routes.manualAdd),
                  ),
                ],
              ),
            ),
            if (all.isNotEmpty)
              Padding(
                padding: AppSpacing.screenH,
                child: KitchenSearchBar(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: all.isEmpty
                  ? EmptyState(
                      art: FrigoArt.emptyKitchen,
                      icon: Icons.kitchen_outlined,
                      title: 'Your kitchen is empty here.',
                      message:
                          "Scan your first grocery receipt and we'll organize everything.",
                      actionLabel: 'Scan Receipt',
                      actionIcon: Icons.document_scanner_outlined,
                      onAction: () => context.push(Routes.scan),
                    )
                  : query.isNotEmpty
                      ? _SearchResults(
                          items: _sorted(all.where((i) =>
                              i.displayName.toLowerCase().contains(query) ||
                              i.name.toLowerCase().contains(query) ||
                              i.category.label.toLowerCase().contains(query))),
                          onEdit: _edit,
                          onDelete: _delete,
                        )
                      : SlidableAutoCloseBehavior(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                                AppSpacing.lg, AppSpacing.xxxl),
                            children: [
                              for (final loc in StorageLocation.values)
                                if (all.any((i) => i.storageLocation == loc))
                                  _StorageGroup(
                                    location: loc,
                                    items: _sorted(all
                                        .where((i) => i.storageLocation == loc)),
                                    expanded: _expanded.contains(loc),
                                    onToggle: () => setState(() =>
                                        _expanded.contains(loc)
                                            ? _expanded.remove(loc)
                                            : _expanded.add(loc)),
                                    onOpenItem: (id) =>
                                        context.push(Routes.itemDetails(id)),
                                    onEdit: _edit,
                                    onDelete: _delete,
                                  ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageGroup extends StatelessWidget {
  const _StorageGroup({
    required this.location,
    required this.items,
    required this.expanded,
    required this.onToggle,
    required this.onOpenItem,
    required this.onEdit,
    required this.onDelete,
  });

  final StorageLocation location;
  final List<InventoryItem> items;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<InventoryItem> onEdit;
  final ValueChanged<InventoryItem> onDelete;

  static const _preview = 4;

  Color get _accent =>
      location == StorageLocation.freezer ? AppColors.freezer : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = expanded ? items : items.take(_preview).toList();
    final hiddenCount = items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: AppRadii.cardSm,
                  ),
                  child: Icon(location.icon, size: 17, color: _accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(location.label, style: text.titleMedium),
                const SizedBox(width: AppSpacing.sm),
                Text('${items.length}',
                    style: text.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardLg,
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: AppSpacing.lg),
                  FadeSlideIn(
                    index: i,
                    child: ClipRRect(
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(20))
                        : BorderRadius.zero,
                    child: SwipeActions(
                      groupTag: location,
                      onEdit: () => onEdit(shown[i]),
                      onDelete: () => onDelete(shown[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        child: InventoryItemTile(
                          item: shown[i],
                          onTap: () => onOpenItem(shown[i].id),
                        ),
                      ),
                    ),
                  ),
                  ),
                ],
                if (items.length > _preview) ...[
                  const Divider(height: 1, indent: AppSpacing.lg),
                  InkWell(
                    onTap: onToggle,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: Text(
                          expanded ? 'Show less' : 'See all $hiddenCount more',
                          style: text.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });
  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onEdit;
  final ValueChanged<InventoryItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        art: FrigoArt.emptyKitchen,
        icon: Icons.search_off,
        title: 'Nothing matches',
        message: 'Try a different word.',
      );
    }
    return SlidableAutoCloseBehavior(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          ClipRRect(
            borderRadius: AppRadii.cardLg,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.cardLg,
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: AppSpacing.lg),
                    SwipeActions(
                      groupTag: 'search',
                      onEdit: () => onEdit(items[i]),
                      onDelete: () => onDelete(items[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        child: Builder(
                          builder: (context) => InventoryItemTile(
                            item: items[i],
                            onTap: () => context
                                .push(Routes.itemDetails(items[i].id)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: filled ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardSm,
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: AppRadii.cardSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon,
              size: 21,
              color: filled ? AppColors.onPrimary : AppColors.textSecondary),
        ),
      ),
    );
    if (badge <= 0) return btn;
    return Badge(
      label: Text('$badge'),
      backgroundColor: AppColors.primary,
      child: btn,
    );
  }
}
