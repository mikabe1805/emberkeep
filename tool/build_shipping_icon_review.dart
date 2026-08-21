import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'build_icon_review.dart' as review;

const shippingReviewWidth = 2244;
const shippingReviewHeight = 620;

final class ShippingIconReviewResult {
  const ShippingIconReviewResult(this.outputFile);

  final File outputFile;
}

ShippingIconReviewResult buildShippingIconReview({
  required String appRootPath,
  required String outputDirectoryPath,
}) {
  review.validateOutputDirectory(outputDirectoryPath);
  final root = Directory(appRootPath).absolute;
  if (!root.existsSync() || !File(_path(root, 'pubspec.yaml')).existsSync()) {
    throw ArgumentError.value(appRootPath, 'appRootPath', 'Not a Flutter app.');
  }

  final ios = _loadPng(
    root,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
    'Icon-App-60x60@3x.png',
  );
  final androidLegacy = _loadPng(
    root,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
  );
  final androidForeground = _loadPng(
    root,
    'android/app/src/main/res/drawable-xxxhdpi/'
    'ic_launcher_foreground.png',
  );
  final androidMonochrome = _loadPng(
    root,
    'android/app/src/main/res/drawable-xxxhdpi/'
    'ic_launcher_monochrome.png',
  );
  final webMaskable = _loadPng(root, 'web/icons/Icon-maskable-512.png');
  final windows = _loadLargestIco(
    File(_path(root, 'windows/runner/resources/app_icon.ico')),
  );

  final tiles = <img.Image>[
    _masked(_resize(ios, 300), _Mask.squircle),
    _masked(_resize(androidLegacy, 300), _Mask.circle),
    _masked(
      composeAdaptiveIcon(
        androidForeground,
        background: img.ColorRgb8(23, 13, 10),
        size: 300,
      ),
      _Mask.circle,
    ),
    _masked(
      composeThemedIcon(
        androidMonochrome,
        background: img.ColorRgb8(53, 43, 38),
        foreground: img.ColorRgb8(226, 192, 117),
        size: 300,
      ),
      _Mask.circle,
    ),
    _masked(_resize(webMaskable, 300), _Mask.circle),
    _resize(windows, 300),
  ];
  const labels = <String>[
    'iOS 180 px',
    'Android legacy 192 px',
    'Android adaptive circle',
    'Android themed preview',
    'Web maskable circle',
    'Windows ICO',
  ];
  final sheet = img.Image(
    width: shippingReviewWidth,
    height: shippingReviewHeight,
    numChannels: 3,
  )..clear(img.ColorRgb8(29, 23, 20));
  _text(
    sheet,
    'Room of Days - approved Day Ledger shipping outputs',
    32,
    28,
    img.arial24,
  );
  const gap = 32;
  const tileSize = 300;
  for (var index = 0; index < tiles.length; index++) {
    final x = 32 + index * (tileSize + gap);
    _text(sheet, labels[index], x, 76, img.arial14);
    img.compositeImage(sheet, tiles[index], dstX: x, dstY: 108);
    var smallX = x;
    for (final size in <int>[96, 60, 32]) {
      img.compositeImage(
        sheet,
        _resize(tiles[index], size),
        dstX: smallX,
        dstY: 448,
      );
      _text(sheet, '$size', smallX, 552, img.arial14);
      smallX += size + 18;
    }
  }

  final outputDirectory = Directory(outputDirectoryPath)
    ..createSync(recursive: true);
  final output = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'shipping-platform-review.png',
  );
  output.writeAsBytesSync(
    img.encodePng(
      sheet.convert(format: img.Format.uint8, numChannels: 3),
      level: 6,
    ),
    flush: true,
  );
  return ShippingIconReviewResult(output);
}

img.Image composeAdaptiveIcon(
  img.Image foreground, {
  required img.Color background,
  required int size,
}) {
  final result = img.Image(width: size, height: size, numChannels: 3)
    ..clear(background);
  final innerSize = (size * 0.84).round();
  final inset = (size - innerSize) ~/ 2;
  img.compositeImage(
    result,
    _resize(foreground, innerSize),
    dstX: inset,
    dstY: inset,
  );
  return result;
}

img.Image composeThemedIcon(
  img.Image monochrome, {
  required img.Color background,
  required img.Color foreground,
  required int size,
}) {
  final tinted = img.Image(
    width: monochrome.width,
    height: monochrome.height,
    numChannels: 4,
  );
  for (final pixel in monochrome) {
    tinted.setPixelRgba(
      pixel.x,
      pixel.y,
      foreground.r,
      foreground.g,
      foreground.b,
      pixel.a,
    );
  }
  return composeAdaptiveIcon(tinted, background: background, size: size);
}

img.Image _loadPng(Directory root, String relative) {
  final file = File(_path(root, relative));
  if (!file.existsSync()) throw StateError('Missing icon output: $relative');
  final decoded = img.decodePng(file.readAsBytesSync());
  if (decoded == null) throw StateError('Invalid PNG icon output: $relative');
  return decoded;
}

img.Image _loadLargestIco(File file) {
  if (!file.existsSync()) {
    throw StateError('Missing icon output: ${file.path}');
  }
  final decoded = img.decodeIco(file.readAsBytesSync());
  if (decoded == null) {
    throw StateError('Invalid ICO icon output: ${file.path}');
  }
  return decoded.frames.reduce(
    (largest, frame) => frame.width > largest.width ? frame : largest,
  );
}

img.Image _resize(img.Image source, int size) => img.copyResize(
  source,
  width: size,
  height: size,
  interpolation: img.Interpolation.cubic,
);

img.Image _masked(img.Image source, _Mask mask) {
  final result = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  )..clear(img.ColorRgb8(70, 61, 54));
  final center = (source.width - 1) / 2;
  final radius = source.width / 2;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final dx = (x - center) / radius;
      final dy = (y - center) / radius;
      final inside = switch (mask) {
        _Mask.circle => dx * dx + dy * dy <= 1,
        _Mask.squircle => math.pow(dx.abs(), 4) + math.pow(dy.abs(), 4) <= 1,
      };
      if (inside) result.setPixel(x, y, source.getPixel(x, y));
    }
  }
  return result;
}

void _text(img.Image image, String value, int x, int y, img.BitmapFont font) {
  img.drawString(
    image,
    value,
    font: font,
    x: x,
    y: y,
    color: img.ColorRgb8(236, 219, 186),
  );
}

String _path(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';

enum _Mask { circle, squircle }

void main(List<String> arguments) {
  try {
    final parsed = _parseArguments(arguments);
    final result = buildShippingIconReview(
      appRootPath: parsed.appRoot,
      outputDirectoryPath: parsed.outputDirectory,
    );
    stdout.writeln('Wrote ${result.outputFile.path}');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

_Arguments _parseArguments(List<String> arguments) {
  String? appRoot;
  String? outputDirectory;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw ArgumentError('Missing value for ${arguments[index]}.');
    }
    switch (arguments[index]) {
      case '--app-root':
        appRoot = arguments[index + 1];
      case '--output-dir':
        outputDirectory = arguments[index + 1];
      default:
        throw ArgumentError('Unknown argument: ${arguments[index]}.');
    }
  }
  if (appRoot == null || outputDirectory == null) {
    throw ArgumentError(
      'Usage: dart run tool/build_shipping_icon_review.dart '
      '--app-root <directory> --output-dir <directory>',
    );
  }
  return _Arguments(appRoot, outputDirectory);
}

final class _Arguments {
  const _Arguments(this.appRoot, this.outputDirectory);

  final String appRoot;
  final String outputDirectory;
}
