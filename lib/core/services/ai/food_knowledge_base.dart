import 'dart:math';

import '../../models/enums.dart';
import 'text_normalizer.dart';

/// One recognised grocery item and how it behaves in a kitchen.
class FoodEntry {
  const FoodEntry(
    this.name,
    this.category,
    this.unit,
    this.storage,
    this.shelfLifeDays,
    this.keywords,
  );

  final String name;
  final FoodCategory category;
  final String unit;
  final StorageLocation storage;
  final int shelfLifeDays;

  /// Lowercase match anchors; multi-word phrases score higher when fully hit.
  final List<String> keywords;
}

class FoodMatch {
  const FoodMatch(this.entry, this.confidence);
  final FoodEntry entry;
  final double confidence;
}

/// The mock "understanding" layer: recognise a real food from expanded receipt
/// tokens rather than echoing the raw text. A server LLM would replace this
/// method while keeping the same [FoodMatch] shape.
class FoodKnowledgeBase {
  const FoodKnowledgeBase._();

  static FoodMatch? recognise(List<String> expandedTokens) {
    if (expandedTokens.isEmpty) return null;
    final tokens = expandedTokens.toSet();

    FoodEntry? best;
    double bestScore = 0;
    int bestPhraseLen = 0;

    for (final entry in _foods) {
      double score = 0;
      int phraseLen = 0;
      for (final kw in entry.keywords) {
        final parts = kw.split(' ');
        final hits =
            parts.where((p) => ReceiptTextTools.fuzzyContains(tokens, p)).length;
        if (hits == parts.length) {
          score += 3.0 * parts.length;
          phraseLen = max(phraseLen, parts.length);
        } else if (hits > 0) {
          score += 0.8 * hits;
        }
      }
      if (score > bestScore ||
          (score == bestScore && phraseLen > bestPhraseLen)) {
        best = entry;
        bestScore = score;
        bestPhraseLen = phraseLen;
      }
    }

    if (best == null || bestScore < 2.4) return null;
    final confidence = (0.55 + bestScore * 0.055).clamp(0.5, 0.97).toDouble();
    return FoodMatch(best, confidence);
  }

  /// Fallback category guess when nothing in the KB matches.
  static FoodCategory guessCategory(Iterable<String> tokens) {
    bool has(List<String> xs) =>
        xs.any((x) => tokens.any((t) => t == x || t.contains(x)));
    if (has(['chicken', 'beef', 'pork', 'steak', 'sausage', 'bacon', 'turkey',
        'salmon', 'fish', 'shrimp', 'ham', 'meat', 'lamb'])) {
      return FoodCategory.meat;
    }
    if (has(['milk', 'cheese', 'yogurt', 'cream', 'butter', 'egg', 'margarine'])) {
      return FoodCategory.dairy;
    }
    if (has(['apple', 'banana', 'lettuce', 'tomato', 'onion', 'pepper', 'carrot',
        'fruit', 'vegetable', 'spinach', 'kale', 'cucumber', 'berry', 'grape',
        'lemon', 'lime', 'orange', 'potato', 'garlic', 'broccoli', 'celery',
        'avocado', 'mushroom'])) {
      return FoodCategory.produce;
    }
    if (has(['rice', 'pasta', 'bread', 'flour', 'oat', 'cereal', 'noodle',
        'tortilla', 'bagel', 'spaghetti'])) {
      return FoodCategory.grains;
    }
    if (has(['chip', 'cookie', 'cracker', 'candy', 'snack', 'granola', 'popcorn',
        'chocolate', 'pretzel'])) {
      return FoodCategory.snacks;
    }
    if (has(['frozen', 'pizza', 'nugget', 'fries'])) return FoodCategory.frozen;
    return FoodCategory.pantry;
  }

  static const List<FoodEntry> _foods = [
    // ---- Meat & seafood ----
    FoodEntry('Chicken Breast', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['chicken breast', 'chicken']),
    FoodEntry('Boneless Chicken Thighs', FoodCategory.meat, 'g',
        StorageLocation.fridge, 3, ['chicken thigh', 'boneless thigh']),
    FoodEntry('Chicken Drumsticks', FoodCategory.meat, 'g', StorageLocation.fridge,
        3, ['chicken drumstick', 'drumstick']),
    FoodEntry('Whole Chicken', FoodCategory.meat, 'piece', StorageLocation.fridge,
        2, ['whole chicken']),
    FoodEntry('Rotisserie Chicken', FoodCategory.meat, 'piece',
        StorageLocation.fridge, 3, ['rotisserie chicken', 'rotisserie']),
    FoodEntry('Ground Beef', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['ground beef', 'lean ground', 'extra lean beef', 'medium ground beef']),
    FoodEntry('Beef Steak', FoodCategory.meat, 'g', StorageLocation.fridge, 4,
        ['beef steak', 'sirloin', 'ribeye', 'striploin']),
    FoodEntry('Pork Chops', FoodCategory.meat, 'g', StorageLocation.fridge, 3,
        ['pork chop', 'pork loin']),
    FoodEntry('Ground Pork', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['ground pork']),
    FoodEntry('Bacon', FoodCategory.meat, 'package', StorageLocation.fridge, 10,
        ['bacon']),
    FoodEntry('Breakfast Sausage', FoodCategory.meat, 'package',
        StorageLocation.fridge, 5, ['sausage']),
    FoodEntry('Sliced Ham', FoodCategory.meat, 'package', StorageLocation.fridge,
        7, ['ham']),
    FoodEntry('Ground Turkey', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['ground turkey', 'turkey']),
    FoodEntry('Salmon Fillet', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['salmon fillet', 'salmon']),
    FoodEntry('Shrimp', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['shrimp', 'prawn']),
    FoodEntry('Tilapia Fillet', FoodCategory.meat, 'g', StorageLocation.fridge, 2,
        ['tilapia']),
    FoodEntry('Canned Tuna', FoodCategory.pantry, 'can', StorageLocation.pantry,
        720, ['canned tuna', 'tuna']),

    // ---- Dairy & eggs ----
    FoodEntry('2% Milk', FoodCategory.dairy, 'L', StorageLocation.fridge, 9,
        ['milk']),
    FoodEntry('Whole Milk', FoodCategory.dairy, 'L', StorageLocation.fridge, 9,
        ['whole milk', 'homo milk']),
    FoodEntry('Almond Milk', FoodCategory.dairy, 'L', StorageLocation.fridge, 10,
        ['almond milk', 'oat milk', 'soy milk']),
    FoodEntry('Large Eggs', FoodCategory.dairy, 'piece', StorageLocation.fridge,
        28, ['egg', 'eggs', 'large egg', 'dozen egg']),
    FoodEntry('Greek Yogurt', FoodCategory.dairy, 'g', StorageLocation.fridge, 14,
        ['greek yogurt']),
    FoodEntry('Yogurt', FoodCategory.dairy, 'g', StorageLocation.fridge, 16,
        ['yogurt']),
    FoodEntry('Cheddar Cheese', FoodCategory.dairy, 'block', StorageLocation.fridge,
        21, ['cheddar cheese', 'cheddar', 'marble cheese']),
    FoodEntry('Mozzarella', FoodCategory.dairy, 'block', StorageLocation.fridge,
        16, ['mozzarella']),
    FoodEntry('Shredded Cheese', FoodCategory.dairy, 'bag', StorageLocation.fridge,
        18, ['shredded cheese', 'shredded mozzarella', 'tex mex']),
    FoodEntry('Parmesan', FoodCategory.dairy, 'piece', StorageLocation.fridge, 60,
        ['parmesan']),
    FoodEntry('Cream Cheese', FoodCategory.dairy, 'package',
        StorageLocation.fridge, 21, ['cream cheese']),
    FoodEntry('Butter', FoodCategory.dairy, 'g', StorageLocation.fridge, 45,
        ['butter']),
    FoodEntry('Sour Cream', FoodCategory.dairy, 'g', StorageLocation.fridge, 14,
        ['sour cream']),
    FoodEntry('Heavy Cream', FoodCategory.dairy, 'mL', StorageLocation.fridge, 10,
        ['heavy cream', 'whipping cream']),

    // ---- Produce ----
    FoodEntry('Bananas', FoodCategory.produce, 'bunch', StorageLocation.counter, 6,
        ['banana']),
    FoodEntry('Apples', FoodCategory.produce, 'piece', StorageLocation.fridge, 21,
        ['apple', 'gala apple', 'fuji apple', 'ambrosia apple']),
    FoodEntry('Avocado', FoodCategory.produce, 'piece', StorageLocation.counter, 4,
        ['avocado', 'hass avocado']),
    FoodEntry('Baby Spinach', FoodCategory.produce, 'bag', StorageLocation.fridge,
        5, ['spinach']),
    FoodEntry('Spring Mix', FoodCategory.produce, 'bag', StorageLocation.fridge, 5,
        ['spring mix', 'mixed greens', 'salad blend']),
    FoodEntry('Romaine Lettuce', FoodCategory.produce, 'head',
        StorageLocation.fridge, 8, ['romaine', 'lettuce']),
    FoodEntry('Roma Tomatoes', FoodCategory.produce, 'piece',
        StorageLocation.counter, 8, ['roma tomato', 'grape tomato']),
    FoodEntry('Tomatoes', FoodCategory.produce, 'piece', StorageLocation.counter,
        8, ['tomato', 'tomatoes', 'tomato vine', 'vine tomato']),
    FoodEntry('Sweet Corn', FoodCategory.produce, 'piece', StorageLocation.fridge,
        5, ['corn', 'sweetcorn', 'corn cob']),
    FoodEntry('Mango', FoodCategory.produce, 'piece', StorageLocation.counter, 6,
        ['mango']),
    FoodEntry('Green Beans', FoodCategory.produce, 'bag', StorageLocation.fridge,
        7, ['green bean', 'string bean']),
    FoodEntry('Bell Peppers', FoodCategory.produce, 'piece',
        StorageLocation.fridge, 10, ['bell pepper', 'sweet pepper']),
    FoodEntry('Yellow Onions', FoodCategory.produce, 'piece',
        StorageLocation.pantry, 30, ['yellow onion', 'onion', 'cooking onion']),
    FoodEntry('Green Onions', FoodCategory.produce, 'bunch',
        StorageLocation.fridge, 7, ['green onion', 'scallion']),
    FoodEntry('Garlic', FoodCategory.produce, 'bulb', StorageLocation.pantry, 40,
        ['garlic']),
    FoodEntry('Carrots', FoodCategory.produce, 'bag', StorageLocation.fridge, 21,
        ['carrot']),
    FoodEntry('Broccoli', FoodCategory.produce, 'head', StorageLocation.fridge, 7,
        ['broccoli']),
    FoodEntry('Bell Pepper', FoodCategory.produce, 'piece', StorageLocation.fridge,
        10, ['bell pepper', 'pepper', 'red pepper', 'green pepper']),
    FoodEntry('Cucumber', FoodCategory.produce, 'piece', StorageLocation.fridge, 7,
        ['cucumber']),
    FoodEntry('Mushrooms', FoodCategory.produce, 'package', StorageLocation.fridge,
        6, ['mushroom', 'cremini', 'white mushroom']),
    FoodEntry('Potatoes', FoodCategory.produce, 'bag', StorageLocation.pantry, 40,
        ['potato', 'russet potato']),
    FoodEntry('Sweet Potato', FoodCategory.produce, 'piece',
        StorageLocation.pantry, 25, ['sweet potato', 'yam']),
    FoodEntry('Zucchini', FoodCategory.produce, 'piece', StorageLocation.fridge, 7,
        ['zucchini']),
    FoodEntry('Celery', FoodCategory.produce, 'bunch', StorageLocation.fridge, 14,
        ['celery']),
    FoodEntry('Lemon', FoodCategory.produce, 'piece', StorageLocation.fridge, 21,
        ['lemon']),
    FoodEntry('Lime', FoodCategory.produce, 'piece', StorageLocation.fridge, 21,
        ['lime']),
    FoodEntry('Strawberries', FoodCategory.produce, 'package',
        StorageLocation.fridge, 5, ['strawberry']),
    FoodEntry('Blueberries', FoodCategory.produce, 'package',
        StorageLocation.fridge, 8, ['blueberry']),
    FoodEntry('Grapes', FoodCategory.produce, 'bag', StorageLocation.fridge, 10,
        ['grape']),
    FoodEntry('Cilantro', FoodCategory.produce, 'bunch', StorageLocation.fridge, 6,
        ['cilantro', 'coriander']),
    FoodEntry('Parsley', FoodCategory.produce, 'bunch', StorageLocation.fridge, 7,
        ['parsley']),
    FoodEntry('Ginger', FoodCategory.produce, 'piece', StorageLocation.fridge, 25,
        ['ginger']),

    // ---- Bakery ----
    FoodEntry('Whole Wheat Bread', FoodCategory.bakery, 'loaf',
        StorageLocation.counter, 6, ['whole wheat bread', 'wheat bread', 'bread']),
    FoodEntry('White Bread', FoodCategory.bakery, 'loaf', StorageLocation.counter,
        6, ['white bread']),
    FoodEntry('Bagels', FoodCategory.bakery, 'pack', StorageLocation.counter, 7,
        ['bagel']),
    FoodEntry('Tortillas', FoodCategory.bakery, 'pack', StorageLocation.pantry, 20,
        ['tortilla', 'wrap']),
    FoodEntry('Hamburger Buns', FoodCategory.bakery, 'pack',
        StorageLocation.counter, 7, ['hamburger bun', 'burger bun', 'bun']),

    // ---- Grains & pasta ----
    FoodEntry('Jasmine Rice', FoodCategory.grains, 'kg', StorageLocation.pantry,
        365, ['jasmine rice', 'rice']),
    FoodEntry('Basmati Rice', FoodCategory.grains, 'kg', StorageLocation.pantry,
        365, ['basmati rice']),
    FoodEntry('Brown Rice', FoodCategory.grains, 'kg', StorageLocation.pantry, 180,
        ['brown rice']),
    FoodEntry('Penne Pasta', FoodCategory.grains, 'g', StorageLocation.pantry, 540,
        ['penne', 'pasta']),
    FoodEntry('Spaghetti', FoodCategory.grains, 'g', StorageLocation.pantry, 540,
        ['spaghetti']),
    FoodEntry('Macaroni', FoodCategory.grains, 'g', StorageLocation.pantry, 540,
        ['macaroni', 'elbow pasta']),
    FoodEntry('Rolled Oats', FoodCategory.grains, 'g', StorageLocation.pantry, 300,
        ['oats', 'oatmeal', 'rolled oat']),
    FoodEntry('Breakfast Cereal', FoodCategory.grains, 'box',
        StorageLocation.pantry, 180, ['cereal', 'corn flakes', 'cheerios']),
    FoodEntry('All-Purpose Flour', FoodCategory.pantry, 'kg',
        StorageLocation.pantry, 300, ['flour']),

    // ---- Pantry / condiments ----
    FoodEntry('Olive Oil', FoodCategory.pantry, 'bottle', StorageLocation.pantry,
        400, ['olive oil']),
    FoodEntry('Vegetable Oil', FoodCategory.pantry, 'bottle',
        StorageLocation.pantry, 300, ['vegetable oil', 'canola oil']),
    FoodEntry('Crushed Tomatoes', FoodCategory.pantry, 'can',
        StorageLocation.pantry, 540, ['crushed tomato', 'diced tomato',
        'canned tomato', 'tomato sauce']),
    FoodEntry('Tomato Paste', FoodCategory.pantry, 'can', StorageLocation.pantry,
        540, ['tomato paste']),
    FoodEntry('Pasta Sauce', FoodCategory.pantry, 'jar', StorageLocation.pantry,
        365, ['pasta sauce', 'marinara']),
    FoodEntry('Chicken Stock', FoodCategory.pantry, 'carton',
        StorageLocation.pantry, 365, ['chicken stock', 'chicken broth', 'broth',
        'stock']),
    FoodEntry('Black Beans', FoodCategory.pantry, 'can', StorageLocation.pantry,
        720, ['black bean', 'kidney bean', 'beans']),
    FoodEntry('Chickpeas', FoodCategory.pantry, 'can', StorageLocation.pantry, 720,
        ['chickpea', 'garbanzo']),
    FoodEntry('Peanut Butter', FoodCategory.pantry, 'jar', StorageLocation.pantry,
        180, ['peanut butter']),
    FoodEntry('Ketchup', FoodCategory.pantry, 'bottle', StorageLocation.fridge,
        180, ['ketchup']),
    FoodEntry('Mayonnaise', FoodCategory.pantry, 'jar', StorageLocation.fridge, 90,
        ['mayonnaise']),
    FoodEntry('Mustard', FoodCategory.pantry, 'bottle', StorageLocation.fridge,
        240, ['mustard']),
    FoodEntry('Soy Sauce', FoodCategory.pantry, 'bottle', StorageLocation.pantry,
        720, ['soy sauce']),
    FoodEntry('Honey', FoodCategory.pantry, 'jar', StorageLocation.pantry, 720,
        ['honey']),
    FoodEntry('Salsa', FoodCategory.pantry, 'jar', StorageLocation.fridge, 30,
        ['salsa']),
    FoodEntry('Table Salt', FoodCategory.pantry, 'box', StorageLocation.pantry,
        1000, ['salt']),
    FoodEntry('Black Pepper', FoodCategory.pantry, 'piece', StorageLocation.pantry,
        720, ['black pepper', 'peppercorn']),
    FoodEntry('Sugar', FoodCategory.pantry, 'kg', StorageLocation.pantry, 720,
        ['sugar']),

    // ---- Drinks ----
    FoodEntry('Orange Juice', FoodCategory.dairy, 'L', StorageLocation.fridge, 12,
        ['orange juice']),
    FoodEntry('Apple Juice', FoodCategory.pantry, 'L', StorageLocation.pantry, 120,
        ['apple juice']),
    FoodEntry('Sparkling Water', FoodCategory.pantry, 'pack',
        StorageLocation.pantry, 300, ['sparkling water', 'club soda']),
    FoodEntry('Coffee', FoodCategory.pantry, 'bag', StorageLocation.pantry, 120,
        ['coffee']),
    FoodEntry('Tea', FoodCategory.pantry, 'box', StorageLocation.pantry, 365,
        ['tea']),

    // ---- Snacks ----
    FoodEntry('Tortilla Chips', FoodCategory.snacks, 'bag', StorageLocation.pantry,
        60, ['tortilla chip', 'corn chip', 'nacho chip']),
    FoodEntry('Potato Chips', FoodCategory.snacks, 'bag', StorageLocation.pantry,
        45, ['potato chip', 'chips']),
    FoodEntry('Crackers', FoodCategory.snacks, 'box', StorageLocation.pantry, 120,
        ['cracker']),
    FoodEntry('Granola Bars', FoodCategory.snacks, 'box', StorageLocation.pantry,
        120, ['granola bar', 'granola']),
    FoodEntry('Cookies', FoodCategory.snacks, 'pack', StorageLocation.pantry, 60,
        ['cookie']),
    FoodEntry('Dark Chocolate', FoodCategory.snacks, 'bar', StorageLocation.pantry,
        200, ['chocolate']),

    // ---- Frozen ----
    FoodEntry('Frozen Berries', FoodCategory.frozen, 'bag',
        StorageLocation.freezer, 240, ['frozen berry', 'frozen fruit']),
    FoodEntry('Frozen Peas', FoodCategory.frozen, 'bag', StorageLocation.freezer,
        240, ['frozen pea', 'frozen vegetable', 'frozen veg']),
    FoodEntry('Frozen Pizza', FoodCategory.frozen, 'piece',
        StorageLocation.freezer, 180, ['frozen pizza', 'pizza']),
    FoodEntry('Chicken Nuggets', FoodCategory.frozen, 'bag',
        StorageLocation.freezer, 180, ['chicken nugget', 'nugget']),
    FoodEntry('French Fries', FoodCategory.frozen, 'bag', StorageLocation.freezer,
        180, ['fries', 'french fry']),
    FoodEntry('Ice Cream', FoodCategory.frozen, 'tub', StorageLocation.freezer,
        120, ['ice cream']),
  ];

  /// Small helper for the fallback path.
  static int guessShelfLife(FoodCategory category, StorageLocation storage) {
    if (storage == StorageLocation.freezer) return 150;
    return switch (category) {
      FoodCategory.meat => 2,
      FoodCategory.dairy => 10,
      FoodCategory.produce => 7,
      FoodCategory.bakery => 6,
      FoodCategory.grains => 300,
      FoodCategory.pantry => 300,
      FoodCategory.snacks => 90,
      FoodCategory.frozen => 150,
      FoodCategory.other => 14,
    };
  }
}
