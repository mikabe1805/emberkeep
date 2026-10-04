// The night ledger names a class day: classes kept with their times, the
// class XP inside WHAT MOVED, Quests still as threads, and tomorrow's classes
// heading the MARK TOMORROW tray without taking a slot. Also the two layout
// defects found on his real days at 393 x 852 (tray ribbons over two-line
// titles, the morning rows clipping their XP line).
//
// Clocks are frozen at LOCAL wall times and kept classes carry no instants,
// so the class window is judged by the device's own night: these pass on a
// host in any zone (Codemagic's Mac is not on New York time).
import 'package:emberkeep/academic_calendar/domain/academic_schedule.dart';
import 'package:emberkeep/academic_calendar/import/academic_schedule_ics_import.dart';
import 'package:emberkeep/academic_calendar/services/class_day_projection.dart';
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/routine_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/rutgers_fall_2026_ics_fixture.dart';

final _mondayNight = DateTime(2026, 10, 5, 21, 30);
final _tuesdayNight = DateTime(2026, 10, 6, 22, 10);
final _tuesdayMorning = DateTime(2026, 10, 6, 8, 5);

AcademicSchedule _fall2026() => AcademicScheduleIcsImporter.parse(
  rutgersFall2026IcsFixture(),
).applyTo(AcademicSchedule.empty(), updatedAt: DateTime.utc(2026, 8, 27));

ClassFacts _facts(
  String code,
  String title,
  int startMinute, {
  required DateTime day,
  String kind = 'lecture',
}) => ClassFacts(
  courseCode: code,
  title: title,
  kind: kind,
  dayKey: Days.key(day),
  startMinute: startMinute,
);

/// His Monday: three lectures kept, the full-day bonus paid.
GameState _monday({List<String> quests = const []}) {
  Clock.freeze(_mondayNight);
  final state = GameState()
    ..playerName = 'Mika'
    ..reduceMotion = true
    ..lastActiveDay = Days.key(_mondayNight);
  final classes = [
    _facts('14:332:361', 'Electronics Devices', 510, day: _mondayNight),
    _facts('14:332:345', 'Linear Systems & Signals', 840, day: _mondayNight),
    _facts('14:332:345', 'Linear Systems & Signals', 1060, day: _mondayNight),
  ];
  final keys = [for (final facts in classes) facts.identity];
  for (final facts in classes) {
    expect(state.keepClass(facts, dayClassKeys: keys), isNotNull);
  }
  if (quests.isNotEmpty) {
    state.todayQuestTitles.addAll(quests);
    state.history[Days.key(_mondayNight)] = quests.length;
  }
  return state;
}

Quest _quest(String title, {DateTime? mainOn, Stat stat = Stat.dis}) => Quest(
  title: title,
  stat: stat,
  difficulty: 3,
  custom: true,
  schedule: QuestSchedule.daily,
  priorityDay: mainOn == null ? null : Days.key(mainOn),
);

Future<void> _phone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpNight(
  WidgetTester tester,
  GameState state, {
  List<Quest> quests = const [],
  ClassDay? tomorrow,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NightFlow(
        state: state,
        quests: quests,
        tomorrowClasses: tomorrow,
        onAdd: (_) => true,
        onPersist: () {},
        onClose: () {},
      ),
    ),
  );
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// The real faces, so line heights and widths match a phone.
Future<void> _loadFonts() async {
  for (final family in <String, List<String>>{
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    'Fraunces': [
      'assets/google_fonts/Fraunces-Bold.ttf',
      'assets/google_fonts/Fraunces-SemiBold.ttf',
    ],
    'Inter': [
      'assets/google_fonts/Inter-Regular.ttf',
      'assets/google_fonts/Inter-Medium.ttf',
      'assets/google_fonts/Inter-SemiBold.ttf',
      'assets/google_fonts/Inter-Bold.ttf',
      'assets/google_fonts/Inter-Italic.ttf',
    ],
    'JetBrainsMono': ['assets/google_fonts/JetBrainsMono-SemiBold.ttf'],
    'EBGaramond': [
      'assets/google_fonts/EBGaramond-Variable.ttf',
      'assets/google_fonts/EBGaramond-Italic-Variable.ttf',
    ],
  }.entries) {
    final loader = FontLoader(family.key);
    for (final asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });
  setUp(() => Sfx.instance.soundEnabled = false);
  tearDown(() {
    Clock.reset();
    Sfx.instance.soundEnabled = true;
  });

  testWidgets('a class-only Monday names its classes, never an empty day', (
    tester,
  ) async {
    await _phone(tester);
    final state = _monday();
    expect(state.nightXp, 3 * 25 + ClassPay.fullDayBonusXp);
    await _pumpNight(tester, state);

    expect(find.text('+85 XP'), findsOneWidget);
    expect(find.text('+0 XP'), findsNothing);
    expect(find.text('the quiet days still count'), findsNothing);
    expect(find.text('THREE CLASSES KEPT'), findsOneWidget);
    expect(find.text('NO THREADS FINISHED'), findsNothing);
    expect(find.text('Nothing had to be proven today.'), findsNothing);
    expect(find.text('Electronics Devices'), findsOneWidget);
    expect(find.text('Linear Systems & Signals'), findsNWidgets(2));
    expect(find.text('8:30 AM'), findsOneWidget);
    expect(find.text('2:00 PM'), findsOneWidget);
    expect(find.text('5:40 PM'), findsOneWidget);
    // In time order, top to bottom.
    final first = tester.getTopLeft(find.text('8:30 AM')).dy;
    final second = tester.getTopLeft(find.text('2:00 PM')).dy;
    final third = tester.getTopLeft(find.text('5:40 PM')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(third));
    expect(find.text('MIND'), findsOneWidget);
    expect(find.text('+9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('classes come first and Quests stay threads', (tester) async {
    await _phone(tester);
    final state = _monday(quests: ['Clear the kitchen counter']);
    await _pumpNight(tester, state);

    expect(find.text('THREE CLASSES · ONE THREAD'), findsOneWidget);
    expect(find.text('THREE CLASSES KEPT'), findsNothing);
    // Three lines show, the fourth folds into the same "more" the threads
    // always used.
    expect(find.text('and 1 more!'), findsOneWidget);
    await tester.tap(find.text('and 1 more!'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Clear the kitchen counter'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Clear the kitchen counter')).dy,
      greaterThan(tester.getTopLeft(find.text('5:40 PM')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day with no classes and no Quests keeps its gentle copy', (
    tester,
  ) async {
    await _phone(tester);
    Clock.freeze(_mondayNight);
    final state = GameState()
      ..reduceMotion = true
      ..lastActiveDay = Days.key(_mondayNight);
    await _pumpNight(tester, state);

    expect(find.text('+0 XP'), findsOneWidget);
    expect(find.text('the quiet days still count'), findsOneWidget);
    expect(find.text('NO THREADS FINISHED'), findsOneWidget);
    expect(find.text('Nothing had to be proven today.'), findsOneWidget);
    expect(find.textContaining('CLASS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tomorrow\'s classes head the tray without taking a slot', (
    tester,
  ) async {
    await _phone(tester);
    final state = _monday();
    final tuesday = projectClassDay(
      _fall2026(),
      DateTime.utc(2026, 10, 6, 1, 30),
      day: CivilDate(2026, 10, 6),
    );
    expect(tuesday.classes, hasLength(2));
    await _pumpNight(tester, state, tomorrow: tuesday);

    final lineText = [
      for (final widget in tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('ledger-tomorrow-classes')),
          matching: find.byType(Text),
        ),
      ))
        widget.textSpan!.toPlainText(),
    ];
    // At 393 pt the course names do not fit beside the tags, so the lines
    // print the tags whole rather than a clipped name.
    expect(lineText, [
      'TUESDAY · 10:20 AM · HLL 114',
      'TUESDAY · 2:00 PM · PHY 001',
    ]);
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byKey(const Key('ledger-tomorrow-classes')),
        matching: find.byType(RichText),
      ),
    )) {
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    // The three tray slots are still open for Quests.
    expect(find.text('Choose one'), findsNWidgets(3));
    final lines = find.byKey(const Key('ledger-tomorrow-classes'));
    final tray = find.text('MARK TOMORROW');
    expect(
      tester.getBottomLeft(lines).dy,
      lessThanOrEqualTo(tester.getTopLeft(tray).dy),
      reason: 'the class lines head the tray',
    );
    // They sit below the Extra Credit line rather than over it.
    expect(
      tester.getTopLeft(lines).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byKey(const Key('extra-credit-entry'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in const [
    (Size(320, 568), 2.0),
    (Size(393, 852), 1.5),
    (Size(393, 852), 2.0),
  ]) {
    testWidgets(
      'a full class night fits ${size.width.round()} pt at ${scale}x text '
      'and stays reachable',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final state = _monday(quests: ['Clear the kitchen counter']);
        expect(
          state.addExtraCredit(
            'Stayed after for the recitation questions',
            dayKey: state.activeNightDayKey,
          ),
          isNotNull,
        );
        final tuesday = projectClassDay(
          _fall2026(),
          DateTime.utc(2026, 10, 6, 1, 30),
          day: CivilDate(2026, 10, 6),
        );
        await _pumpNight(tester, state, tomorrow: tuesday);
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        for (final target in [
          find.byKey(const Key('extra-credit-entry')),
          find
              .descendant(
                of: find.byKey(const Key('ledger-tomorrow-classes')),
                matching: find.byType(RichText),
              )
              .first,
          find.text('MARK TOMORROW'),
          find.text('CLOSE THE DAY'),
          find.text('reflect · optional'),
        ]) {
          await tester.scrollUntilVisible(target, 200, scrollable: scroll);
          await tester.pump(const Duration(milliseconds: 150));
          expect(target.hitTestable(), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a Tuesday night shows Wednesday\'s lab in his words', (
    tester,
  ) async {
    await _phone(tester);
    Clock.freeze(_tuesdayNight);
    final state = GameState()
      ..reduceMotion = true
      ..lastActiveDay = Days.key(_tuesdayNight);
    final wednesday = projectClassDay(
      _fall2026(),
      DateTime.utc(2026, 10, 7, 2, 10),
      day: CivilDate(2026, 10, 7),
    );
    await _pumpNight(tester, state, tomorrow: wednesday);
    expect(
      find.textContaining('WEDNESDAY · 8:30 AM · EE 103', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tray ribbons hang below two-line titles at 393 x 852', (
    tester,
  ) async {
    await _phone(tester);
    final tomorrow = Days.afterNight(_mondayNight);
    final quests = [
      _quest('Read ten pages', mainOn: tomorrow),
      _quest('Clear the kitchen counter', mainOn: tomorrow),
      _quest('Message someone I miss', mainOn: tomorrow),
    ];
    for (var i = 0; i < quests.length; i++) {
      quests[i].priorityRank = i + 1;
    }
    final state = _monday();
    await _pumpNight(tester, state, quests: quests);

    final ribbons = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.contains('priority-ribbon'),
    );
    final ribbonTops = [
      for (final element in ribbons.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ];
    expect(ribbonTops, isNotEmpty);
    final ribbonTop = ribbonTops.reduce((a, b) => a < b ? a : b);
    var twoLine = 0;
    for (final quest in quests) {
      final title = find.text(quest.displayTitle);
      final paragraph = tester.renderObject<RenderParagraph>(title);
      final lines = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: quest.displayTitle.length),
      );
      final textBottom =
          tester.getTopLeft(title).dy +
          lines.map((box) => box.bottom).reduce((a, b) => a > b ? a : b);
      if (lines.map((box) => box.top).toSet().length > 1) twoLine++;
      expect(
        textBottom,
        lessThanOrEqualTo(ribbonTop + 0.5),
        reason: '"${quest.displayTitle}" must not sit under a ribbon',
      );
    }
    expect(twoLine, greaterThan(0), reason: 'the case needs a wrapped title');
    expect(tester.takeException(), isNull);
  });

  for (final withNote in [false, true]) {
    testWidgets('morning rows keep their XP line at 393 x 852'
        '${withNote ? ' under a note from last night' : ''}', (tester) async {
      await _phone(tester);
      Clock.freeze(_tuesdayMorning);
      final quests = [
        _quest('Read ten pages', mainOn: _tuesdayMorning, stat: Stat.intl),
        _quest('Clear the kitchen counter', mainOn: _tuesdayMorning),
        _quest(
          'Message someone I miss',
          mainOn: _tuesdayMorning,
          stat: Stat.soc,
        ),
      ];
      for (var i = 0; i < quests.length; i++) {
        quests[i].priorityRank = i + 1;
      }
      final state = GameState()..reduceMotion = true;
      if (withNote) {
        Clock.freeze(DateTime(2026, 10, 5, 21, 30));
        final note = state.saveNightJournal(
          const NightJournalData(tomorrowMessage: 'Start with the reading.'),
          state.nightJournalTrace(quests),
        );
        state.finalizeNightJournal(state.nightJournalTrace(quests));
        state.closeNight();
        expect(note, isNotNull);
        Clock.freeze(_tuesdayMorning);
      }
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MorningFlow(state: state, quests: quests, onClose: () {}),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'Build 49 clipped rows 2 and 3 by 6.9 pt here',
      );
      for (final quest in quests.skip(1)) {
        // The title is never shortened to make room for the XP line.
        final title = tester.renderObject<RenderParagraph>(
          find.text(quest.displayTitle),
        );
        expect(title.didExceedMaxLines, isFalse);
        final row = find.ancestor(
          of: find.text(quest.displayTitle),
          matching: find.byType(Container),
        );
        final rowBottom = tester.getBottomLeft(row.first).dy;
        final detail = find.text(
          '${quest.stat.abbr} · +${state.xpPreview(quest)} XP',
        );
        if (withNote && detail.evaluate().isEmpty) continue;
        // Without the note there is room for the XP line, whole, inside
        // its row (Build 49 cut it at the row's bottom).
        expect(detail, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(detail).didExceedMaxLines,
          isFalse,
        );
        expect(
          tester.getBottomLeft(detail).dy,
          lessThanOrEqualTo(rowBottom + 0.5),
        );
      }
    });
  }
}
