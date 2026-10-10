import '../../models/inventory_item.dart';

/// MVP notification surface.
///
/// The scheduling backend (flutter_local_notifications / FCM) is intentionally
/// stubbed — what matters for the MVP is the *policy*: one useful summary
/// rather than a stream of individual alerts.
abstract interface class NotificationService {
  Future<void> scheduleExpirySummary(String body, {DateTime? when});
  Future<void> scheduleDailyCookIdea(String body);
  Future<void> cancelAll();
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> scheduleExpirySummary(String body, {DateTime? when}) async {}

  @override
  Future<void> scheduleDailyCookIdea(String body) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Builds the single daily summary line from current inventory.
class NotificationCopy {
  const NotificationCopy._();

  static String? expirySummary(List<InventoryItem> inventory) {
    final soon = inventory
        .where((i) => (i.daysUntilExpiration ?? 999) <= 2)
        .toList();
    if (soon.isEmpty) return null;
    if (soon.length == 1) {
      return 'Your ${soon.first.displayName.toLowerCase()} should be used soon.';
    }
    final fridge = soon
        .where((i) => i.storageLocation.name == 'fridge')
        .length;
    if (fridge >= 2) {
      return '$fridge items in your fridge should be used soon.';
    }
    return '${soon.length} items in your kitchen should be used soon.';
  }

  static String cookIdea(List<InventoryItem> inventory) {
    final soon = inventory
        .where((i) => (i.daysUntilExpiration ?? 999) <= 2)
        .map((i) => i.displayName.toLowerCase())
        .take(2)
        .toList();
    if (soon.isEmpty) return 'Not sure what to cook tonight? Tap for 3 ideas.';
    return 'Your ${soon.join(' and ')} should be used soon. Here are 3 ideas.';
  }
}
