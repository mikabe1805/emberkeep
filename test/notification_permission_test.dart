import 'package:emberkeep/engine.dart';
import 'package:emberkeep/notifications.dart';
import 'package:emberkeep/platform/notifications_stub.dart' as stub;
import 'package:emberkeep/screens/shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('denied system permission clears both enabled reminder preferences', () {
    final state = GameState()
      ..setNotify(enabled: true, hour: 8, minute: 30)
      ..setNightReminder(enabled: true, hour: 21, minute: 45);
    var changes = 0;
    state.addListener(() => changes++);

    state.disableRemindersWithoutPermission();

    expect(state.notifyEnabled, isFalse);
    expect(state.nightReminderEnabled, isFalse);
    expect(changes, 1);

    final restored = GameState.fromJson(state.toJson());
    expect(restored.notifyEnabled, isFalse);
    expect(restored.nightReminderEnabled, isFalse);
  });

  test('clearing already-disabled reminder preferences is a no-op', () {
    final state = GameState();
    var changes = 0;
    state.addListener(() => changes++);

    state.disableRemindersWithoutPermission();

    expect(changes, 0);
  });

  test(
    'unsupported notification facades report permission as unknown',
    () async {
      expect(
        await stub.Notifications.permissionStatus(),
        stub.ReminderPermissionStatus.unknown,
      );
      if (!Notifications.isSupported) {
        expect(
          await Notifications.permissionStatus(),
          ReminderPermissionStatus.unknown,
        );
      }
    },
  );

  test('unknown permission preserves enabled reminder preferences', () async {
    final state = GameState()
      ..setNotify(enabled: true, hour: 8, minute: 30)
      ..setNightReminder(enabled: true, hour: 21, minute: 45);
    final permission = await stub.Notifications.permissionStatus();

    if (permission == stub.ReminderPermissionStatus.denied) {
      state.disableRemindersWithoutPermission();
    }

    expect(permission, stub.ReminderPermissionStatus.unknown);
    expect(state.notifyEnabled, isTrue);
    expect(state.nightReminderEnabled, isTrue);
  });

  test('night reminder suppression follows the next occurrence owner', () {
    final tuesdayEarly = DateTime(2026, 8, 4, 1);
    expect(
      nextNightReminderOccurrence(tuesdayEarly, 2, 0),
      DateTime(2026, 8, 4, 2),
    );
    expect(
      shouldSuppressNextNightReminder(
        now: tuesdayEarly,
        hour: 2,
        minute: 0,
        nightDoneDay: '2026-08-03',
      ),
      isTrue,
      reason: 'Tuesday 02:00 still belongs to Monday\'s night routine',
    );
    expect(
      shouldSuppressNextNightReminder(
        now: DateTime(2026, 8, 4, 3),
        hour: 21,
        minute: 0,
        nightDoneDay: '2026-08-03',
      ),
      isFalse,
      reason: 'Tuesday evening belongs to Tuesday and must stay scheduled',
    );
    expect(
      shouldSuppressNextNightReminder(
        now: DateTime(2026, 8, 4, 20),
        hour: 21,
        minute: 0,
        nightDoneDay: '2026-08-04',
      ),
      isTrue,
    );
    expect(
      shouldSuppressNextNightReminder(
        now: DateTime(2026, 8, 4, 22),
        hour: 2,
        minute: 0,
        nightDoneDay: '2026-08-04',
      ),
      isTrue,
      reason: 'Wednesday 02:00 still belongs to Tuesday\'s routine',
    );
    expect(
      shouldSuppressNextNightReminder(
        now: DateTime(2026, 8, 4, 22),
        hour: 21,
        minute: 0,
        nightDoneDay: '2026-08-04',
      ),
      isFalse,
      reason: 'the next occurrence is Wednesday evening',
    );
  });
}
