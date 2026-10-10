import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/receipt.dart';
import '../providers/service_providers.dart';
import '../services/local_store.dart';

/// Stores confirmed receipts for the history screen.
class ReceiptNotifier extends Notifier<List<Receipt>> {
  late final LocalStore _store;

  @override
  List<Receipt> build() {
    _store = ref.watch(localStoreProvider);
    return _store
        .readList(LocalStore.kReceipts)
        .map(Receipt.fromJson)
        .sorted((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  void _write(List<Receipt> receipts) {
    final sorted =
        receipts.sorted((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    state = List.unmodifiable(sorted);
    _store.writeList(LocalStore.kReceipts, sorted.map((e) => e.toJson()).toList());
  }

  Receipt? byId(String id) => state.firstWhereOrNull((e) => e.id == id);

  void save(Receipt receipt) =>
      _write([receipt, ...state.where((e) => e.id != receipt.id)]);

  void delete(String id) => _write(state.where((e) => e.id != id).toList());
}

final receiptsProvider =
    NotifierProvider<ReceiptNotifier, List<Receipt>>(ReceiptNotifier.new);
