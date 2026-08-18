import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:emberkeep/tokens.dart';
import 'package:emberkeep/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_platform_policy.dart';

const _verifyExactGoldens = bool.fromEnvironment('VERIFY_EXACT_GOLDENS');

void main() {
  testWidgets('warm background has no hard ambient planes', (tester) async {
    await _pumpWarmBackground(tester);
    await runExactGoldenCheck(
      operatingSystem: Platform.operatingSystem,
      explicitlyEnabled: _verifyExactGoldens,
      updatingGoldens: autoUpdateGoldenFiles,
      compare: () => expectLater(
        find.byType(WarmBackground),
        matchesGoldenFile('goldens/warm_background_no_planes_430x932.png'),
      ),
    );
  });

  test('warm glow bounds fade without clipped color jumps', () async {
    final bytes = await File(
      'test/goldens/warm_background_no_planes_430x932.png',
    ).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final rgba = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();

    expect(rgba, isNotNull);
    expect(
      _averageRgbStep(
        rgba!,
        width: 430,
        from: const Offset(290, 199),
        to: const Offset(420, 199),
        dx: 0,
        dy: 1,
      ),
      lessThan(6),
      reason: 'the upper edge of the right glow must fade continuously',
    );
    expect(
      _averageRgbStep(
        rgba,
        width: 430,
        from: const Offset(239, 245),
        to: const Offset(239, 399),
        dx: 1,
        dy: 0,
      ),
      lessThan(6),
      reason: 'the left edge of the right glow must fade continuously',
    );
  });
}

Future<void> _pumpWarmBackground(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    const MaterialApp(
      home: RepaintBoundary(
        key: ValueKey('warm-background-boundary'),
        child: WarmBackground(
          themeId: 'walnut',
          tint: Palette.streak,
          reduceMotion: true,
          child: SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _averageRgbStep(
  ByteData rgba, {
  required int width,
  required Offset from,
  required Offset to,
  required int dx,
  required int dy,
}) {
  var total = 0;
  var samples = 0;
  for (var y = from.dy.toInt(); y <= to.dy.toInt(); y++) {
    for (var x = from.dx.toInt(); x <= to.dx.toInt(); x++) {
      final first = (y * width + x) * 4;
      final second = ((y + dy) * width + x + dx) * 4;
      for (var channel = 0; channel < 3; channel++) {
        total +=
            (rgba.getUint8(first + channel) - rgba.getUint8(second + channel))
                .abs();
      }
      samples++;
    }
  }
  return total / samples;
}
