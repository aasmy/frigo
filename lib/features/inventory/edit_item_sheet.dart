import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/providers/service_providers.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/services/ai/food_knowledge_base.dart';
import '../../core/services/ai/text_normalizer.dart';
import '../../core/services/images/image_resolver.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/food_image.dart';
import '../../shared/widgets/unit_field.dart';

/// One editor for an inventory item — used from the Kitchen swipe action and
/// from the item detail page. Rewrites category / unit / storage / image live
/// as the name is edited (unless the user has touched that field).
Future<void> showEditItemSheet(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditItemSheet(item: item),
  );
}

class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({required this.item});
  final InventoryItem item;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late final _name = TextEditingController(text: widget.item.displayName);
  late final _qty =
      TextEditingController(text: Fmt.quantity(widget.item.quantity, ''));
  late String _unit;
  late FoodCategory _category;
  late StorageLocation _storage;
  late String? _imageUrl;

  Timer? _debounce;
  String _lastInferred = '';
  bool _inferring = false;
  bool _touchedCategory = false;
  bool _touchedUnit = false;
  bool _touchedStorage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.item.unit;
    _category = widget.item.category;
    _storage = widget.item.storageLocation;
    _imageUrl = widget.item.imageUrl;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  StorageLocation _storageFor(FoodCategory c) => switch (c) {
        FoodCategory.meat || FoodCategory.frozen => StorageLocation.freezer,
        FoodCategory.dairy || FoodCategory.produce => StorageLocation.fridge,
        FoodCategory.bakery => StorageLocation.counter,
        _ => StorageLocation.pantry,
      };

  void _onNameChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _infer);
  }

  Future<void> _infer() async {
    final name = _name.text.trim();
    if (name.length < 3 || name == _lastInferred) return;
    _lastInferred = name;

    final expanded =
        ReceiptTextTools.expand(ReceiptTextTools.tokenize(name));
    final local = FoodKnowledgeBase.recognise(expanded);
    if (local != null) {
      setState(() {
        if (!_touchedCategory) _category = local.entry.category;
        if (!_touchedUnit) _unit = local.entry.unit;
        if (!_touchedStorage) _storage = _storageFor(local.entry.category);
      });
    }

    setState(() => _inferring = true);
    try {
      final r = await ref.read(aiServiceProvider).normalizeName(name);
      if (!mounted || _name.text.trim() != name) return;
      setState(() {
        if (!_touchedCategory) _category = r.category;
        if (!_touchedUnit && r.unit.trim().isNotEmpty) _unit = r.unit.trim();
        if (!_touchedStorage) _storage = _storageFor(r.category);
      });
      final url = await ImageResolver.instance.resolve(name);
      if (mounted && url != null) setState(() => _imageUrl = url);
    } catch (_) {
      // keep the local guess
    } finally {
      if (mounted) setState(() => _inferring = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final newName = _name.text.trim();
    final base = newName.isEmpty ? widget.item.displayName : newName;
    final image = _imageUrl ??
        (newName != widget.item.displayName
            ? await ImageResolver.instance.resolve(base)
            : widget.item.imageUrl);

    ref.read(inventoryProvider.notifier).updateItem(
          widget.item.copyWith(
            normalizedName: base,
            name: base,
            quantity: double.tryParse(_qty.text.trim()) ?? widget.item.quantity,
            unit: _unit.trim().isEmpty ? widget.item.unit : _unit.trim(),
            category: _category,
            storageLocation: _storage,
            imageUrl: image,
            manualStatus: _storage == StorageLocation.freezer
                ? FreshnessStatus.frozen
                : (widget.item.manualStatus == FreshnessStatus.frozen
                    ? null
                    : widget.item.manualStatus),
          ),
        );
    if (mounted) Navigator.pop(context);
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
            Row(
              children: [
                FoodImage(
                  name: _name.text.trim().isEmpty
                      ? widget.item.displayName
                      : _name.text.trim(),
                  category: _category,
                  imageUrl: _imageUrl,
                  size: 56,
                  radius: 14,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Edit item', style: text.titleLarge)),
                if (_inferring)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: _onNameChanged,
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
                    onChanged: (u) => setState(() {
                      _unit = u;
                      _touchedUnit = true;
                    }),
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
                    onSelected: (_) => setState(() {
                      _category = c;
                      _touchedCategory = true;
                    }),
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
                    onSelected: (_) => setState(() {
                      _storage = s;
                      _touchedStorage = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
