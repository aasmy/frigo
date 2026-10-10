import 'package:collection/collection.dart';

import '../../models/enums.dart';
import '../../models/inventory_item.dart';

class ShoppingSuggestion {
  const ShoppingSuggestion(this.name, this.reason);
  final String name;
  final String reason;
}

/// Rule-based "you should probably buy this" list, derived from what's in the
/// kitchen right now — staples you've run out of, things running low, and
/// perishables that are past their best.
class ShoppingSuggestionEngine {
  const ShoppingSuggestionEngine._();

  static const _staples = <String>[
    'milk', 'eggs', 'bread', 'butter', 'onion', 'garlic', 'rice', 'pasta',
    'olive oil', 'salt', 'black pepper', 'sugar', 'flour', 'chicken', 'cheese',
    'tomatoes', 'potatoes', 'coffee', 'yogurt', 'carrots',
  ];
  static const _perishableStaples = {'milk', 'eggs', 'bread', 'yogurt'};
  static const _countUnits = {
    'piece', 'pieces', 'bunch', 'bag', 'pack', 'loaf', 'bottle', 'can', 'jar',
    'carton', 'box', 'head', 'bulb', 'tub', 'dozen', '',
  };

  static List<ShoppingSuggestion> compute({
    required List<InventoryItem> inventory,
    required Set<String> alreadyListed,
  }) {
    final have = inventory.map((i) => i.displayName.toLowerCase()).toList();
    bool inKitchen(String s) =>
        have.any((h) => h.contains(s) || s.contains(h));
    InventoryItem? find(String s) => inventory.firstWhereOrNull((i) {
          final d = i.displayName.toLowerCase();
          return d.contains(s) || s.contains(d);
        });

    final seen = <String>{...alreadyListed.map((e) => e.toLowerCase())};
    final out = <ShoppingSuggestion>[];
    void add(String name, String reason) {
      if (seen.add(name.toLowerCase())) {
        out.add(ShoppingSuggestion(name, reason));
      }
    }

    // 1. Staples you're completely out of.
    for (final s in _staples) {
      if (!inKitchen(s)) add(_title(s), "A staple you're out of");
    }

    // 2. Staples that are running low or stale.
    for (final s in _staples) {
      final it = find(s);
      if (it == null) continue;
      final isCount = _countUnits.contains(it.unit.toLowerCase());
      final low = isCount && it.quantity <= 1;
      final stale = it.status == FreshnessStatus.expired ||
          (it.status == FreshnessStatus.useSoon &&
              _perishableStaples.contains(s));
      if (stale) {
        add(it.displayName, 'Yours is past its best');
      } else if (low) {
        add(it.displayName, 'Running low');
      }
    }

    // 3. Any perishable item that has expired — worth replacing.
    for (final it in inventory) {
      if (it.status != FreshnessStatus.expired) continue;
      if (it.category != FoodCategory.produce &&
          it.category != FoodCategory.dairy &&
          it.category != FoodCategory.meat) {
        continue;
      }
      add(it.displayName, 'Expired — replace it');
    }

    return out.take(8).toList();
  }

  static String _title(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
