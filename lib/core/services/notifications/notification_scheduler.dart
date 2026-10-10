import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/inventory_item.dart';
import '../../models/user_preferences.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/preferences_repository.dart';
import 'local_notification_service.dart';
import 'notification_service.dart';

/// Keeps the two scheduled reminders in step with the kitchen.
///
/// Reminder *text* is baked in at schedule time, so it has to be refreshed
/// whenever inventory or preferences change — otherwise the 5:30pm summary
/// would describe last week's fridge.
class NotificationScheduler {
  NotificationScheduler(this._service);

  final LocalNotificationService _service;
  String? _lastSignature;

  Future<void> sync({
    required UserPreferences prefs,
    required List<InventoryItem> inventory,
  }) async {
    if (!AppConfig.notificationsEnabled) return;

    final expiryBody = NotificationCopy.expirySummary(inventory);
    final cookBody = NotificationCopy.cookIdea(inventory);
    final signature = [
      prefs.expiryNotifications,
      prefs.dailyCookIdea,
      expiryBody ?? '',
      cookBody,
    ].join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    try {
      if (prefs.expiryNotifications && expiryBody != null) {
        await _service.scheduleExpirySummary(expiryBody);
      } else {
        await _service.cancelExpirySummary();
      }

      if (prefs.dailyCookIdea) {
        await _service.scheduleDailyCookIdea(cookBody);
      } else {
        await _service.cancelDailyCookIdea();
      }
    } catch (e) {
      debugPrint('notification sync: $e');
    }
  }

  /// Called when a switch is turned on, so the OS prompt has context.
  Future<bool> requestPermission() => _service.requestPermission();
}

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => NotificationScheduler(LocalNotificationService.instance),
);

/// Invisible widget that mirrors app state into the OS scheduler.
class NotificationSync extends ConsumerWidget {
  const NotificationSync({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final inventory = ref.watch(inventoryProvider);
    final scheduler = ref.watch(notificationSchedulerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduler.sync(prefs: prefs, inventory: inventory);
    });

    return child;
  }
}
