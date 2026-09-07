import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/domain_detail.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/notes_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'domain history settles earned XP and later writing survives return',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      Clock.freeze(DateTime(2026, 9, 5, 13));
      Sfx.instance.soundEnabled = false;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        Clock.reset();
        Sfx.instance.soundEnabled = true;
        tester.binding.setSurfaceSize(null);
      });
      final state = GameState()..reduceMotion = true;
      final quest = Quest(
        title: 'Read one page',
        stat: Stat.intl,
        difficulty: 2,
      );
      final quests = [
        quest,
        Quest(title: 'Stretch', stat: Stat.str, difficulty: 1),
      ];
      state.rollover(quests);
      state.setEnergyWeather(EnergyWeather.steady);
      late void Function(Quest, Offset) complete;
      var restored = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuestsPage(
              state: state,
              quests: quests,
              onRefresh: () => 0,
              onPersist: () {},
              onAdd: (_) => false,
              onRemove: (_) {},
              onSnapshot: () => 'before-earned-progress',
              onRestore: (_) => restored = true,
              onBindComplete: (callback) => complete = callback,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final xp = state.xpPreview(quest);
      complete(quest, const Offset(180, 600));
      await tester.pump(const Duration(milliseconds: 30));
      expect(state.totalXp, 0);
      await tester.tap(find.text('MIND'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DomainDetailScreen), findsOneWidget);
      expect(state.totalXp, xp);
      expect(
        state.ledger.where((entry) => entry.stat == Stat.intl),
        isNotEmpty,
      );
      await tester.tap(find.byType(JournalPanel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byType(TextField),
        'Keep the book by the kettle.',
      );
      await tester.pump();
      await tester.ensureVisible(find.byIcon(Icons.add).last);
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();
      expect(
        state.notesFor(Stat.intl).single.text,
        'Keep the book by the kettle.',
      );
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await tester.pump(const Duration(milliseconds: 350));
      Navigator.of(tester.element(find.byType(DomainDetailScreen))).pop();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(ValueKey('undo-${quest.title}')), findsNothing);
      expect(restored, isFalse);
      expect(state.totalXp, xp);
      expect(
        state.notesFor(Stat.intl).single.text,
        'Keep the book by the kettle.',
      );
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
