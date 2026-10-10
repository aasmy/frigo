import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/demo_data.dart';
import '../models/shopping_list_item.dart';
import '../providers/service_providers.dart';
import '../services/local_store.dart';
import '../services/shopping/shopping_suggestions.dart';
import 'inventory_repository.dart';

class ShoppingListNotifier extends Notifier<List<ShoppingListItem>> {
  late final LocalStore _store;
  final _uuid = const Uuid();

  @override
  List<ShoppingListItem> build() {
    _store = ref.watch(localStoreProvider);
    final raw = _store.readList(LocalStore.kShopping);
    if (raw.isEmpty && !_store.isSeeded) {
      final seeded = DemoData.shoppingList();
      Future.microtask(() => _store.writeList(
          LocalStore.kShopping, seeded.map((e) => e.toJson()).toList()));
      return List.unmodifiable(seeded);
    }
    return List.unmodifiable(raw.map(ShoppingListItem.fromJson));
  }

  void _write(List<ShoppingListItem> items) {
    state = List.unmodifiable(items);
    _store.writeList(LocalStore.kShopping, items.map((e) => e.toJson()).toList());
  }

  bool _has(String name) =>
      state.any((e) => e.name.toLowerCase().trim() == name.toLowerCase().trim());

  void addNeed(String name, {double? quantity, String? unit}) {
    if (name.trim().isEmpty || _has(name)) return;
    _write([
      ShoppingListItem(
        id: _uuid.v4(),
        name: name.trim(),
        quantity: quantity,
        unit: unit,
        createdAt: DateTime.now(),
      ),
      ...state,
    ]);
  }

  void addSuggestion(String name, String reason) {
    if (_has(name)) return;
    _write([
      ...state,
      ShoppingListItem(
        id: _uuid.v4(),
        name: name,
        section: ShoppingSection.suggested,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  void toggleComplete(String id) => _write([
        for (final i in state)
          if (i.id == id) i.copyWith(completed: !i.completed) else i,
      ]);

  /// Move a suggested item into the active "Need" list.
  void promote(String id) => _write([
        for (final i in state)
          if (i.id == id) i.copyWith(section: ShoppingSection.need) else i,
      ]);

  void remove(String id) => _write(state.where((e) => e.id != id).toList());

  void clearCompleted() => _write(state.where((e) => !e.completed).toList());

  List<ShoppingListItem> section(ShoppingSection s) =>
      state.where((e) => e.section == s).sorted((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
}

final shoppingListProvider =
    NotifierProvider<ShoppingListNotifier, List<ShoppingListItem>>(
        ShoppingListNotifier.new);

/// Live "you should probably buy this" list from the current kitchen state.
final shoppingSuggestionsProvider = Provider<List<ShoppingSuggestion>>((ref) {
  final inventory = ref.watch(inventoryProvider);
  final list = ref.watch(shoppingListProvider);
  return ShoppingSuggestionEngine.compute(
    inventory: inventory,
    alreadyListed: list.map((e) => e.name).toSet(),
  );
});

/// How many items are still to buy — handy for a nav badge.
final shoppingNeedCountProvider = Provider<int>((ref) => ref
    .watch(shoppingListProvider)
    .where((e) => e.section == ShoppingSection.need && !e.completed)
    .length);
