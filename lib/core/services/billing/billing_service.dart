import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config/app_config.dart';

/// Wraps `in_app_purchase` for the Frigo Pro subscription.
///
/// **Receipt verification is local only.** `_isEntitled` trusts the purchase
/// object the platform hands back, which is fine for a launch but is bypassable
/// on a rooted device. Before the subscription earns real money, the purchase
/// token should be validated server-side against the Play Developer API or
/// Apple's verifyReceipt. See STORE_RELEASE.md.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool _busy = false;
  String? _lastError;
  List<ProductDetails> _products = const [];

  /// Fires when a purchase is confirmed, so the entitlement store can persist
  /// it. Set by the repository at start-up.
  void Function(bool isPro)? onEntitlementChanged;

  bool get available => _available;
  bool get busy => _busy;
  String? get lastError => _lastError;

  /// Products the store actually returned, cheapest period first.
  List<ProductDetails> get products => _products;

  ProductDetails? get monthly => _byId(AppConfig.proMonthlyId);
  ProductDetails? get yearly => _byId(AppConfig.proYearlyId);

  ProductDetails? _byId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> init() async {
    if (_sub != null) return;
    try {
      _available = await _iap.isAvailable();
      if (!_available) return;

      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          _lastError = '$e';
          notifyListeners();
        },
      );

      final response =
          await _iap.queryProductDetails(AppConfig.proProductIds);
      if (response.error != null) {
        _lastError = response.error!.message;
      }
      // notFoundIDs is the usual symptom of products that exist in code but
      // were never created in the store console, or are not yet approved.
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('IAP products not found: ${response.notFoundIDs}');
      }
      _products = response.productDetails;
      notifyListeners();
    } catch (e) {
      _lastError = '$e';
      debugPrint('Billing init failed: $e');
    }
  }

  Future<void> buy(ProductDetails product) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      // The result arrives on the purchase stream, not here.
    } catch (e) {
      _lastError = '$e';
      _busy = false;
      notifyListeners();
    }
  }

  /// Required by both stores: a visible way to recover a subscription on a new
  /// device. App Review rejects builds without one.
  Future<void> restore() async {
    _busy = true;
    notifyListeners();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = '$e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _busy = true;

        case PurchaseStatus.error:
          _lastError = p.error?.message ?? 'Purchase failed.';
          _busy = false;

        case PurchaseStatus.canceled:
          _busy = false;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _busy = false;
          if (_isEntitled(p)) onEntitlementChanged?.call(true);
      }

      // Must always be acknowledged, or the store refunds it automatically
      // after a few days.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  bool _isEntitled(PurchaseDetails p) =>
      AppConfig.proProductIds.contains(p.productID);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
