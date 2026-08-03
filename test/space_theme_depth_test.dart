import 'package:emberkeep/audio.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/screens/shop.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await preloadHomeRoomAssets();
  });

  testWidgets(
    'every complete room shares the same intact-camera and light response',
    (tester) async {
      final parallax = ValueNotifier(Offset.zero);
      addTearDown(parallax.dispose);

      for (final size in const [Size(430, 932), Size(320, 568)]) {
        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(size);

        for (final theme in spaceThemes) {
          for (final lightweight in const [false, true]) {
            final roomKey = ValueKey(
              'depth-${size.width}-${theme.id}-$lightweight',
            );
            parallax.value = Offset.zero;
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: size.width,
                      child: HomeRoom(
                        key: roomKey,
                        aspect: 1.5,
                        lively: false,
                        unlocked: const {},
                        plateId: theme.id,
                        lightweightPreview: lightweight,
                        parallax: parallax,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            final paintFinder = find.descendant(
              of: find.byKey(roomKey),
              matching: find.byType(CustomPaint),
            );
            final parked = tester.widget<CustomPaint>(paintFinder).painter;
            expect((parked as dynamic).plate, isNotNull);
            expect((parked as dynamic).parallax, Offset.zero);

            parallax.value = const Offset(0.82, -0.68);
            await tester.pump();
            final tilted = tester.widget<CustomPaint>(paintFinder).painter;

            expect(
              tilted,
              isNot(same(parked)),
              reason:
                  '${theme.name} ${lightweight ? 'chooser' : 'full room'} '
                  'must answer the shared camera/light field at ${size.width} px',
            );
            expect((tilted as dynamic).parallax, const Offset(0.82, -0.68));
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'chooser cards use shared parallax without three autonomous fire loops',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final parallax = ValueNotifier(const Offset(0.55, -0.35));
      addTearDown(parallax.dispose);
      Sfx.instance.soundEnabled = false;
      addTearDown(() => Sfx.instance.soundEnabled = true);
      final state = GameState();
      await tester.pumpWidget(
        MaterialApp(
          home: ShopScreen(state: state, onPersist: () {}, parallax: parallax),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final current = tester.widget<HomeRoom>(
        find.byKey(const ValueKey('current-space-wall_walnut')),
      );
      expect(current.lively, isTrue);
      expect(current.parallax, same(parallax));

      final list = find.byKey(const ValueKey('space-theme-list'));
      final target = find.byKey(const ValueKey('space-choice-wall_walnut'));
      for (var attempt = 0; attempt < 8 && !tester.any(target); attempt++) {
        await tester.drag(list, const Offset(0, -220));
        await tester.pump(const Duration(milliseconds: 60));
      }
      final chooser = tester.widget<HomeRoom>(target);
      expect(chooser.lightweightPreview, isTrue);
      expect(chooser.lively, isFalse);
      expect(chooser.parallax, same(parallax));

      final cardGesture = find
          .ancestor(of: target, matching: find.byType(GestureDetector))
          .first;
      tester.widget<GestureDetector>(cardGesture).onTap!.call();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final fullPreview = tester.widget<HomeRoom>(
        find.byKey(const ValueKey('theme-preview-wall_walnut')),
      );
      expect(fullPreview.lightweightPreview, isFalse);
      expect(fullPreview.lively, isTrue);
      expect(fullPreview.parallax, same(parallax));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chooser previews keep depth and Reduced Motion parks every room',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final parallax = ValueNotifier(const Offset(0.55, -0.35));
      addTearDown(parallax.dispose);
      final state = GameState()..reduceMotion = true;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.5),
              disableAnimations: true,
            ),
            child: ShopScreen(
              state: state,
              onPersist: () {},
              parallax: parallax,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final current = tester.widget<HomeRoom>(
        find.byKey(const ValueKey('current-space-wall_walnut')),
      );
      expect(current.lightweightPreview, isFalse);
      expect(current.parallax, isNull);
      expect(current.lively, isFalse);

      final list = find.byKey(const ValueKey('space-theme-list'));
      for (final theme in spaceThemes) {
        final target = find.byKey(ValueKey('space-choice-${theme.id}'));
        for (var attempt = 0; attempt < 12 && !tester.any(target); attempt++) {
          await tester.drag(list, const Offset(0, -220));
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(target, findsOneWidget);
        final room = tester.widget<HomeRoom>(target);
        expect(room.plateId, theme.id);
        expect(room.lightweightPreview, isTrue);
        expect(room.parallax, isNull);
        expect(room.lively, isFalse);
      }

      expect(find.text('The Moonlit Archive'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
