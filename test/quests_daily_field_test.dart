import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Quest _daily(String title, {int difficulty = 2}) => Quest(
  title: title,
  stat: Stat.foc,
  difficulty: difficulty,
  custom: true,
  schedule: QuestSchedule.daily,
);

Widget _board(GameState state, List<Quest> quests) => MaterialApp(
  home: Scaffold(
    body: QuestsPage(
      state: state,
      quests: quests,
      onRefresh: () => 0,
      onPersist: () {},
      onAdd: (quest) {
        quests.add(quest);
        return true;
      },
      onRemove: quests.remove,
      onSnapshot: () => '{}',
      onRestore: (_) {},
    ),
  ),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.instance.soundEnabled = false;
  });

  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  testWidgets(
    'a dated field keeps optional quests available behind OPEN IF IT FITS',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 8, 30, 10);
      Clock.freeze(now);
      final key = Days.key(now);
      final first = _daily('First chosen')
        ..priorityDay = key
        ..priorityRank = 1;
      final second = _daily('Second chosen')
        ..priorityDay = key
        ..priorityRank = 2;
      final optionalOne = _daily('Optional sketch');
      final optionalTwo = _daily('Optional walk');
      final commitment = Quest(
        title: 'Submit the form',
        stat: Stat.intl,
        difficulty: 3,
        custom: true,
        schedule: QuestSchedule.once,
        dueDate: now,
      );
      final state = GameState()..reduceMotion = true;

      await tester.pumpWidget(
        _board(state, [first, second, optionalOne, optionalTwo, commitment]),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.drag(
        find.byKey(const ValueKey('quest-board-scroll')),
        const Offset(0, -420),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.ensureVisible(find.byKey(const Key('daily-field-rail')));

      expect(find.text('TODAY’S FIELD'), findsOneWidget);
      expect(find.text('OPEN IF IT FITS · 2'), findsOneWidget);
      expect(find.text('First chosen'), findsOneWidget);
      expect(find.text('Second chosen'), findsOneWidget);
      expect(find.text('Submit the form'), findsOneWidget);
      expect(find.text('Optional sketch'), findsNothing);
      expect(find.text('Optional walk'), findsNothing);

      await tester.tap(find.text('OPEN IF IT FITS · 2'));
      await tester.pump(const Duration(milliseconds: 180));

      expect(find.text('HIDE OPTIONAL QUESTS'), findsOneWidget);
      expect(find.text('Optional sketch'), findsOneWidget);
      expect(find.text('Optional walk'), findsOneWidget);
    },
  );

  testWidgets('a snoozed selected quest does not falsely clear today’s field', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final now = DateTime(2026, 8, 30, 10);
    Clock.freeze(now);
    final chosen = _daily('Still chosen')
      ..priorityDay = Days.key(now)
      ..priorityRank = 1
      ..snoozedDay = Days.key(now);
    final state = GameState()..reduceMotion = true;

    await tester.pumpWidget(_board(state, [chosen, _daily('Optional idea')]));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(
      find.byKey(const ValueKey('quest-board-scroll')),
      const Offset(0, -420),
    );
    await tester.pump(const Duration(milliseconds: 180));
    await tester.ensureVisible(find.byKey(const Key('daily-field-rail')));

    expect(find.text('TODAY’S FIELD · 1 TO CARRY'), findsOneWidget);
    expect(find.textContaining('set aside for today'), findsOneWidget);
    expect(find.text('TODAY’S FIELD · ENOUGH'), findsNothing);
  });

  testWidgets(
    'the true field can be enough while optional inspiration stays open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });
      final now = DateTime(2026, 8, 30, 10);
      Clock.freeze(now);
      final key = Days.key(now);
      final chosen = _daily('Chosen and kept')
        ..priorityDay = key
        ..priorityRank = 1
        ..lastDoneDay = key;
      final commitment = Quest(
        title: 'Appointment kept',
        stat: Stat.intl,
        difficulty: 3,
        custom: true,
        schedule: QuestSchedule.once,
        dueDate: now,
      )..lastDoneDay = key;
      final optional = _daily('Sketch if there is room');
      final state = GameState()..reduceMotion = true;

      await tester.pumpWidget(_board(state, [chosen, commitment, optional]));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.drag(
        find.byKey(const ValueKey('quest-board-scroll')),
        const Offset(0, -420),
      );
      await tester.pump(const Duration(milliseconds: 180));
      await tester.ensureVisible(find.byKey(const Key('daily-field-rail')));

      expect(find.text('TODAY’S FIELD · ENOUGH'), findsOneWidget);
      expect(find.text('OPEN IF IT FITS · 1'), findsOneWidget);
      expect(find.text('Sketch if there is room'), findsNothing);

      await tester.tap(find.text('OPEN IF IT FITS · 1'));
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('Sketch if there is room'), findsOneWidget);
    },
  );
}
