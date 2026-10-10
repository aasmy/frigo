import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

/// iOS App Tracking Transparency.
///
/// Timing matters more than anything else here. Asking at cold start, before
/// the user knows what Frigo is, gets refused by most people; asking once they
/// have finished onboarding and seen the app work converts far better. Either
/// answer is fine for us — a refusal just means non-personalised ads.
class TrackingConsent {
  const TrackingConsent._();

  static bool get _applies =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Shows the system prompt once, if iOS has not already recorded an answer.
  static Future<void> requestIfNeeded() async {
    if (!_applies) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;

      // A beat after the UI settles — the prompt should not race the
      // transition the user is still watching.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('ATT request failed: $e');
      // Not fatal: without authorisation the SDK serves non-personalised ads.
    }
  }
}
