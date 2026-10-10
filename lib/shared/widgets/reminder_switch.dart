import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notifications/notification_scheduler.dart';
import '../../core/theme/app_colors.dart';

/// A reminder toggle that asks the OS for permission the moment it is switched
/// on — never at launch — and quietly reverts if the user says no.
class ReminderSwitch extends ConsumerWidget {
  const ReminderSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: (v) async {
        if (!v) {
          onChanged(false);
          return;
        }
        final granted =
            await ref.read(notificationSchedulerProvider).requestPermission();
        if (granted) {
          onChanged(true);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Notifications are off for Frigo. Turn them on in system settings.'),
            ),
          );
        }
      },
    );
  }
}
