// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../models/enums.dart';
import '../../models/receipt.dart';
import '../../models/receipt_item.dart';
import '../../models/recipe.dart';
import '../../models/shelf_life_estimate.dart';
import '../../models/user_preferences.dart';
import 'ai_health.dart';
import 'ai_service.dart';
import 'llm_client.dart';

/// Real AI implementation backed by Google Gemini.
///
/// Every method degrades gracefully: on a network error, quota error, timeout
/// or malformed response it delegates to [_fallback] (the offline mock), so the
/// app keeps working no matter what.
class LlmAiService implements AiService {
  LlmAiService({required LlmClient client, required AiService fallback})
      : _client = client,
        _fallback = fallback;

  final AiService _fallback;
  final LlmClient _client;
  final _uuid = const Uuid();

  bool get _live => AppConfig.aiEnabled;

  // ---------------------------------------------------------------------------
  // Task A + B — receipt parsing
  // ---------------------------------------------------------------------------
  static const _receiptPrompt = '''
You are a grocery-receipt parser. From the receipt IMAGE (and the OCR text as a
hint) extract ONLY the purchased product line items. IGNORE store name/address,
department headers, subtotals, taxes, totals, tender/payment, card numbers,
auth/ref numbers, loyalty points and any footer text.

Rules:
- Merge weight / discount / "N @ price" continuation lines into the item above.
- "name": 2-3 words, Title Case, expand abbreviations, no packaging codes.
  Drop colour / grade / size / "Organic" adjectives UNLESS they define the
  product (keep "Greek" in Greek Yogurt, keep "2%" in 2% Milk).
  Examples: "CHKN BRST BNLS" -> "Chicken Breast"; "TOV GH RED ORG" -> "Vine
  Tomatoes"; "CORN BICOLOR" -> "Corn"; "MANGO RED" -> "Mango".
- The LAST number on an item line is the PRICE, never a quantity.
- "quantity" defaults to 1. Only change it for an explicit count ("(3)",
  "3 @ 2.00" -> 3) or a weight. Convert lb->g; weights >= 1000 g -> kg.
- "is_food" is false for cleaning supplies, toiletries, pet food, general
  merchandise, bags, bottle deposits.
- "purchase_date": read the Date / DateTime line. It may be YY/MM/DD,
  DD/MM/YYYY or MM/DD/YYYY — pick the interpretation that is a real past date.

Return JSON ONLY:
{
  "merchant": string,
  "purchase_date": string|null,   // ISO yyyy-mm-dd
  "currency": string,
  "items": [{
    "raw_name": string,
    "name": string,
    "brand": string|null,
    "category": "Produce"|"Meat"|"Dairy"|"Grains"|"Bakery"|"Pantry"|"Snacks"|"Frozen"|"Beverages"|"Other",
    "quantity": number,
    "unit": "piece"|"g"|"kg"|"L"|"mL"|"bunch"|"bag"|"pack"|"loaf"|"can"|"bottle"|"package"|"bulb"|"head"|"block",
    "price": number|null,
    "is_food": boolean,
    "storage": "Fridge"|"Freezer"|"Pantry"|"Counter",
    "confidence": number
  }]
}''';

  @override
  Future<Receipt> parseReceipt({
    required String ocrText,
    String? imagePath,
  }) async {
    if (!_live) return _fallback.parseReceipt(ocrText: ocrText, imagePath: imagePath);
    try {
      // The photo is the *fallback*, not the default. On-device OCR is free and
      // instant, and a text-only call answers in ~10s where the same call with
      // the image attached takes 60-75s — for no better result when the OCR is
      // legible. We only pay for vision when OCR came back too thin to trust.
      List<int>? bytes;
      if (imagePath != null &&
          _client.supportsVision &&
          !_ocrLooksUsable(ocrText)) {
        final f = File(imagePath);
        if (f.existsSync()) {
          final b = await f.readAsBytes();
          if (b.lengthInBytes <= 6 * 1024 * 1024) bytes = b;
        }
      }

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await _client.generateJson(
        prompt: '$_receiptPrompt\n\nTODAY IS $today. A receipt is never dated '
            'in the future — use this to resolve two-digit years.'
            '\n\nOCR TEXT HINT:\n$ocrText',
        imageBytes: bytes,
        timeout:
            bytes == null ? AppConfig.aiTimeout : AppConfig.aiVisionTimeout,
      );
      final map = data as Map<String, dynamic>;
      final rawItems = (map['items'] as List?) ?? const [];

      final items = <ReceiptItem>[];
      for (final r in rawItems) {
        final m = r as Map<String, dynamic>;
        final name = (m['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        items.add(ReceiptItem(
          id: _uuid.v4(),
          rawName: (m['raw_name'] as String?)?.trim().isNotEmpty == true
              ? (m['raw_name'] as String).trim()
              : name,
          normalizedName: name,
          brand: (m['brand'] as String?)?.trim().isNotEmpty == true
              ? (m['brand'] as String).trim()
              : null,
          category: FoodCategory.fromAny(m['category'] as String?),
          quantity: _num(m['quantity'], 1),
          unit: (m['unit'] as String?)?.trim().isNotEmpty == true
              ? (m['unit'] as String).trim()
              : 'piece',
          price: m['price'] == null ? null : _num(m['price'], 0),
          isFood: m['is_food'] as bool? ?? true,
          confidence: _num(m['confidence'], 0.8).clamp(0, 1).toDouble(),
          storageLocation: StorageLocation.fromName(
              (m['storage'] as String?)?.toLowerCase()),
        ));
      }

      if (!items.any((i) => i.isFood)) {
        throw const LlmException('No food items returned.');
      }
      AiHealth.instance.recordSuccess(AiTask.receipt);

      return Receipt(
        id: _uuid.v4(),
        merchant: (map['merchant'] as String?)?.trim().isNotEmpty == true
            ? (map['merchant'] as String).trim()
            : 'Grocery store',
        purchaseDate: _date(map['purchase_date']) ?? DateTime.now(),
        currency: (map['currency'] as String?)?.trim() ?? 'USD',
        items: items,
        createdAt: DateTime.now(),
        imagePath: imagePath,
        rawOcrText: ocrText,
      );
    } catch (e) {
      AiHealth.instance.recordFailure(AiTask.receipt, e);
      return _fallback.parseReceipt(ocrText: ocrText, imagePath: imagePath);
    }
  }

  /// Whether on-device OCR produced enough of a receipt to skip the photo.
  ///
  /// A real receipt scan gives us many short lines, a good share of which carry
  /// digits (prices, weights, quantities). A blurry or failed scan gives a
  /// handful of noise lines — that is when the image is worth its latency.
  static bool _ocrLooksUsable(String ocrText) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 8) return false;
    final withDigits = lines.where((l) => RegExp(r'\d').hasMatch(l)).length;
    return withDigits >= 4 && ocrText.trim().length >= 120;
  }

  // ---------------------------------------------------------------------------
  // Task B — single-name normalization
  // ---------------------------------------------------------------------------
  @override
  Future<NormalizationResult> normalizeName(String rawName) async {
    if (!_live) return _fallback.normalizeName(rawName);
    try {
      final data = await _client.generateJson(
        prompt: '''
Normalize this grocery item name into a clean, human, 1-4 word name. Expand
abbreviations. Return JSON ONLY:
{"name": string, "brand": string|null,
 "category": "Produce"|"Meat"|"Dairy"|"Grains"|"Bakery"|"Pantry"|"Snacks"|"Frozen"|"Beverages"|"Other",
 "unit": "piece"|"g"|"kg"|"L"|"mL"|"bunch"|"bag"|"pack"|"loaf"|"can"|"bottle"|"package"|"bulb"|"head"|"block",
 "confidence": number}

INPUT: "$rawName"''',
        timeout: const Duration(seconds: 18),
      );
      final m = data as Map<String, dynamic>;
      final name = (m['name'] as String?)?.trim();
      if (name == null || name.isEmpty) throw const LlmException('no name');
      AiHealth.instance.recordSuccess(AiTask.normalize);
      return NormalizationResult(
        normalizedName: name,
        category: FoodCategory.fromAny(m['category'] as String?),
        unit: (m['unit'] as String?)?.trim().isNotEmpty == true
            ? (m['unit'] as String).trim()
            : 'piece',
        confidence: _num(m['confidence'], 0.85).clamp(0, 1).toDouble(),
        brand: (m['brand'] as String?)?.trim().isNotEmpty == true
            ? (m['brand'] as String).trim()
            : null,
      );
    } catch (e) {
      AiHealth.instance.recordFailure(AiTask.normalize, e);
      return _fallback.normalizeName(rawName);
    }
  }

  // ---------------------------------------------------------------------------
  // Task C — shelf life
  // ---------------------------------------------------------------------------
  @override
  Future<ShelfLifeEstimate> estimateShelfLife({
    required String productName,
    required FoodCategory category,
    required DateTime purchaseDate,
    required StorageLocation storage,
    bool opened = false,
  }) async {
    if (!_live) {
      return _fallback.estimateShelfLife(
        productName: productName,
        category: category,
        purchaseDate: purchaseDate,
        storage: storage,
        opened: opened,
      );
    }
    try {
      final data = await _client.generateJson(
        prompt: '''
Estimate how many days "$productName" (${category.label}) stays good when kept
in the ${storage.label}, bought today, opened=$opened. This is an ESTIMATE, not
a food-safety guarantee. Return JSON ONLY:
{"estimated_days": integer, "confidence": "low"|"medium"|"high", "notes": string}''',
        timeout: const Duration(seconds: 14),
      );
      final m = data as Map<String, dynamic>;
      AiHealth.instance.recordSuccess(AiTask.shelfLife);
      return ShelfLifeEstimate(
        estimatedDays: _num(m['estimated_days'], 7).round().clamp(1, 3650),
        confidence: switch ((m['confidence'] as String?)?.toLowerCase()) {
          'high' => EstimateConfidence.high,
          'low' => EstimateConfidence.low,
          _ => EstimateConfidence.medium,
        },
        notes: (m['notes'] as String?)?.trim() ?? '',
      );
    } catch (e) {
      AiHealth.instance.recordFailure(AiTask.shelfLife, e);
      return _fallback.estimateShelfLife(
        productName: productName,
        category: category,
        purchaseDate: purchaseDate,
        storage: storage,
        opened: opened,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Task D — recipe generation
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
    if (!_live || inventory.isEmpty) {
      return _fallback.generateRecipes(
        inventory: inventory,
        prioritiseNames: prioritiseNames,
        diet: diet,
        maxMinutes: maxMinutes,
        excludedIngredients: excludedIngredients,
        avoidTitles: avoidTitles,
      );
    }
    try {
      final inv = inventory.map((i) => i.toJson()).toList();
      final data = await _client.generateJson(
        prompt: '''
Suggest 4-5 realistic home recipes that mostly use THIS kitchen inventory,
prioritising ingredients expiring soon. Prefer quick meals.

INVENTORY (JSON): ${jsonEncode(inv)}
DIET: ${diet.label} ${_dietRule(diet)}
MAX COOKING TIME: ${maxMinutes ?? 'any'} minutes
AVOID INGREDIENTS: ${excludedIngredients.isEmpty ? 'none' : excludedIngredients.join(', ')}
DO NOT SUGGEST AGAIN: ${avoidTitles.isEmpty ? 'none' : avoidTitles.join(', ')}
USE-SOON PRIORITY: ${prioritiseNames.isEmpty ? 'none' : prioritiseNames.join(', ')}

Return JSON ONLY:
{"recipes": [{
  "title": string,
  "description": string,          // one sentence
  "cooking_minutes": integer,
  "hero_emoji": string,           // single emoji
  "tags": [string],               // e.g. ["High protein","Under 30 min"]
  "steps": [string],              // 3-6 short steps
  "ingredients": [{
    "name": string,
    "quantity_label": string|null,
    "have": boolean,              // true only if it is in the inventory above
    "use_soon": boolean
  }]
}]}''',
        timeout: const Duration(seconds: 40),
      );

      final invNames = inventory.map((i) => i.name.toLowerCase()).toList();
      final soon = {
        ...prioritiseNames.map((e) => e.toLowerCase()),
        ...inventory
            .where((i) => (i.expiresInDays ?? 999) <= 2)
            .map((i) => i.name.toLowerCase()),
      };

      final recipesJson = ((data as Map)['recipes'] as List?) ?? const [];
      final recipes = <Recipe>[];
      for (final r in recipesJson) {
        final m = r as Map<String, dynamic>;
        final ings = <RecipeIngredient>[];
        for (final ig in (m['ingredients'] as List? ?? const [])) {
          final im = ig as Map<String, dynamic>;
          final iname = (im['name'] as String?)?.trim() ?? '';
          if (iname.isEmpty) continue;
          // Trust Gemini, but verify against the real inventory.
          final have = (im['have'] as bool? ?? false) ||
              _inventoryHas(invNames, iname);
          final useSoon = have &&
              ((im['use_soon'] as bool? ?? false) || _matchesSoon(soon, iname));
          ings.add(RecipeIngredient(
            name: iname,
            quantityLabel: (im['quantity_label'] as String?)?.trim(),
            available: have,
            useSoon: useSoon,
          ));
        }
        if (ings.isEmpty) continue;
        recipes.add(Recipe(
          id: _uuid.v4(),
          title: (m['title'] as String?)?.trim() ?? 'Recipe',
          description: (m['description'] as String?)?.trim() ?? '',
          cookingMinutes: _num(m['cooking_minutes'], 25).round().clamp(3, 240),
          heroEmoji: (m['hero_emoji'] as String?)?.trim().isNotEmpty == true
              ? (m['hero_emoji'] as String).trim()
              : '🍽️',
          tags: ((m['tags'] as List?) ?? const []).cast<String>(),
          steps: ((m['steps'] as List?) ?? const []).cast<String>(),
          ingredients: ings,
        ));
      }

      if (recipes.isEmpty) throw const LlmException('no recipes');
      AiHealth.instance.recordSuccess(AiTask.recipes);

      // No photo lookup here on purpose: an ingredient-matched stock dish is
      // usually a *different* meal. These render as an illustrated card, while
      // recipes sourced from TheMealDB carry their own real photo.
      return recipes;
    } catch (e) {
      AiHealth.instance.recordFailure(AiTask.recipes, e);
      return _fallback.generateRecipes(
        inventory: inventory,
        prioritiseNames: prioritiseNames,
        diet: diet,
        maxMinutes: maxMinutes,
        excludedIngredients: excludedIngredients,
        avoidTitles: avoidTitles,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------------
  bool _inventoryHas(List<String> invNames, String ingredient) {
    final ing = ingredient.toLowerCase();
    final words = ing.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    for (final inv in invNames) {
      if (inv.contains(ing) || ing.contains(inv)) return true;
      final iw = inv.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      if (words.isNotEmpty && words.every(iw.contains)) return true;
      if (words.length == 1 && iw.contains(words.first)) return true;
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

  double _num(Object? v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  String _dietRule(DietPreference d) => switch (d) {
        DietPreference.halal =>
          '(strictly no pork, bacon, ham, lard, gelatin or ANY alcohol/wine/beer in the recipe)',
        DietPreference.vegetarian => '(no meat, poultry or fish)',
        DietPreference.vegan =>
          '(no meat, fish, dairy, egg or honey — fully plant-based)',
        DietPreference.pescatarian => '(no meat or poultry; fish is fine)',
        DietPreference.none => '',
      };

  DateTime? _date(Object? v) {
    if (v is! String || v.trim().isEmpty) return null;
    final d = DateTime.tryParse(v.trim());
    if (d == null) return null;
    if (d.isAfter(DateTime.now().add(const Duration(days: 2)))) return null;
    return d;
  }
}
