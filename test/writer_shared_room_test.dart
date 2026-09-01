import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/room_photo.dart';
import 'package:emberkeep/widgets/home_room.dart';
import 'package:emberkeep/widgets/quest_depth_room.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

Offset _translation(WidgetTester tester, String key) {
  final transform = tester.widget<Transform>(find.byKey(ValueKey(key)));
  final translation = transform.transform.getTranslation();
  return Offset(translation.x, translation.y);
}

Set<String> _assetNames(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => image.image)
    .whereType<AssetImage>()
    .map((image) => image.assetName)
    .toSet();

Widget _room({
  required ValueListenable<Offset> parallax,
  required ValueListenable<double> scrollPosition,
  required String wall,
  bool disableAnimations = false,
  bool tickerEnabled = false,
  bool hearthLit = true,
  bool lively = true,
  bool lightweightPreview = false,
  bool softened = false,
  RoomPhotoData? roomPhoto,
  Key? key,
}) => MaterialApp(
  home: TickerMode(
    enabled: tickerEnabled,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Center(
        child: SizedBox(
          width: 430,
          child: HomeRoom(
            key: key,
            aspect: 1.7,
            lively: lively,
            unlocked: const {},
            plateId: wall,
            parallax: parallax,
            scrollPosition: scrollPosition,
            hearthLit: hearthLit,
            lightweightPreview: lightweightPreview,
            softened: softened,
            roomPhoto: roomPhoto,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'the shared Writer room preserves registered depth and hearth attachment',
    (tester) async {
      final parallax = ValueNotifier(Offset.zero);
      final scroll = ValueNotifier(0.0);
      addTearDown(parallax.dispose);
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        _room(parallax: parallax, scrollPosition: scroll, wall: 'wall_walnut'),
      );
      await tester.pump();

      for (final key in const [
        'quest-depth-far-plane',
        'quest-depth-wall-plane',
        'quest-depth-furniture-plane',
        'quest-depth-foreground-plane',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(find.byType(QuestDepthRoom), findsOneWidget);

      parallax.value = const Offset(.6, -.4);
      scroll.value = 120;
      await tester.pump();

      final far = _translation(tester, 'quest-depth-far-plane');
      final wall = _translation(tester, 'quest-depth-wall-plane');
      final furniture = _translation(tester, 'quest-depth-furniture-plane');
      final foreground = _translation(tester, 'quest-depth-foreground-plane');
      expect(far, isNot(Offset.zero));
      expect(far.distance, lessThan(wall.distance));
      expect(wall.distance, lessThan(furniture.distance));
      expect(furniture.distance, lessThan(foreground.distance));
      expect(
        find.byKey(const ValueKey('quest-depth-overlay-plane')),
        findsNothing,
      );

      final fireTransforms = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.byKey(const ValueKey('quest-depth-fire')),
              matching: find.byType(Transform),
            ),
          )
          .map((transform) {
            final translation = transform.transform.getTranslation();
            return Offset(translation.x, translation.y);
          })
          .toList();
      expect(
        fireTransforms,
        contains(far),
        reason: 'the live hearth remains attached to the same far plane',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an explicit Writer photo swaps only the registered wall treatment',
    (tester) async {
      final parallax = ValueNotifier(Offset.zero);
      final scroll = ValueNotifier(0.0);
      addTearDown(parallax.dispose);
      addTearDown(scroll.dispose);
      final asset = await rootBundle.load(
        'assets/brand/room-of-days-monochrome-v2.png',
      );
      final photo = RoomPhotoData(
        bytes: asset.buffer.asUint8List(
          asset.offsetInBytes,
          asset.lengthInBytes,
        ),
        pixelWidth: 1024,
        pixelHeight: 1024,
      );

      await tester.pumpWidget(
        _room(
          key: const ValueKey('writer-photo-mode'),
          parallax: parallax,
          scrollPosition: scroll,
          wall: 'wall_walnut',
          roomPhoto: photo,
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          MemoryImage(photo.bytes),
          tester.element(find.byType(MaterialApp)),
        );
      });
      await tester.pump();

      var depthRoom = tester.widget<QuestDepthRoom>(
        find.byType(QuestDepthRoom),
      );
      expect(depthRoom.wallAssetOverride, QuestDepthRoom.photoReadyWallAsset);
      expect(depthRoom.layers, isNull);
      expect(depthRoom.flattenedAsset, isNull);
      expect(
        find.byKey(const ValueKey('room-private-photo-plane')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _room(
          key: const ValueKey('writer-photo-mode'),
          parallax: parallax,
          scrollPosition: scroll,
          wall: 'wall_walnut',
          roomPhoto: photo,
          softened: true,
        ),
      );
      await tester.pump();

      depthRoom = tester.widget<QuestDepthRoom>(find.byType(QuestDepthRoom));
      expect(depthRoom.wallAssetOverride, isNull);
      expect(depthRoom.layers, same(QuestDepthRoom.photoSoftLayers));
      expect(depthRoom.flattenedAsset, isNull);

      await tester.pumpWidget(
        _room(
          key: const ValueKey('writer-photo-mode'),
          parallax: parallax,
          scrollPosition: scroll,
          wall: 'wall_walnut',
        ),
      );
      await tester.pump();

      depthRoom = tester.widget<QuestDepthRoom>(find.byType(QuestDepthRoom));
      expect(depthRoom.wallAssetOverride, isNull);
      expect(depthRoom.layers, isNull);
      expect(depthRoom.flattenedAsset, isNull);
      expect(
        find.byKey(const ValueKey('room-private-photo-plane')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion parks the shared Writer depth scene', (
    tester,
  ) async {
    final parallax = ValueNotifier(const Offset(.75, -.5));
    final scroll = ValueNotifier(180.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _room(
        parallax: parallax,
        scrollPosition: scroll,
        wall: 'wall_walnut',
        disableAnimations: true,
      ),
    );
    await tester.pump();

    for (final key in const [
      'quest-depth-far-plane',
      'quest-depth-wall-plane',
      'quest-depth-furniture-plane',
      'quest-depth-foreground-plane',
    ]) {
      expect(_translation(tester, key), Offset.zero);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Writer previews and soft room use the authored flattened plates',
    (tester) async {
      final parallax = ValueNotifier(Offset.zero);
      final scroll = ValueNotifier(0.0);
      addTearDown(parallax.dispose);
      addTearDown(scroll.dispose);
      final writer = spaceThemeById('wall_walnut')!;

      await tester.pumpWidget(
        _room(
          key: const ValueKey('writer-mode'),
          parallax: parallax,
          scrollPosition: scroll,
          wall: writer.id,
          lightweightPreview: true,
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('quest-depth-overlay-plane')),
        findsNothing,
      );
      expect(_assetNames(tester), contains(writer.previewAsset));
      expect(
        find.byKey(const ValueKey('quest-depth-wall-plane')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _room(
          key: const ValueKey('writer-mode'),
          parallax: parallax,
          scrollPosition: scroll,
          wall: writer.id,
          softened: true,
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('quest-depth-overlay-plane')),
        findsNothing,
      );
      expect(_assetNames(tester), contains(QuestDepthRoom.scrollSoftAsset));
      expect(
        find.byKey(const ValueKey('quest-depth-far-plane')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quest-depth-wall-plane')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('quest-depth-furniture-plane')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('quest-depth-foreground-plane')),
        findsNothing,
      );
      parallax.value = const Offset(.45, -.3);
      scroll.value = 100;
      await tester.pump();
      final far = _translation(tester, 'quest-depth-far-plane');
      expect(far, isNot(Offset.zero));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an unlit lively Writer room parks its fire painter', (
    tester,
  ) async {
    final parallax = ValueNotifier(Offset.zero);
    final scroll = ValueNotifier(0.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _room(
        parallax: parallax,
        scrollPosition: scroll,
        wall: 'wall_walnut',
        hearthLit: false,
        tickerEnabled: true,
      ),
    );
    await tester.pump();
    final fire = find.byKey(const ValueKey('quest-depth-fire'));
    final parked = tester.widget<CustomPaint>(fire).painter;
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<CustomPaint>(fire).painter, same(parked));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a still Writer preview keeps camera response without fire life',
    (tester) async {
      final parallax = ValueNotifier(Offset.zero);
      final scroll = ValueNotifier(0.0);
      addTearDown(parallax.dispose);
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        _room(
          parallax: parallax,
          scrollPosition: scroll,
          wall: 'wall_walnut',
          lightweightPreview: true,
          lively: false,
          tickerEnabled: true,
        ),
      );
      await tester.pump();
      final parkedFar = _translation(tester, 'quest-depth-far-plane');
      final fire = find.byKey(const ValueKey('quest-depth-fire'));
      final parkedFire = tester.widget<CustomPaint>(fire).painter;

      parallax.value = const Offset(.52, -.36);
      await tester.pump();
      expect(_translation(tester, 'quest-depth-far-plane'), isNot(parkedFar));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.widget<CustomPaint>(fire).painter, same(parkedFire));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('other saved room identities retain the authored plate route', (
    tester,
  ) async {
    final parallax = ValueNotifier(const Offset(.4, -.2));
    final scroll = ValueNotifier(80.0);
    addTearDown(parallax.dispose);
    addTearDown(scroll.dispose);

    await tester.pumpWidget(
      _room(parallax: parallax, scrollPosition: scroll, wall: 'wall_rain'),
    );
    await tester.pump();

    expect(find.byType(QuestDepthRoom), findsNothing);
    expect(
      find.byKey(const ValueKey('quest-depth-overlay-plane')),
      findsNothing,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
