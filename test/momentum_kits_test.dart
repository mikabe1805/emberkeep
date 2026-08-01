import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/momentum_kits.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/momentum_kits.dart';
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

  test('low flame capacity creates only the kindness the user chose', () {
    final now = DateTime(2026, 7, 28, 14);
    final one = buildLowFlameQuests(capacity: 1, now: now);
    final three = buildLowFlameQuests(capacity: 3, now: now);

    expect(one, hasLength(1));
    expect(three, hasLength(3));
    expect(three.map((q) => q.difficulty), everyElement(1));
    expect(three.map((q) => q.bonus), everyElement(isTrue));
    expect(three.map((q) => q.priority), everyElement(isFalse));
    expect(three.map((q) => q.dueDate), everyElement(DateTime(2026, 7, 28)));
    expect(three.map((q) => q.stat), [Stat.vit, Stat.dis, Stat.soc]);
  });

  test('unstick kit creates a short verified first move', () {
    final quest = buildUnstickQuest(
      task: '  open   the application ',
      minutes: 2,
      stat: Stat.dis,
      now: DateTime(2026, 7, 28),
    );

    expect(quest.title, 'Touch open the application for 2 minutes');
    expect(quest.verification, Verification.timer);
    expect(quest.timerMinutes, 2);
    expect(quest.stat, Stat.dis);
    expect(quest.schedule, QuestSchedule.once);
  });

  test('home reset grows from a visible win into an ordered path', () {
    final quick = buildHomeResetQuests(room: 'Kitchen', minutes: 5);
    final full = buildHomeResetQuests(room: 'Kitchen', minutes: 30);

    expect(quick, hasLength(1));
    expect(quick.single.title, contains('visible surface'));
    expect(full, hasLength(3));
    expect(full.first.title, contains('does not belong'));
    expect(full.last.timerMinutes, 30);
  });

  test('rhythm kits remain tied to ordinary goal progress', () {
    final focus = buildFocusQuest(target: 'chapter four', minutes: 25);
    final creative = buildCreativeQuest(
      project: 'the moon sketch',
      minutes: 10,
    );
    final steady = buildSteadyDayQuests(capacity: 3);

    expect(focus.goalTitle, 'Protect my attention');
    expect(creative.goalTitle, 'Keep a creative practice');
    expect(steady.map((q) => q.goalTitle).toSet(), {'Build a steady day'});
  });

  test('unused kit sparks expire quietly at dawn', () {
    final quests = buildLowFlameQuests(
      capacity: 3,
      now: DateTime(2026, 7, 28, 22),
    ).toList();
    final state = GameState()..lastActiveDay = '2026-07-28';
    Clock.freeze(DateTime(2026, 7, 29, 8));

    state.rollover(quests);

    expect(quests, isEmpty);
  });

  testWidgets('all six kit launchers fit the phone and open', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MomentumKitsPage(
          state: GameState()..reduceMotion = true,
          onAdd: (_) => true,
          onPersist: () {},
          onOpenQuests: () {},
        ),
      ),
    );
    await tester.pump();

    for (final kit in momentumKits) {
      await tester.scrollUntilVisible(
        find.text(kit.title),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(kit.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(kit.detail), findsOneWidget);
      await tester.tapAt(const Offset(12, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }
  });

  testWidgets('low flame launcher pins its selected sparks to Quests', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final added = <Quest>[];
    var openedBoard = false;
    final state = GameState();

    await tester.pumpWidget(
      MaterialApp(
        home: MomentumKitsPage(
          state: state,
          onAdd: (q) {
            added.add(q);
            return true;
          },
          onPersist: () {},
          onOpenQuests: () => openedBoard = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Gentle Mode Day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('How much capacity do you truly have?'.toUpperCase()),
      findsOneWidget,
    );

    await tester.tap(find.text('CHOOSE 2 STEPS'));
    await tester.pump();
    expect(added, hasLength(2));
    expect(state.lowFlameActive, isTrue);
    expect(state.lowFlameQuestTitles, added.map((q) => q.title));
    expect(find.text('2 steps will carry the day'), findsOneWidget);

    await tester.tap(find.text('OPEN QUESTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(openedBoard, isTrue);
  });
}
