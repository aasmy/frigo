import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/services/ads/ads_config.dart';
import '../../core/services/ads/ads_service.dart';
import '../../core/theme/app_colors.dart';

/// An anchored adaptive banner that occupies **zero space until it has an ad**.
///
/// The two rules that keep ads from wrecking the app:
/// 1. No reserved empty slot — a grey rectangle where an ad failed looks
///    broken, and reserving height shifts content when the ad arrives.
/// 2. Never inside a task flow (scanning, confirming, cooking). Ads live on
///    browse surfaces only, where an interruption costs the user nothing.
class FrigoBannerAd extends StatefulWidget {
  const FrigoBannerAd({super.key});

  @override
  State<FrigoBannerAd> createState() => _FrigoBannerAdState();
}

class _FrigoBannerAdState extends State<FrigoBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requested) {
      _requested = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (!AdsService.instance.canRequestAds) return;

    // Adaptive size is keyed to the screen width, so the banner matches the
    // device instead of being letterboxed at a fixed 320x50.
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    final ad = BannerAd(
      size: size,
      adUnitId: AdsConfig.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Stay collapsed. A missing ad is invisible, not an error state.
          debugPrint('Banner failed: ${error.message}');
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: AdWidget(ad: ad),
    );
  }
}
