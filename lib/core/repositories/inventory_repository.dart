import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/demo_data.dart';
import '../models/enums.dart';
import '../models/inventory_item.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../providers/service_providers.dart';
import '../services/ai/ai_service.dart';
import '../services/expiration/expiration_estimator.dart';
import '../services/images/image_resolver.dart';
import '../services/local_store.dart';

/// Owns the kitchen inventory: the offline cache, demo seeding, and every
/// mutation (manual add, receipt import, cooking deductions).
class InventoryNotifier extends Notifier<List<InventoryItem>> {
  late final LocalStore _store;
  final _uuid = const Uuid();

  @override
  List<InventoryItem> build() {
    _store = ref.watch(localStoreProvider);
    final raw = _store.readList(LocalStore.kInventory);
    if (raw.isEmpty && !_store.isSeeded) {
      final seeded = DemoData.inventory();
      // Persist after build completes — never assign `state` from build().
      Future.microtask(() {
        _store.writeList(
            LocalStore.kInventory, seeded.map((e) => e.toJson()).toList());
        _store.markSeeded();
        _backfillImages();
      });
      return List.unmodifiable(seeded);
    }
    Future.microtask(_backfillImages);
    return List.unmodifiable(raw.map(InventoryItem.fromJson));
  }

  /// Make sure every item ends up with a photo: resolve one for anything that
  /// still has `imageUrl == null` and persist it.
  Future<void> _backfillImages() async {
    final missing = state.where((i) => i.imageUrl == null).toList();
    if (missing.isEmpty) return;
    for (final item in missing) {
      final url = await ImageResolver.instance.resolve(item.displayName);
      if (url == null) continue;
      final idx = state.indexWhere((e) => e.id == item.id);
      if (idx == -1) continue; // removed meanwhile
      final next = [...state];
      next[idx] = next[idx].copyWith(imageUrl: url);
      _write(next);
    }
  }

  void _write(List<InventoryItem> items) {
    state = List.unmodifiable(items);
    _store.writeList(
      LocalStore.kInventory,
      items.map((e) => e.toJson()).toList(),
    );
  }

  // --- reads ---------------------------------------------------------------
  InventoryItem? byId(String id) => state.firstWhereOrNull((e) => e.id == id);

  List<InventoryItem> get useSoon => state
      .where((i) =>
          i.status == FreshnessStatus.useSoon || i.status == FreshnessStatus.expired)
      .sorted((a, b) =>
          (a.daysUntilExpiration ?? 999).compareTo(b.daysUntilExpiration ?? 999));

  /// Inventory items whose name resembles [name] (used for duplicate warnings
  /// and recipe reconciliation).
  List<InventoryItem> matching(String name) {
    final n = name.toLowerCase().trim();
    final words = n.split(' ').where((w) => w.length > 2).toSet();
    return state.where((i) {
      final d = i.displayName.toLowerCase();
      if (d.contains(n) || n.contains(d)) return true;
      final dw = d.split(' ').where((w) => w.length > 2).toSet();
      return words.isNotEmpty && words.every(dw.contains);
    }).toList();
  }

  // --- mutations ---------------------------------------------------------------
  void addItem(InventoryItem item) => _write([item, ...state]);

  void updateItem(InventoryItem item) => _write(
        state.map((e) => e.id == item.id ? item.copyWith(updatedAt: DateTime.now()) : e).toList(),
      );

  void removeItem(String id) => _write(state.where((e) => e.id != id).toList());

  /// Convert the confirmed, food, included rows of a receipt into inventory
  /// items, estimating an expiration date for each (AI first, heuristic
  /// fallback).
  Future<int> addFromReceipt(Receipt receipt) async {
    final ai = ref.read(aiServiceProvider);
    final rows = receipt.items.where((i) => i.included && i.isFood).toList();
    final additions = <InventoryItem>[];

    for (final row in rows) {
      final estimate = await _estimateFor(ai, row, receipt.purchaseDate);
      additions.add(
        InventoryItem(
          id: _uuid.v4(),
          name: row.rawName,
          normalizedName: row.normalizedName,
          category: row.category,
          quantity: row.quantity,
          unit: row.unit,
          storageLocation: row.effectiveStorage,
          purchaseDate: receipt.purchaseDate,
          estimatedExpirationDate: ExpirationEstimator.expirationDate(
            purchaseDate: receipt.purchaseDate,
            estimatedDays: estimate,
          ),
          receiptId: receipt.id,
          imageUrl: await ImageResolver.instance.resolve(row.normalizedName),
          manualStatus: row.effectiveStorage == StorageLocation.freezer
              ? FreshnessStatus.frozen
              : null,
        ),
      );
    }

    _write([...additions, ...state]);
    return additions.length;
  }

  Future<int> _estimateFor(
    AiService ai,
    ReceiptItem row,
    DateTime purchaseDate,
  ) async {
    try {
      final e = await ai.estimateShelfLife(
        productName: row.normalizedName,
        category: row.category,
        purchaseDate: purchaseDate,
        storage: row.effectiveStorage,
      );
      return e.estimatedDays;
    } on AiException {
      return ExpirationEstimator.estimate(
        name: row.normalizedName,
        category: row.category,
        storage: row.effectiveStorage,
      ).estimatedDays;
    }
  }

  /// Apply a cooking deduction. [changes] maps inventory id -> action, with an
  /// optional explicit remaining quantity for [ConsumptionAction.usedSome].
  void applyConsumption(List<ConsumptionChange> changes) {
    var next = [...state];
    for (final change in changes) {
      final idx = next.indexWhere((e) => e.id == change.itemId);
      if (idx == -1) continue;
      final item = next[idx];
      switch (change.action) {
        case ConsumptionAction.usedAll:
        case ConsumptionAction.threwAway:
          next.removeAt(idx);
        case ConsumptionAction.stillHaveIt:
          break;
        case ConsumptionAction.froze:
          next[idx] = item.copyWith(
            storageLocation: StorageLocation.freezer,
            manualStatus: FreshnessStatus.frozen,
          );
        case ConsumptionAction.usedSome:
          final remaining = change.remainingQuantity ??
              (item.quantity * 0.6).clamp(0, item.quantity).toDouble();
          if (remaining <= 0) {
            next.removeAt(idx);
          } else {
            next[idx] = item.copyWith(quantity: remaining);
          }
      }
    }
    _write(next);
  }

  void resetToDemo() {
    final seeded = DemoData.inventory();
    _write(seeded);
  }
}

class ConsumptionChange {
  const ConsumptionChange({
    required this.itemId,
    required this.action,
    this.remainingQuantity,
  });

  final String itemId;
  final ConsumptionAction action;
  final double? remainingQuantity;
}

final inventoryProvider =
    NotifierProvider<InventoryNotifier, List<InventoryItem>>(InventoryNotifier.new);

/// Convenience: items that need attention, already sorted.
final useSoonProvider = Provider<List<InventoryItem>>(
  (ref) {
    ref.watch(inventoryProvider);
    return ref.read(inventoryProvider.notifier).useSoon;
  },
);
