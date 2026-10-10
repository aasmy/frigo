import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/enums.dart';
import '../../core/models/inventory_item.dart';
import '../../core/providers/service_providers.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/services/ai/ai_service.dart';
import '../../core/services/ai/food_knowledge_base.dart';
import '../../core/services/ai/text_normalizer.dart';
import '../../core/services/expiration/expiration_estimator.dart';
import '../../core/services/images/image_resolver.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/food_image.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/unit_field.dart';

/// Secondary path to add an item. AI infers category + shelf life so the user
/// only types a name, amount and where it lives.
class ManualAddItemScreen extends ConsumerStatefulWidget {
  const ManualAddItemScreen({super.key});

  @override
  ConsumerState<ManualAddItemScreen> createState() =>
      _ManualAddItemScreenState();
}

class _ManualAddItemScreenState extends ConsumerState<ManualAddItemScreen> {
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '1');
  String _unit = 'piece';
  FoodCategory _category = FoodCategory.other;
  StorageLocation _storage = StorageLocation.pantry;
  bool _inferring = false;
  bool _saving = false;
  bool _userTouchedCategory = false;
  bool _userTouchedUnit = false;
  bool _userTouchedStorage = false;

  Timer? _debounce;
  String _lastInferred = '';

  /// The tidy name for what the user typed (used for display + image).
  String? _tidyName;
  double _imageConfidence = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {}); // live image preview
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _infer);
  }

  StorageLocation _storageFor(FoodCategory c) => switch (c) {
        FoodCategory.meat => StorageLocation.freezer,
        FoodCategory.frozen => StorageLocation.freezer,
        FoodCategory.dairy => StorageLocation.fridge,
        FoodCategory.produce => StorageLocation.fridge,
        FoodCategory.bakery => StorageLocation.counter,
        _ => StorageLocation.pantry,
      };

  void _applyGuess({
    required String tidyName,
    required FoodCategory category,
    required String unit,
    required double confidence,
    StorageLocation? storage,
  }) {
    setState(() {
      _tidyName = tidyName;
      _imageConfidence = confidence;
      if (!_userTouchedCategory) _category = category;
      if (!_userTouchedUnit && unit.trim().isNotEmpty) _unit = unit.trim();
      if (!_userTouchedStorage) {
        _storage = storage ?? _storageFor(category);
      }
    });
  }

  Future<void> _infer() async {
    final name = _name.text.trim();
    if (name.length < 3 || name == _lastInferred) return;
    _lastInferred = name;

    // 1. Instant, offline guess so the fields react as you type.
    final expanded =
        ReceiptTextTools.expand(ReceiptTextTools.tokenize(name));
    final local = FoodKnowledgeBase.recognise(expanded);
    if (local != null) {
      _applyGuess(
        tidyName: local.entry.name,
        category: local.entry.category,
        unit: local.entry.unit,
        confidence: local.confidence,
        // storage from the category map: raw meat -> freezer, produce -> fridge…
      );
    }

    // 2. Refine with the AI (Gemini when available).
    setState(() => _inferring = true);
    try {
      final r = await ref.read(aiServiceProvider).normalizeName(name);
      if (!mounted || _name.text.trim() != name) return;
      _applyGuess(
        tidyName: r.normalizedName,
        category: r.category,
        unit: r.unit,
        confidence: r.confidence,
      );
    } catch (_) {
      // keep the local guess
    } finally {
      if (mounted) setState(() => _inferring = false);
    }
  }

  Future<void> _save() async {
    final typed = _name.text.trim();
    if (typed.isEmpty) return;
    setState(() => _saving = true);

    // If inference hasn't run yet (fast typers), do it now so the item gets a
    // tidy name + image.
    if (_tidyName == null) {
      try {
        final r = await ref.read(aiServiceProvider).normalizeName(typed);
        _tidyName = r.normalizedName;
        _imageConfidence = r.confidence;
        if (!_userTouchedCategory) _category = r.category;
      } catch (_) {}
    }
    final displayName =
        (_imageConfidence >= 0.6 && _tidyName != null) ? _tidyName! : typed;

    final now = DateTime.now();
    int days;
    try {
      final estimate = await ref.read(aiServiceProvider).estimateShelfLife(
            productName: displayName,
            category: _category,
            purchaseDate: now,
            storage: _storage,
          );
      days = estimate.estimatedDays;
    } on AiException {
      days = ExpirationEstimator.estimate(
        name: displayName,
        category: _category,
        storage: _storage,
      ).estimatedDays;
    }

    final item = InventoryItem(
      id: const Uuid().v4(),
      name: typed,
      normalizedName: displayName,
      imageUrl: await ImageResolver.instance.resolve(displayName),
      category: _category,
      quantity: double.tryParse(_qty.text.trim()) ?? 1,
      unit: _unit.trim().isEmpty ? 'piece' : _unit.trim(),
      storageLocation: _storage,
      purchaseDate: now,
      estimatedExpirationDate: ExpirationEstimator.expirationDate(
        purchaseDate: now,
        estimatedDays: days,
      ),
      manualStatus: _storage == StorageLocation.freezer
          ? FreshnessStatus.frozen
          : null,
    );

    ref.read(inventoryProvider.notifier).addItem(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${item.displayName} to your kitchen')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add item')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: FoodImage(
                name: _tidyName ?? _name.text,
                category: _category,
                size: 96,
                radius: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Chicken thighs',
                suffixIcon: _inferring
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onNameChanged,
              onEditingComplete: _infer,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
            if (_tidyName != null &&
                _tidyName!.toLowerCase() != _name.text.trim().toLowerCase()) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                      _inferring
                          ? Icons.auto_awesome
                          : Icons.check_circle_outline,
                      size: 15,
                      color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _inferring
                          ? 'Recognizing…'
                          : 'Recognized as “${_tidyName!}”',
                      style: text.labelMedium?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
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
                      _userTouchedUnit = true;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
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
                      _userTouchedCategory = true;
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
                      _userTouchedStorage = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: AppRadii.cardMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'We\'ll estimate a freshness window when you save.',
                      style: text.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Add to kitchen',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
