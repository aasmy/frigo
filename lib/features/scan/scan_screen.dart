import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/loading_receipt_state.dart';
import '../../core/repositories/entitlement_repository.dart';
import '../paywall/paywall_screen.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/motion/success_check.dart';
import '../../shared/motion/motion.dart';
import 'controller/scan_controller.dart';
import 'receipt_confirmation_screen.dart';

/// The whole Scan → Processing → Confirmation → Done flow lives here and is
/// driven entirely by [scanControllerProvider], so there are no navigation
/// races between async steps.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(scanControllerProvider);
      if (s is! ScanIdle) ref.read(scanControllerProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            controller.reset();
            context.pop();
          },
        ),
        title: Text(switch (state) {
          ScanReview() => 'Confirm groceries',
          ScanComplete() => 'Done',
          _ => 'Scan receipt',
        }),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: AppMotion.enter,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(state.runtimeType),
            child: switch (state) {
          ScanIdle() => _IdleView(
              onCamera: () => controller.start(ScanSource.camera),
              onGallery: () => controller.start(ScanSource.gallery),
              onDemo: () => controller.start(ScanSource.demo),
            ),
          ScanProcessing(:final message, :final progress) =>
            LoadingReceiptState(message: message, progress: progress),
          ScanReview() => const ReceiptConfirmationScreen(),
          ScanError(:final message, :final canRetry) => _ErrorView(
              message: message,
              canRetry: canRetry,
              onRetry: controller.retry,
              onAnother: () => controller.start(ScanSource.gallery),
              onManual: () {
                controller.reset();
                context.pop();
                context.push(Routes.manualAdd);
              },
            ),
          ScanQuotaExhausted() => _QuotaView(
              onUpgrade: () async {
                final changed = await PaywallScreen.show(context,
                    reason: PaywallReason.outOfScans);
                if (!context.mounted) return;
                controller.reset();
                // Either a purchase or a rewarded ad can have topped the
                // allowance up, so just re-check rather than assuming.
                if (changed ||
                    ref.read(entitlementProvider).canAiScan) {
                  controller.start(ScanSource.camera);
                }
              },
              onDemo: () => controller.start(ScanSource.demo),
            ),
          ScanComplete(:final addedCount, :final merchant) => _SuccessView(
              addedCount: addedCount,
              merchant: merchant,
              onDone: () {
                controller.reset();
                context.go(Routes.kitchen);
              },
            ),
            },
          ),
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.onCamera,
    required this.onGallery,
    required this.onDemo,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Scan a grocery receipt', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We read the items, tidy up the names and get them ready for your kitchen. '
            'You confirm before anything is added.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: AppRadii.cardLg,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: Container(
                      width: constraints.maxWidth * 0.62,
                      height: constraints.maxHeight * 0.72,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.cardMd,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 44, color: AppColors.textTertiary),
                          SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            child: Text(
                              'Line the receipt up inside the frame',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Take photo',
            icon: Icons.camera_alt_outlined,
            onPressed: onCamera,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Choose from library',
            icon: Icons.photo_library_outlined,
            onPressed: onGallery,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: onDemo,
              child: const Text('Use a sample receipt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onAnother,
    required this.onManual,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onAnother;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 44, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(message, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A clear, flat photo with good light works best.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (canRetry) ...[
            PrimaryButton(label: 'Try again', onPressed: onRetry),
            const SizedBox(height: AppSpacing.md),
          ],
          SecondaryButton(label: 'Choose another photo', onPressed: onAnother),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: onManual,
              child: const Text('Add items manually'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaView extends ConsumerWidget {
  const _QuotaView({required this.onUpgrade, required this.onDemo});
  final VoidCallback onUpgrade;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final ent = ref.watch(entitlementProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FrigoIllustration(FrigoArt.emptyKitchen,
              height: 190, width: double.infinity),
          const SizedBox(height: AppSpacing.lg),
          Text("That's this month's AI scans",
              style: text.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your kitchen, reminders and recipes all keep working. '
            'Scans reset on the 1st.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'See options', onPressed: onUpgrade),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Add items by hand instead',
            onPressed: () => context.pop(),
          ),
          if (ent.bonusScans > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('${ent.bonusScans} bonus scans available',
                  style: text.labelMedium, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.addedCount,
    required this.merchant,
    required this.onDone,
  });

  final int addedCount;
  final String merchant;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SuccessCheck(size: 84)),
          const SizedBox(height: AppSpacing.lg),
          FadeSlideIn(
            index: 4,
            child: Column(
              children: [
                // The count ticks up, so the number is the thing you notice.
                AnimatedCounter(
                  addedCount,
                  suffix: ' item${addedCount == 1 ? '' : 's'} added',
                  style: text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'From your $merchant receipt. Freshness estimates are in place.',
                  style:
                      text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeSlideIn(
            index: 7,
            child: PrimaryButton(label: 'See my kitchen', onPressed: onDone),
          ),
        ],
      ),
    );
  }
}
