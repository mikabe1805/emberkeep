import 'dart:io';

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/cosmetics.dart';
import 'package:emberkeep/content/creature_skins.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RoomPublishResult> _publishRoom(
  GameState _, {
  required String code,
}) async => RoomPublishResult.success(code);

Widget _mePage(GameState state) => MaterialApp(
  home: Scaffold(
    body: MePage(
      state: state,
      quests: const <Quest>[],
      onPersist: () {},
      onPublishRoom: _publishRoom,
      onAddQuest: (_) => true,
      onExport: () async => true,
      onImport: (_) async => true,
      onReset: () async => null,
      onNotifyChanged: () async {},
      onEnableCloud: () async => null,
      onLinkAccount: (_, _) async => null,
      onSignIn: (_, _) async => null,
      onSignOut: () async {},
      onDeleteAccount: (_) async => null,
      onRemovePrivateServiceIdentity: () async => null,
    ),
  ),
);

void main() {
  setUpAll(() async {
    Sfx.instance.soundEnabled = false;
  });

  tearDownAll(() {
    Sfx.instance.soundEnabled = true;
  });

  test('wearing a found skin overrides and then reveals the chosen flame', () {
    final state = GameState()
      ..creatureSkin = 'mint_glass'
      ..collectedLoot.add('Periwinkle Frost');
    final underlying = flameHueFor(state);

    state.equipSkin('Periwinkle Frost');
    expect(flameSkinIdFor(state), 'found_periwinkle');
    expect(flameHueFor(state), flameHueById('Periwinkle Frost'));
    expect(flameHueFor(state), isNot(underlying));

    state.equipSkin('Periwinkle Frost');
    expect(flameSkinIdFor(state), 'mint_glass');
    expect(flameHueFor(state), underlying);
  });

  test('the reported wardrobe colours resolve to distinct flame hues', () {
    final colours = <int>{
      for (final name in const [
        'Periwinkle Frost',
        'Midnight Theme Shard',
        'Bloomlight',
      ])
        flameHueById(name).toARGB32(),
    };
    expect(colours, hasLength(3));
  });

  test(
    'the public room carries the same bounded flame identity visitors use',
    () {
      final state = GameState()..collectedLoot.add('Midnight Theme Shard');
      state.equipSkin('Midnight Theme Shard');

      final payload = roomDisplay(state);
      expect(payload['skin'], 'found_midnight');
      expect(flameHueById(payload['skin'] as String), flameHueFor(state));

      final rules = File('firestore.rules').readAsStringSync();
      for (final name in cosmetics.keys) {
        final found = GameState()..collectedLoot.add(name);
        found.equipSkin(name);
        expect(rules, contains("'${flameSkinIdFor(found)}'"));
      }
    },
  );

  testWidgets('the wardrobe dialog previews the flame WEAR THIS applies', (
    tester,
  ) async {
    await tester.runAsync(preloadHomeRoomAssets);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = GameState()
      ..reduceMotion = true
      ..collectedLoot.add('Periwinkle Frost');
    await tester.pumpWidget(_mePage(state));
    await tester.pump();

    final triggerFinder = find.byKey(
      const ValueKey('wardrobe-skin-Periwinkle Frost'),
    );
    await tester.scrollUntilVisible(
      triggerFinder,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    final trigger = tester.widget<GestureDetector>(triggerFinder);
    trigger.onTap!();
    await tester.pumpAndSettle();

    final preview = tester.widget<HomeRoom>(
      find.byKey(const ValueKey('skin-preview-room-Periwinkle Frost')),
    );
    expect(preview.emberGlow, flameHueById('Periwinkle Frost'));
    await tester.tap(find.text('WEAR THIS'));
    await tester.pumpAndSettle();
    expect(state.equippedSkin, 'Periwinkle Frost');
    expect(flameHueFor(state), preview.emberGlow);
  });
}
