import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Native (iOS/Android) local-notification scheduling. Selected by the
/// conditional export in lib/notifications.dart when dart:io is available;
/// the web build uses the no-op stub instead and never compiles this file.
class Notifications {
  Notifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const int _dailyId = 1000;
  static const int _eventBase = 2000; // event reminders use 2000..2063
  static const int _eventSlots = 64;

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Notifications tz init (continuing): $e');
    }
    const ios = DarwinInitializationSettings(
      // we request explicitly when the user turns reminders on
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    try {
      await _plugin.initialize(
          const InitializationSettings(iOS: ios, android: android));
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init (continuing): $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
            alert: true, badge: true, sound: true);
        return granted ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Notifications permission (continuing): $e');
    }
    return false;
  }

  static NotificationDetails _details() => const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: AndroidNotificationDetails(
          'emberkeep_reminders',
          'Reminders',
          channelDescription: 'Quest reminders and plan nudges',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> scheduleDailyNudge(int hour, int minute) async {
    await init();
    try {
      await _plugin.cancel(_dailyId);
      await _plugin.zonedSchedule(
        _dailyId,
        'Your quests are waiting',
        'One small win before the day gets away from you 🔥',
        _nextInstanceOfTime(hour, minute),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Notifications daily nudge (continuing): $e');
    }
  }

  static Future<void> cancelDailyNudge() async {
    await init();
    try {
      await _plugin.cancel(_dailyId);
    } catch (_) {/* best effort */}
  }

  /// Clears the event-reminder window and re-schedules the upcoming ones.
  static Future<void> scheduleEvents(List<EventReminder> events) async {
    await init();
    try {
      for (var i = 0; i < _eventSlots; i++) {
        await _plugin.cancel(_eventBase + i);
      }
      final now = tz.TZDateTime.now(tz.local);
      var slot = 0;
      for (final e in events) {
        if (slot >= _eventSlots) break;
        final when = tz.TZDateTime.from(e.when, tz.local);
        if (!when.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          _eventBase + slot,
          e.title,
          e.body,
          when,
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        slot++;
      }
    } catch (e) {
      debugPrint('Notifications events (continuing): $e');
    }
  }

  static Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {/* best effort */}
  }
}

/// One scheduled plan/event reminder (shared shape with the stub).
class EventReminder {
  const EventReminder(
      {required this.when, required this.title, required this.body});
  final DateTime when;
  final String title;
  final String body;
}
