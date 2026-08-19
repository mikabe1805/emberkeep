import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../tool/build_shipping_icon_review.dart' as shipping;

void main() {
  test('renders the exact platform outputs into one opaque review sheet', () {
    final root = Directory.systemTemp.createTempSync('shipping-icon-review-');
    addTearDown(() => root.deleteSync(recursive: true));
    _writeFixture(root);
    final output = Directory(_path(root, 'design/icon-review'));

    final result = shipping.buildShippingIconReview(
      appRootPath: root.path,
      outputDirectoryPath: output.path,
    );

    final decoded = img.decodePng(result.outputFile.readAsBytesSync());
    expect(decoded, isNotNull);
    expect(decoded!.width, shipping.shippingReviewWidth);
    expect(decoded.height, shipping.shippingReviewHeight);
    expect(decoded.numChannels, 3);
  });

  test('adaptive preview applies the configured eight-percent inset', () {
    final foreground = img.Image(width: 100, height: 100, numChannels: 4)
      ..clear(img.ColorRgba8(220, 180, 100, 255));
    final composed = shipping.composeAdaptiveIcon(
      foreground,
      background: img.ColorRgb8(20, 10, 5),
      size: 100,
    );

    expect(composed.getPixel(0, 0).r, 20);
    expect(composed.getPixel(7, 50).r, 20);
    expect(composed.getPixel(8, 50).r, 220);
    expect(composed.getPixel(91, 50).r, 220);
    expect(composed.getPixel(92, 50).r, 20);
  });
}

void _writeFixture(Directory root) {
  File(_path(root, 'pubspec.yaml'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('name: fixture\n');
  final opaque = img.Image(width: 512, height: 512, numChannels: 3)
    ..clear(img.ColorRgb8(80, 45, 22));
  final transparent = img.Image(width: 432, height: 432, numChannels: 4)
    ..clear(img.ColorRgba8(0, 0, 0, 0));
  img.fillRect(
    transparent,
    x1: 80,
    y1: 100,
    x2: 351,
    y2: 331,
    color: img.ColorRgba8(220, 180, 100, 255),
  );
  final outputs = <String, img.Image>{
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
            'Icon-App-60x60@3x.png':
        opaque,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': opaque,
    'android/app/src/main/res/drawable-xxxhdpi/'
            'ic_launcher_foreground.png':
        transparent,
    'android/app/src/main/res/drawable-xxxhdpi/'
            'ic_launcher_monochrome.png':
        transparent,
    'web/icons/Icon-maskable-512.png': opaque,
  };
  for (final entry in outputs.entries) {
    final file = File(_path(root, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(entry.value));
  }
  final icoFile = File(_path(root, 'windows/runner/resources/app_icon.ico'))
    ..parent.createSync(recursive: true);
  icoFile.writeAsBytesSync(
    img.encodeIco(img.copyResize(opaque, width: 256, height: 256)),
  );
}

String _path(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';
