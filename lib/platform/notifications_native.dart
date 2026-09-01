import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum ReminderPermissionStatus { granted, denied, unknown }

/// Native (iOS/Android) local-notification scheduling. Selected by the
/// conditional export in lib/notifications.dart when dart:io is available;
/// the web build uses the no-op stub instead and never compiles this file.
class Notifications {
  Notifications._();

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _timeZonesLoaded = false;

  static const int _dailyId = 1000;
  static const int _nightId = 1001;
  static const int _eventBase = 2000; // event reminders use 2000..2063
  static const int _eventCancelSlots = 64;
  // iOS retains at most 64 pending local notifications. Reserve two slots for
  // the morning and night recurring reminders, then use the rest for plans.
  static const int _eventScheduleSlots = 62;

  static Future<void> _refreshLocalTimeZone() async {
    if (!_timeZonesLoaded) {
      tzdata.initializeTimeZones();
      _timeZonesLoaded = true;
    }
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name));
  }

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _refreshLocalTimeZone();
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
        const InitializationSettings(iOS: ios, android: android),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init (continuing): $e');
    }
    // Android bakes a channel's sound at creation, so the room's reminder
    // voice ships on the v2 channel; drop the old default-sound channel so
    // settings don't show two entries both named Reminders.
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel('emberkeep_reminders');
    } catch (e) {
      debugPrint('Notifications channel cleanup (continuing): $e');
    }
  }

  /// Refreshes the wall-clock zone after the app resumes. A phone may travel
  /// while the process is parked; recurring reminders should follow it.
  static Future<void> refreshTimeZone() async {
    try {
      await _refreshLocalTimeZone();
    } catch (e) {
      debugPrint('Notifications tz refresh (continuing): $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Notifications permission (continuing): $e');
    }
    return false;
  }

  /// Reads the current system permission without showing a prompt.
  ///
  /// This is deliberately separate from [requestPermission]: launch, restore,
  /// and resume paths may verify an enabled preference, but only an explicit
  /// user toggle should be able to open the operating-system permission sheet.
  static Future<ReminderPermissionStatus> permissionStatus() async {
    if (!isSupported) return ReminderPermissionStatus.unknown;
    await init();
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final permissions = await ios.checkPermissions();
        if (permissions == null) return ReminderPermissionStatus.unknown;
        return permissions.isEnabled == true ||
                permissions.isProvisionalEnabled == true
            ? ReminderPermissionStatus.granted
            : ReminderPermissionStatus.denied;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == null) return ReminderPermissionStatus.unknown;
        return enabled
            ? ReminderPermissionStatus.granted
            : ReminderPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('Notifications permission check (continuing): $e');
    }
    return ReminderPermissionStatus.unknown;
  }

  /// Every reminder speaks the room's own voice: "two knocks, rising"
  /// (room-notification-voice-v1, owner-selected 2026-08-25), byte-identical
  /// to the audition master on both platforms and byte-locked by test.
  static NotificationDetails _details() => const NotificationDetails(
    iOS: DarwinNotificationDetails(sound: 'knock_paced.wav'),
    android: AndroidNotificationDetails(
      'emberkeep_reminders_v2',
      'Reminders',
      channelDescription: 'Quest, plan, and night routine reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      sound: RawResourceAndroidNotificationSound('knock_paced'),
    ),
  );

  static tz.TZDateTime _nextInstanceOfTime(
    int hour,
    int minute, {
    bool skipNext = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      // Construct the next calendar day in the local zone. Adding 24 hours
      // drifts the displayed time across daylight-saving boundaries.
      scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    if (skipNext) {
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day + 1,
        hour,
        minute,
      );
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
        'One small win before the day gets away from you.',
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
    } catch (_) {
      /* best effort */
    }
  }

  static Future<void> scheduleNightRoutine(
    int hour,
    int minute, {
    bool skipNext = false,
  }) async {
    await init();
    try {
      await _plugin.cancel(_nightId);
      await _plugin.zonedSchedule(
        _nightId,
        'Close the day when you’re ready',
        'See what you finished, keep anything worth remembering, and set up tomorrow.',
        _nextInstanceOfTime(hour, minute, skipNext: skipNext),
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Notifications night routine (continuing): $e');
    }
  }

  static Future<void> cancelNightRoutine() async {
    await init();
    try {
      await _plugin.cancel(_nightId);
    } catch (_) {
      /* best effort */
    }
  }

  /// Clears the event-reminder window and re-schedules the upcoming ones.
  static Future<void> scheduleEvents(List<EventReminder> events) async {
    await init();
    try {
      for (var i = 0; i < _eventCancelSlots; i++) {
        await _plugin.cancel(_eventBase + i);
      }
      final now = tz.TZDateTime.now(tz.local);
      var slot = 0;
      final ordered = [...events]..sort((a, b) => a.when.compareTo(b.when));
      for (final e in ordered) {
        if (slot >= _eventScheduleSlots) break;
        final when = e.absolute
            ? tz.TZDateTime.from(e.when.toUtc(), tz.local)
            : tz.TZDateTime(
                tz.local,
                e.when.year,
                e.when.month,
                e.when.day,
                e.when.hour,
                e.when.minute,
              );
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

  static Future<void> cancelEvents() async {
    await init();
    try {
      for (var i = 0; i < _eventCancelSlots; i++) {
        await _plugin.cancel(_eventBase + i);
      }
    } catch (_) {
      /* best effort */
    }
  }

  static Future<void> cancelAll() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {
      /* best effort */
    }
  }
}

/// One scheduled plan/event reminder (shared shape with the stub).
class EventReminder {
  const EventReminder({
    required this.when,
    required this.title,
    required this.body,
    this.absolute = false,
  });
  final DateTime when;
  final String title;
  final String body;

  /// Absolute instants keep class reminders attached to the class even when
  /// the phone is temporarily in another time zone. Ordinary dated plans use
  /// local wall-clock construction instead.
  final bool absolute;
}
