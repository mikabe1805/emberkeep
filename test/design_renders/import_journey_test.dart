// Renders the "Add your classes" journey in the real app at iPhone size:
// the Plans doorway, the three ways in, the shared review, the result with
// its class-reminder choice, two-term and busy-only calendars, the plain
// messages, and a small phone at large text.
//
// Run: flutter test --dart-define=CLASS_DAY_RENDERS=true \
//        test/design_renders/import_journey_test.dart
//
// Frames go to design/comparisons/2026-10-03/class-day/build/import/ in this
// worktree. Sheet: python test/design_renders/import_sheet.py <dir> <png>.
import 'package:emberkeep/academic_calendar/import/calendar_link.dart';
import 'package:emberkeep/screens/calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// The plugin hides its platform base class, which is what holds the
// registered implementation this file swaps for a test and puts back. It
// arrives with flutter_local_notifications, so no new dependency.
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/calendar_export_samples.dart';
import '../support/rutgers_fall_2026_ics_fixture.dart';
import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('CLASS_DAY_RENDERS');
final _out = classDayDir('build/import');

final class _FakeFetcher implements CalendarLinkFetcher {
  _FakeFetcher(this.body);
  final String body;
  @override
  Future<String> fetch(CalendarLink link) async => checkCalendarText(body);
}

const _filesChannel = MethodChannel('room_of_days/academic_schedule_files');
const _notificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(
      tester.element(finder.first),
      alignment: 0.5,
    );
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 500));
  }
  final target = finder.hitTestable().evaluate().isEmpty
      ? finder.first
      : finder.hitTestable().first;
  await tester.tap(target, warnIfMissed: false);
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

/// Plans ends on the doorway (after the day, never above it): scroll there.
Future<void> _toDoorway(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _key('add-classes-doorway'),
    260,
    scrollable: find
        .descendant(
          of: find.byType(CalendarPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.drag(
    find
        .descendant(
          of: find.byType(CalendarPage),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -400),
  );
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _scrollSheet(WidgetTester tester, double dy) async {
  final scroll = find
      .descendant(
        of: _key('add-classes-sheet'),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.drag(scroll, Offset(0, -dy));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 700));
}

/// Pastes [link] and reads [body] as if the calendar host had served it.
Future<void> _readLink(
  WidgetTester tester, {
  required String link,
  required String body,
}) async {
  await _tap(tester, _key('add-classes-link'));
  await tester.enterText(_key('add-classes-link-field'), link);
  await tester.pump();
  debugCalendarLinkFetcherOverride = _FakeFetcher(body);
  try {
    await _tap(tester, _key('add-classes-read-link'));
  } finally {
    debugCalendarLinkFetcherOverride = null;
  }
}

/// flutter_tester registers no notifications plugin. Registers the iOS one,
/// answering [answer] on its channel, and when the test ends puts back what
/// was registered before. Nothing was, the first time, and an unset platform
/// cannot be unset again, so an inert stand-in takes its place: later tests
/// in this file boot with no iOS plugin and no channel answers, as before.
void _useIosNotifications(Future<Object?> Function(MethodCall call) answer) {
  FlutterLocalNotificationsPlatform? previous;
  try {
    previous = FlutterLocalNotificationsPlatform.instance;
  } on Error {
    previous = null;
  }
  IOSFlutterLocalNotificationsPlugin.registerWith();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_notificationsChannel, answer);
  addTearDown(() {
    messenger.setMockMethodCallHandler(_notificationsChannel, null);
    FlutterLocalNotificationsPlatform.instance =
        previous ?? _NoNotificationsPlugin();
  });
}

final class _NoNotificationsPlugin extends FlutterLocalNotificationsPlatform {}

/// iPhone SE (1st gen): 320 x 568 pt at 2x, 20 pt status bar, at 130% text.
void _smallPhoneLargeText(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(640, 1136);
  tester.view.padding = const FakeViewPadding(top: 40);
  tester.view.viewPadding = const FakeViewPadding(top: 40);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  // flutter_tester answers unmocked platform channels on real time, which a
  // pumped (fake-time) test never reaches; answer the device zone directly.
  const zoneChannel = MethodChannel('flutter_timezone');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, (call) async {
          return call.method == 'getLocalTimezone' ? 'America/New_York' : null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(zoneChannel, null);
  });
  final sheet = FrameSheet(_out);
  // tearDownAll runs even when every test here skips: only a render run may
  // write, or a plain `flutter test` leaves frames.json in the checkout.
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  // Sunday evening, the week before classes get counted: a student sets up.
  final at = DateTime(2026, 10, 4, 19, 30);

  roomRenderTest('import: a calendar link, review, result', skip: !_renders, (
    tester,
  ) async {
    // The notification prompt answers yes, so the reminder choice can be
    // shown turned on.
    _useIosNotifications((call) async {
      return switch (call.method) {
        'initialize' || 'requestPermissions' => true,
        'checkPermissions' => const <String, bool>{
          'isEnabled': true,
          'isAlertEnabled': true,
          'isBadgeEnabled': true,
          'isSoundEnabled': true,
          'isProvisionalEnabled': false,
          'isCriticalEnabled': false,
        },
        'pendingNotificationRequests' ||
        'getActiveNotifications' => const <Object?>[],
        _ => null,
      };
    });
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await settle(tester, total: const Duration(milliseconds: 1200));
    await _toDoorway(tester);
    await sheet.shot(
      tester,
      'I01_plans_no_classes',
      at: at,
      surface: 'Plans, no classes yet, scrolled to the end',
      note: 'the calm doorway after the day; ADD offers it at the top',
    );

    await _tap(tester, _key('add-classes-doorway'));
    await sheet.shot(
      tester,
      'I02_add_your_classes',
      at: at,
      surface: 'Add your classes, the ways in',
    );

    await _tap(tester, _key('add-classes-help'));
    await _scrollSheet(tester, 400);
    await sheet.shot(
      tester,
      'I03_where_do_i_find_mine',
      at: at,
      surface: 'Add your classes, help open',
    );
    await _scrollSheet(tester, -600);

    await _tap(tester, _key('add-classes-link'));
    await tester.enterText(
      _key('add-classes-link-field'),
      'https://calendar.google.com/calendar/ical/jordan.lee.uiuc%40gmail.com/private-8f2c41d9a7e0b3c5/basic.ics',
    );
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 500));
    await sheet.shot(
      tester,
      'I04_paste_link',
      at: at,
      surface: 'Calendar link, pasted',
      note: 'a Google secret iCal address (invented)',
    );

    debugCalendarLinkFetcherOverride = _FakeFetcher(
      googleCalendarStudentExport(),
    );
    try {
      await _tap(tester, _key('add-classes-read-link'));
    } finally {
      debugCalendarLinkFetcherOverride = null;
    }
    await sheet.shot(
      tester,
      'I05_review_top',
      at: at,
      surface: 'Pick your classes',
      note: 'Google Calendar export: 4 courses checked, everyday life left out',
    );
    await _scrollSheet(tester, 520);
    await _tap(tester, _key('add-classes-others'));
    await _scrollSheet(tester, 600);
    await sheet.shot(
      tester,
      'I06_review_not_classes',
      at: at,
      surface: 'Pick your classes, scrolled',
      note: 'probably not classes, opened: unchecked',
    );

    await _tap(tester, _key('add-classes-confirm'));
    await sheet.shot(
      tester,
      'I07_result',
      at: at,
      surface: 'Classes added',
      note: 'class reminders offered, off until turned on',
    );

    await _tap(tester, _key('add-classes-reminder-switch'));
    await sheet.shot(
      tester,
      'I07b_result_reminders_on',
      at: at,
      surface: 'Classes added, reminders on',
      note: 'asked for notifications only at this tap',
    );

    await _tap(tester, _key('add-classes-see-week'));
    await sheet.shot(
      tester,
      'I08_plans_week_after',
      at: at,
      surface: 'Plans, WEEK view after import',
      note: 'SEE MY WEEK opens WEEK on the week of the next class',
    );
  });

  roomRenderTest('import: typing classes in', skip: !_renders, (tester) async {
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await settle(tester, total: const Duration(milliseconds: 800));
    // The other way in: Plans, ADD, then the first SCHOOL row.
    await _tap(tester, _key('academic-add-class'));
    await sheet.shot(
      tester,
      'I09a_add_menu',
      at: at,
      surface: 'Plans ADD menu',
      note: 'ADD YOUR CLASSES leads the SCHOOL rows',
    );
    await _tap(tester, _key('academic-add-choice-import'));
    await _tap(tester, _key('add-classes-type'));
    await sheet.shot(
      tester,
      'I09_type_first',
      at: at,
      surface: 'Type them in, empty',
    );
    await tester.enterText(
      _key('add-classes-quick-name'),
      'MATH 152 Calculus II',
    );
    await _tap(tester, _key('add-classes-day-2'));
    await _tap(tester, _key('add-classes-day-4'));
    await _tap(tester, _key('add-classes-quick-add'));
    await tester.enterText(_key('add-classes-quick-name'), 'Bio lab');
    await _tap(tester, _key('add-classes-day-3'));
    await _tap(tester, _key('add-classes-length-110'));
    await _scrollSheet(tester, -400);
    await sheet.shot(
      tester,
      'I10_type_second',
      at: at,
      surface: 'Type them in, one added, the next half typed',
    );
    await _tap(tester, _key('add-classes-quick-add'));
    await _tap(tester, _key('add-classes-quick-done'));
    await sheet.shot(
      tester,
      'I11_type_result',
      at: at,
      surface: 'Classes added (typed)',
    );
  });

  roomRenderTest(
    'import: typing a class in over winter break',
    skip: !_renders,
    (tester) async {
      // After fall ends, a first typed class starts next spring.
      final winter = DateTime(2026, 12, 22, 12);
      final account = mikaAccount(
        renderAt: winter,
        lastActive: DateTime(2026, 12, 21),
      );
      await bootRoom(tester, account);
      await openTab(tester, RoomTab.plans);
      await precacheArt(tester, RoomArt.plans);
      await settle(tester, total: const Duration(milliseconds: 800));
      await _tap(tester, _key('academic-add-class'));
      await _tap(tester, _key('academic-add-choice-import'));
      await _tap(tester, _key('add-classes-type'));
      await tester.enterText(
        _key('add-classes-quick-name'),
        'CS 112 Data Structures',
      );
      await _tap(tester, _key('add-classes-day-2'));
      await _tap(tester, _key('add-classes-day-4'));
      await _scrollSheet(tester, 400);
      await sheet.shot(
        tester,
        'I22_type_winter_break',
        at: winter,
        surface: 'Type them in, Dec 22',
        note: 'the term line names next spring',
      );
      await _tap(tester, _key('add-classes-quick-add'));
      await _tap(tester, _key('add-classes-quick-done'));
      await sheet.shot(
        tester,
        'I23_type_winter_result',
        at: winter,
        surface: 'Classes added (typed over winter break)',
      );
    },
  );

  roomRenderTest('import: a Canvas feed', skip: !_renders, (tester) async {
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await _toDoorway(tester);
    await _tap(tester, _key('add-classes-doorway'));
    await _readLink(
      tester,
      link: 'https://canvas.illinois.edu/feeds/calendars/user_8hT2kLq9.ics',
      body: canvasFeedExport(),
    );
    await sheet.shot(
      tester,
      'I12_canvas_no_classes',
      at: at,
      surface: 'A Canvas feed: no weekly classes',
    );
  });

  roomRenderTest('import: Mika opens his Room of Days file', skip: !_renders, (
    tester,
  ) async {
    var delivered = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_filesChannel, (call) async {
          if (call.method != 'takeInitialAcademicSchedule' || delivered) {
            return null;
          }
          delivered = true;
          return <String, String>{
            'name': 'rutgers-fall-2026-room-of-days.ics',
            'contents': rutgersFall2026IcsFixture(),
          };
        });
    try {
      final account = mikaAccount(renderAt: at);
      await bootRoom(tester, account);
      await precacheArt(tester, RoomArt.plans);
      await settle(tester, total: const Duration(milliseconds: 1600));
      await sheet.shot(
        tester,
        'I13_rod_file_opened',
        at: at,
        surface: 'Opened from Files: his Room of Days .ics',
        note: 'same original importer, same 168 meetings',
      );
      await _tap(tester, _key('add-classes-confirm'));
      await sheet.shot(
        tester,
        'I14_rod_result',
        at: at,
        surface: 'Classes added (his file)',
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_filesChannel, null);
    }
  });

  roomRenderTest('import: a calendar that holds two terms', skip: !_renders, (
    tester,
  ) async {
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await _toDoorway(tester);
    await _tap(tester, _key('add-classes-doorway'));
    await _readLink(
      tester,
      link:
          'https://calendar.google.com/calendar/ical/jordan.lee.uiuc%40gmail.com/private-8f2c41d9a7e0b3c5/basic.ics',
      body: googleTwoTermExport(),
    );
    await sheet.shot(
      tester,
      'I15_two_terms',
      at: at,
      surface: 'Pick your classes, two terms in one calendar',
      note: 'only Fall 2026 is checked; last spring is one tap away',
    );
    await _tap(tester, _key('add-classes-term-0'));
    await sheet.shot(
      tester,
      'I15b_two_terms_spring',
      at: at,
      surface: 'The same calendar, showing Spring 2026',
      note: 'nothing from fall carried over',
    );
  });

  roomRenderTest('import: busy-only and web page links', skip: !_renders, (
    tester,
  ) async {
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await _toDoorway(tester);
    await _tap(tester, _key('add-classes-doorway'));
    await _readLink(
      tester,
      link:
          'https://outlook.office365.com/owa/calendar/9a1c/b77e/calendar.html',
      body: '<!doctype html><html><title>Outlook</title></html>',
    );
    await sheet.shot(
      tester,
      'I16_web_page_link',
      at: at,
      surface: 'A link that opens a web page',
      note: 'the field keeps the link so it can be fixed',
    );
    debugCalendarLinkFetcherOverride = _FakeFetcher(
      outlookExport(busyOnly: true),
    );
    try {
      await tester.enterText(
        _key('add-classes-link-field'),
        'https://outlook.office365.com/owa/calendar/9a1c/b77e/calendar.ics',
      );
      await tester.pump();
      await _tap(tester, _key('add-classes-read-link'));
    } finally {
      debugCalendarLinkFetcherOverride = null;
    }
    await sheet.shot(
      tester,
      'I17_busy_only',
      at: at,
      surface: 'An Outlook calendar published as busy only',
    );
  });

  roomRenderTest('import: small phone, large text', skip: !_renders, (
    tester,
  ) async {
    _smallPhoneLargeText(tester);
    final account = mikaAccount(renderAt: at);
    await bootRoom(tester, account);
    await openTab(tester, RoomTab.plans);
    await precacheArt(tester, RoomArt.plans);
    await settle(tester, total: const Duration(milliseconds: 1200));
    await _toDoorway(tester);
    await _tap(tester, _key('add-classes-doorway'));
    await sheet.shot(
      tester,
      'I18_small_ways',
      at: at,
      surface: '320 pt phone at 130% text: the ways in',
    );
    await _readLink(
      tester,
      link:
          'https://calendar.google.com/calendar/ical/jordan.lee.uiuc%40gmail.com/private-8f2c41d9a7e0b3c5/basic.ics',
      body: googleTwoTermExport(),
    );
    await sheet.shot(
      tester,
      'I19_small_review',
      at: at,
      surface: '320 pt phone at 130% text: the review',
    );
    await _tap(tester, _key('add-classes-confirm'));
    await sheet.shot(
      tester,
      'I20_small_result',
      at: at,
      surface: '320 pt phone at 130% text: the result',
    );
    // The notification prompt answers no this time.
    _useIosNotifications((call) async {
      return switch (call.method) {
        'initialize' => true,
        'requestPermissions' => false,
        _ => null,
      };
    });
    await _scrollSheet(tester, 500);
    await _tap(tester, _key('add-classes-reminder-switch'));
    await sheet.shot(
      tester,
      'I21_small_reminders_declined',
      at: at,
      surface: '320 pt phone: notifications declined',
      note: 'reminders stay off; a calm line says where to allow them',
    );
  });
}
