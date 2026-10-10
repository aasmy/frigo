import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_ai/core/services/images/ingredient_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => IngredientCatalog.instance.load());

  test('catalog loads', () {
    expect(IngredientCatalog.instance.isLoaded, isTrue);
    expect(IngredientCatalog.instance.match('Chicken Breast'), 'Chicken Breast');
  });

  test('matches are exact or a safe generalisation — never a different food', () {
    const cases = <String, String>{
      'Chicken Breast': 'Chicken Breast',
      'Boneless Chicken Thighs': 'Chicken Thighs',
      '2% Milk': 'Milk',
      'Large Eggs': 'Egg',
      'Greek Yogurt': 'Greek Yogurt',
      'Cheddar Cheese': 'Cheddar Cheese',
      'Bananas': 'Banana',
      'Baby Spinach': 'Spinach',
      'Roma Tomatoes': 'Tomato',
      'Yellow Onions': 'Yellow Onion',
      'Whole Wheat Bread': 'Bread',
      'Jasmine Rice': 'Jasmine Rice',
      'Penne Pasta': 'Penne Pasta',
      'Olive Oil': 'Olive Oil',
      'Ground Beef': 'Ground Beef',
      'Extra Lean Ground Beef': 'Ground Beef',
      'Organic Baby Spinach': 'Spinach',
      'Mini Yellow Potato': 'Potatoes',
      'Vine Tomatoes': 'Vine Tomatoes',
      'Peanut Butter': 'Peanut Butter',
      'Frozen Peas': 'Frozen Peas',
    };
    cases.forEach((query, expected) {
      expect(IngredientCatalog.instance.match(query), expected,
          reason: '"$query" should map to "$expected"');
    });
  });

  test('never substitutes a different food', () {
    // Regressions we specifically fixed: these must NOT match a wrong entry.
    expect(IngredientCatalog.instance.match('Salmon Fillet'), isNot('Anchovy Fillet'));
    expect(IngredientCatalog.instance.match('Dragon Fruit'), isNot('Dried Fruit'));
    expect(IngredientCatalog.instance.match('Mini Yellow Potato'),
        isNot('Russet Potato'));
    // Unknown foods return null so the UI can fall back, never a random image.
    expect(IngredientCatalog.instance.match('zzzz qqqq'), isNull);
  });

  test('is deterministic', () {
    for (var i = 0; i < 5; i++) {
      expect(IngredientCatalog.instance.imageUrl('Chicken Breast'),
          'https://www.themealdb.com/images/ingredients/Chicken%20Breast-Medium.png');
    }
  });
}
