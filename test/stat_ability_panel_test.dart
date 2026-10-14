// A stat's own page says what it is for in the weekend fight: the ability, the
// four tiers and where the stat stands, what this week's training does, and
// the week's monster when it is weak to the stat.
import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/domain_detail.dart';
import 'package:emberkeep/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _page(GameState state, Stat stat, {double textScale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(393, 852),
      textScaler: TextScaler.linear(textScale),
    ),
    child: DomainDetailScreen(
      stat: stat,
      state: state,
      quests: const [],
      onPersist: () {},
      onAddQuest: (_) => true,
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    Sfx.instance.soundEnabled = false;
    // Wed Oct 14 2026: ISO week 42, so the Couch Troll, weak to Strength.
    Clock.freeze(DateTime(2026, 10, 14, 12, 30));
  });
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  testWidgets('the ability, its tier and what each tier adds', (tester) async {
    _phone(tester);
    final state = GameState()
      ..reduceMotion = true
      ..stats[Stat.str] = 54;
    await tester.pumpWidget(_page(state, Stat.str));
    await tester.pump();
    expect(find.byKey(const Key('stat-ability-str')), findsOneWidget);
    expect(find.text('Power Slam'), findsOneWidget);
    expect(_text(tester, 'stat-ability-tier-str'), 'TIER 2');
    // Four tiers, the first two reached.
    for (var t = 1; t <= 4; t++) {
      expect(find.byKey(Key('stat-ability-tier-str-$t')), findsOneWidget);
    }
    expect(find.textContaining('Tier 3 at 80'), findsOneWidget);
    expect(find.textContaining('a bigger slam'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
  });

  testWidgets('a locked ability reads as an aspiration', (tester) async {
    _phone(tester);
    final state = GameState()
      ..reduceMotion = true
      ..stats[Stat.soc] = 5;
    await tester.pumpWidget(_page(state, Stat.soc));
    await tester.pump();
    expect(_text(tester, 'stat-ability-tier-soc'), 'LOCKED');
    expect(
      _text(tester, 'stat-ability-locked-soc'),
      'Reach Social 10 to unlock Call a Friend',
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('training this week glows with its boost; a quiet week asks '
      'for quests', (tester) async {
    _phone(tester);
    final state = GameState()
      ..reduceMotion = true
      ..stats[Stat.intl] = 30;
    await tester.pumpWidget(_page(state, Stat.intl));
    await tester.pump();
    expect(find.byKey(const Key('stat-ability-week-intl')), findsNothing);
    expect(
      _text(tester, 'stat-ability-quiet-intl'),
      'Finish quests for Intellect this week to boost Spell Bolt in the '
      'fight.',
    );

    // Five quests since Monday 04:00 is a 1.9 boost.
    for (var i = 0; i < 5; i++) {
      state.markTraining(Stat.intl, at: DateTime(2026, 10, 12 + i % 2, 9 + i));
    }
    await tester.pumpWidget(_page(state, Stat.intl));
    await tester.pump();
    expect(find.text('+5 this week'), findsOneWidget);
    expect(
      _text(tester, 'stat-ability-boost-intl'),
      'Spell Bolt is boosted ×1.9 in the fight.',
    );
    expect(find.byKey(const Key('stat-ability-quiet-intl')), findsNothing);
  });

  testWidgets('the week\'s monster says when it is weak to this stat', (
    tester,
  ) async {
    _phone(tester);
    final state = GameState()..reduceMotion = true;
    await tester.pumpWidget(_page(state, Stat.str));
    await tester.pump();
    expect(
      _text(tester, 'stat-ability-weak-str'),
      'The Couch Troll is weak to Strength this week, so it matters most.',
    );
    await tester.pumpWidget(_page(state, Stat.vit));
    await tester.pump();
    expect(find.byKey(const Key('stat-ability-weak-vit')), findsNothing);

    // Next week the Fog rolls in, weak to Intellect.
    Clock.freeze(DateTime(2026, 10, 21, 12));
    await tester.pumpWidget(_page(state, Stat.intl));
    await tester.pump();
    expect(
      _text(tester, 'stat-ability-weak-intl'),
      'The Fog is weak to Intellect this week, so it matters most.',
    );
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('it holds at ${(scale * 100).round()}% text', (tester) async {
      _phone(tester);
      final state = GameState()
        ..reduceMotion = true
        ..stats[Stat.str] = 88;
      for (var i = 0; i < 6; i++) {
        state.markTraining(Stat.str, at: DateTime(2026, 10, 12, 9 + i));
      }
      await tester.pumpWidget(_page(state, Stat.str, textScale: scale));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stat-ability-str')), findsOneWidget);
    });
  }

  testWidgets('no word scolds', (tester) async {
    _phone(tester);
    final state = GameState()..reduceMotion = true;
    await tester.pumpWidget(_page(state, Stat.dis));
    await tester.pump();
    final panel = find.byKey(const Key('stat-ability-dis'));
    final all = [
      for (final t in tester.widgetList<Text>(
        find.descendant(of: panel, matching: find.byType(Text)),
      ))
        t.data,
      for (final t in tester.widgetList<RichText>(
        find.descendant(of: panel, matching: find.byType(RichText)),
      ))
        t.text.toPlainText(),
    ].whereType<String>().join(' ').toLowerCase();
    for (final word in [
      'lost',
      'missed',
      'failed',
      'broke',
      'behind',
      'overdue',
      '—',
    ]) {
      expect(all.contains(word), isFalse, reason: word);
    }
  });
}
