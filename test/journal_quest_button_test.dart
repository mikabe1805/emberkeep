import 'package:emberkeep/clock.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/gold_surface.dart';
import 'package:emberkeep/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Quest _quest({required bool opensJournal}) => Quest(
  title: opensJournal ? 'Name three good things' : 'Clear one surface',
  stat: opensJournal ? Stat.intl : Stat.dis,
  difficulty: 2,
  journalPrompt: opensJournal
      ? const JournalQuestPrompt(
          starter: 'Three things I’m thankful for:\n',
          hint: 'A person, place, moment, or tiny detail all count.',
        )
      : null,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required bool opensJournal,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(320, 568),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: Palette.parchment,
        body: Center(
          child: SizedBox(
            width: 290,
            child: QuestCard(
              quest: _quest(opensJournal: opensJournal),
              done: false,
              featured: true,
              xpPreview: 10,
              reduceMotion: true,
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => Clock.freeze(DateTime(2026, 8, 3, 13)));
  tearDown(Clock.reset);

  testWidgets(
    'Journal Quest uses an accessible inset bookplate at 2x text size',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final semantics = tester.ensureSemantics();
      await _pumpCard(tester, opensJournal: true, textScale: 2);

      final bookplate = find.byKey(const ValueKey('journal-quest-bookplate'));
      expect(bookplate, findsOneWidget);
      expect(tester.getSize(bookplate).height, greaterThanOrEqualTo(52));
      expect(find.byType(GoldSurface), findsNothing);
      expect(find.text('OPEN JOURNAL'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(r'Name three good things, Open Journal, 10 XP'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('ordinary featured Quest keeps the luminous completion plate', (
    tester,
  ) async {
    await _pumpCard(tester, opensJournal: false);

    expect(find.byKey(const ValueKey('journal-quest-bookplate')), findsNothing);
    expect(find.byType(GoldSurface), findsOneWidget);
    expect(find.text('MARK COMPLETE'), findsOneWidget);
    expect(find.text('OPEN JOURNAL'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
