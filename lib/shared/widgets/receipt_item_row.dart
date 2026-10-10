import 'package:flutter/material.dart';

import '../../core/models/enums.dart';
import '../../core/models/receipt_item.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'food_image.dart';
import 'unit_field.dart';

/// A single detected line on the Receipt Confirmation screen.
///
/// Tapping the body opens an editor sheet; the leading checkbox includes or
/// excludes the row; low-confidence rows get a soft hint.
class ReceiptItemRow extends StatelessWidget {
  const ReceiptItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  final ReceiptItem item;
  final ValueChanged<ReceiptItem> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = !item.included;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: AppColors.expiredSoft,
        child: const Icon(Icons.delete_outline, color: AppColors.expired),
      ),
      child: InkWell(
        onTap: () => _openEditor(context),
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: muted ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                _IncludeToggle(
                  value: item.included,
                  onChanged: (v) => onChanged(item.copyWith(included: v)),
                ),
                const SizedBox(width: AppSpacing.md),
                item.isFood
                    ? FoodImage(
                        name: item.normalizedName,
                        category: item.category,
                        size: 42,
                      )
                    : Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint,
                          borderRadius: AppRadii.cardSm,
                        ),
                        child: const Icon(Icons.remove_shopping_cart_outlined,
                            size: 19, color: AppColors.textTertiary),
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.normalizedName,
                              style: text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.brand != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.brand!,
                                style: text.labelSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.isFood
                            ? '${item.quantityLabel}  ·  ${item.effectiveStorage.label}'
                            : 'Not food — won\'t be added',
                        style: text.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isLowConfidence && item.isFood) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.useSoonSoft,
                            borderRadius: AppRadii.pillAll,
                          ),
                          child: Text(
                            'Best guess — tap to check',
                            style: text.labelSmall
                                ?.copyWith(color: AppColors.useSoon),
                          ),
                        ),
                      ] else if (item.rawName.toUpperCase() !=
                          item.normalizedName.toUpperCase()) ...[
                        const SizedBox(height: 2),
                        Text(
                          'from “${item.rawName}”',
                          style: text.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.isFood)
                  _QtyStepper(
                    quantity: item.quantity,
                    onChanged: (q) => onChanged(item.copyWith(quantity: q)),
                  )
                else
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final result = await showModalBottomSheet<ReceiptItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiptItemEditor(item: item),
    );
    if (result != null) onChanged(result);
  }
}

/// Compact −/N/+ control. Steps whole units; keeps a sensible floor.
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.quantity, required this.onChanged});
  final double quantity;
  final ValueChanged<double> onChanged;

  String get _label => quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: AppRadii.pillAll,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
        );
    final step = quantity >= 100 ? 50.0 : (quantity > 10 ? 5.0 : 1.0);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(Icons.remove,
              () => onChanged((quantity - step).clamp(step, 100000))),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 24),
            child: Text(_label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700)),
          ),
          btn(Icons.add, () => onChanged(quantity + step)),
        ],
      ),
    );
  }
}

class _IncludeToggle extends StatelessWidget {
  const _IncludeToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 24,
        width: 24,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.textTertiary,
            width: 1.5,
          ),
        ),
        child: value
            ? const Icon(Icons.check, size: 16, color: AppColors.onPrimary)
            : null,
      ),
    );
  }
}

class _ReceiptItemEditor extends StatefulWidget {
  const _ReceiptItemEditor({required this.item});
  final ReceiptItem item;

  @override
  State<_ReceiptItemEditor> createState() => _ReceiptItemEditorState();
}

class _ReceiptItemEditorState extends State<_ReceiptItemEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item.normalizedName);
  late final TextEditingController _qty = TextEditingController(
      text: widget.item.quantity == widget.item.quantity.roundToDouble()
          ? widget.item.quantity.toStringAsFixed(0)
          : widget.item.quantity.toStringAsFixed(1));
  late String _unit = widget.item.unit;
  late FoodCategory _category = widget.item.category;
  late StorageLocation _storage = widget.item.effectiveStorage;
  late bool _isFood = widget.item.isFood;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      widget.item.copyWith(
        normalizedName: _name.text.trim().isEmpty
            ? widget.item.normalizedName
            : _name.text.trim(),
        quantity: double.tryParse(_qty.text.trim()) ?? widget.item.quantity,
        unit: _unit.trim().isEmpty ? widget.item.unit : _unit.trim(),
        category: _category,
        storageLocation: _storage,
        isFood: _isFood,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit item', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('From receipt: "${widget.item.rawName}"',
                style: text.labelMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: UnitField(
                    value: _unit,
                    onChanged: (u) => setState(() => _unit = u),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Category', style: text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in FoodCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Storage', style: text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final s in StorageLocation.values)
                  ChoiceChip(
                    label: Text(s.label),
                    avatar: Icon(s.icon, size: 16),
                    selected: _storage == s,
                    onSelected: (_) => setState(() => _storage = s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('This is food'),
              subtitle: const Text('Non-food items are kept off your kitchen list'),
              value: _isFood,
              onChanged: (v) => setState(() => _isFood = v),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 52),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
