import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Where an item physically lives in the kitchen.
enum StorageLocation {
  fridge,
  freezer,
  pantry,
  counter;

  String get label => switch (this) {
        StorageLocation.fridge => 'Fridge',
        StorageLocation.freezer => 'Freezer',
        StorageLocation.pantry => 'Pantry',
        StorageLocation.counter => 'Counter',
      };

  IconData get icon => switch (this) {
        StorageLocation.fridge => Icons.kitchen_outlined,
        StorageLocation.freezer => Icons.ac_unit_outlined,
        StorageLocation.pantry => Icons.door_sliding_outlined,
        StorageLocation.counter => Icons.countertops_outlined,
      };

  static StorageLocation fromName(String? value) => StorageLocation.values
      .firstWhere((e) => e.name == value, orElse: () => StorageLocation.pantry);
}

/// Freshness status. Kept deliberately soft — these are estimates, never
/// food-safety guarantees.
enum FreshnessStatus {
  fresh,
  useSoon,
  expired,
  frozen,
  unknown;

  String get label => switch (this) {
        FreshnessStatus.fresh => 'Fresh',
        FreshnessStatus.useSoon => 'Use soon',
        FreshnessStatus.expired => 'Past estimate',
        FreshnessStatus.frozen => 'Frozen',
        FreshnessStatus.unknown => 'Unknown',
      };

  Color get color => switch (this) {
        FreshnessStatus.fresh => AppColors.fresh,
        FreshnessStatus.useSoon => AppColors.useSoon,
        FreshnessStatus.expired => AppColors.expired,
        FreshnessStatus.frozen => AppColors.frozen,
        FreshnessStatus.unknown => AppColors.unknown,
      };

  Color get softColor => switch (this) {
        FreshnessStatus.fresh => AppColors.freshSoft,
        FreshnessStatus.useSoon => AppColors.useSoonSoft,
        FreshnessStatus.expired => AppColors.expiredSoft,
        FreshnessStatus.frozen => AppColors.frozenSoft,
        FreshnessStatus.unknown => AppColors.unknownSoft,
      };

  static FreshnessStatus fromName(String? value) => FreshnessStatus.values
      .firstWhere((e) => e.name == value, orElse: () => FreshnessStatus.unknown);
}

/// Coarse food categories. Intentionally small.
enum FoodCategory {
  produce,
  meat,
  dairy,
  grains,
  snacks,
  frozen,
  bakery,
  pantry,
  other;

  String get label => switch (this) {
        FoodCategory.produce => 'Produce',
        FoodCategory.meat => 'Meat',
        FoodCategory.dairy => 'Dairy',
        FoodCategory.grains => 'Grains',
        FoodCategory.snacks => 'Snacks',
        FoodCategory.frozen => 'Frozen',
        FoodCategory.bakery => 'Bakery',
        FoodCategory.pantry => 'Pantry',
        FoodCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        FoodCategory.produce => Icons.eco_outlined,
        FoodCategory.meat => Icons.set_meal_outlined,
        FoodCategory.dairy => Icons.egg_outlined,
        FoodCategory.grains => Icons.grass_outlined,
        FoodCategory.snacks => Icons.cookie_outlined,
        FoodCategory.frozen => Icons.ac_unit_outlined,
        FoodCategory.bakery => Icons.bakery_dining_outlined,
        FoodCategory.pantry => Icons.inventory_2_outlined,
        FoodCategory.other => Icons.shopping_basket_outlined,
      };

  static FoodCategory fromAny(String? value) {
    if (value == null) return FoodCategory.other;
    final v = value.trim().toLowerCase();
    for (final c in FoodCategory.values) {
      if (c.name == v || c.label.toLowerCase() == v) return c;
    }
    return switch (v) {
      'fruit' || 'vegetable' || 'vegetables' || 'fruits' => FoodCategory.produce,
      'poultry' || 'seafood' || 'fish' => FoodCategory.meat,
      'grain' || 'pasta' || 'rice' || 'bread' => FoodCategory.grains,
      _ => FoodCategory.other,
    };
  }
}

/// How the user consumed an item after cooking. Forgiving by design.
enum ConsumptionAction {
  usedSome,
  usedAll,
  stillHaveIt,
  threwAway,
  froze;

  String get label => switch (this) {
        ConsumptionAction.usedSome => 'Used some',
        ConsumptionAction.usedAll => 'Finished',
        ConsumptionAction.stillHaveIt => 'Still have it',
        ConsumptionAction.threwAway => 'Threw away',
        ConsumptionAction.froze => 'Froze it',
      };
}
