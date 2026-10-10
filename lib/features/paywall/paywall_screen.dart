import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/app_config.dart';
import '../../core/repositories/entitlement_repository.dart';
import '../../core/services/ads/ads_service.dart';
import '../../core/services/ads/rewarded_ad_service.dart';
import '../../core/services/billing/billing_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/primary_button.dart';

/// Why someone is seeing this, so the copy can say so plainly.
enum PaywallReason {
  outOfScans,
  outOfAssistant,
  removeAds,
  browse;

  String get title => switch (this) {
        PaywallReason.outOfScans => "You've used this month's AI scans",
        PaywallReason.outOfAssistant => "You've used today's AI replies",
        PaywallReason.removeAds => 'Frigo without ads',
        PaywallReason.browse => 'Frigo Pro',
      };

  String get body => switch (this) {
        PaywallReason.outOfScans =>
          'Your kitchen, reminders and recipes keep working. Only AI receipt '
              'scanning is paused until next month.',
        PaywallReason.outOfAssistant =>
          'Ask Frigo resets tomorrow. Everything else keeps working as normal.',
        PaywallReason.removeAds =>
          'Remove the banner and unlock unlimited AI.',
        PaywallReason.browse =>
          'Unlimited AI, no ads, and the same app you already have.',
      };
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({this.reason = PaywallReason.browse, super.key});

  final PaywallReason reason;

  /// Opens the paywall as a sheet. Returns true if the user left it as Pro.
  static Future<bool> show(
    BuildContext context, {
    PaywallReason reason = PaywallReason.browse,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PaywallScreen(reason: reason),
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    // Warm both paths while the user reads, so neither button stalls.
    BillingService.instance.init();
    RewardedAdService.instance.preload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ent = ref.watch(entitlementProvider);

    return ListenableBuilder(
      listenable: BillingService.instance,
      builder: (context, _) {
        final billing = BillingService.instance;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            children: [
              FadeSlideIn(
                child: FrigoIllustration(
                  widget.reason == PaywallReason.outOfScans
                      ? FrigoArt.emptyKitchen
                      : FrigoArt.scanSuccess,
                  height: 180,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.reason.title, style: text.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.reason.body,
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              const _Benefits(),
              const SizedBox(height: AppSpacing.lg),

              if (billing.products.isEmpty)
                _Unavailable(error: billing.lastError)
              else
                for (final p in _ordered(billing))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PlanTile(
                      product: p,
                      best: p.id == AppConfig.proYearlyId,
                      busy: billing.busy,
                      onTap: () {
                        Haptics.light();
                        billing.buy(p);
                      },
                    ),
                  ),

              // The free way out. Offered only when it actually helps.
              if (!ent.isPro &&
                  widget.reason == PaywallReason.outOfScans &&
                  AdsService.instance.canRequestAds) ...[
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Watch an ad for '
                      '${AppConfig.rewardedScanBonus} more scans',
                  icon: Icons.play_circle_outline,
                  onPressed: () async {
                    final ok = await ref
                        .read(entitlementProvider.notifier)
                        .watchAdForScans();
                    if (!context.mounted) return;
                    if (ok) {
                      Haptics.success();
                      Navigator.pop(context, false);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('No ad available right now.')),
                      );
                    }
                  },
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: billing.busy
                      ? null
                      : () =>
                          ref.read(entitlementProvider.notifier).restorePurchases(),
                  child: const Text('Restore purchases'),
                ),
              ),
              Text(
                'Subscriptions renew automatically until cancelled. Manage or '
                'cancel any time in your Google Play or App Store account '
                'settings.',
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Yearly first — it is the better value and the one worth anchoring on.
  List<ProductDetails> _ordered(BillingService b) => [
        if (b.yearly != null) b.yearly!,
        if (b.monthly != null) b.monthly!,
      ];
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _rows = [
    (Icons.document_scanner_outlined, 'Unlimited AI receipt scans',
        'Instead of ${AppConfig.freeAiScansPerMonth} a month'),
    (Icons.auto_awesome, 'Unlimited Ask Frigo',
        'Instead of ${AppConfig.freeAssistantRepliesPerDay} replies a day'),
    (Icons.block_outlined, 'No ads', 'The banner disappears everywhere'),
    (Icons.favorite_outline, 'Supports a small app',
        'Built by one person, not a company'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardLg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (final (i, row) in _rows.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            FadeSlideIn(
              index: i + 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.$1, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$2, style: text.titleSmall),
                        Text(row.$3, style: text.labelMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.product,
    required this.best,
    required this.busy,
    required this.onTap,
  });

  final ProductDetails product;
  final bool best;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PressFeedback(
      child: Material(
        color: best ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadii.cardLg,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: AppRadii.cardLg,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardLg,
              border: Border.all(
                  color: best ? AppColors.primary : AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title.replaceAll(RegExp(r'\s*\(.*\)$'), ''),
                        style: text.titleMedium?.copyWith(
                          color: best
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        // The store's localised price string — never a
                        // hard-coded one, which would be wrong in most markets.
                        product.price,
                        style: text.labelMedium?.copyWith(
                          color: best
                              ? AppColors.onPrimary.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (best)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(AppRadii.pill),
                    ),
                    child: Text('Best value',
                        style: text.labelSmall
                            ?.copyWith(color: AppColors.onPrimary)),
                  ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.useSoonSoft,
        borderRadius: AppRadii.cardLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscriptions are not available yet', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            error ??
                'The products need to be created in Play Console and App '
                    'Store Connect before they appear here.',
            style: text.labelMedium,
          ),
        ],
      ),
    );
  }
}
