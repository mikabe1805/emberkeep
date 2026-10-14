// The engine remembers a mark for every Quest finished, so the week's training
// is real: a Quest is a point for its stat, one proven with the timer is 1.5,
// the whole-save undo takes the point back, a kept class counts for the stat
// it feeds, and the marks ride along in the save.
import 'dart:convert';
import 'dart:math';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Never crits, never drops loot: for assertions about exact numbers.
class _NoLuck implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.999999;
  @override
  int nextInt(int max) => 0;
}

Quest _quest(String title, Stat stat) =>
    Quest(title: title, stat: stat, difficulty: 2);

void _finish(GameState state, Quest quest, {bool timer = false}) {
  state.commit(state.roll(quest, verified: timer));
}

GameState _restore(String snapshot) =>
    GameState.fromJson((jsonDecode(snapshot) as Map).cast<String, dynamic>());

void main() {
  tearDown(Clock.reset);

  test('a finished Quest is a point for the stat that names it', () {
    Clock.freeze(DateTime(2026, 10, 14, 12)); // Wed
    final state = GameState(rng: _NoLuck());
    expect(state.weeklyTraining().any, isFalse);

    _finish(state, _quest('Do 5 push-ups', Stat.str));
    _finish(state, _quest('Walk 10 minutes', Stat.vit));
    _finish(state, _quest('Do 8 push-ups', Stat.str));

    final week = state.weeklyTraining();
    expect(week.pointsOf(Stat.str), 2);
    expect(week.pointsOf(Stat.vit), 1);
    expect(week.pointsOf(Stat.intl), 0);
    expect(week.boost(Stat.str), closeTo(1.36, 1e-9));
  });

  test('one proven with the timer counts 1.5', () {
    Clock.freeze(DateTime(2026, 10, 14, 12));
    final state = GameState(rng: _NoLuck());
    _finish(state, _quest('25-minute focus session', Stat.foc), timer: true);
    _finish(state, _quest('Practice', Stat.foc));
    expect(state.weeklyTraining().pointsOf(Stat.foc), 2.5);
  });

  test('the week turns over on Monday at 04:00', () {
    final tuesday = DateTime(2026, 10, 13, 9);
    Clock.freeze(tuesday);
    final state = GameState(rng: _NoLuck());
    _finish(state, _quest('Read one page', Stat.intl));
    // Sunday evening: still this week's.
    expect(
      state.weeklyTraining(DateTime(2026, 10, 18, 20)).pointsOf(Stat.intl),
      1,
    );
    // Monday 03:59 is still the old week, 04:00 starts a quiet one.
    expect(
      state.weeklyTraining(DateTime(2026, 10, 19, 3, 59)).pointsOf(Stat.intl),
      1,
    );
    expect(
      state.weeklyTraining(DateTime(2026, 10, 19, 4)).pointsOf(Stat.intl),
      0,
    );
  });

  test('undo takes the point back: the whole-save snapshot restores it', () {
    Clock.freeze(DateTime(2026, 10, 14, 12));
    final state = GameState(rng: _NoLuck());
    _finish(state, _quest('Do 5 push-ups', Stat.str));
    // The shell snapshots the save just before the next completion...
    final before = jsonEncode(state.toJson());
    _finish(state, _quest('Do 8 push-ups', Stat.str));
    expect(state.weeklyTraining().pointsOf(Stat.str), 2);
    // ...and Undo restores it: the second point goes with the completion.
    final restored = _restore(before);
    expect(restored.weeklyTraining().pointsOf(Stat.str), 1);
    expect(restored.trainingLog, hasLength(1));
  });

  test('the marks are in the save, and an old save reads as a quiet week', () {
    Clock.freeze(DateTime(2026, 10, 14, 12));
    final state = GameState(rng: _NoLuck());
    _finish(state, _quest('Do 5 push-ups', Stat.str));
    _finish(state, _quest('Read one page', Stat.intl), timer: true);
    final json = state.toJson();
    expect(json['trainingLog'], isA<List<dynamic>>());
    final back = _restore(jsonEncode(json));
    expect(back.weeklyTraining().pointsOf(Stat.str), 1);
    expect(back.weeklyTraining().pointsOf(Stat.intl), 1.5);

    // A save from before the feature has no such key.
    final old = Map<String, dynamic>.of(json)..remove('trainingLog');
    expect(_restore(jsonEncode(old)).weeklyTraining().any, isFalse);
    // A fresh state writes no key at all.
    expect(GameState().toJson().containsKey('trainingLog'), isFalse);
    // A damaged entry is skipped and the rest survive.
    final damaged = Map<String, dynamic>.of(json)
      ..['trainingLog'] = [
        'junk',
        {'t': 'x'},
        ...(json['trainingLog'] as List),
      ];
    expect(
      _restore(jsonEncode(damaged)).weeklyTraining().pointsOf(Stat.str),
      1,
    );
  });

  test('only a fortnight of marks is kept', () {
    final state = GameState(rng: _NoLuck());
    Clock.freeze(DateTime(2026, 10, 14, 12));
    state.markTraining(Stat.str, at: DateTime(2026, 9, 1, 9));
    state.markTraining(Stat.str, at: DateTime(2026, 10, 7, 9)); // last week
    state.markTraining(Stat.str, at: DateTime(2026, 10, 13, 9));
    expect(state.trainingLog, hasLength(2));
    expect(state.weeklyTraining().pointsOf(Stat.str), 1);
  });

  test('a kept class counts for the stat its kind feeds', () {
    Clock.freeze(DateTime(2026, 10, 14, 12)); // Wed
    final state = GameState(rng: _NoLuck());
    final lecture = ClassFacts(
      occurrenceKey: 'occ-331-1014',
      courseCode: '14:332:331',
      title: 'Computer Architecture',
      kind: 'lecture',
      dayKey: '2026-10-14',
      startMinute: 620,
      startsAt: DateTime(2026, 10, 14, 10, 20),
      endsAt: DateTime(2026, 10, 14, 11, 40),
    );
    final lab = ClassFacts(
      occurrenceKey: 'occ-333-1014',
      courseCode: '14:332:333',
      title: 'Architecture Lab',
      kind: 'lab',
      dayKey: '2026-10-14',
      startMinute: 510,
      startsAt: DateTime(2026, 10, 14, 8, 30),
      endsAt: DateTime(2026, 10, 14, 11, 30),
    );
    expect(state.keepClass(lecture), isNotNull);
    expect(state.keepClass(lab), isNotNull);
    final week = state.weeklyTraining();
    expect(week.pointsOf(Stat.intl), 1);
    expect(week.pointsOf(Stat.foc), 1);
    // Keeping a class made no Quest mark.
    expect(state.trainingLog, isEmpty);
    // And the whole-save undo of the keep takes it back.
    final fresh = _restore(jsonEncode(GameState().toJson()));
    expect(fresh.weeklyTraining().any, isFalse);
  });
}
