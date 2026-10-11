// "Your space": YOUR SPACE on the mantel opens a page whose hero is the
// player's own room, with the controls the old sheet held under it. It opens
// from the pill, shows the live HomeRoom, reaches every control, returns to the
// mantel (button, system back, edge swipe), shows a room chosen in the shop at
// once, and holds up at large text, with Reduce Motion and for VoiceOver.

import 'package:emberkeep/audio.dart';
import 'package:emberkeep/clock.dart';
import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart' show RoomStyleKind;
import 'package:emberkeep/screens/me.dart';
import 'package:emberkeep/screens/shop.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/house/me/mantel_model.dart';
import 'package:emberkeep/widgets/house/me/your_space_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_sheet_support.dart';

Widget _app(
  GameState state, {
  ValueListenable<Offset>? parallax,
  bool discovery = true,
}) => MaterialApp(
  home: Scaffold(
    body: MePage(
      state: state,
      quests: const [],
      onPersist: () {},
      onPublishRoom: (_, {required code}) async =>
          RoomPublishResult.success(code),
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
      parallax: parallax ?? const AlwaysStoppedAnimation(Offset.zero),
      spaceDiscoveryEnabled: discovery,
    ),
  ),
);

/// A phone, 393 x 852 points, under a 59 point status bar and over a 34 point
/// home indicator. Every route sees the text size (the platform's).
void _phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}

GameState _state({bool reduceMotion = true}) => GameState()
  ..reduceMotion = reduceMotion
  ..level = 18
  ..streakDays = 4
  ..embers = 640;

Finder get _room => find.byKey(const Key('your-space-room'));
Finder get _page => find.byType(YourSpacePage);
HomeRoom get _homeRoom => (_room.evaluate().single.widget) as HomeRoom;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The rooms decode once, here, in real time, as the shop's tests do.
    await preloadHomeRoomAssets();
  });
  setUp(() {
    Sfx.instance.soundEnabled = false;
    Clock.freeze(DateTime(2026, 10, 6, 12, 30));
  });
  tearDown(() {
    Sfx.instance.soundEnabled = true;
    Clock.reset();
  });

  group('it opens from the pill', () {
    testWidgets('YOUR SPACE is a page: the room, the heading, no sheet', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_state()));
      await tester.pump();
      expect(_page, findsNothing);

      await openMantelSheet(tester, 'space');
      expect(_page, findsOneWidget);
      expect(find.byKey(const Key('mantel-sheet')), findsNothing);
      expect(_room, findsOneWidget);
      expect(find.text('YOUR OWN ROOM'), findsOneWidget);
      expect(find.text('Your space'), findsOneWidget);
      // The page is its own route, named for the way back.
      final route = ModalRoute.of(tester.element(_page))!;
      expect(route.settings.name, 'your-space');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the old Me sheet for it is gone: one path', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_state()));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mantel-tab-space')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // No dimmed barrier, no CLOSE: a page has BACK.
      expect(find.byKey(const Key('mantel-sheet-barrier')), findsNothing);
      expect(find.byKey(const Key('mantel-sheet-close')), findsNothing);
      expect(find.byKey(const Key('your-space-back')), findsOneWidget);
    });
  });

  group('the room is the hero', () {
    testWidgets('the live HomeRoom, from the save, under the status bar', (
      tester,
    ) async {
      _phone(tester);
      final state = _state()..roomCode = 'ABC234';
      await tester.pumpWidget(_app(state));
      await tester.pump();
      await openMantelSheet(tester, 'space');

      final room = _homeRoom;
      expect(room.plateId, state.wallStyle);
      expect(room.level, 18);
      expect(room.petAwake, isTrue);
      expect(room.unlocked, isEmpty);
      // About 57% of the screen, edge to edge, up to the top of it. The fall
      // at its foot marks where the picture ends.
      final fall = tester.getRect(find.byKey(const Key('your-space-fall')));
      expect(fall.left, 0);
      expect(fall.right, 393);
      expect(fall.bottom, closeTo(852 * YourSpaceFrame.heroFraction, 0.5));
      // The glass rises over the room's foot.
      final glass = tester.getRect(find.byKey(const Key('your-space-glass')));
      expect(glass.top, closeTo(fall.bottom - YourSpaceFrame.glassLift, 0.5));
      expect(glass.left, YourSpaceFrame.glassInset);
      // The room's name is under the title.
      expect(find.text('The Writer’s Hearth'), findsOneWidget);
    });

    testWidgets('a room tried on in the shop is the hero when it returns', (
      tester,
    ) async {
      _phone(tester);
      final state = _state();
      await tester.pumpWidget(_app(state));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(_homeRoom.plateId, 'wall_walnut');

      // CHANGE SPACE opens the shop, over the page.
      await tester.tap(find.text('CHANGE SPACE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ShopScreen), findsOneWidget);

      // Move into a free room through the shop's own button.
      final move = find.text('MOVE IN');
      await tester.scrollUntilVisible(
        move,
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('space-theme-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(move.first);
      await tester.pump();
      await tester.tap(move.first);
      // The shop readies the room's painting before it moves in.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.wallStyle, isNot('wall_walnut'));
      final chosen = state.wallStyle;

      // Back from the shop: the hero is already that room.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShopScreen), findsNothing);
      expect(_page, findsOneWidget);
      expect(_homeRoom.plateId, chosen);
      expect(find.text(spaceThemeById(chosen)!.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a room bought while the page waits shows on return too', (
      tester,
    ) async {
      _phone(tester);
      final state = _state()..embers = 900;
      await tester.pumpWidget(_app(state));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      await tester.tap(find.text('CHANGE SPACE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      // Bought (by the shop's own path in the save), then back.
      final bought = state.buyStyle(
        'wall_archive',
        spaceThemeById('wall_archive')!.price,
        RoomStyleKind.wall,
      );
      expect(bought, isTrue);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_homeRoom.plateId, 'wall_archive');
      expect(find.text('The Moonlit Archive'), findsOneWidget);
    });
  });

  group('every control is on the page', () {
    testWidgets('change space, the room photo, the links, Discover, My Space', (
      tester,
    ) async {
      _phone(tester);
      final state = _state()..roomCode = 'ABC234';
      await tester.pumpWidget(_app(state));
      await tester.pump();
      await openMantelSheet(tester, 'space');

      for (final control in [
        find.text('CHANGE SPACE'),
        find.text('640 GLIMMERS'),
        find.text('Your room photo'),
        find.byKey(const Key('preview-public-space')),
        find.textContaining('Shared'),
        find.text('Discover spaces'),
        find.text('MY SPACE'),
        find.byKey(const ValueKey('space-page-open-arranger')),
      ]) {
        await tester.scrollUntilVisible(
          control,
          200,
          scrollable: mantelSheetScrollable,
        );
        await tester.ensureVisible(control.first);
        await tester.pump();
        expect(control, findsWidgets);
        expect(control.hitTestable(), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Visit a space stands in for Discover when it is off', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_state(), discovery: false));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(find.text('Visit a space'), findsOneWidget);
      expect(find.text('Discover spaces'), findsNothing);
    });

    testWidgets('a control that follows the save answers at once', (
      tester,
    ) async {
      _phone(tester);
      final state = _state();
      await tester.pumpWidget(_app(state));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(find.text('Share my space'), findsOneWidget);
      state.setRoomCode('XYZ789');
      await tester.pump();
      expect(find.text('Share my space'), findsNothing);
      expect(find.textContaining('XYZ789'), findsWidgets);
    });
  });

  group('back returns to the mantel', () {
    for (final way in ['BACK', 'system back', 'edge swipe']) {
      testWidgets(way, (tester) async {
        _phone(tester);
        if (way == 'edge swipe') {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        }
        try {
          await tester.pumpWidget(_app(_state()));
          await tester.pump();
          await openMantelSheet(tester, 'space');
          expect(_page, findsOneWidget);
          // The mantel waits under it.
          expect(find.byKey(const Key('mantel-build-card')), findsNothing);

          switch (way) {
            case 'BACK':
              await tester.tap(find.byKey(const Key('your-space-back')));
            case 'system back':
              await tester.binding.handlePopRoute();
            case 'edge swipe':
              await tester.dragFrom(const Offset(3, 400), const Offset(330, 0));
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
          expect(_page, findsNothing, reason: way);
          expect(find.byKey(const Key('mantel-build-card')), findsOneWidget);
          expect(find.byKey(const Key('mantel-tab-space')), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('the page can be opened again after it was left', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_state()));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await openMantelSheet(tester, 'space');
        expect(_page, findsOneWidget);
        await closeMantelSheet(tester);
        expect(_page, findsNothing);
      }
    });
  });

  group('large text, Reduce Motion and VoiceOver', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
        'at ${(scale * 100).round()}% the controls scroll under the room',
        (tester) async {
          _phone(tester, textScale: scale);
          final state = _state()..roomCode = 'ABC234';
          await tester.pumpWidget(_app(state));
          await tester.pump();
          await openMantelSheet(tester, 'space');
          expect(tester.takeException(), isNull);

          // At rest: BACK clear of the glass, 44 points to touch, the heading
          // under the room.
          final back = tester.getRect(find.byKey(const Key('your-space-back')));
          expect(back.width, greaterThanOrEqualTo(44));
          expect(back.height, greaterThanOrEqualTo(44));
          final glass = tester.getRect(
            find.byKey(const Key('your-space-glass')),
          );
          expect(back.bottom, lessThanOrEqualTo(glass.top));
          expect(find.text('Your space'), findsOneWidget);

          // Every control scrolls into reach and stays whole.
          for (final control in [
            find.text('CHANGE SPACE'),
            find.byKey(const Key('preview-public-space')),
            find.text('Discover spaces'),
            find.byKey(const ValueKey('space-page-open-arranger')),
          ]) {
            await tester.scrollUntilVisible(
              control,
              220,
              scrollable: mantelSheetScrollable,
            );
            await tester.ensureVisible(control.first);
            await tester.pump();
            expect(control.hitTestable(), findsWidgets);
            expect(tester.takeException(), isNull);
          }
          // The page does not scroll sideways.
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('your-space-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(scroll.position.axis, Axis.vertical);
        },
      );
    }

    testWidgets('Reduce Motion: the room keeps still, no tilt, no drift', (
      tester,
    ) async {
      _phone(tester);
      final tilt = ValueNotifier(const Offset(0.4, -0.2));
      addTearDown(tilt.dispose);
      await tester.pumpWidget(_app(_state(), parallax: tilt));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      final room = _homeRoom;
      expect(room.parallax, isNull);
      expect(room.scrollPosition, isNull);
      expect(room.lively, isFalse);
      expect(find.byKey(const Key('your-space-hero-shift')), findsNothing);
    });

    testWidgets('the system Reduce Motion does the same', (tester) async {
      _phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      final tilt = ValueNotifier(const Offset(0.4, -0.2));
      addTearDown(tilt.dispose);
      await tester.pumpWidget(
        _app(_state(reduceMotion: false), parallax: tilt),
      );
      await tester.pump();
      await openMantelSheet(tester, 'space');
      final room = _homeRoom;
      expect(room.parallax, isNull);
      expect(room.lively, isFalse);
      expect(find.byKey(const Key('your-space-hero-shift')), findsNothing);
    });

    testWidgets(
      'with motion on, the room tilts and drifts as the page scrolls',
      (tester) async {
        _phone(tester);
        final tilt = ValueNotifier(const Offset(0.4, -0.2));
        addTearDown(tilt.dispose);
        await tester.pumpWidget(
          _app(_state(reduceMotion: false), parallax: tilt),
        );
        await tester.pump();
        await openMantelSheet(tester, 'space');
        final room = _homeRoom;
        expect(room.parallax, same(tilt));
        expect(room.scrollPosition, isNotNull);
        expect(room.lively, isTrue);

        double lift() => tester
            .widget<Transform>(find.byKey(const Key('your-space-hero-shift')))
            .transform
            .getTranslation()
            .y;
        expect(lift(), 0);
        await tester.drag(
          find.byKey(const Key('your-space-scroll')),
          const Offset(0, -120),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(room.scrollPosition!.value, greaterThan(90));
        expect(lift(), closeTo(-room.scrollPosition!.value * 0.075, 0.1));
      },
    );

    testWidgets('VoiceOver: a named page, a back control, the room spoken', (
      tester,
    ) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_state()));
      await tester.pump();
      await openMantelSheet(tester, 'space');
      expect(find.bySemanticsLabel('Back to the mantel'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Your room, The Writer’s Hearth')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Your space'), findsWidgets);
      expect(
        tester.getSemantics(find.byKey(const Key('your-space-back'))),
        matchesSemantics(
          label: 'Back to the mantel',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('where things sit', () {
    test('the hero is 57 percent of a phone, never a sliver on a tall one', () {
      expect(
        YourSpaceFrame.heroHeight(const Size(393, 852)),
        closeTo(485.6, 0.1),
      );
      // A 430 x 2200 test surface keeps the room in proportion.
      expect(
        YourSpaceFrame.heroHeight(const Size(430, 2200)),
        430 * YourSpaceFrame.heroMaxWidths,
      );
    });

    test('the camera keeps the hearth in the slice, the far wall out', () {
      // The walnut room (1.7 wide, fire at .887) in a 393 x 427 slice shows
      // about 54% of it: the camera is on the fire's side.
      final walnut = YourSpaceFrame.cameraX(
        hero: const Size(393, 427),
        roomAspect: 1.7,
        hearthX: 0.887,
      );
      expect(walnut, greaterThan(0.5));
      expect(walnut, lessThanOrEqualTo(1));
      // A slice as wide as the room needs no camera.
      expect(
        YourSpaceFrame.cameraX(
          hero: const Size(700, 400),
          roomAspect: 1.5,
          hearthX: 0.866,
        ),
        0,
      );
      // A portrait slice shows the room's whole height; a wide one (a tablet)
      // is held on the fire's height, not on the ceiling.
      expect(
        YourSpaceFrame.cameraY(
          hero: const Size(393, 427),
          roomAspect: 1.7,
          hearthY: 0.78,
        ),
        0,
      );
      expect(
        YourSpaceFrame.cameraY(
          hero: const Size(1024, 414),
          roomAspect: 1.7,
          hearthY: 0.78,
        ),
        greaterThan(0.3),
      );
      // A fire in the middle of the room is centred.
      final middle = YourSpaceFrame.cameraX(
        hero: const Size(393, 427),
        roomAspect: 1.5,
        hearthX: 0.5,
        hearthAt: 0.5,
      );
      expect(middle, closeTo(0, 0.001));
    });
  });
}
