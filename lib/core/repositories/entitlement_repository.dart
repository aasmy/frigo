import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/entitlements.dart';
import '../providers/service_providers.dart';
import '../services/ads/rewarded_ad_service.dart';
import '../services/billing/billing_service.dart';
import '../services/local_store.dart';

/// Single source of truth for tier and free-allowance state.
///
/// Every read goes through [build]/`rolled`, so a period that expired while the
/// app was closed is reset the first time anything asks — there is no timer to
/// miss and no stale counter to explain away.
class EntitlementNotifier extends Notifier<Entitlements> {
  late final LocalStore _store;
  var _disposed = false;

  @override
  Entitlements build() {
    _store = ref.watch(localStoreProvider);
    final json = _store.readMap(LocalStore.kEntitlements);
    final loaded =
        json == null ? const Entitlements() : Entitlements.fromJson(json);

    // A purchase confirmed on the billing stream (including a restore on a new
    // device) flows straight back into persisted state.
    ref.onDispose(() => _disposed = true);
    BillingService.instance.onEntitlementChanged = (isPro) {
      // The stream outlives a rebuild; dropping late callbacks avoids writing
      // through a notifier that is no longer attached.
      if (_disposed) return;
      _persist(state.copyWith(
        isPro: isPro,
        proSince: isPro ? (state.proSince ?? DateTime.now()) : null,
      ));
    };

    final rolled = loaded.rolled();
    if (rolled != loaded) _store.writeMap(LocalStore.kEntitlements, rolled.toJson());
    return rolled;
  }

  void _persist(Entitlements next) {
    state = next;
    _store.writeMap(LocalStore.kEntitlements, next.toJson());
  }

  /// Call before starting an AI scan. Returns false when the allowance is spent,
  /// so the caller can offer the paywall instead of silently doing nothing.
  bool consumeAiScan() {
    final e = state.rolled();
    if (!e.canAiScan) {
      _persist(e);
      return false;
    }
    if (e.isPro) {
      _persist(e);
      return true;
    }
    // Spend bonus scans first so a rewarded ad feels immediately worthwhile.
    _persist(e.bonusScans > 0
        ? e.copyWith(bonusScans: e.bonusScans - 1)
        : e.copyWith(aiScansUsed: e.aiScansUsed + 1));
    return true;
  }

  bool consumeAssistantReply() {
    final e = state.rolled();
    if (!e.canAskAssistant) {
      _persist(e);
      return false;
    }
    _persist(e.isPro
        ? e
        : e.copyWith(assistantRepliesUsed: e.assistantRepliesUsed + 1));
    return true;
  }

  /// Shows a rewarded ad and grants scans only if it was actually watched.
  Future<bool> watchAdForScans() async {
    final earned = await RewardedAdService.instance.show();
    if (!earned) return false;
    final e = state.rolled();
    _persist(e.copyWith(bonusScans: e.bonusScans + AppConfig.rewardedScanBonus));
    return true;
  }

  Future<void> restorePurchases() => BillingService.instance.restore();

  /// Debug helper for exercising the paid paths without a store account.
  /// Never reachable in release.
  void debugSetPro(bool value) {
    assert(() {
      _persist(state.copyWith(
          isPro: value, proSince: value ? DateTime.now() : null));
      return true;
    }());
  }
}

final entitlementProvider =
    NotifierProvider<EntitlementNotifier, Entitlements>(
        EntitlementNotifier.new);

/// Convenience for the many widgets that only care about the ad flag.
final showAdsProvider =
    Provider<bool>((ref) => ref.watch(entitlementProvider).showAds);
