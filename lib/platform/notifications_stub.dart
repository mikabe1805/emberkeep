/// No-op notification API for the web build (and any platform without the
/// native plugin). Selected by default in lib/notifications.dart; the native
/// impl swaps in when dart:io is available. Mirrors the native public API so
/// callers never branch on platform.
class Notifications {
  Notifications._();

  static Future<void> init() async {}
  static Future<bool> requestPermission() async => false;
  static Future<void> scheduleDailyNudge(int hour, int minute) async {}
  static Future<void> cancelDailyNudge() async {}
  static Future<void> scheduleEvents(List<EventReminder> events) async {}
  static Future<void> cancelAll() async {}
}

/// One scheduled plan/event reminder (shared shape with the native impl).
class EventReminder {
  const EventReminder(
      {required this.when, required this.title, required this.body});
  final DateTime when;
  final String title;
  final String body;
}
