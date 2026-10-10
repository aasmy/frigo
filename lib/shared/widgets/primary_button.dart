import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// The single filled call-to-action — warm ink, with a soft press-in.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final child = widget.loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(widget.label, overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final button = AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: AppMotion.fast,
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        child: FilledButton(
          onPressed: _enabled
              ? () {
                  Haptics.light();
                  widget.onPressed!();
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
            disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.6),
            minimumSize: const Size(0, 54),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            textStyle: Theme.of(context).textTheme.labelLarge,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardMd),
          ),
          child: child,
        ),
      ),
    );

    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Quiet outline button for secondary actions.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed == null
          ? null
          : () {
              Haptics.tap();
              onPressed!();
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: AppColors.dividerStrong),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        textStyle: Theme.of(context).textTheme.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
