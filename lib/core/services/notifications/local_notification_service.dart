import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Real scheduling backend for the two reminders Frigo promises.
///
/// Policy over volume: at most two notifications a day — one expiry summary
/// and one cook idea — both delivered in the early evening, when there is
/// still time to actually do something about them.
class LocalNotificationService implements NotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _expiryId = 1001;
  static const _cookId = 1002;

  /// 5:30pm and 6:00pm local — after work, before dinner is decided.
  static const _expiryHour = 17, _expiryMinute = 30;
  static const _cookHour = 18, _cookMinute = 0;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _permitted = false;

  bool get permitted => _permitted;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Unknown zone name — fall back to UTC so scheduling still works.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );
    _ready = true;
  }

  /// Asks for permission the first time a reminder is switched on — never at
  /// launch, so the prompt always has visible context.
  Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _permitted = await android.requestNotificationsPermission() ?? false;
        return _permitted;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _permitted =
            await ios.requestPermissions(alert: true, badge: true, sound: true) ??
                false;
        return _permitted;
      }
    } catch (e) {
      debugPrint('notification permission: $e');
    }
    _permitted = true; // desktop / test platforms
    return _permitted;
  }

  @override
  Future<void> scheduleExpirySummary(String body, {DateTime? when}) =>
      _daily(_expiryId, 'Use these soon', body, _expiryHour, _expiryMinute,
          channel: 'expiry',
          channelName: 'Expiry reminders',
          channelDescription:
              'One evening summary of what is about to go off.');

  @override
  Future<void> scheduleDailyCookIdea(String body) =>
      _daily(_cookId, "Tonight's idea", body, _cookHour, _cookMinute,
          channel: 'cook_idea',
          channelName: 'Daily cook idea',
          channelDescription: 'A dinner suggestion built from your kitchen.');

  Future<void> cancelExpirySummary() => _cancel(_expiryId);
  Future<void> cancelDailyCookIdea() => _cancel(_cookId);

  @override
  Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('cancelAll: $e');
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _cancel(int id) async {
    await init();
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('cancel $id: $e');
    }
  }

  Future<void> _daily(
    int id,
    String title,
    String body,
    int hour,
    int minute, {
    required String channel,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextOccurrence(hour, minute),
        details,
        // Inexact keeps us off the SCHEDULE_EXACT_ALARM permission, which
        // Android 14 gates behind a settings screen. A reminder does not need
        // to land on the exact second.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('schedule $id: $e');
    }
  }

  tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}
