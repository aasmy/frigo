import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_ai/core/services/images/ingredient_catalog.dart';

/// Names taken from real receipts + typical manual entries. Every one of these
/// should land on a *correct* catalog image, not a near-miss and not nothing.
/// Where a more specific catalog entry exists (Basmati Rice, Ground Cinnamon),
/// the matcher is expected to prefer it over the generic one.
const _expected = <String, String>{
  'PC Free Run Chicken Breast': 'Chicken Breast',
  'ORGANIC BANANAS': 'Banana',
  'Whole Milk 2L': 'Milk',
  'Large Brown Eggs': 'Egg',
  'Roma Tomatoes': 'Tomato',
  'Baby Spinach': 'Spinach',
  'Extra Virgin Olive Oil': 'Extra Virgin Olive Oil',
  'Basmati Rice 5kg': 'Basmati Rice',
  'Greek Yogurt Plain': 'Greek Yogurt',
  'Atlantic Salmon Fillet': 'Salmon',
  'Sweet Onions': 'Onion',
  'Russet Potatoes': 'Potatoes',
  'Sharp Cheddar Cheese': 'Cheddar Cheese',
  'Unsalted Butter': 'Butter',
  'Boneless Beef Sirloin': 'Beef',
  'Fresh Garlic Bulb': 'Garlic Bulb',
  'Whole Wheat Bread': 'Bread',
  'Avocados Bag of 5': 'Avocado',
  'Frozen Peas': 'Frozen Peas',
  'Ground Cinnamon': 'Ground Cinnamon',
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await IngredientCatalog.instance.load();
  });

  test('catalog resolves everyday grocery names to the right ingredient', () {
    final wrong = <String>[];
    for (final e in _expected.entries) {
      final got = IngredientCatalog.instance.match(e.key);
      if (got != e.value) wrong.add('${e.key}: expected ${e.value}, got $got');
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('unknown foods resolve to nothing rather than a wrong picture', () {
    for (final name in ['Zorblax Berries', 'Instant Lottery Ticket', 'Bag']) {
      expect(IngredientCatalog.instance.match(name), isNull, reason: name);
    }
  });
}
