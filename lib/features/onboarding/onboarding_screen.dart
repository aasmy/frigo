import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_preferences.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/services/ads/tracking_consent.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/frigo_illustration.dart';
import '../../shared/widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;

  static const _slides = [
    (
      art: FrigoArt.onboardingScan,
      title: "Know what's in your kitchen.",
      body: 'Scan grocery receipts and automatically keep track.',
    ),
    (
      art: FrigoArt.onboardingTrack,
      title: 'Waste less food.',
      body: "We'll remind you what should be used first.",
    ),
    (
      art: FrigoArt.onboardingCook,
      title: 'Never ask "What should I cook?" again.',
      body: 'Get meal ideas based on food you already have.',
    ),
  ];

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length) {
      _pager.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  }

  void _finish() {
    ref.read(preferencesProvider.notifier).completeOnboarding();
    context.go(Routes.home);
    // Ask about tracking only now, once the user has seen what Frigo does.
    TrackingConsent.requestIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final total = _slides.length + 1; // + preference step

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final s in _slides)
                    _Slide(art: s.art, title: s.title, body: s.body),
                  const _PreferenceStep(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(3),
                    height: 6,
                    width: i == _page ? 20 : 6,
                    decoration: BoxDecoration(
                      color:
                          i == _page ? AppColors.primary : AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: PrimaryButton(
                label: _page < _slides.length ? 'Continue' : 'Set Up My Kitchen',
                onPressed: _page < _slides.length ? _next : _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.art, required this.title, required this.body});
  final FrigoArt art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            offset: 18,
            child: FrigoIllustration(art, height: 260, width: double.infinity),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeSlideIn(
            index: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.displaySmall),
                const SizedBox(height: AppSpacing.md),
                Text(
                  body,
                  style:
                      text.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceStep extends ConsumerWidget {
  const _PreferenceStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A couple of quick preferences', style: text.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Optional — you can change these later.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          Text('Diet', style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final d in DietPreference.values)
                ChoiceChip(
                  label: Text(d.label),
                  selected: prefs.diet == d,
                  onSelected: (_) =>
                      notifier.update((p) => p.copyWith(diet: d)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Cooking time', style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in MaxCookingTime.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: prefs.maxCookingTime == t,
                  onSelected: (_) =>
                      notifier.update((p) => p.copyWith(maxCookingTime: t)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
