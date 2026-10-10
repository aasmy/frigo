import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/service_providers.dart';
import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';
import '../paywall/paywall_screen.dart';
import '../../shared/widgets/frigo_logo.dart';
import 'assistant_controller.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final t = (preset ?? _input.text).trim();
    if (t.isEmpty) return;
    Haptics.light();
    _input.clear();
    ref.read(assistantProvider.notifier).send(t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 240,
            duration: AppMotion.base, curve: AppMotion.enter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantProvider);
    final text = Theme.of(context).textTheme;
    final available = ref.watch(assistantAvailableProvider);
    final showPrompts = messages.length <= 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Frigo'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () => ref.read(assistantProvider.notifier).reset(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                children: [
                  for (final m in messages) _Bubble(message: m),
                  if (showPrompts) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final p in AssistantController.suggestedPrompts)
                          ActionChip(
                            label: Text(p),
                            onPressed: available ? () => _send(p) : null,
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.divider),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!available)
              Container(
                width: double.infinity,
                color: AppColors.useSoonSoft,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.useSoon),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Add a Gemini key in Profile to chat.',
                        style: text.labelMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(Routes.settings),
                      child: const Text('Profile'),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: available,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your kitchen…',
                        filled: true,
                        fillColor: AppColors.surfaceTint,
                        border: OutlineInputBorder(
                          borderRadius: AppRadii.pillAll,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: available ? () => _send() : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = message.fromUser;

    final bubble = Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: user
            ? AppColors.primary
            : message.failed
                ? AppColors.expiredSoft
                : message.quotaBlocked
                    ? AppColors.primarySoft
                    : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(user ? 16 : 4),
          bottomRight: Radius.circular(user ? 4 : 16),
        ),
        border: user ? null : Border.all(color: AppColors.divider),
      ),
      child: message.pending
          ? const _Typing()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.text,
                  style: text.bodyMedium?.copyWith(
                    color: user ? AppColors.onPrimary : AppColors.textPrimary,
                  ),
                ),
                if (message.quotaBlocked)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => PaywallScreen.show(context,
                          reason: PaywallReason.outOfAssistant),
                      child: const Text('See Frigo Pro'),
                    ),
                  ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[
            const FrigoLogo(size: 26),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value + i * 0.2) % 1);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2),
                child: const CircleAvatar(
                    radius: 3, backgroundColor: AppColors.textSecondary),
              ),
            );
          }),
        ),
      ),
    );
  }
}
