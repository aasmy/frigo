import '../../models/user_preferences.dart';

/// A recipe blueprint the mock generator reconciles against inventory.
class RecipeTemplate {
  const RecipeTemplate({
    required this.title,
    required this.emoji,
    required this.minutes,
    required this.coreIngredients,
    required this.pantryIngredients,
    required this.steps,
    required this.description,
    this.tags = const [],
    this.diets = const {
      DietPreference.none,
    },
  });

  final String title;
  final String emoji;
  final int minutes;

  /// Ingredients that really define the dish. Missing these hurts the score.
  final List<String> coreIngredients;

  /// Staples we assume most kitchens have; lighter weight when missing.
  final List<String> pantryIngredients;
  final List<String> steps;
  final String description;
  final List<String> tags;
  final Set<DietPreference> diets;

  List<String> get allIngredients => [...coreIngredients, ...pantryIngredients];
}

const List<RecipeTemplate> kRecipeTemplates = [
  RecipeTemplate(
    title: 'Chicken Avocado Rice Bowl',
    emoji: '🥑',
    minutes: 22,
    description: 'A fast, balanced bowl that uses up ripe avocado and chicken.',
    coreIngredients: ['chicken breast', 'avocado', 'rice'],
    pantryIngredients: ['onion', 'garlic', 'olive oil', 'salt', 'pepper', 'lime'],
    tags: ['High protein', 'One bowl'],
    diets: {DietPreference.none, DietPreference.halal, DietPreference.pescatarian},
    steps: [
      'Cook the rice and set aside.',
      'Season and sear the chicken breast until cooked through, then slice.',
      'Soften the diced onion and garlic in olive oil.',
      'Build the bowl: rice, chicken, sliced avocado.',
      'Finish with salt, pepper and a squeeze of lime.',
    ],
  ),
  RecipeTemplate(
    title: 'Creamy Chicken Pasta',
    emoji: '🍝',
    minutes: 25,
    description: 'Weeknight pasta that leans on chicken and whatever cheese you have.',
    coreIngredients: ['chicken breast', 'pasta', 'cheese'],
    pantryIngredients: ['garlic', 'onion', 'olive oil', 'milk', 'salt', 'pepper'],
    tags: ['Comfort', 'Family'],
    diets: {DietPreference.none, DietPreference.halal},
    steps: [
      'Boil the pasta until al dente; reserve a cup of pasta water.',
      'Sear diced chicken with garlic and onion.',
      'Add milk and grated cheese, stir into a light sauce.',
      'Toss in the pasta, loosening with pasta water as needed.',
      'Season and serve.',
    ],
  ),
  RecipeTemplate(
    title: 'Vegetable Omelette',
    emoji: '🍳',
    minutes: 12,
    description: 'Three-egg omelette to clear out fridge vegetables.',
    coreIngredients: ['eggs', 'spinach', 'cheese'],
    pantryIngredients: ['onion', 'tomatoes', 'butter', 'salt', 'pepper'],
    tags: ['Under 15 min', 'Vegetarian'],
    diets: {
      DietPreference.none,
      DietPreference.vegetarian,
      DietPreference.halal,
      DietPreference.pescatarian,
    },
    steps: [
      'Whisk the eggs with a pinch of salt.',
      'Wilt spinach and onion in butter.',
      'Pour in the eggs, scatter cheese and diced tomato.',
      'Fold once the base is set, slide onto a plate.',
    ],
  ),
  RecipeTemplate(
    title: 'Avocado Egg Toast',
    emoji: '🥑',
    minutes: 8,
    description: 'The classic — good for very ripe avocados.',
    coreIngredients: ['bread', 'avocado', 'eggs'],
    pantryIngredients: ['salt', 'pepper', 'lemon', 'olive oil'],
    tags: ['Under 15 min', 'Breakfast'],
    diets: {
      DietPreference.none,
      DietPreference.vegetarian,
      DietPreference.halal,
      DietPreference.pescatarian,
    },
    steps: [
      'Toast the bread.',
      'Mash avocado with lemon, salt and pepper.',
      'Fry or poach the eggs.',
      'Spread avocado on toast, top with egg.',
    ],
  ),
  RecipeTemplate(
    title: 'One-Pan Chicken & Vegetables',
    emoji: '🍗',
    minutes: 35,
    description: 'Sheet-pan dinner that flexes around whatever vegetables need using.',
    coreIngredients: ['chicken thighs', 'carrots', 'onion'],
    pantryIngredients: ['garlic', 'olive oil', 'salt', 'pepper'],
    tags: ['Hands off', 'Family'],
    diets: {DietPreference.none, DietPreference.halal},
    steps: [
      'Heat the oven to 220°C / 425°F.',
      'Toss chopped carrots and onion with olive oil, salt and pepper.',
      'Nestle in the chicken thighs, scatter smashed garlic.',
      'Roast 30–35 minutes until the chicken is cooked and vegetables caramelised.',
    ],
  ),
  RecipeTemplate(
    title: 'Tomato & Spinach Pasta',
    emoji: '🍅',
    minutes: 20,
    description: 'Meatless pasta built on crushed tomatoes and greens.',
    coreIngredients: ['pasta', 'tomatoes', 'spinach'],
    pantryIngredients: ['garlic', 'onion', 'olive oil', 'salt', 'pepper', 'cheese'],
    tags: ['Vegetarian', 'Pantry'],
    diets: {
      DietPreference.none,
      DietPreference.vegetarian,
      DietPreference.vegan,
      DietPreference.halal,
      DietPreference.pescatarian,
    },
    steps: [
      'Cook the pasta.',
      'Simmer garlic and onion in olive oil, add tomatoes.',
      'Stir spinach through until wilted.',
      'Toss with pasta, season, finish with cheese if using.',
    ],
  ),
  RecipeTemplate(
    title: 'Greek Yogurt Breakfast Bowl',
    emoji: '🥣',
    minutes: 5,
    description: 'Uses up Greek yogurt before it turns.',
    coreIngredients: ['greek yogurt', 'bananas'],
    pantryIngredients: ['apples', 'olive oil'],
    tags: ['Under 15 min', 'Breakfast', 'No cook'],
    diets: {
      DietPreference.none,
      DietPreference.vegetarian,
      DietPreference.halal,
      DietPreference.pescatarian,
    },
    steps: [
      'Spoon Greek yogurt into a bowl.',
      'Top with sliced banana and apple.',
      'Add any nuts, seeds or honey you have on hand.',
    ],
  ),
  RecipeTemplate(
    title: 'Salmon Rice Bowl',
    emoji: '🍣',
    minutes: 25,
    description: 'Quick seared salmon over rice with a fridge-vegetable pile.',
    coreIngredients: ['salmon', 'rice', 'spinach'],
    pantryIngredients: ['garlic', 'olive oil', 'salt', 'pepper', 'lime'],
    tags: ['High protein', 'Pescatarian'],
    diets: {DietPreference.none, DietPreference.pescatarian},
    steps: [
      'Cook the rice.',
      'Season the salmon and sear skin-side down until just cooked.',
      'Wilt spinach with garlic.',
      'Plate rice, greens and salmon; finish with lime.',
    ],
  ),
];
