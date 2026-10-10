import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/inventory_item.dart';
import '../models/shopping_list_item.dart';

/// Realistic starting kitchen so the app is useful the moment it opens.
class DemoData {
  const DemoData._();

  static final _uuid = const Uuid();

  static DateTime _daysAgo(int d) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: d));
  }

  static DateTime _inDays(int d) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: d));
  }

  static List<InventoryItem> inventory() {
    InventoryItem make({
      required String name,
      required FoodCategory category,
      required double quantity,
      required String unit,
      required StorageLocation storage,
      required int purchasedDaysAgo,
      required int expiresInDays,
      FreshnessStatus? manualStatus,
    }) {
      return InventoryItem(
        id: _uuid.v4(),
        name: name,
        normalizedName: name,
        // imageUrl is filled by the inventory image backfill on first load.
        category: category,
        quantity: quantity,
        unit: unit,
        storageLocation: storage,
        purchaseDate: _daysAgo(purchasedDaysAgo),
        estimatedExpirationDate: _inDays(expiresInDays),
        manualStatus: manualStatus,
      );
    }

    return [
      make(
        name: 'Chicken Breast',
        category: FoodCategory.meat,
        quantity: 500,
        unit: 'g',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 1,
        expiresInDays: 2,
      ),
      make(
        name: 'Avocados',
        category: FoodCategory.produce,
        quantity: 3,
        unit: 'piece',
        storage: StorageLocation.counter,
        purchasedDaysAgo: 3,
        expiresInDays: 2,
      ),
      make(
        name: 'Baby Spinach',
        category: FoodCategory.produce,
        quantity: 1,
        unit: 'bag',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 3,
        expiresInDays: 1,
      ),
      make(
        name: 'Eggs',
        category: FoodCategory.dairy,
        quantity: 8,
        unit: 'piece',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 6,
        expiresInDays: 21,
      ),
      make(
        name: 'Milk',
        category: FoodCategory.dairy,
        quantity: 1.5,
        unit: 'L',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 4,
        expiresInDays: 4,
      ),
      make(
        name: 'Greek Yogurt',
        category: FoodCategory.dairy,
        quantity: 400,
        unit: 'g',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 5,
        expiresInDays: 3,
      ),
      make(
        name: 'Rice',
        category: FoodCategory.grains,
        quantity: 2,
        unit: 'kg',
        storage: StorageLocation.pantry,
        purchasedDaysAgo: 20,
        expiresInDays: 300,
      ),
      make(
        name: 'Penne Pasta',
        category: FoodCategory.grains,
        quantity: 800,
        unit: 'g',
        storage: StorageLocation.pantry,
        purchasedDaysAgo: 20,
        expiresInDays: 320,
      ),
      make(
        name: 'Tomatoes',
        category: FoodCategory.produce,
        quantity: 4,
        unit: 'piece',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 3,
        expiresInDays: 6,
      ),
      make(
        name: 'Yellow Onions',
        category: FoodCategory.produce,
        quantity: 5,
        unit: 'piece',
        storage: StorageLocation.pantry,
        purchasedDaysAgo: 10,
        expiresInDays: 25,
      ),
      make(
        name: 'Garlic',
        category: FoodCategory.produce,
        quantity: 1,
        unit: 'bulb',
        storage: StorageLocation.pantry,
        purchasedDaysAgo: 10,
        expiresInDays: 40,
      ),
      make(
        name: 'Cheddar Cheese',
        category: FoodCategory.dairy,
        quantity: 1,
        unit: 'block',
        storage: StorageLocation.fridge,
        purchasedDaysAgo: 8,
        expiresInDays: 18,
      ),
      make(
        name: 'Olive Oil',
        category: FoodCategory.pantry,
        quantity: 1,
        unit: 'bottle',
        storage: StorageLocation.pantry,
        purchasedDaysAgo: 30,
        expiresInDays: 300,
      ),
      make(
        name: 'Ground Beef',
        category: FoodCategory.meat,
        quantity: 700,
        unit: 'g',
        storage: StorageLocation.freezer,
        purchasedDaysAgo: 12,
        expiresInDays: 120,
        manualStatus: FreshnessStatus.frozen,
      ),
    ];
  }

  static List<ShoppingListItem> shoppingList() {
    return [
      ShoppingListItem(
        id: _uuid.v4(),
        name: 'Lime',
        section: ShoppingSection.need,
        createdAt: _daysAgo(0),
      ),
      ShoppingListItem(
        id: _uuid.v4(),
        name: 'Bread',
        section: ShoppingSection.need,
        createdAt: _daysAgo(1),
      ),
      ShoppingListItem(
        id: _uuid.v4(),
        name: 'Milk',
        reason: 'You usually buy milk around this time.',
        section: ShoppingSection.suggested,
        createdAt: _daysAgo(0),
      ),
    ];
  }
}
