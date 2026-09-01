import 'dart:collection';

import 'package:emberkeep/academic_calendar/import/academic_schedule_file_picker.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_file_inbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cold-start native files stay FIFO until Flutter takes them', () async {
    const channel = MethodChannel('room_of_days/test_academic_files');
    final native = Queue<Map<String, String>>.from([
      {'name': 'first.ics', 'contents': 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n'},
      {
        'name': 'second.ics',
        'contents': '\uFEFFBEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
      },
    ]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'takeInitialAcademicSchedule');
          return native.isEmpty ? null : native.removeFirst();
        });

    final inbox = AcademicScheduleFileInbox(channel: channel);
    await inbox.initialize();

    expect(inbox.takeNext()?.name, 'first.ics');
    final second = inbox.takeNext();
    expect(second?.name, 'second.ics');
    expect(second?.contents, startsWith('BEGIN:VCALENDAR'));
    expect(inbox.takeNext(), isNull);

    inbox.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('rejects a native payload that is not an .ics file', () async {
    const channel = MethodChannel('room_of_days/test_academic_files_invalid');
    var delivered = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (delivered) return null;
          delivered = true;
          return {'name': 'notes.txt', 'contents': 'not a calendar'};
        });

    final inbox = AcademicScheduleFileInbox(channel: channel);
    await inbox.initialize();
    expect(inbox.isNotEmpty, isFalse);

    inbox.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('keeps a bounded newest-first arrival window in FIFO order', () {
    final inbox = AcademicScheduleFileInbox(
      channel: const MethodChannel('room_of_days/test_academic_files_bounded'),
    );
    for (var index = 0; index < 6; index++) {
      inbox.enqueue(
        AcademicScheduleImportSource(
          name: '$index.ics',
          contents: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
        ),
      );
    }

    expect(
      [for (var index = 0; index < 4; index++) inbox.takeNext()?.name],
      ['2.ics', '3.ics', '4.ics', '5.ics'],
    );
    expect(inbox.takeNext(), isNull);
    inbox.dispose();
  });
}
