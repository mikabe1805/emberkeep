import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('committed icon sources and derivatives match the hash manifest', () {
    final manifest =
        jsonDecode(
              File(
                'assets/brand/room-of-days-icon-manifest-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(manifest['identity'], 'Room of Days - Day Ledger');
    final records = <Map<String, dynamic>>[
      ...(manifest['sources'] as List).cast<Map<String, dynamic>>(),
      ...(manifest['outputs'] as List).cast<Map<String, dynamic>>(),
    ];
    expect(records.length, greaterThanOrEqualTo(48));

    for (final record in records) {
      final path = record['path'] as String;
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'Missing icon asset: $path');
      final bytes = file.readAsBytesSync();
      expect(
        sha256.convert(bytes).toString().toUpperCase(),
        record['sha256'],
        reason: 'Hash mismatch: $path',
      );
      if (path.endsWith('.png')) {
        final decoded = img.decodePng(bytes);
        expect(decoded, isNotNull, reason: 'Invalid PNG: $path');
        expect(decoded!.width, record['width'], reason: path);
        expect(decoded.height, record['height'], reason: path);
        expect(decoded.numChannels, record['channels'], reason: path);
      }
    }
  });

  test(
    'platform icon configuration preserves transparency and mask safety',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains(
          'adaptive_icon_foreground: '
          '"assets/brand/room-of-days-adaptive-foreground-v1.png"',
        ),
      );
      expect(
        pubspec,
        contains(
          'adaptive_icon_monochrome: '
          '"assets/brand/room-of-days-monochrome-v2.png"',
        ),
      );
      expect(pubspec, contains('adaptive_icon_foreground_inset: 8'));
      final adaptiveXml = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      expect(adaptiveXml, contains('android:inset="8%"'));

      final foreground = img.decodePng(
        File(
          'assets/brand/room-of-days-adaptive-foreground-v1.png',
        ).readAsBytesSync(),
      )!;
      expect(foreground.numChannels, 4);
      expect(foreground.getPixel(0, 0).a, 0);
      expect(
        foreground.getPixel(foreground.width ~/ 2, foreground.height ~/ 2).a,
        255,
      );
      var greenLeak = 0;
      for (final pixel in foreground) {
        if (pixel.a.toInt() > 20 &&
            pixel.g.toInt() - math.max(pixel.r.toInt(), pixel.b.toInt()) > 48) {
          greenLeak++;
        }
      }
      expect(greenLeak, 0);

      final iosStore = img.decodePng(
        File(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
          'Icon-App-1024x1024@1x.png',
        ).readAsBytesSync(),
      )!;
      expect(iosStore.width, 1024);
      expect(iosStore.height, 1024);
      expect(iosStore.numChannels, 3);
      final webStore = img.decodePng(
        File('web/icons/Icon-1024.png').readAsBytesSync(),
      )!;
      expect(webStore.numChannels, 3);
    },
  );
}
