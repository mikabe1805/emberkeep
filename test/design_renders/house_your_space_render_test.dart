// Renders the "Your space" page through the real app at iPhone size (393 x 852
// at 3x, PNGs 1179 x 2556): the mantel, the page at rest and scrolled, at 130%
// and 200% text, at midday and at evening, in the other room styles, and the
// shop's CHANGE SPACE page opened from it. Skipped unless asked for:
//
//   flutter test --dart-define=HOUSE_YOUR_SPACE=true \
//     test/design_renders/house_your_space_render_test.dart
//
// Output: design/comparisons/2026-10-11/h53-your-room/ in this checkout.
// YS_ONLY=rest,text,styles,evening,shop picks groups.
import 'dart:typed_data';

import 'package:emberkeep/clock.dart';
import 'package:emberkeep/content/space_themes.dart';
import 'package:emberkeep/room_photo.dart';
import 'package:emberkeep/widgets/class_day/doorway_art.dart';
import 'package:emberkeep/widgets/house/house_room.dart';
import 'package:emberkeep/widgets/house/me/mantel_model.dart';
import 'package:emberkeep/widgets/house/me/your_space_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'class_day_harness.dart';

const _renders = bool.fromEnvironment('HOUSE_YOUR_SPACE');
const _only = String.fromEnvironment('YS_ONLY');
bool _wants(String name) =>
    _only.isEmpty || _only.split(',').map((s) => s.trim()).contains(name);

const _out = String.fromEnvironment(
  'YS_OUT',
  defaultValue:
      'C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey/'
      'design/comparisons/2026-10-11/h53-your-room',
);

DateTime _at(int day, int hour, int minute) =>
    DateTime(2026, 10, day, hour, minute);

List<String> get _plates => {
  for (final set in [HousePlateSets.me]) ...set.all,
}.toList();

Future<void> _boot(
  WidgetTester tester,
  DateTime at, {
  String wall = 'wall_walnut',
}) async {
  final account = mikaAccount(renderAt: at);
  account.state.ownedStyles.add(wall);
  account.state.wallStyle = wall;
  Clock.freeze(at);
  await bootRoom(
    tester,
    account,
    schedule: mikaSchedule(),
    precache: [...RoomArt.everyday, ..._plates],
  );
  final context = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    for (final asset in DoorwayAssets.all) {
      await precacheImage(DoorwayAssets.providerFor(asset), context);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  await tester.pump(const Duration(milliseconds: 200));
}

/// A photograph to hang over the fireplace (a drawn sunset, for this render).
RoomPhotoData _photo() {
  const w = 900, h = 600;
  final picture = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final c = t < 0.55
        ? [
            246 + (217 - 246) * t / 0.55,
            197 + (128 - 197) * t / 0.55,
            139 + (92 - 139) * t / 0.55,
          ]
        : [
            217 + (94 - 217) * (t - 0.55) / 0.45,
            128 + (74 - 128) * (t - 0.55) / 0.45,
            92 + (116 - 92) * (t - 0.55) / 0.45,
          ];
    img.fillRect(
      picture,
      x1: 0,
      y1: y,
      x2: w,
      y2: y + 1,
      color: img.ColorRgb8(c[0].round(), c[1].round(), c[2].round()),
    );
  }
  img.fillCircle(
    picture,
    x: 640,
    y: 250,
    radius: 80,
    color: img.ColorRgb8(255, 233, 184),
  );
  img.fillPolygon(
    picture,
    vertices: [
      img.Point(0, 420),
      img.Point(220, 330),
      img.Point(460, 400),
      img.Point(700, 450),
      img.Point(900, 340),
      img.Point(900, 600),
      img.Point(0, 600),
    ],
    color: img.ColorRgb8(46, 42, 63),
  );
  return RoomPhotoData(
    bytes: Uint8List.fromList(img.encodePng(picture)),
    pixelWidth: w,
    pixelHeight: h,
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await settle(tester, total: const Duration(milliseconds: 900));
}

Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.drag(find.byKey(const Key('your-space-scroll')), Offset(0, -by));
  await settle(tester, total: const Duration(milliseconds: 700));
}

void main() {
  setUpAll(setUpRoomRenders);
  tearDownAll(tearDownRoomRenders);
  final sheet = FrameSheet(_out);
  tearDownAll(() {
    if (_renders) sheet.writeManifest();
  });

  for (final (name, at, label) in [
    ('midday', _at(6, 12, 30), 'Tue Oct 6 12:30'),
    ('evening', _at(6, 21, 0), 'Tue Oct 6 21:00'),
  ]) {
    roomRenderTest('Your space at $name', skip: !_renders, (tester) async {
      if (!_wants(name == 'midday' ? 'rest' : 'evening')) return;
      await _boot(tester, at);
      await openTab(tester, RoomTab.me);
      await sheet.shot(
        tester,
        'Y_mantel_$name',
        at: at,
        surface: 'ME',
        note: 'the mantel, $label',
      );
      await _tap(tester, 'mantel-tab-space');
      await sheet.shot(
        tester,
        'Y_rest_$name',
        at: at,
        surface: 'YOUR SPACE',
        note: 'the page at rest, $label',
      );
      await _scroll(tester, 330);
      await sheet.shot(
        tester,
        'Y_scrolled_$name',
        at: at,
        surface: 'YOUR SPACE',
        note: 'scrolled 330, $label',
      );
      await _scroll(tester, 900);
      await sheet.shot(
        tester,
        'Y_end_$name',
        at: at,
        surface: 'YOUR SPACE',
        note: 'scrolled to the end, $label',
      );
    });
  }

  roomRenderTest('Your space and the shop', skip: !_renders, (tester) async {
    if (!_wants('shop')) return;
    final at = _at(6, 12, 30);
    await _boot(tester, at);
    await openTab(tester, RoomTab.me);
    await _tap(tester, 'mantel-tab-space');
    await tester.tap(find.text('CHANGE SPACE'));
    await tester.pump();
    await settle(tester, total: const Duration(milliseconds: 1000));
    await sheet.shot(
      tester,
      'Y_shop',
      at: at,
      surface: 'CHANGE SPACE',
      note: 'the shop opened from the page',
    );
  });

  roomRenderTest('Your space in every room style', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('styles')) return;
    final at = _at(6, 12, 30);
    for (final wall in [
      'wall_rain',
      'wall_conservatory',
      'wall_listening',
      'wall_archive',
      'wall_atelier',
    ]) {
      await _boot(tester, at, wall: wall);
      await openTab(tester, RoomTab.me);
      await _tap(tester, 'mantel-tab-space');
      await sheet.shot(
        tester,
        'Y_style_$wall',
        at: at,
        surface: 'YOUR SPACE',
        note: wall,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  // The room photo lives in the private store, whose image codec does not run
  // under the test harness, so the hero is rendered on its own (the page's own
  // widget, the same crop and fall) with the photo handed to it.
  roomRenderTest('The hero with a photo over the fireplace', skip: !_renders, (
    tester,
  ) async {
    if (!_wants('photo')) return;
    final at = _at(6, 12, 30);
    final photo = _photo();
    for (final wall in ['wall_walnut', 'wall_rain']) {
      final state = mikaAccount(renderAt: at).state
        ..ownedStyles.add(wall)
        ..wallStyle = wall;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF191210),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 852 * YourSpaceFrame.heroFraction,
                  child: YourRoomHero(
                    state: state,
                    quests: const [],
                    theme: spaceThemeById(wall)!,
                    ground: const Color(0xFF191210),
                    inset: 59,
                    roomPhoto: photo,
                    parallax: null,
                    scrollPosition: null,
                    scroll: null,
                    lively: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(YourRoomHero));
      await tester.runAsync(() async {
        await precacheImage(MemoryImage(photo.bytes), context);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await sheet.shot(
        tester,
        'Y_photo_$wall',
        at: at,
        surface: 'YOUR SPACE',
        note: 'the hero with a photo over the fireplace, $wall',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  for (final scale in [1.3, 2.0]) {
    roomRenderTest('Your space at ${scale}x text', skip: !_renders, (
      tester,
    ) async {
      if (!_wants('text')) return;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final at = _at(6, 12, 30);
      final pct = (scale * 100).round();
      await _boot(tester, at);
      await openTab(tester, RoomTab.me);
      await _tap(tester, 'mantel-tab-space');
      await sheet.shot(
        tester,
        'Y_rest_text$pct',
        at: at,
        surface: 'YOUR SPACE',
        note: 'the page at $pct% text',
      );
      await _scroll(tester, 420);
      await sheet.shot(
        tester,
        'Y_scrolled_text$pct',
        at: at,
        surface: 'YOUR SPACE',
        note: 'scrolled 420 at $pct% text',
      );
    });
  }
}
