import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/memories.dart';
import 'package:emberkeep/content/momentum_kits.dart';
import 'package:emberkeep/content/weekly_chronicle.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/hearth_circle.dart';
import 'package:emberkeep/screens/memory_cabinet.dart';
import 'package:emberkeep/screens/weekly_chronicle.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  test('weekly chronicle tells last week honestly', () {
    final state = GameState();
    state.history.addAll({
      '2026-07-20': 2,
      '2026-07-22': 1,
      '2026-07-26': 3,
      '2026-07-13': 1,
      '2026-07-15': 1,
    });
    state.journal = [
      Note(
        at: DateTime(2026, 7, 23, 20),
        text: 'I made the room feel like mine.',
      ),
    ];

    final chronicle = weeklyChronicleFor(state, now: DateTime(2026, 7, 28));

    expect(chronicle.rangeLabel, 'JUL 20 — JUL 26');
    expect(chronicle.counts, [2, 0, 1, 0, 0, 0, 3]);
    expect(chronicle.litDays, 3);
    expect(chronicle.total, 6);
    expect(chronicle.delta, 4);
    expect(chronicle.reflection?.text, contains('room'));
  });

  test('chronicle excerpts stop at a readable word boundary', () {
    final excerpt = chronicleExcerpt(
      'This is a deliberately long journal sentence that should become a clean and readable Chronicle excerpt without cutting a final word in half.',
      max: 72,
    );
    expect(excerpt.endsWith('…'), isTrue);
    expect(excerpt.length, lessThanOrEqualTo(73));
    expect(excerpt, isNot(contains('rea…')));
  });

  test('memory cabinet combines chosen moments and earned proof', () {
    final note = Note(at: DateTime(2026, 7, 28), text: 'A warm detail.');
    final state = GameState()
      ..level = 10
      ..journal = [note]
      ..memoryPins.add(note.id)
      ..unlockedAchievements.add('first-step');
    state.goals.add(
      Goal(
        title: 'Make a room feel calm',
        stat: Stat.dis,
        target: 25,
        progress: 25,
      ),
    );

    final cabinet = memoryCollection(state, const []);

    expect(cabinet.kept.single.note?.id, note.id);
    expect(cabinet.trophies.map((m) => m.title), contains('First Step'));
    expect(
      cabinet.goals.map((m) => m.title),
      contains('Make a room feel calm'),
    );
    expect(cabinet.hearth.map((m) => m.title), ['First Five', 'Double Digits']);
  });

  test('identity features survive a save round trip', () {
    Clock.freeze(DateTime(2026, 7, 28, 10));
    final state = GameState()..roomCode = 'ABC234';
    expect(state.addCircleCode('DEF567'), isTrue);
    state.setEnergyWeather(EnergyWeather.low);
    state.setLowFlameQuests(['One gentle thing', 'Another gentle thing']);
    state.memoryPins.add('note-1');
    state.startQuietCompany('study', const Duration(minutes: 25));

    final restored = GameState.fromJson(state.toJson());

    expect(restored.hearthCircleCodes, ['DEF567']);
    expect(restored.energyWeather, EnergyWeather.low);
    expect(restored.energyHistory['2026-07-28'], EnergyWeather.low);
    expect(restored.lowFlameQuestTitles, [
      'One gentle thing',
      'Another gentle thing',
    ]);
    expect(restored.memoryPins, {'note-1'});
    expect(restored.quietCompanyKind, 'study');
    expect(restored.quietCompanyActive, isTrue);
  });

  test('circle codes are private, bounded, and cannot add your own keep', () {
    final state = GameState()..roomCode = 'ABC234';
    expect(state.addCircleCode('ABC234'), isFalse);
    expect(state.addCircleCode('not-a-code'), isFalse);
    for (final code in ['DEF567', 'GHJ678', 'KMN789', 'PQR892', 'STU923']) {
      expect(state.addCircleCode(code), isTrue);
    }
    expect(state.addCircleCode('VWX934'), isFalse);
    expect(state.hearthCircleCodes, hasLength(5));
  });

  test(
    'published room remains appearance-only while gaining fixed presence',
    () {
      Clock.freeze(DateTime(2026, 7, 28, 11));
      final state = GameState()
        ..level = 12
        ..journal = [
          Note(at: DateTime(2026, 7, 28), text: 'never publish this'),
        ]
        ..memoryPins.add('private-note')
        ..quietCompanyKind = 'study'
        ..quietCompanyUntil = DateTime(
          2026,
          7,
          28,
          11,
          25,
        ).millisecondsSinceEpoch;
      state.history['2026-07-28'] = 1;
      state.setEnergyWeather(EnergyWeather.steady);

      final room = roomDisplay(state);

      expect(room['v'], 5);
      expect(room['profileVisible'], isFalse);
      expect(room['displayName'], isEmpty);
      expect(room['about'], isEmpty);
      expect(room['featuredGoals'], isEmpty);
      expect(room['cardOrder'], isEmpty);
      expect(room['pinnedMoments'], isEmpty);
      expect(room['season'], isEmpty);
      expect(room['todayLit'], isTrue);
      // Energy weather is a private daily capacity lens (engine.dart); it
      // travels only behind the explicit visitor-profile opt-in, unlike the
      // fixed presence facts above.
      expect(room['weather'], 'unknown');
      expect(room['focusKind'], 'study');
      expect(room['memories'], greaterThan(0));
      expect(room.containsKey('journal'), isFalse);
      expect(room.values.join(' '), isNot(contains('never publish this')));

      state.shareSpaceProfile = true;
      expect(roomDisplay(state)['weather'], 'unknown');
      expect(
        roomDisplay(state, visitorProfileSharingEnabled: true)['weather'],
        'steady',
      );
    },
  );

  test('life chapters create small same-economy quest paths', () {
    final exam = buildExamSeasonQuests(capacity: 3);
    final move = buildMovingHomeQuests(capacity: 2);
    final work = buildJobSearchQuests(capacity: 1);
    final returnPath = buildStartingAgainQuests(capacity: 3);

    expect(exam, hasLength(3));
    expect(exam[1].verification, Verification.timer);
    expect(exam.map((q) => q.goalTitle).toSet(), {'Cross exam season'});
    expect(move, hasLength(2));
    expect(work.single.stat, Stat.foc);
    expect(returnPath.map((q) => q.difficulty), everyElement(1));
    expect(
      [...exam, ...move, ...work, ...returnPath].map((q) => q.bonus),
      everyElement(isTrue),
    );
  });

  testWidgets('new identity screens fit a phone viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final note = Note(
      at: DateTime(2026, 7, 23),
      text: 'The first evening this place felt like mine.',
    );
    final state = GameState()
      ..level = 10
      ..totalXp = 1800
      ..reduceMotion = true
      ..journal = [note]
      ..memoryPins.add(note.id)
      ..unlockedAchievements.add('first-step');
    state.history.addAll({'2026-07-20': 2, '2026-07-23': 1});

    await tester.pumpWidget(
      MaterialApp(home: WeeklyChronicleScreen(state: state)),
    );
    await tester.pump();
    expect(find.text('Your Week'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: MemoryCabinetScreen(state: state, quests: const []),
      ),
    );
    await tester.pump();
    expect(find.text('Keepsakes'), findsOneWidget);
    expect(find.text('First Step'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: HearthCircleScreen(state: state, onPersist: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('Circle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
