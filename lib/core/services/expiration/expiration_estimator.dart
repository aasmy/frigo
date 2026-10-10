import '../../models/enums.dart';
import '../../models/shelf_life_estimate.dart';

/// Pure, synchronous shelf-life fallback.
///
/// The primary path is [AiService.estimateShelfLife]; this is used when the AI
/// call fails or hasn't been wired up, so the app always has *some* estimate.
class ExpirationEstimator {
  const ExpirationEstimator._();

  static ShelfLifeEstimate estimate({
    required String name,
    required FoodCategory category,
    required StorageLocation storage,
  }) {
    if (storage == StorageLocation.freezer) {
      return const ShelfLifeEstimate(
        estimatedDays: 120,
        confidence: EstimateConfidence.low,
        notes: 'Frozen — keeps for months.',
      );
    }

    final n = name.toLowerCase();
    int days = switch (category) {
      FoodCategory.meat => 2,
      FoodCategory.dairy => 9,
      FoodCategory.produce => 6,
      FoodCategory.bakery => 5,
      FoodCategory.grains => 180,
      FoodCategory.pantry => 240,
      FoodCategory.snacks => 90,
      FoodCategory.frozen => 120,
      FoodCategory.other => 14,
    };

    if (n.contains('egg')) days = 28;
    if (n.contains('milk')) days = 8;
    if (n.contains('yogurt')) days = 12;
    if (n.contains('banana')) days = storage == StorageLocation.counter ? 5 : 7;
    if (n.contains('avocado')) days = storage == StorageLocation.fridge ? 5 : 3;
    if (n.contains('spinach') || n.contains('greens') || n.contains('lettuce')) {
      days = 4;
    }
    if (n.contains('bread')) days = 5;

    return ShelfLifeEstimate(
      estimatedDays: days,
      confidence: EstimateConfidence.low,
      notes: '',
    );
  }

  static DateTime expirationDate({
    required DateTime purchaseDate,
    required int estimatedDays,
  }) =>
      DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day)
          .add(Duration(days: estimatedDays));
}
