import '../config/app_config.dart';

/// What the user is currently entitled to, and how much of the free allowance
/// they have spent.
///
/// The free tier is deliberately generous on everything that costs Frigo
/// nothing — unlimited manual items, unlimited inventory, unlimited recipes
/// from TheMealDB — and metered only on the two things that cost real money
/// per use: AI receipt scans and assistant replies. That keeps the server bill
/// bounded by design rather than by hope.
class Entitlements {
  const Entitlements({
    this.isPro = false,
    this.proSince,
    this.aiScansUsed = 0,
    this.bonusScans = 0,
    this.assistantRepliesUsed = 0,
    this.periodStart,
    this.assistantDay,
  });

  final bool isPro;
  final DateTime? proSince;

  /// AI receipt scans spent in the current monthly period.
  final int aiScansUsed;

  /// Extra scans earned by watching a rewarded ad. Spent before the monthly
  /// allowance so a user who watched an ad sees the benefit immediately.
  final int bonusScans;

  /// Assistant replies spent today.
  final int assistantRepliesUsed;

  final DateTime? periodStart;
  final DateTime? assistantDay;

  // ---------------------------------------------------------------------------
  // Allowances
  // ---------------------------------------------------------------------------

  bool get showAds => !isPro;

  int get scanAllowance => AppConfig.freeAiScansPerMonth + bonusScans;

  int get scansLeft =>
      isPro ? 1 << 30 : (scanAllowance - aiScansUsed).clamp(0, 1 << 30);

  bool get canAiScan => isPro || scansLeft > 0;

  int get assistantRepliesLeft => isPro
      ? 1 << 30
      : (AppConfig.freeAssistantRepliesPerDay - assistantRepliesUsed)
          .clamp(0, 1 << 30);

  bool get canAskAssistant => isPro || assistantRepliesLeft > 0;

  /// Shown on the Profile tile and the paywall.
  String get summary {
    if (isPro) return 'Frigo Pro — unlimited AI, no ads';
    return '$scansLeft of $scanAllowance AI scans left this month';
  }

  // ---------------------------------------------------------------------------
  // Period rollover
  // ---------------------------------------------------------------------------

  /// Returns a copy with counters cleared for any period that has rolled over.
  ///
  /// Rollover is computed from the stored dates rather than scheduled, so it is
  /// correct after the app has been closed for a month and cannot be gamed by
  /// changing the clock backwards — a later `periodStart` simply stands.
  Entitlements rolled([DateTime? now]) {
    final at = now ?? DateTime.now();
    var next = this;

    final start = periodStart;
    if (start == null || at.year != start.year || at.month != start.month) {
      next = next.copyWith(
        aiScansUsed: 0,
        periodStart: DateTime(at.year, at.month),
      );
    }

    final day = assistantDay;
    if (day == null ||
        at.year != day.year ||
        at.month != day.month ||
        at.day != day.day) {
      next = next.copyWith(
        assistantRepliesUsed: 0,
        assistantDay: DateTime(at.year, at.month, at.day),
      );
    }
    return next;
  }

  Entitlements copyWith({
    bool? isPro,
    Object? proSince = _sentinel,
    int? aiScansUsed,
    int? bonusScans,
    int? assistantRepliesUsed,
    DateTime? periodStart,
    DateTime? assistantDay,
  }) {
    return Entitlements(
      isPro: isPro ?? this.isPro,
      proSince: proSince == _sentinel ? this.proSince : proSince as DateTime?,
      aiScansUsed: aiScansUsed ?? this.aiScansUsed,
      bonusScans: bonusScans ?? this.bonusScans,
      assistantRepliesUsed: assistantRepliesUsed ?? this.assistantRepliesUsed,
      periodStart: periodStart ?? this.periodStart,
      assistantDay: assistantDay ?? this.assistantDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_pro': isPro,
        'pro_since': proSince?.toIso8601String(),
        'ai_scans_used': aiScansUsed,
        'bonus_scans': bonusScans,
        'assistant_replies_used': assistantRepliesUsed,
        'period_start': periodStart?.toIso8601String(),
        'assistant_day': assistantDay?.toIso8601String(),
      };

  factory Entitlements.fromJson(Map<String, dynamic> json) => Entitlements(
        isPro: json['is_pro'] as bool? ?? false,
        proSince: _date(json['pro_since']),
        aiScansUsed: json['ai_scans_used'] as int? ?? 0,
        bonusScans: json['bonus_scans'] as int? ?? 0,
        assistantRepliesUsed: json['assistant_replies_used'] as int? ?? 0,
        periodStart: _date(json['period_start']),
        assistantDay: _date(json['assistant_day']),
      );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static const Object _sentinel = Object();
}
