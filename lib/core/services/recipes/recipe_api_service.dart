import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../models/recipe.dart';
import '../../models/user_preferences.dart';
import 'recipe_diet.dart';

/// Real recipe data from TheMealDB (free, no key). Used to give the Recipes tab
/// far more variety than the built-in templates, and as a "discover more" feed.
class RecipeApiService {
  RecipeApiService._();
  static final RecipeApiService instance = RecipeApiService._();

  final _http = http.Client();
  final _uuid = const Uuid();
  static const _base = 'https://www.themealdb.com/api/json/v1/1';

  final Map<String, Recipe> _lookupCache = {};

  /// Recipes built around what the user actually has, expiring items first.
  Future<List<Recipe>> discoverByInventory({
    required List<String> inventoryNames,
    List<String> prioritise = const [],
    DietPreference diet = DietPreference.none,
    List<String> exclude = const [],
    int want = 12,
  }) async {
    final seeds = <String>[
      ...prioritise,
      ...inventoryNames,
    ].map(_ingredientKey).where((s) => s.isNotEmpty).toSet().take(7).toList();
    if (seeds.isEmpty) return const [];

    final ids = <String>{};
    for (final seed in seeds) {
      try {
        final res = await _http
            .get(Uri.parse('$_base/filter.php?i=$seed'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode != 200) continue;
        final meals = (jsonDecode(res.body) as Map)['meals'];
        if (meals is List) {
          for (final m in meals.take(8)) {
            final id = (m as Map)['idMeal'];
            if (id is String) ids.add(id);
          }
        }
      } catch (e) {
        debugPrint('themealdb filter($seed) failed: $e');
      }
      if (ids.length > want * 3) break;
    }

    final invLower = inventoryNames.map((e) => e.toLowerCase()).toList();
    final soon = prioritise.map((e) => e.toLowerCase()).toSet();
    final recipes = <Recipe>[];
    for (final id in ids) {
      final r = await _lookup(id, invLower, soon);
      if (r == null) continue;
      if (!RecipeDiet.allows(_haystack(r), diet: diet, exclude: exclude)) {
        continue;
      }
      recipes.add(r);
      if (recipes.length >= want * 2) break;
    }

    recipes.sort((a, b) => b.availabilityRatio.compareTo(a.availabilityRatio));
    return recipes.take(want).toList();
  }

  /// A random grab-bag for the "discover more" section.
  Future<List<Recipe>> random({
    int count = 8,
    DietPreference diet = DietPreference.none,
    List<String> exclude = const [],
    List<String> inventoryNames = const [],
  }) async {
    final invLower = inventoryNames.map((e) => e.toLowerCase()).toList();
    final out = <Recipe>[];
    var tries = 0;
    while (out.length < count && tries < count * 4) {
      tries++;
      try {
        final res = await _http
            .get(Uri.parse('$_base/random.php'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode != 200) continue;
        final meals = (jsonDecode(res.body) as Map)['meals'];
        if (meals is! List || meals.isEmpty) continue;
        final r = _parseMeal(meals.first as Map<String, dynamic>, invLower, {});
        if (r == null || out.any((e) => e.title == r.title)) continue;
        if (!RecipeDiet.allows(_haystack(r), diet: diet, exclude: exclude)) {
          continue;
        }
        out.add(r);
      } catch (e) {
        debugPrint('themealdb random failed: $e');
      }
    }
    return out;
  }

  // --- internals ------------------------------------------------------------
  Future<Recipe?> _lookup(
      String id, List<String> invLower, Set<String> soon) async {
    if (_lookupCache.containsKey(id)) {
      return _reconcile(_lookupCache[id]!, invLower, soon);
    }
    try {
      final res = await _http
          .get(Uri.parse('$_base/lookup.php?i=$id'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final meals = (jsonDecode(res.body) as Map)['meals'];
      if (meals is! List || meals.isEmpty) return null;
      final r = _parseMeal(meals.first as Map<String, dynamic>, invLower, soon);
      if (r != null) _lookupCache[id] = r;
      return r;
    } catch (e) {
      debugPrint('themealdb lookup($id) failed: $e');
      return null;
    }
  }

  Recipe _reconcile(Recipe r, List<String> invLower, Set<String> soon) {
    final ings = r.ingredients.map((i) {
      final have = _has(invLower, i.name);
      return i.copyWith(
        available: have,
        useSoon: have && soon.any((s) => i.name.toLowerCase().contains(s)),
      );
    }).toList();
    return Recipe(
      id: r.id,
      title: r.title,
      description: r.description,
      cookingMinutes: r.cookingMinutes,
      heroEmoji: r.heroEmoji,
      tags: r.tags,
      steps: r.steps,
      ingredients: ings,
      imageUrl: r.imageUrl,
    );
  }

  Recipe? _parseMeal(
      Map<String, dynamic> m, List<String> invLower, Set<String> soon) {
    final title = (m['strMeal'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final ingredients = <RecipeIngredient>[];
    for (var i = 1; i <= 20; i++) {
      final name = (m['strIngredient$i'] as String?)?.trim() ?? '';
      if (name.isEmpty || name.toLowerCase() == 'null') continue;
      final measure = (m['strMeasure$i'] as String?)?.trim();
      final have = _has(invLower, name);
      ingredients.add(RecipeIngredient(
        name: name,
        quantityLabel:
            (measure == null || measure.isEmpty || measure == ' ') ? null : measure,
        available: have,
        useSoon: have && soon.any((s) => name.toLowerCase().contains(s)),
      ));
    }
    if (ingredients.isEmpty) return null;

    final tags = <String>{
      if ((m['strCategory'] as String?)?.isNotEmpty == true) m['strCategory'],
      if ((m['strArea'] as String?)?.isNotEmpty == true) m['strArea'],
      ...((m['strTags'] as String?) ?? '').split(',').map((e) => e.trim()),
    }.where((e) => e.isNotEmpty).take(4).cast<String>().toList();

    final instr = (m['strInstructions'] as String?) ?? '';
    return Recipe(
      id: _uuid.v4(),
      title: title,
      description: (m['strArea'] as String?)?.isNotEmpty == true
          ? '${m['strArea']} · ${m['strCategory'] ?? 'recipe'}'
          : (m['strCategory'] as String? ?? ''),
      cookingMinutes: _estimateMinutes(instr, m['strCategory'] as String?),
      heroEmoji: _emojiFor(m['strCategory'] as String?),
      tags: tags,
      steps: _steps(instr),
      ingredients: ingredients,
      imageUrl: (m['strMealThumb'] as String?),
    );
  }

  String _haystack(Recipe r) =>
      '${r.title} ${r.tags.join(' ')} ${r.ingredients.map((e) => e.name).join(' ')}'
          .toLowerCase();

  bool _has(List<String> invLower, String ingredient) {
    final ing = ingredient.toLowerCase();
    final words = ing.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    for (final inv in invLower) {
      if (inv.contains(ing) || ing.contains(inv)) return true;
      final iw = inv.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
      if (words.isNotEmpty && words.every(iw.contains)) return true;
      if (words.length == 1 && iw.contains(words.first)) return true;
    }
    return false;
  }

  List<String> _steps(String instr) {
    var parts = instr
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      parts = instr
          .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])'))
          .map((s) => s.trim())
          .where((s) => s.length > 3)
          .toList();
    }
    return parts
        .map((s) => s.replaceFirst(RegExp(r'^(step\s*)?\d+[\.\):]\s*',
            caseSensitive: false), ''))
        .take(10)
        .toList();
  }

  int _estimateMinutes(String instr, String? category) {
    final s = instr.toLowerCase();
    if (s.contains('overnight') || s.contains('slow cook') ||
        s.contains('slow-cook')) {
      return 240;
    }
    var total = 0;
    for (final m
        in RegExp(r'(\d+)\s*(hour|hr|minute|min)').allMatches(s).take(4)) {
      final n = int.tryParse(m.group(1)!) ?? 0;
      total += m.group(2)!.startsWith('h') ? n * 60 : n;
    }
    if (total > 0) return total.clamp(5, 240);
    return switch (category?.toLowerCase()) {
      'breakfast' || 'side' || 'starter' || 'dessert' => 20,
      'beef' || 'lamb' || 'pork' => 60,
      _ => 35,
    };
  }

  String _emojiFor(String? category) => switch (category?.toLowerCase()) {
        'beef' => '🥩',
        'chicken' => '🍗',
        'pork' => '🥓',
        'lamb' || 'goat' => '🍖',
        'seafood' => '🐟',
        'pasta' => '🍝',
        'vegetarian' || 'vegan' => '🥗',
        'dessert' => '🍰',
        'breakfast' => '🍳',
        'side' || 'starter' => '🥘',
        _ => '🍽️',
      };

  static const _stop = {
    'the', 'and', 'with', 'fresh', 'organic', 'large', 'small', 'boneless',
    'skinless', 'of', 'a', 'ground', 'whole', 'baby', 'sweet', 'red', 'green',
    'yellow', 'mini', 'jumbo', 'can', 'canned', 'jar', 'bag', 'pack',
  };

  String _ingredientKey(String name) {
    final words = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stop.contains(w))
        .toList();
    if (words.isEmpty) return '';
    // TheMealDB expects underscores for multi-word ingredients.
    return words.take(2).join('_');
  }

  /// Test hook.
  String debugIngredientKey(String n) => _ingredientKey(n);
}
