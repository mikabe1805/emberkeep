import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/goals.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/living_hearth_fire.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a worn wardrobe skin overrides the fire without losing its shop hue',
    () {
      final state = GameState()
        ..creatureSkin = 'rose_quartz'
        ..collectedLoot.add('Periwinkle Frost');
      final underlyingHue = flameHueFor(state);

      state.equipSkin('Periwinkle Frost');
      expect(flameSkinIdFor(state), 'found_periwinkle');
      expect(flameHueFor(state), flameHueById('Periwinkle Frost'));
      expect(flameHueFor(state), isNot(underlyingHue));

      state.equipSkin('Periwinkle Frost');
      expect(state.equippedSkin, isNull);
      expect(flameSkinIdFor(state), 'rose_quartz');
      expect(flameHueFor(state), underlyingHue);
    },
  );

  testWidgets('Me keeps the shared painted flame animated', (tester) async {
    await tester.runAsync(preloadHomeRoomAssets);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 430,
          child: HomeRoom(unlocked: {}, plateId: 'wall_walnut', lively: true),
        ),
      ),
    );
    await tester.pump();
    final paintFinder = find.descendant(
      of: find.byType(HomeRoom),
      matching: find.byType(CustomPaint),
    );
    final before =
        (tester.widget<CustomPaint>(paintFinder).painter as dynamic).t;

    await tester.pump(const Duration(milliseconds: 180));
    final after =
        (tester.widget<CustomPaint>(paintFinder).painter as dynamic).t;

    expect(after, isNot(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quest animates the shared painted frames in the wardrobe hue', (
    tester,
  ) async {
    final parallax = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);
    final hue = flameHueById('Bloomlight');

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 430,
          height: 253,
          child: QuestDepthRoom(
            parallax: parallax,
            scrollPosition: scroll,
            flameHue: hue,
            lively: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final frames = tester.widgetList<RecoloredHearthFireFrame>(
      find.byType(RecoloredHearthFireFrame),
    );
    expect(frames, hasLength(2));
    expect(frames.every((frame) => frame.hue == hue), isTrue);
    expect(
      find.byKey(const ValueKey('recolored-hearth-fire')),
      findsNWidgets(2),
    );

    final firstAssets = frames.map((frame) => frame.asset).toList();
    await tester.pump(const Duration(milliseconds: 600));
    final advancedAssets = tester
        .widgetList<RecoloredHearthFireFrame>(
          find.byType(RecoloredHearthFireFrame),
        )
        .map((frame) => frame.asset)
        .toList();
    expect(advancedAssets, isNot(firstAssets));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Goals no longer adds the floating procedural flame', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });
    final state = GameState()..reduceMotion = true;

    await tester.pumpWidget(
      MaterialApp(
        home: GoalsPage(
          state: state,
          onAdd: (_) => true,
          activeTitles: const {},
          onRemoveGoal: (_) {},
          onPersist: () {},
          quests: const [],
          onOpenQuests: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('luxe-hero-fire')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
