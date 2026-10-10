/// A recipe ingredient plus how it maps onto the user's kitchen.
class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantityLabel,
    this.available = false,
    this.useSoon = false,
  });

  final String name;
  final String? quantityLabel;

  /// True when a matching inventory item was found.
  final bool available;

  /// True when the matching inventory item is expiring soon.
  final bool useSoon;

  RecipeIngredient copyWith({bool? available, bool? useSoon}) => RecipeIngredient(
        name: name,
        quantityLabel: quantityLabel,
        available: available ?? this.available,
        useSoon: useSoon ?? this.useSoon,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity_label': quantityLabel,
        'available': available,
        'use_soon': useSoon,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        name: json['name'] as String,
        quantityLabel: json['quantity_label'] as String?,
        available: json['available'] as bool? ?? false,
        useSoon: json['use_soon'] as bool? ?? false,
      );
}

/// An AI-generated meal suggestion, already reconciled against inventory.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.cookingMinutes,
    required this.ingredients,
    required this.steps,
    this.description = '',
    this.heroEmoji = '🍽️',
    this.tags = const [],
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final int cookingMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String heroEmoji;
  final List<String> tags;

  /// Best-effort photo URL from a free API; null → illustrated fallback.
  final String? imageUrl;

  Recipe withImage(String? url) => Recipe(
        id: id,
        title: title,
        cookingMinutes: cookingMinutes,
        ingredients: ingredients,
        steps: steps,
        description: description,
        heroEmoji: heroEmoji,
        tags: tags,
        imageUrl: url,
      );

  List<RecipeIngredient> get availableIngredients =>
      ingredients.where((i) => i.available).toList();

  List<RecipeIngredient> get missingIngredients =>
      ingredients.where((i) => !i.available).toList();

  List<RecipeIngredient> get useSoonIngredients =>
      ingredients.where((i) => i.useSoon).toList();

  double get availabilityRatio => ingredients.isEmpty
      ? 0
      : availableIngredients.length / ingredients.length;

  int get availabilityPercent => (availabilityRatio * 100).round();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cooking_minutes': cookingMinutes,
        'hero_emoji': heroEmoji,
        'tags': tags,
        'steps': steps,
        'image_url': imageUrl,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        cookingMinutes: (json['cooking_minutes'] as num?)?.toInt() ?? 20,
        heroEmoji: json['hero_emoji'] as String? ?? '🍽️',
        imageUrl: json['image_url'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        steps: (json['steps'] as List<dynamic>? ?? []).cast<String>(),
        ingredients: (json['ingredients'] as List<dynamic>? ?? [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
