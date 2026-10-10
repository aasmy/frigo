import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Owns SDK start-up and the privacy consent flow.
///
/// Nothing requests an ad until consent has been resolved, because serving a
/// personalised ad to an EEA/UK user before they have answered the form is the
/// fastest way to lose an AdMob account.
class AdsService extends ChangeNotifier {
  AdsService._();
  static final AdsService instance = AdsService._();

  bool _ready = false;
  bool _consentResolved = false;
  String? _lastError;

  /// True once the SDK is up and consent has been settled, so ads may load.
  bool get canRequestAds => _ready && _consentResolved && AdsConfig.enabled;
  String? get lastError => _lastError;

  Future<void> init() async {
    if (_ready || !AdsConfig.enabled) return;
    try {
      await _resolveConsent();
      await MobileAds.instance.initialize();
      _ready = true;
      notifyListeners();
    } catch (e) {
      _lastError = '$e';
      debugPrint('AdMob init failed: $e');
      // A failed ad stack must never break the app — it just means no ads.
    }
  }

  /// Google's User Messaging Platform decides whether a form is required
  /// (EEA/UK) and remembers the answer across launches.
  Future<void> _resolveConsent() async {
    try {
      final params = ConsentRequestParameters();
      await _requestConsentInfo(params);
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        await _loadAndShowFormIfRequired();
      }
    } catch (e) {
      debugPrint('Consent flow failed: $e');
    } finally {
      // Outside the EEA, or if the form errors, carry on — the SDK falls back
      // to non-personalised ads rather than serving nothing.
      _consentResolved = true;
    }
  }

  Future<void> _requestConsentInfo(ConsentRequestParameters params) {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      done.complete,
      (error) {
        debugPrint('Consent info update: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  Future<void> _loadAndShowFormIfRequired() {
    final done = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) debugPrint('Consent form: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  /// Lets the user reopen the privacy options form, which the GDPR rules
  /// require to stay reachable after the first answer.
  Future<void> showPrivacyOptions() async {
    if (!AdsConfig.enabled) return;
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('Privacy options: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  Future<bool> get privacyOptionsRequired async {
    if (!AdsConfig.enabled) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }
}
