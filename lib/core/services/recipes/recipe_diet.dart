import '../../models/user_preferences.dart';

/// Shared diet / allergy filter applied to every recipe list before it reaches
/// the UI — Gemini output, TheMealDB results and the built-in templates all go
/// through this so a preference is never silently ignored.
class RecipeDiet {
  const RecipeDiet._();

  static const _landMeat = [
    'pork', 'bacon', 'ham', 'gammon', 'prosciutto', 'pancetta', 'lardon',
    'salami', 'pepperoni', 'chorizo', 'sausage', 'chicken', 'beef', 'steak',
    'mince', 'meatball', 'lamb', 'mutton', 'veal', 'goat', 'turkey', 'duck',
    'venison', 'rabbit', 'liver', 'kidney', 'oxtail', 'brisket',
  ];

  static const _seafood = [
    'fish', 'salmon', 'tuna', 'cod', 'haddock', 'tilapia', 'pollock', 'trout',
    'mackerel', 'sardine', 'anchov', 'prawn', 'shrimp', 'crab', 'lobster',
    'mussel', 'clam', 'oyster', 'scallop', 'squid', 'octopus', 'calamari',
    'caviar', 'roe',
  ];

  static const _animalProduce = [
    'milk', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'egg', 'honey',
    'ghee', 'mayonnaise', 'gelatin', 'gelatine', 'lard', 'custard', 'parmesan',
    'mozzarella', 'ricotta', 'feta', 'paneer', 'buttermilk', 'whey', 'casein',
  ];

  static const _nonHalal = [
    'pork', 'bacon', 'ham', 'gammon', 'lard', 'prosciutto', 'pancetta',
    'chorizo', 'pepperoni', 'salami', 'gelatin', 'gelatine',
    // alcohol
    'wine', 'beer', 'rum', 'brandy', 'sherry', 'vodka', 'whisky', 'whiskey',
    'bourbon', 'marsala', 'cognac', 'liqueur', 'vermouth', 'sake', 'mirin',
    'ale', 'lager', 'prosecco', 'champagne', 'kahlua', 'amaretto', 'cointreau',
    'triple sec', 'grand marnier', 'kirsch', 'schnapps', 'baileys',
  ];

  /// [haystack] should be title + category + all ingredient names, lower-cased.
  static bool allows(
    String haystack, {
    required DietPreference diet,
    List<String> exclude = const [],
  }) {
    final h = haystack.toLowerCase();
    for (final e in exclude) {
      final t = e.trim().toLowerCase();
      if (t.isNotEmpty && h.contains(t)) return false;
    }
    bool any(List<String> words) => words.any(h.contains);

    return switch (diet) {
      DietPreference.none => true,
      DietPreference.halal => !any(_nonHalal),
      DietPreference.pescatarian => !any(_landMeat),
      DietPreference.vegetarian => !any(_landMeat) && !any(_seafood),
      DietPreference.vegan =>
        !any(_landMeat) && !any(_seafood) && !any(_animalProduce),
    };
  }
}
