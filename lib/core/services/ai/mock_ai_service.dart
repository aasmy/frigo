import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../models/enums.dart';
import '../../models/receipt.dart';
import '../../models/recipe.dart';
import '../../models/shelf_life_estimate.dart';
import '../../models/user_preferences.dart';
import '../recipes/recipe_api_service.dart';
import 'ai_service.dart';
import 'food_knowledge_base.dart';
import 'receipt_parser.dart';
import 'recipe_templates.dart';
import 'text_normalizer.dart';

/// Offline stand-in for the four AI tasks.
///
/// The receipt path is a real (small) understanding pipeline, not a text echo:
/// noise stripping → abbreviation expansion → brand extraction → fuzzy match
/// against a food knowledge base → category / unit / storage inference. Swap in
/// a server-backed [AiService] and nothing in the UI changes.
class MockAiService implements AiService {
  MockAiService({this.latency = const Duration(milliseconds: 1100)});

  final Duration latency;
  final _uuid = const Uuid();

  static const _massUnits = {'g', 'kg', 'mL', 'L'};

  // ---------------------------------------------------------------------------
  // AI Task A + B — receipt parsing & normalization
  // ---------------------------------------------------------------------------
  @override
  Future<Receipt> parseReceipt({
    required String ocrText,
    String? imagePath,
  }) async {
    await Future<void>.delayed(latency);

    if (ocrText.trim().split('\n').where((l) => l.trim().isNotEmpty).length < 3) {
      throw const AiException("We couldn't read enough of this receipt.");
    }

    final parsed = ReceiptParser(_uuid).parse(ocrText);

    if (!parsed.items.any((i) => i.isFood)) {
      throw const AiException(
          "We couldn't find any groceries on this receipt.");
    }

    return Receipt(
      id: _uuid.v4(),
      merchant: parsed.merchant,
      purchaseDate: parsed.date ?? DateTime.now(),
      currency: 'USD',
      items: parsed.items,
      createdAt: DateTime.now(),
      imagePath: imagePath,
      rawOcrText: ocrText,
    );
  }

  // ---------------------------------------------------------------------------
  // AI Task B — single-name normalization (Manual Add)
  // ---------------------------------------------------------------------------
  @override
  Future<NormalizationResult> normalizeName(String rawName) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final cleaned = ReceiptTextTools.stripNoise(rawName);
    final expanded =
        ReceiptTextTools.expand(ReceiptTextTools.tokenize(cleaned));
    final brand = ReceiptTextTools.extractBrand(cleaned.toLowerCase());

    final match = FoodKnowledgeBase.recognise(expanded);
    if (match != null) {
      final unit = _massUnits.contains(match.entry.unit)
          ? 'package'
          : match.entry.unit;
      return NormalizationResult(
        normalizedName: match.entry.name,
        category: match.entry.category,
        unit: unit,
        confidence: match.confidence,
        brand: brand,
      );
    }

    final category = FoodKnowledgeBase.guessCategory(expanded);
    final meaningful =
        expanded.where((t) => !kStopwords.contains(t)).toList();
    return NormalizationResult(
      normalizedName: ReceiptTextTools.titleCase(
          (meaningful.isEmpty ? expanded : meaningful).join(' ')),
      category: category,
      unit: _defaultUnitFor(category),
      confidence: 0.55,
      brand: brand,
    );
  }

  // ---------------------------------------------------------------------------
  // AI Task C — shelf-life estimation
  // ---------------------------------------------------------------------------
  @override
  Future<ShelfLifeEstimate> estimateShelfLife({
    required String productName,
    required FoodCategory category,
    required DateTime purchaseDate,
    required StorageLocation storage,
    bool opened = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (storage == StorageLocation.freezer) {
      return const ShelfLifeEstimate(
        estimatedDays: 120,
        confidence: EstimateConfidence.low,
        notes: 'Frozen items keep for months. Quality slowly declines.',
      );
    }

    // Prefer a knowledge-base match for the specific item.
    final expanded = ReceiptTextTools.expand(
        ReceiptTextTools.tokenize(productName));
    final match = FoodKnowledgeBase.recognise(expanded);

    int days;
    var confidence = EstimateConfidence.medium;
    var notes = '';

    if (match != null) {
      days = match.entry.shelfLifeDays;
      final n = productName.toLowerCase();
      if (n.contains('milk') && opened) days = min(days, 5);
      if (match.entry.category == FoodCategory.meat) {
        notes = 'Fresh raw protein — best cooked within a day or two.';
      } else if (match.entry.category == FoodCategory.produce && days <= 6) {
        notes = 'Leafy or soft produce goes fast.';
      } else if (match.entry.category == FoodCategory.grains ||
          match.entry.category == FoodCategory.pantry) {
        confidence = EstimateConfidence.low;
        notes = 'Shelf-stable — the package best-before is the real guide.';
      }
    } else {
      days = FoodKnowledgeBase.guessShelfLife(category, storage);
      confidence = EstimateConfidence.low;
    }

    if (storage == StorageLocation.pantry &&
        (category == FoodCategory.dairy || category == FoodCategory.meat)) {
      days = 1;
      notes = 'This really belongs in the fridge.';
    }
    if (storage == StorageLocation.counter &&
        category == FoodCategory.produce) {
      days = (days * 0.8).round();
    }

    return ShelfLifeEstimate(
        estimatedDays: max(1, days), confidence: confidence, notes: notes);
  }

  // ---------------------------------------------------------------------------
  // AI Task D — recipe generation
  // ---------------------------------------------------------------------------
  @override
  Future<List<Recipe>> generateRecipes({
    required List<RecipeRequestItem> inventory,
    List<String> prioritiseNames = const [],
    DietPreference diet = DietPreference.none,
    int? maxMinutes,
    List<String> excludedIngredients = const [],
    List<String> avoidTitles = const [],
  }) async {
    await Future<void>.delayed(latency);

    final invNames = inventory.map((i) => i.name.toLowerCase()).toList();
    final soon = <String>{
      ...prioritiseNames.map((e) => e.toLowerCase()),
      ...inventory
          .where((i) => (i.expiresInDays ?? 999) <= 2)
          .map((i) => i.name.toLowerCase()),
    };

    // Prefer real, varied recipes from TheMealDB built around the kitchen.
    if (AppConfig.networkImagesEnabled && inventory.isNotEmpty) {
      try {
        final api = await RecipeApiService.instance.discoverByInventory(
          inventoryNames: inventory.map((i) => i.name).toList(),
          prioritise: prioritiseNames,
          diet: diet,
          exclude: excludedIngredients,
          want: 12,
        );
        final fresh = api
            .where((r) => !avoidTitles
                .map((e) => e.toLowerCase())
                .contains(r.title.toLowerCase()))
            .where((r) => maxMinutes == null || r.cookingMinutes <= maxMinutes)
            .toList();
        if (fresh.length >= 3) return fresh;
      } catch (_) {
        // fall through to templates
      }
    }
    final excluded = excludedIngredients.map((e) => e.toLowerCase()).toList();
    final avoid = avoidTitles.map((e) => e.toLowerCase()).toSet();

    final scored = <_ScoredRecipe>[];
    for (final t in kRecipeTemplates) {
      if (diet != DietPreference.none && !t.diets.contains(diet)) continue;
      if (maxMinutes != null && t.minutes > maxMinutes) continue;
      if (avoid.contains(t.title.toLowerCase())) continue;
      if (t.allIngredients.any((ing) =>
          excluded.any((ex) => ing.contains(ex) || ex.contains(ing)))) {
        continue;
      }

      final ingredients = <RecipeIngredient>[];
      var coreHave = 0;
      var soonHits = 0;
      for (final ing in t.coreIngredients) {
        final have = _inventoryHas(invNames, ing);
        final useSoon = have && _matchesSoon(soon, ing);
        if (have) coreHave++;
        if (useSoon) soonHits++;
        ingredients.add(RecipeIngredient(
            name: ReceiptTextTools.titleCase(ing),
            available: have,
            useSoon: useSoon));
      }
      for (final ing in t.pantryIngredients) {
        final have = _inventoryHas(invNames, ing);
        final useSoon = have && _matchesSoon(soon, ing);
        if (useSoon) soonHits++;
        ingredients.add(RecipeIngredient(
            name: ReceiptTextTools.titleCase(ing),
            available: have,
            useSoon: useSoon));
      }

      if (coreHave == 0) continue;

      final availability =
          ingredients.where((i) => i.available).length / ingredients.length;
      final speedBonus = (60 - t.minutes).clamp(0, 60) / 60.0;
      final score = soonHits * 3.0 +
          coreHave * 2.0 +
          availability * 4.0 +
          speedBonus * 1.5;

      scored.add(_ScoredRecipe(
        score: score,
        recipe: Recipe(
          id: _uuid.v4(),
          title: t.title,
          description: t.description,
          cookingMinutes: t.minutes,
          heroEmoji: t.emoji,
          tags: t.tags,
          steps: t.steps,
          ingredients: ingredients,
        ),
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(5).toList();
    if (top.isEmpty) {
      throw const AiException(
        "Add a few more groceries and we'll find something to cook.",
        recoverable: false,
      );
    }

    // Template recipes render as an illustrated card. We deliberately don't
    // look up a stock photo by ingredient — it tends to show a different dish.
    return top.map((s) => s.recipe).toList();
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------
  bool _inventoryHas(List<String> invNames, String ingredient) {
    final ing = ingredient.toLowerCase();
    final ingWords = ing.split(' ').where((w) => w.length > 2).toList();
    for (final inv in invNames) {
      if (inv.contains(ing) || ing.contains(inv)) return true;
      final invWords = inv.split(' ').where((w) => w.length > 2).toSet();
      final shared = ingWords.where(invWords.contains).length;
      if (ingWords.isNotEmpty && shared >= ingWords.length) return true;
      if (shared >= 1 && ingWords.length == 1) return true;
    }
    return false;
  }

  bool _matchesSoon(Set<String> soon, String ingredient) {
    final ing = ingredient.toLowerCase();
    return soon.any((s) =>
        s.contains(ing) ||
        ing.contains(s) ||
        ing.split(' ').any((w) => w.length > 2 && s.contains(w)));
  }

  String _defaultUnitFor(FoodCategory category) => switch (category) {
        FoodCategory.meat => 'package',
        FoodCategory.dairy => 'piece',
        FoodCategory.produce => 'piece',
        FoodCategory.grains => 'package',
        FoodCategory.bakery => 'loaf',
        FoodCategory.frozen => 'bag',
        _ => 'piece',
      };
}

class _ScoredRecipe {
  _ScoredRecipe({
    required this.score,
    required this.recipe,
  });
  final double score;
  final Recipe recipe;
}
