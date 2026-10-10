import 'package:flutter/foundation.dart';

/// Ad placement policy and unit IDs.
///
/// Ships with Google's **official test unit IDs**. Real IDs come from your own
/// AdMob account and are injected at build time:
///
/// ```
/// flutter build appbundle \
///   --dart-define=ADMOB_ANDROID_BANNER=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_IOS_BANNER=ca-app-pub-XXXX/ZZZZ
/// ```
///
/// Serving live ads against test IDs earns nothing; serving test ads against
/// live IDs gets the account suspended. Keeping the default on *test* means a
/// build that forgets the flag fails safe.
class AdsConfig {
  const AdsConfig._();

  /// Master switch. Off for tests and anywhere the plugin has no platform
  /// implementation (web, desktop).
  static bool enabled = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Google's published test units — safe to run in debug forever.
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static const _bannerAndroid =
      String.fromEnvironment('ADMOB_ANDROID_BANNER', defaultValue: '');
  static const _bannerIos =
      String.fromEnvironment('ADMOB_IOS_BANNER', defaultValue: '');
  static const _rewardedAndroid =
      String.fromEnvironment('ADMOB_ANDROID_REWARDED', defaultValue: '');
  static const _rewardedIos =
      String.fromEnvironment('ADMOB_IOS_REWARDED', defaultValue: '');

  // defaultTargetPlatform rather than dart:io — this file is also compiled for
  // web, where dart:io does not exist.
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String get bannerUnitId {
    final configured = _android ? _bannerAndroid : _bannerIos;
    if (configured.isNotEmpty) return configured;
    return _android ? _testBannerAndroid : _testBannerIos;
  }

  static String get rewardedUnitId {
    final configured = _android ? _rewardedAndroid : _rewardedIos;
    if (configured.isNotEmpty) return configured;
    return _android ? _testRewardedAndroid : _testRewardedIos;
  }

  /// True when the build is still pointing at Google's test units. Surfaced in
  /// Profile so a release build that forgot the flags is obvious.
  static bool get usingTestUnits =>
      (_android ? _bannerAndroid : _bannerIos).isEmpty;
}
