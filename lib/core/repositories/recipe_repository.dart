import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';
import '../models/user_preferences.dart';
import '../providers/service_providers.dart';
import '../services/ai/ai_service.dart';
import '../services/local_store.dart';
import '../services/recipes/recipe_api_service.dart';
import '../services/recipes/recipe_diet.dart';
import 'inventory_repository.dart';
import 'preferences_repository.dart';

/// Final safety net — drop anything that violates the user's diet / allergies
/// no matter which source produced it (Gemini, TheMealDB or a template).
List<Recipe> _filterDiet(
    List<Recipe> recipes, DietPreference diet, List<String> exclude) {
  if (diet == DietPreference.none && exclude.isEmpty) return recipes;
  return recipes.where((r) {
    final hay =
        '${r.title} ${r.tags.join(' ')} ${r.ingredients.map((e) => e.name).join(' ')}';
    return RecipeDiet.allows(hay, diet: diet, exclude: exclude);
  }).toList();
}

List<RecipeRequestItem> _toRequest(List<InventoryItem> items) => items
    .map((i) => RecipeRequestItem(
          name: i.displayName,
          quantity: i.quantity,
          unit: i.unit,
          expiresInDays: i.daysUntilExpiration,
        ))
    .toList();

/// Standard meal suggestions from the current kitchen + preferences.
final recipeSuggestionsProvider =
    FutureProvider.autoDispose<List<Recipe>>((ref) async {
  final inventory = ref.watch(inventoryProvider);
  final prefs = ref.watch(preferencesProvider);
  final ai = ref.watch(aiServiceProvider);

  if (inventory.isEmpty) return const [];

  final recipes = await ai.generateRecipes(
    inventory: _toRequest(inventory),
    diet: prefs.diet,
    maxMinutes: prefs.maxCookingTime.minutes,
    excludedIngredients: prefs.excludedIngredients,
  );
  return _filterDiet(recipes, prefs.diet, prefs.excludedIngredients);
});

/// "Discover more" — a bigger, browsable feed of real recipes from TheMealDB,
/// still respecting diet + allergies. Appends a fresh batch each call.
class DiscoverMoreNotifier extends AutoDisposeAsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() => _load([]);

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? [];
    state = const AsyncLoading<List<Recipe>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(current));
  }

  Future<List<Recipe>> _load(List<Recipe> existing) async {
    final prefs = ref.read(preferencesProvider);
    final inventory = ref.read(inventoryProvider);
    final seen = existing.map((e) => e.title.toLowerCase()).toSet();

    final batch = await RecipeApiService.instance.random(
      count: 8,
      diet: prefs.diet,
      exclude: prefs.excludedIngredients,
      inventoryNames: inventory.map((i) => i.displayName).toList(),
    );
    final merged = [
      ...existing,
      ...batch.where((r) => seen.add(r.title.toLowerCase())),
    ];
    return merged;
  }
}

final discoverMoreProvider =
    AutoDisposeAsyncNotifierProvider<DiscoverMoreNotifier, List<Recipe>>(
        DiscoverMoreNotifier.new);

/// Rescue Mode — recipes optimised to use up the items closest to expiring.
final rescueRecipesProvider =
    FutureProvider.autoDispose<RescueResult>((ref) async {
  final inventory = ref.watch(inventoryProvider);
  final prefs = ref.watch(preferencesProvider);
  final ai = ref.watch(aiServiceProvider);

  final atRisk = inventory
      .where((i) =>
          i.status == FreshnessStatus.useSoon ||
          i.status == FreshnessStatus.expired)
      .toList();

  if (atRisk.isEmpty) {
    return const RescueResult(atRisk: [], recipes: []);
  }

  final recipes = await ai.generateRecipes(
    inventory: _toRequest(inventory),
    prioritiseNames: atRisk.map((e) => e.displayName).toList(),
    diet: prefs.diet,
    excludedIngredients: prefs.excludedIngredients,
  );

  return RescueResult(
    atRisk: atRisk,
    recipes: _filterDiet(recipes, prefs.diet, prefs.excludedIngredients),
  );
});

class RescueResult {
  const RescueResult({required this.atRisk, required this.recipes});
  final List<InventoryItem> atRisk;
  final List<Recipe> recipes;
}

/// Persisted log of cooked recipes (recipes_history table).
class RecipeHistoryEntry {
  const RecipeHistoryEntry({
    required this.id,
    required this.recipeName,
    required this.ingredientsUsed,
    required this.cookedAt,
  });

  final String id;
  final String recipeName;
  final List<String> ingredientsUsed;
  final DateTime cookedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipe_name': recipeName,
        'ingredients_used': ingredientsUsed,
        'cooked_at': cookedAt.toIso8601String(),
      };

  factory RecipeHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RecipeHistoryEntry(
        id: json['id'] as String,
        recipeName: json['recipe_name'] as String,
        ingredientsUsed:
            (json['ingredients_used'] as List<dynamic>? ?? []).cast<String>(),
        cookedAt: DateTime.parse(json['cooked_at'] as String),
      );
}

class RecipeHistoryNotifier extends Notifier<List<RecipeHistoryEntry>> {
  late final LocalStore _store;
  final _uuid = const Uuid();

  @override
  List<RecipeHistoryEntry> build() {
    _store = ref.watch(localStoreProvider);
    return _store
        .readList(LocalStore.kRecipeHistory)
        .map(RecipeHistoryEntry.fromJson)
        .toList();
  }

  void record(Recipe recipe) {
    final entry = RecipeHistoryEntry(
      id: _uuid.v4(),
      recipeName: recipe.title,
      ingredientsUsed:
          recipe.availableIngredients.map((e) => e.name).toList(),
      cookedAt: DateTime.now(),
    );
    final next = [entry, ...state].take(50).toList();
    state = List.unmodifiable(next);
    _store.writeList(
        LocalStore.kRecipeHistory, next.map((e) => e.toJson()).toList());
  }

  /// Titles cooked in the last few days, so suggestions can avoid repeats.
  List<String> get recentTitles => state
      .where((e) => DateTime.now().difference(e.cookedAt).inDays < 4)
      .map((e) => e.recipeName)
      .toList();
}

final recipeHistoryProvider =
    NotifierProvider<RecipeHistoryNotifier, List<RecipeHistoryEntry>>(
        RecipeHistoryNotifier.new);
