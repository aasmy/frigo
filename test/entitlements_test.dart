import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_ai/core/config/app_config.dart';
import 'package:pantry_ai/core/models/entitlements.dart';

void main() {
  group('free tier allowance', () {
    test('starts with the full monthly scan allowance', () {
      const e = Entitlements();
      expect(e.canAiScan, isTrue);
      expect(e.scansLeft, AppConfig.freeAiScansPerMonth);
      expect(e.showAds, isTrue);
    });

    test('runs out after the monthly allowance is spent', () {
      final e = const Entitlements()
          .copyWith(aiScansUsed: AppConfig.freeAiScansPerMonth);
      expect(e.canAiScan, isFalse);
      expect(e.scansLeft, 0);
    });

    test('bonus scans extend the allowance past the monthly cap', () {
      final e = const Entitlements().copyWith(
        aiScansUsed: AppConfig.freeAiScansPerMonth,
        bonusScans: AppConfig.rewardedScanBonus,
      );
      expect(e.canAiScan, isTrue);
      expect(e.scansLeft, AppConfig.rewardedScanBonus);
    });

    test('scansLeft never goes negative', () {
      final e = const Entitlements()
          .copyWith(aiScansUsed: AppConfig.freeAiScansPerMonth + 50);
      expect(e.scansLeft, 0);
    });
  });

  group('pro', () {
    test('removes ads and both limits', () {
      final e = const Entitlements().copyWith(
        isPro: true,
        aiScansUsed: 9999,
        assistantRepliesUsed: 9999,
      );
      expect(e.showAds, isFalse);
      expect(e.canAiScan, isTrue);
      expect(e.canAskAssistant, isTrue);
    });
  });

  group('period rollover', () {
    test('a new calendar month resets scans but keeps bonus scans', () {
      final january = Entitlements(
        aiScansUsed: AppConfig.freeAiScansPerMonth,
        bonusScans: 2,
        periodStart: DateTime(2026, 1),
      );
      final february = january.rolled(DateTime(2026, 2, 1, 9));

      expect(february.aiScansUsed, 0);
      expect(february.bonusScans, 2, reason: 'earned, not rented');
      expect(february.canAiScan, isTrue);
    });

    test('the same month does not reset', () {
      final e = Entitlements(
        aiScansUsed: 4,
        periodStart: DateTime(2026, 3),
      );
      expect(e.rolled(DateTime(2026, 3, 28)).aiScansUsed, 4);
    });

    test('a new day resets assistant replies only', () {
      final e = Entitlements(
        aiScansUsed: 3,
        assistantRepliesUsed: AppConfig.freeAssistantRepliesPerDay,
        periodStart: DateTime(2026, 5),
        assistantDay: DateTime(2026, 5, 10),
      );
      final next = e.rolled(DateTime(2026, 5, 11, 0, 5));

      expect(next.assistantRepliesUsed, 0);
      expect(next.aiScansUsed, 3, reason: 'scans are monthly, not daily');
    });

    test('a year boundary counts as a new month', () {
      final e = Entitlements(
        aiScansUsed: AppConfig.freeAiScansPerMonth,
        periodStart: DateTime(2026, 12),
      );
      expect(e.rolled(DateTime(2027, 1, 1)).aiScansUsed, 0);
    });

    test('rolled() returns the same instance when nothing changed', () {
      final e = Entitlements(
        periodStart: DateTime(2026, 6),
        assistantDay: DateTime(2026, 6, 15),
      );
      // The repository relies on identity to decide whether to write to disk.
      expect(identical(e.rolled(DateTime(2026, 6, 15, 12)), e), isTrue);
    });
  });

  group('persistence', () {
    test('survives a JSON round trip', () {
      final e = Entitlements(
        isPro: true,
        proSince: DateTime(2026, 4, 2),
        aiScansUsed: 7,
        bonusScans: 3,
        assistantRepliesUsed: 2,
        periodStart: DateTime(2026, 4),
        assistantDay: DateTime(2026, 4, 9),
      );
      final back = Entitlements.fromJson(e.toJson());

      expect(back.isPro, isTrue);
      expect(back.proSince, e.proSince);
      expect(back.aiScansUsed, 7);
      expect(back.bonusScans, 3);
      expect(back.assistantRepliesUsed, 2);
      expect(back.periodStart, e.periodStart);
      expect(back.assistantDay, e.assistantDay);
    });

    test('an empty map reads as a fresh free account', () {
      final e = Entitlements.fromJson(const {});
      expect(e.isPro, isFalse);
      expect(e.aiScansUsed, 0);
    });

    test('garbage dates do not throw', () {
      final e = Entitlements.fromJson(const {
        'is_pro': true,
        'period_start': 'not-a-date',
        'pro_since': 42,
      });
      expect(e.periodStart, isNull);
      expect(e.proSince, isNull);
      expect(e.isPro, isTrue);
    });
  });
}
