import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/content/quest_desk_styles.dart';
import 'package:emberkeep/screens/quests.dart';
import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/morrow_tapestry_glyph.dart';
import 'package:emberkeep/widgets/quest_desk.dart';
import 'package:emberkeep/widgets/stat_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public vocabulary changes without migrating persisted fields', () {
    final state = GameState()..embers = 17;
    final json = state.toJson();

    expect(EnergyWeather.low.label, 'GENTLE MODE');
    expect(GameState.unlocks[8], 'TODAY’S BONUS');
    expect(GameState.unlocks.containsKey(10), isFalse);
    expect(json['embers'], 17);
    expect(json, isNot(contains('glimmers')));
  });

  test('Quest Desk style is backward compatible and round-trips', () {
    final oldSave = GameState.fromJson(<String, dynamic>{});
    expect(oldSave.questDeskStyle, 'wall_walnut');

    final state = GameState()
      ..ownedStyles.add('wall_indigo')
      ..setQuestDeskStyle('wall_indigo');
    final restored = GameState.fromJson(state.toJson());

    expect(restored.questDeskStyle, 'wall_archive');
    expect(restored.ownedStyles, contains('wall_archive'));
    expect(activeQuestDeskLook(restored).name, 'Archive Ledger');
    expect(state.toJson()['questDeskStyle'], 'wall_indigo');
  });

  testWidgets('Quest Desk applies an owned room finish from its picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = GameState()
      ..onboarded = true
      ..reduceMotion = true
      ..ownedStyles.add('wall_archive');
    var saves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestsPage(
            state: state,
            quests: [
              Quest(title: 'Read ten pages', stat: Stat.intl, difficulty: 2),
            ],
            onRefresh: () => 0,
            onPersist: () => saves++,
            onAdd: (_) => true,
            onRemove: (_) {},
            onSnapshot: () => '',
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StatChips), findsOneWidget);
    expect(find.byType(QuestTapestryPanel), findsNothing);

    await tester.tap(find.byType(QuestDeskStyleButton));
    await tester.pumpAndSettle();
    expect(find.text('QUEST DESK'), findsOneWidget);

    final midnight = find.text('ARCHIVE LEDGER');
    await tester.scrollUntilVisible(
      midnight,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(midnight);
    await tester.pumpAndSettle();

    expect(state.questDeskStyle, 'wall_archive');
    expect(saves, 1);
    expect(
      find.bySemanticsLabel(RegExp('Quest Desk style, Archive Ledger')),
      findsOneWidget,
    );
  });

  testWidgets('Morrow Tapestry stays crisp while its woven cord grows', (
    tester,
  ) async {
    Future<void> show(int level) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MorrowTapestryGlyph(
              level: level,
              lit: true,
              reduceMotion: true,
              size: 96,
            ),
          ),
        ),
      ),
    );

    await show(1);
    expect(
      find.bySemanticsLabel('Morrow Tapestry, 12 percent woven'),
      findsOneWidget,
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(1));
    for (final image in images) {
      expect(
        (image.image as AssetImage).assetName,
        'assets/brand/morrowloom-icon-runtime-v2.webp',
      );
    }
    final earlyProgress = tester.widget<SizedBox>(
      find.byKey(const ValueKey('morrow-woven-progress')),
    );

    await show(34);
    expect(
      find.bySemanticsLabel('Morrow Tapestry, 100 percent woven'),
      findsOneWidget,
    );
    final completeProgress = tester.widget<SizedBox>(
      find.byKey(const ValueKey('morrow-woven-progress')),
    );
    expect(completeProgress.height!, greaterThan(earlyProgress.height! * 4));
  });

  testWidgets('wide tapestry remains available for milestone moments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: QuestTapestryPanel(
                level: 1,
                generation: 0,
                look: questDeskLooks.first,
                reduceMotion: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Morrow Tapestry, 12 percent permanently woven'),
      findsOneWidget,
    );
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images, isNotEmpty);
    for (final image in images) {
      expect(
        (image.image as AssetImage).assetName,
        'assets/brand/morrow-tapestry-wide-v2.webp',
      );
    }
  });

  testWidgets(
    'completion XP flight cleans itself up after reduced motion beat',
    (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 430,
              height: 932,
              child: QuestCompletionStitch(
                origin: const Offset(80, 680),
                destination: const Offset(220, 120),
                xp: 12,
                statColor: Stat.vit.color,
                reduceMotion: true,
                onDone: () => finished = true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('quest-completion-stitch')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 260));
      expect(finished, isTrue);
    },
  );
}
