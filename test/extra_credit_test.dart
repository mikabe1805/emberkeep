import 'dart:convert';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from the goals-everyday-review Extra Credit engine tests. The
/// behavior tests are unchanged; the three raw-JSON decode tests are
/// rewritten for the unified `dayRecords` list (schema 29), and a stored
/// award is now checked against a sane range instead of today's amount.
Map<String, dynamic> _creditRecord(
  String day,
  String title, {
  int xp = 10,
  int createdAt = 1,
}) => {
  'dayKey': day,
  'extraCredit': {'title': title, 'xp': xp, 'createdAt': createdAt},
};

void main() {
  tearDown(Clock.reset);

  group('extra credit', () {
    test('awards fixed XP once without inventing Quest progress', () {
      Clock.freeze(DateTime(2026, 9, 3, 22));
      final state = GameState()
        ..xp = 51
        ..totalXp = 151
        ..embers = 12
        ..streakDays = 4
        ..totalCompletions = 7
        ..history['2026-09-03'] = 2
        ..todayXp = 42
        ..todayStats[Stat.intl] = 5
        ..todayQuestTitles.add('Read the chapter');
      final before = state.toJson();
      final day = Days.nightKey(Clock.now());

      final entry = state.addExtraCredit(
        '  I attended all of my classes  ',
        dayKey: day,
      );

      expect(entry, isNotNull);
      expect(entry!.xp, GameState.extraCreditXp);
      expect(entry.title, 'I attended all of my classes');
      expect(state.xp, 61);
      expect(state.totalXp, 161);
      expect(state.extraCreditForDay(day), entry);
      expect(state.addExtraCredit('Another win', dayKey: day), isNull);
      final after = state.toJson();
      for (final key in ['xp', 'totalXp', 'dayRecords']) {
        before.remove(key);
        after.remove(key);
      }
      expect(after, before);
    });

    test('allows wording edits without a second award', () {
      Clock.freeze(DateTime(2026, 9, 3, 22));
      final state = GameState();
      final day = Days.nightKey(Clock.now());
      state.addExtraCredit('Went to class', dayKey: day);
      final xp = state.xp;

      expect(state.updateExtraCredit(day, '  Went to every class  '), isTrue);
      expect(state.extraCreditForDay(day)!.title, 'Went to every class');
      expect(state.xp, xp);
      expect(state.totalXp, xp);
      expect(state.extraCreditEntries, hasLength(1));
      Clock.freeze(DateTime(2026, 9, 4, 5));
      expect(state.updateExtraCredit(day, 'This must stay expired'), isFalse);
      expect(state.extraCreditForDay(day)!.title, 'Went to every class');
    });

    test('rejects blank, overlong, stale, and arbitrary past-day claims', () {
      Clock.freeze(DateTime(2026, 9, 3, 22));
      final state = GameState();
      final day = Days.nightKey(Clock.now());

      expect(state.addExtraCredit('   ', dayKey: day), isNull);
      expect(
        state.addExtraCredit(
          'x' * (ExtraCreditEntry.maxTitleLength + 1),
          dayKey: day,
        ),
        isNull,
      );
      expect(state.addExtraCredit('Yesterday', dayKey: '2026-09-02'), isNull);
      Clock.freeze(DateTime(2026, 9, 4, 5));
      expect(state.addExtraCredit('Too late', dayKey: day), isNull);
      expect(state.updateExtraCredit(day, ''), isFalse);
      expect(state.extraCreditEntries, isEmpty);
    });

    test('counts visible emoji graphemes like the text field', () {
      Clock.freeze(DateTime(2026, 9, 3, 22));
      final day = Days.nightKey(Clock.now());
      final exact = List.filled(
        ExtraCreditEntry.maxTitleLength,
        '👩🏽‍💻',
      ).join();
      final over = '$exact👩🏽‍💻';
      expect(GameState().addExtraCredit(exact, dayKey: day), isNotNull);
      expect(GameState().addExtraCredit(over, dayKey: day), isNull);
    });

    test(
      'serializes, deduplicates malformed records, and preserves its trace',
      () {
        Clock.freeze(DateTime(2026, 9, 3, 22));
        final state = GameState();
        final day = Days.nightKey(Clock.now());
        state.addExtraCredit('Attended all classes', dayKey: day);
        final restored = GameState.fromJson(
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
        );
        expect(restored.extraCreditForDay(day)!.title, 'Attended all classes');
        expect(restored.todayJournalTrace(const []).extraCreditTitles, [
          'Attended all classes',
        ]);
        expect(restored.todayJournalTrace(const []).hasDayEvidence, isTrue);

        final malformed = state.toJson()
          ..['dayRecords'] = [
            _creditRecord(day, 'Older wording', createdAt: 1),
            _creditRecord(day, 'Newer wording', createdAt: 2),
            _creditRecord('not-a-day', 'Bad', createdAt: 3),
            _creditRecord(
              '2026-09-02',
              'x' * (ExtraCreditEntry.maxTitleLength + 1),
              createdAt: 3,
            ),
            _creditRecord(day, 'No award', xp: 0, createdAt: 4),
            _creditRecord(day, 'Absurd award', xp: 5000, createdAt: 5),
            _creditRecord(day, 'Too far', createdAt: 1 << 62),
            'not a record',
          ];
        final repaired = GameState.fromJson(malformed);
        expect(repaired.extraCreditEntries, hasLength(1));
        expect(repaired.extraCreditForDay(day)!.title, 'Newer wording');
        // Decode repairs wording but never re-awards a duplicate record.
        expect(repaired.xp, state.xp);

        final wrongType = state.toJson()..['dayRecords'] = {'not': 'a list'};
        expect(GameState.fromJson(wrongType).extraCreditEntries, isEmpty);
      },
    );

    test('an award amount from an earlier build still decodes', () {
      // The old decoder required xp == awardXp, so any change to the award
      // would have silently dropped every stored record (and its proof).
      final encoded = GameState().toJson()
        ..['dayRecords'] = [
          _creditRecord('2026-09-01', 'An older, larger award', xp: 15),
        ];
      final restored = GameState.fromJson(encoded);
      expect(restored.extraCreditForDay('2026-09-01')!.xp, 15);
      expect(restored.extraCreditXpForDay('2026-09-01'), 15);
    });

    test('ordinary and legacy save decode do not read the live clock', () {
      Clock.use(() => throw StateError('Decode must not depend on now'));
      expect(GameState.fromJson({}).extraCreditEntries, isEmpty);
      final current = GameState().toJson()
        ..['dayRecords'] = [_creditRecord('2026-09-03', 'Went to all classes')];
      final restored = GameState.fromJson(current);
      expect(restored.extraCreditEntries, hasLength(1));
      expect(restored.extraCreditEntries.single.title, 'Went to all classes');

      // A schema-29 preview build stored the same entry under its own key.
      final preview = GameState().toJson()
        ..remove('dayRecords')
        ..['extraCredit'] = [
          {
            'dayKey': '2026-09-03',
            'title': 'Went to all classes',
            'xp': 10,
            'createdAt': 1,
          },
        ];
      final fromPreview = GameState.fromJson(preview);
      expect(fromPreview.extraCreditEntries, hasLength(1));
      expect(
        fromPreview.extraCreditForDay('2026-09-03')!.title,
        'Went to all classes',
      );
    });

    test(
      'bounds restored history while retaining the active day on a backward clock',
      () {
        Clock.freeze(DateTime(2025, 1, 1, 22));
        final activeDay = Days.nightKey(Clock.now());
        final encoded = GameState().toJson()
          ..['dayRecords'] = [
            _creditRecord(activeDay, 'The active night stays', createdAt: 0),
            for (var i = 1; i <= GameState.dayRecordHorizon; i++)
              _creditRecord(
                Days.key(DateTime(2025, 1, 1 + i)),
                'Earlier win $i',
                createdAt: i,
              ),
          ];

        final restored = GameState.fromJson(encoded);

        expect(
          restored.extraCreditEntries,
          hasLength(GameState.dayRecordHorizon),
        );
        expect(
          restored.extraCreditForDay(activeDay)!.title,
          'The active night stays',
        );
        // Trimming is by day: the oldest day other than the active night goes.
        expect(restored.extraCreditForDay('2025-01-02'), isNull);
        expect(restored.extraCreditForDay('2025-06-30'), isNotNull);
      },
    );

    test('attributes a 1am credit to the prior night before rollover', () {
      Clock.freeze(DateTime(2026, 9, 3, 23, 50));
      final state = GameState()
        ..lastActiveDay = Days.key(Clock.now())
        ..todayXp = 37
        ..todayStats[Stat.intl] = 4;
      Clock.freeze(DateTime(2026, 9, 4, 1));
      final night = Days.nightKey(Clock.now());

      state.addExtraCredit('Made it to every class', dayKey: night);

      expect(state.nightXp, 47);
      expect(state.nightJournalTrace(const []).extraCreditTitles, [
        'Made it to every class',
      ]);
      expect(state.todayJournalTrace(const []).todayXp, 0);
      expect(state.todayJournalTrace(const []).extraCreditTitles, isEmpty);
      expect(state.todayStats, {Stat.intl: 4});
    });

    test(
      'a fresh before-4am state never leaks current-day buckets backward',
      () {
        Clock.freeze(DateTime(2026, 9, 4, 1));
        final state = GameState()
          ..todayXp = 37
          ..todayStats[Stat.intl] = 4;
        final night = Days.nightKey(Clock.now());

        state.addExtraCredit('Finished the late lab', dayKey: night);

        expect(state.nightXp, 10);
        expect(state.nightJournalTrace(const []).todayXp, 10);
        expect(state.todayJournalTrace(const []).todayXp, 37);
        expect(state.nightStatGains, isEmpty);
        expect(state.todayStats, {Stat.intl: 4});
      },
    );

    test(
      'attributes a post-rollover 1am credit and cold restore correctly',
      () {
        Clock.freeze(DateTime(2026, 9, 3, 23, 50));
        final state = GameState()
          ..lastActiveDay = Days.key(Clock.now())
          ..todayXp = 37;
        Clock.freeze(DateTime(2026, 9, 4, 1));
        state.rollover(<Quest>[]);
        final night = Days.nightKey(Clock.now());
        state.addExtraCredit('Went to all classes', dayKey: night);
        expect(state.previousDayKey, night);
        expect(state.nightXp, 47);

        final cold = GameState.fromJson(
          jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
        );
        expect(cold.nightXp, 47);
        expect(cold.nightJournalTrace(const []).extraCreditTitles, [
          'Went to all classes',
        ]);
      },
    );

    test(
      'a new night can claim after rollover while yesterday remains frozen',
      () {
        Clock.freeze(DateTime(2026, 9, 3, 22));
        final state = GameState();
        final yesterday = Days.nightKey(Clock.now());
        state.addExtraCredit('Went to class', dayKey: yesterday);
        Clock.freeze(DateTime(2026, 9, 4, 5));
        state.rollover(<Quest>[]);
        final today = Days.nightKey(Clock.now());

        expect(
          state.addExtraCredit('Did the unplanned reading', dayKey: today),
          isNotNull,
        );
        expect(state.extraCreditForDay(yesterday)!.title, 'Went to class');
        expect(state.extraCreditEntries, hasLength(2));
      },
    );
  });
}
