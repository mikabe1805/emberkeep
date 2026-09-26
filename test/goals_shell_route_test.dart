import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/release_notes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/release_notes_preferences.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/screens/shell.dart';
import 'package:emberkeep/storage.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Clock.reset);

  testWidgets(
    'Today’s three opens its exact Quest once, then a normal Quests visit resets the board',
    (tester) async {
      final today = DateTime(2026, 9, 26, 10);
      Clock.freeze(today);
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = GameState()
        ..onboarded = true
        ..reduceMotion = true
        ..soundEnabled = false;
      final commitment = Quest(
        title: 'Due commitment',
        stat: Stat.dis,
        difficulty: 1,
        schedule: QuestSchedule.once,
        dueDate: today,
      );
      final selected =
          Quest(title: 'Today’s exact quest', stat: Stat.foc, difficulty: 5)
            ..priorityDay = Days.key(today)
            ..priorityRank = 1;
      await Storage.save(state, [commitment, selected]);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        whatsNewSeenReleasePreferenceKey,
        currentRoomReleaseNotes.id,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(initialPage: AppShellInitialPage.goals),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Today’s three'), findsOneWidget);
      final liveQuests = tester
          .widget<GoalsPage>(find.byType(GoalsPage))
          .quests;
      final liveCommitment = liveQuests.singleWhere((quest) => quest.isEvent);
      final liveSelected = liveQuests.singleWhere(
        (quest) => !quest.isEvent && quest.stat == Stat.foc,
      );
      final fieldRow = find.byKey(
        const ValueKey<String>('goals-today-field-today’s exact quest'),
      );
      expect(fieldRow, findsOneWidget);
      await tester.ensureVisible(fieldRow);
      await tester.pump();
      await tester.tap(fieldRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuestsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('quest-arrival-1')), findsOneWidget);
      List<QuestCard> boardCards() => tester
          .widgetList<QuestCard>(find.byType(QuestCard, skipOffstage: false))
          .toList();
      expect(identical(boardCards().first.quest, liveSelected), isTrue);
      final focused = boardCards().singleWhere((card) => card.featured);
      expect(identical(focused.quest, liveSelected), isTrue);

      await tester.tap(find.text('GOALS'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('QUESTS'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('quest-arrival-1')), findsNothing);
      expect(identical(boardCards().first.quest, liveCommitment), isTrue);
      final reopened = boardCards().singleWhere((card) => card.featured);
      expect(identical(reopened.quest, liveCommitment), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
