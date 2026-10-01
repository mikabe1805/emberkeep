import 'dart:async';
import 'dart:convert';

import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tooLarge = 'paused (save too large to back up)';

/// Tests boot no Firebase app, so a push the size guard lets through fails at
/// the write itself and lands on the generic status. That is the same status
/// a real device showed when Firestore rejected an oversized document.
const _writeAttempted = 'on (last sync didn’t go through)';

/// One ordinary night of journaling in Hebrew: letters are 2 UTF-8 bytes but
/// one UTF-16 code unit each.
const _hebrewPage =
    'היום הרגשתי איטי בבוקר, אבל עדיין יצאתי לריצה קצרה ליד הנהר. '
    'השיעור במעבדה היה ארוך ועזר לי סוף סוף להבין את המעגל. '
    'בערב הלכתי לטייל עם אמא ודיברנו על התוכניות לחורף. '
    'אני עייף אבל גאה במה שהספקתי, ומחר אני רוצה לקום מוקדם יותר '
    'ולכתוב לפני העבודה.';

Note _page(int day, String text) => Note(
  at: DateTime(2023, 10, 1 + day),
  text: text,
  id: 'he-${day.toString().padLeft(5, '0')}',
);

/// The first [bytes] UTF-8 bytes of the page, repeated as needed. A Hebrew
/// letter cannot be split, so an odd last byte becomes a full stop.
String _hebrewText(int bytes) {
  final out = StringBuffer();
  var used = 0;
  for (final char in (_hebrewPage * 3).split('')) {
    final size = utf8.encode(char).length;
    if (used + size > bytes) break;
    out.write(char);
    used += size;
  }
  expect(bytes - used, lessThan(2), reason: 'page text ran out');
  if (used < bytes) out.write('.');
  return out.toString();
}

/// Writes a Hebrew-journal save through [Storage.save] and returns the exact
/// blob the cloud mirror would read, sized to [utf8Bytes].
Future<String> _saveHebrewJournal(int utf8Bytes) async {
  Future<String> write(int fullPages, String lastPage) async {
    final state = GameState()
      ..journal = [
        for (var day = 0; day < fullPages; day++) _page(day, _hebrewPage),
        _page(fullPages, lastPage),
      ];
    expect(await Storage.save(state, const []), isTrue);
    return (await Storage.exportRaw())!;
  }

  final base = cloudSaveBytes(await write(0, ''));
  final perPage = cloudSaveBytes(await write(1, '')) - base;
  final fullPages = (utf8Bytes - base) ~/ perPage;
  final rest = utf8Bytes - base - fullPages * perPage;
  final raw = await write(fullPages, _hebrewText(rest));
  expect(cloudSaveBytes(raw), utf8Bytes);
  expect(Storage.isValidSave(raw), isTrue);
  return raw;
}

/// Runs the real debounced-push body once and reports where it settled.
Future<String> _pushAndReadStatus() async {
  final cloud = CloudSync.instance;
  final settled = Completer<void>();
  void onChange() {
    if (!settled.isCompleted) settled.complete();
  }

  cloud.addListener(onChange);
  try {
    cloud.flush();
    await settled.future.timeout(const Duration(seconds: 10));
  } finally {
    cloud.removeListener(onChange);
  }
  return cloud.status;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CloudSync.instance
      ..ready = true
      ..status = 'connecting…';
  });

  tearDown(() => CloudSync.instance.ready = false);

  test('save size is measured in UTF-8 bytes, as Firestore counts it', () {
    expect(cloudSaveBytes('quest'), 5);
    expect(cloudSaveBytes('שלום'), 8);
    expect('שלום'.length, 4);
    expect(cloudSaveBytes('日記'), 6);
    expect(cloudSaveBytes('🌙'), 4);
    expect('🌙'.length, 2);
  });

  test('the limit leaves room for Firestore document overhead', () {
    // Firestore's documented size, which the emulator matched to the byte on
    // 2026-09-30: the `saves/{uid}` name (each segment's bytes + 1, plus 16;
    // Auth uids are 28 characters), each field name's bytes + 1, a string
    // value's bytes + 1, an 8-byte timestamp, and 32 for the document itself.
    const name = (5 + 1) + (28 + 1) + 16;
    const fields = (4 + 1) + (cloudSaveByteLimit + 1) + (9 + 1) + 8;
    expect(name + fields + 32, lessThan(1024 * 1024));
  });

  test(
    'a Hebrew journal over Firestore’s 1 MiB pauses with the explicit status',
    () async {
      // The 3-year Hebrew replay from the 2026-09-30 host benchmark.
      final raw = await _saveHebrewJournal(1183320);
      expect(cloudSaveBytes(raw), greaterThan(1024 * 1024));
      // The old guard compared UTF-16 code units against 900 KiB, so it sent
      // this save to a write Firestore rejects.
      expect(raw.length, lessThan(900 * 1024));

      expect(await _pushAndReadStatus(), _tooLarge);
    },
  );

  test('a Hebrew save at the byte limit still backs up', () async {
    await _saveHebrewJournal(cloudSaveByteLimit);
    expect(await _pushAndReadStatus(), _writeAttempted);
  });

  test('one byte over the limit pauses instead of writing', () async {
    await _saveHebrewJournal(cloudSaveByteLimit + 1);
    expect(await _pushAndReadStatus(), _tooLarge);
  });
}
