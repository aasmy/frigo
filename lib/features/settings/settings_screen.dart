import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../core/services/ads/ads_config.dart';
import '../../core/services/ads/ads_service.dart';
import '../../core/services/ai/llm_client.dart';
import '../../core/repositories/entitlement_repository.dart';
import '../paywall/paywall_screen.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/preferences_repository.dart';
import '../../core/repositories/receipt_repository.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatting.dart';
import '../../core/services/ai/ai_health.dart';
import '../../shared/motion/motion.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/reminder_switch.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final inventory = ref.watch(inventoryProvider);
    final receipts = ref.watch(receiptsProvider);
    final text = Theme.of(context).textTheme;
    final aiOn = ref.watch(assistantAvailableProvider);
    final ent = ref.watch(entitlementProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileTile(
              name: prefs.displayName,
              subtitle: '${inventory.length} items · ${receipts.length} receipts',
              onEdit: () => _editName(context, ref, prefs.displayName),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProBanner(
              isPro: ent.isPro,
              summary: ent.summary,
              onTap: () => PaywallScreen.show(
                context,
                reason: ent.isPro
                    ? PaywallReason.browse
                    : PaywallReason.removeAds,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Kitchen', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _Group(children: [
              _NavTile(
                icon: Icons.tune,
                label: 'Preferences',
                subtitle: '${prefs.diet.label} · ${prefs.maxCookingTime.label}',
                onTap: () => context.push(Routes.preferences),
              ),
              _NavTile(
                icon: Icons.add_circle_outline,
                label: 'Add an item manually',
                onTap: () => context.push(Routes.manualAdd),
              ),
              _NavTile(
                icon: Icons.shopping_cart_outlined,
                label: 'Shopping list',
                onTap: () => context.push(Routes.shoppingList),
              ),
              _NavTile(
                icon: Icons.receipt_long_outlined,
                label: 'Receipt history',
                subtitle: '${receipts.length} scanned',
                onTap: () => context.push(Routes.receiptHistory),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Text('Notifications', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _Group(children: [
              ReminderSwitch(
                icon: Icons.notifications_none_rounded,
                title: 'Expiry reminders',
                subtitle: 'One 5:30pm summary, not constant pings',
                value: prefs.expiryNotifications,
                onChanged: (v) => ref
                    .read(preferencesProvider.notifier)
                    .update((p) => p.copyWith(expiryNotifications: v)),
              ),
              ReminderSwitch(
                icon: Icons.local_dining_outlined,
                title: 'Daily "what to cook" idea',
                subtitle: 'A 6:00pm nudge built from your kitchen',
                value: prefs.dailyCookIdea,
                onChanged: (v) => ref
                    .read(preferencesProvider.notifier)
                    .update((p) => p.copyWith(dailyCookIdea: v)),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _Group(children: [
              _NavTile(
                icon: aiOn ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                label: aiOn ? 'Ask Frigo (AI assistant)' : 'AI assistant',
                subtitle: aiOn
                    ? 'Chat about your kitchen, recipes and plans'
                    : 'Pick an AI provider below to enable chat',
                onTap: aiOn ? () => context.push(Routes.assistant) : () {},
              ),
              _NavTile(
                icon: Icons.memory_outlined,
                label: 'AI provider',
                subtitle: prefs.aiProvider.label,
                onTap: () => _pickProvider(context, ref, prefs.aiProvider),
              ),
              if (aiOn)
                ListenableBuilder(
                  listenable: AiHealth.instance,
                  builder: (context, _) {
                    final h = AiHealth.instance;
                    final bad = h.degraded;
                    return ListTile(
                      leading: Icon(
                        bad ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                        color: bad ? AppColors.useSoon : AppColors.fresh,
                      ),
                      title: Text(bad ? 'AI running offline' : 'AI connected'),
                      subtitle: Text(
                        h.statusDetail ??
                            (h.lastSuccessAt == null
                                ? 'Gemini key set — not used yet'
                                : 'Last response ${Fmt.relativeTime(h.lastSuccessAt!)}'),
                      ),
                    );
                  },
                ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            Text('Privacy & data', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your kitchen, receipts and preferences stay on this device. '
              'Receipt images are sent to your chosen AI provider only to pull '
              'out the grocery items, and you can delete them any time.',
              style: text.labelMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Group(children: [
              // GDPR requires the consent choice to stay changeable, not just
              // be asked once on first launch.
              if (AdsConfig.enabled)
                FutureBuilder<bool>(
                  future: AdsService.instance.privacyOptionsRequired,
                  builder: (context, snap) => snap.data == true
                      ? _NavTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Ad privacy choices',
                          subtitle: 'Change what ads may use',
                          onTap: AdsService.instance.showPrivacyOptions,
                        )
                      : const SizedBox.shrink(),
                ),
              if (AdsConfig.enabled && AdsConfig.usingTestUnits)
                const ListTile(
                  leading: Icon(Icons.science_outlined,
                      color: AppColors.useSoon),
                  title: Text('Test ads'),
                  subtitle: Text(
                      'This build serves Google test ads and earns nothing. '
                      'Pass your AdMob unit IDs at build time to go live.'),
                ),
              _NavTile(
                icon: Icons.delete_sweep_outlined,
                label: 'Delete all receipts',
                destructive: true,
                onTap: () => _run(context, ref,
                    title: 'Delete all receipts?',
                    message: 'Kitchen items already added will stay.', action: () {
                  for (final r in [...ref.read(receiptsProvider)]) {
                    ref.read(receiptsProvider.notifier).delete(r.id);
                  }
                }),
              ),
              _NavTile(
                icon: Icons.kitchen_outlined,
                label: 'Clear kitchen inventory',
                destructive: true,
                onTap: () => _run(context, ref,
                    title: 'Clear your kitchen?',
                    message: 'Every tracked item will be removed.', action: () {
                  for (final i in [...ref.read(inventoryProvider)]) {
                    ref.read(inventoryProvider.notifier).removeItem(i.id);
                  }
                }),
              ),
              _NavTile(
                icon: Icons.restart_alt,
                label: 'Reset to demo data',
                onTap: () => _run(context, ref,
                    title: 'Reset to demo data?',
                    message: 'Replaces your kitchen with the sample inventory.',
                    confirmLabel: 'Reset',
                    action: () =>
                        ref.read(inventoryProvider.notifier).resetToDemo()),
              ),
              _NavTile(
                icon: Icons.person_off_outlined,
                label: 'Delete account',
                destructive: true,
                onTap: () => _run(context, ref,
                    title: 'Delete account?',
                    message:
                        'This clears all local data on this device. In the full app this also removes your server data.',
                    action: () {
                  for (final i in [...ref.read(inventoryProvider)]) {
                    ref.read(inventoryProvider.notifier).removeItem(i.id);
                  }
                  for (final r in [...ref.read(receiptsProvider)]) {
                    ref.read(receiptsProvider.notifier).delete(r.id);
                  }
                  ref.read(preferencesProvider.notifier).reset();
                }),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),
            Center(child: Text('Frigo · MVP build', style: text.labelSmall)),
          ],
        ),
      ),
    );
  }

  /// Every option here still leaves the app fully usable — the offline
  /// pipeline is the floor, not a failure mode.
  Future<void> _pickProvider(
    BuildContext context,
    WidgetRef ref,
    AiProvider current,
  ) async {
    final chosen = await showModalBottomSheet<AiProvider>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text('AI provider',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            RadioGroup<AiProvider>(
              groupValue: current,
              onChanged: (v) => Navigator.pop(context, v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in AiProvider.values)
                    RadioListTile<AiProvider>(
                      value: p,
                      enabled: providerConfigured(p),
                      title: Text(p.label),
                      subtitle: Text(
                        providerConfigured(p)
                            ? p.blurb
                            : 'No credential set — add one in secrets.dart',
                      ),
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(aiProvider: chosen));
    }
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) {
      ref
          .read(preferencesProvider.notifier)
          .setDisplayName(result.isEmpty ? null : result);
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required VoidCallback action,
    String confirmLabel = 'Delete',
  }) async {
    final ok = await confirmDestructive(context,
        title: title, message: message, confirmLabel: confirmLabel);
    if (!ok) return;
    action();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Done')));
    }
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.name,
    required this.onEdit,
    this.subtitle,
  });
  final String? name;
  final String? subtitle;
  final VoidCallback onEdit;

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
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : 'Guest',
                  style: text.titleMedium,
                ),
                if (subtitle != null)
                  Text(subtitle!, style: text.labelMedium),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

/// Upgrade entry point. Reads as a status line once the user is Pro, so it
/// stops selling to someone who already bought.
class _ProBanner extends StatelessWidget {
  const _ProBanner({
    required this.isPro,
    required this.summary,
    required this.onTap,
  });

  final bool isPro;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PressFeedback(
      child: Material(
        color: isPro ? AppColors.surface : AppColors.primary,
        borderRadius: AppRadii.cardLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardLg,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardLg,
              border: Border.all(
                  color: isPro ? AppColors.divider : AppColors.primary),
            ),
            child: Row(
              children: [
                Icon(
                  isPro ? Icons.verified_rounded : Icons.auto_awesome,
                  color: isPro ? AppColors.fresh : AppColors.onPrimary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPro ? 'Frigo Pro' : 'Upgrade to Frigo Pro',
                        style: text.titleMedium?.copyWith(
                          color: isPro
                              ? AppColors.textPrimary
                              : AppColors.onPrimary,
                        ),
                      ),
                      Text(
                        summary,
                        style: text.labelMedium?.copyWith(
                          color: isPro
                              ? AppColors.textSecondary
                              : AppColors.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: isPro
                        ? AppColors.textTertiary
                        : AppColors.onPrimary.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardLg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.expired : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon,
          color: destructive ? AppColors.expired : AppColors.textSecondary),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}
