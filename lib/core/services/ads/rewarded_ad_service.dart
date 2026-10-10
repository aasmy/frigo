import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'ads_service.dart';

/// Rewarded ads — the only ad in Frigo the user chooses to watch.
///
/// A rewarded ad is offered exactly once: when the free AI scan allowance runs
/// out. It is never auto-played and never blocks a task. The trade is explicit
/// ("watch an ad, get 3 more scans"), which is why rewarded inventory earns
/// several times what a banner does without feeling like an interruption.
class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  RewardedAd? _ad;
  bool _loading = false;

  bool get isReady => _ad != null;

  /// Pre-loads so the ad is ready the moment the user taps. Called when the
  /// paywall opens, not at launch.
  Future<void> preload() async {
    if (!AdsService.instance.canRequestAds || _ad != null || _loading) return;
    _loading = true;
    final done = Completer<void>();
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          if (!done.isCompleted) done.complete();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed: ${error.message}');
          _loading = false;
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    return done.future;
  }

  /// Shows the ad. Resolves `true` only when the reward was actually earned —
  /// a user who closes the ad early gets nothing, which is the store rule.
  Future<bool> show() async {
    if (!AdsService.instance.canRequestAds) return false;
    if (_ad == null) await preload();
    final ad = _ad;
    if (ad == null) return false;

    var earned = false;
    final closed = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        if (!closed.isCompleted) closed.complete();
        // Warm the next one so a second request is instant.
        unawaited(preload());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded show failed: ${error.message}');
        ad.dispose();
        _ad = null;
        if (!closed.isCompleted) closed.complete();
      },
    );

    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    await closed.future;
    return earned;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
