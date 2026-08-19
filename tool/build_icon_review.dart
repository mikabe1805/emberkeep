import 'dart:io';

import 'package:image/image.dart' as img;

const _rowLabels = <String>[
  'Current',
  'Option 1 - Inhabited Room retry',
  'Option 2 - Completion Latch / Orbit',
  'Option 3 - Daybook / Light',
];

final class IconReviewResult {
  const IconReviewResult(this.outputFiles);

  final List<String> outputFiles;

  List<String> get rowLabels => _rowLabels;
}

IconReviewResult buildIconReview({
  required String currentPath,
  required List<String> candidatePaths,
  required String outputDirectoryPath,
}) {
  if (candidatePaths.length != 3) {
    throw ArgumentError.value(
      candidatePaths,
      'candidatePaths',
      'Exactly three candidate masters are required.',
    );
  }
  validateOutputDirectory(outputDirectoryPath);

  final masters = <img.Image>[
    _loadMaster(currentPath),
    ...candidatePaths.map(_loadMaster),
  ];
  final outputDirectory = Directory(outputDirectoryPath)
    ..createSync(recursive: true);
  final smallSizes = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'contact-sheet-32-60-180-1024.png',
  );
  final platformMasks = File(
    '${outputDirectory.path}${Platform.pathSeparator}'
    'contact-sheet-platform-masks.png',
  );

  _writeRgbPng(smallSizes, _buildSmallSizeSheet(masters));
  _writeRgbPng(platformMasks, _buildPlatformMaskSheet(masters));
  return IconReviewResult(<String>[smallSizes.path, platformMasks.path]);
}

void validateOutputDirectory(String path) {
  final segments = _normalisedPathSegments(path);
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (segment == 'ios' ||
        segment == 'android' ||
        segment == 'windows' ||
        segment == 'store-assets' ||
        (segment == 'web' && _nextIs(segments, index, 'icons')) ||
        (segment == 'assets' && _nextIs(segments, index, 'brand'))) {
      throw ArgumentError.value(
        path,
        'path',
        'Review output cannot be written inside a shipping asset path.',
      );
    }
  }
}

List<String> _normalisedPathSegments(String path) {
  final result = <String>[];
  for (final rawSegment in path.replaceAll('\\', '/').split('/')) {
    final segment = rawSegment.toLowerCase();
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (result.isNotEmpty && result.last != '..') result.removeLast();
      continue;
    }
    result.add(segment);
  }
  return result;
}

bool _nextIs(List<String> values, int index, String expected) =>
    index + 1 < values.length && values[index + 1] == expected;

img.Image _loadMaster(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Missing icon master: $path');
  final decoded = img.decodePng(file.readAsBytesSync());
  if (decoded == null ||
      decoded.width != decoded.height ||
      decoded.width < 1024) {
    throw ArgumentError.value(
      path,
      'path',
      'Each icon master must be a square PNG at least 1024 pixels wide.',
    );
  }
  return decoded;
}

img.Image _buildSmallSizeSheet(List<img.Image> masters) {
  const labelWidth = 300;
  const gap = 32;
  const titleHeight = 118;
  const rowHeight = 1096;
  const widths = <int>[1024, 180, 60, 32];
  const headings = <String>['1024 px', '180 px', '60 px', '32 px'];
  final columnXs = <int>[];
  var x = labelWidth + gap;
  for (final width in widths) {
    columnXs.add(x);
    x += width + gap;
  }
  final sheet = _canvas(x, titleHeight + rowHeight * masters.length);
  _text(
    sheet,
    'Room of Days icon comparison - original masters and launcher sizes',
    32,
    32,
    img.arial24,
  );
  for (var index = 0; index < headings.length; index++) {
    _text(sheet, headings[index], columnXs[index], 82, img.arial14);
  }
  for (var row = 0; row < masters.length; row++) {
    final top = titleHeight + row * rowHeight;
    _text(sheet, _rowLabels[row], 32, top + 24, img.arial24);
    _text(
      sheet,
      row == 0 ? 'Baseline' : 'Review candidate',
      32,
      top + 60,
      img.arial14,
    );
    for (var column = 0; column < widths.length; column++) {
      final size = widths[column];
      final tile = _resize(masters[row], size);
      img.compositeImage(sheet, tile, dstX: columnXs[column], dstY: top + 48);
    }
  }
  return sheet;
}

img.Image _buildPlatformMaskSheet(List<img.Image> masters) {
  const labelWidth = 300;
  const tileSize = 360;
  const gap = 32;
  const titleHeight = 118;
  const rowHeight = 416;
  const headings = <String>[
    'Square',
    'iOS rounded square',
    'Android circle',
    'Android safe area',
    'Themed / grayscale',
  ];
  final sheet = _canvas(
    labelWidth + gap + (tileSize + gap) * headings.length,
    titleHeight + rowHeight * masters.length,
  );
  _text(
    sheet,
    'Room of Days icon comparison - platform masks and themed preview',
    32,
    32,
    img.arial24,
  );
  for (var index = 0; index < headings.length; index++) {
    _text(
      sheet,
      headings[index],
      labelWidth + gap + index * (tileSize + gap),
      82,
      img.arial14,
    );
  }
  for (var row = 0; row < masters.length; row++) {
    final top = titleHeight + row * rowHeight;
    _text(sheet, _rowLabels[row], 32, top + 24, img.arial24);
    final source = _resize(masters[row], tileSize);
    final tiles = <img.Image>[
      source,
      _masked(source, _Mask.roundedSquare),
      _masked(source, _Mask.circle),
      _safeArea(source),
      _grayscale(source),
    ];
    for (var column = 0; column < tiles.length; column++) {
      img.compositeImage(
        sheet,
        tiles[column],
        dstX: labelWidth + gap + column * (tileSize + gap),
        dstY: top + 48,
      );
    }
  }
  return sheet;
}

img.Image _resize(img.Image source, int size) => img.copyResize(
  source,
  width: size,
  height: size,
  interpolation: img.Interpolation.cubic,
);

img.Image _canvas(int width, int height) => img.Image(
  width: width,
  height: height,
  numChannels: 3,
  backgroundColor: img.ColorRgb8(29, 23, 20),
);

void _text(img.Image image, String text, int x, int y, img.BitmapFont font) =>
    img.drawString(
      image,
      text,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgb8(236, 219, 186),
    );

img.Image _masked(img.Image source, _Mask mask) {
  final result = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
    backgroundColor: img.ColorRgb8(70, 61, 54),
  );
  final center = (source.width - 1) / 2;
  final radius = source.width / 2;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final dx = x - center;
      final dy = y - center;
      final inside = switch (mask) {
        _Mask.circle => dx * dx + dy * dy <= radius * radius,
        _Mask.roundedSquare => _insideRoundedSquare(
          x,
          y,
          source.width,
          radius * .225,
        ),
      };
      if (inside) result.setPixel(x, y, source.getPixel(x, y));
    }
  }
  return result;
}

bool _insideRoundedSquare(int x, int y, int size, double cornerRadius) {
  final closestX = x.clamp(cornerRadius, size - 1 - cornerRadius);
  final closestY = y.clamp(cornerRadius, size - 1 - cornerRadius);
  final dx = x - closestX;
  final dy = y - closestY;
  return dx * dx + dy * dy <= cornerRadius * cornerRadius;
}

img.Image _safeArea(img.Image source) {
  final tile = _canvas(source.width, source.height);
  final inset = (source.width * .125).round();
  img.compositeImage(
    tile,
    _resize(source, source.width - inset * 2),
    dstX: inset,
    dstY: inset,
  );
  img.drawCircle(
    tile,
    x: source.width ~/ 2,
    y: source.height ~/ 2,
    radius: source.width ~/ 2 - 2,
    color: img.ColorRgb8(229, 192, 109),
  );
  img.drawCircle(
    tile,
    x: source.width ~/ 2,
    y: source.height ~/ 2,
    radius: source.width ~/ 2 - 3,
    color: img.ColorRgb8(229, 192, 109),
  );
  img.drawRect(
    tile,
    x1: inset,
    y1: inset,
    x2: source.width - inset - 1,
    y2: source.height - inset - 1,
    color: img.ColorRgb8(229, 192, 109),
    thickness: 2,
  );
  return tile;
}

img.Image _grayscale(img.Image source) => img.grayscale(source);

void _writeRgbPng(File file, img.Image image) {
  final rgb = image.convert(format: img.Format.uint8, numChannels: 3);
  file.writeAsBytesSync(img.encodePng(rgb, level: 6));
  final decoded = img.decodePng(file.readAsBytesSync());
  if (decoded == null || decoded.hasAlpha || decoded.numChannels != 3) {
    throw StateError('Review sheet did not encode as opaque RGB: ${file.path}');
  }
}

enum _Mask { roundedSquare, circle }

void main(List<String> arguments) {
  try {
    final argumentsByFlag = _parseArguments(arguments);
    final result = buildIconReview(
      currentPath: argumentsByFlag.currentPath,
      candidatePaths: argumentsByFlag.candidatePaths,
      outputDirectoryPath: argumentsByFlag.outputDirectoryPath,
    );
    for (final output in result.outputFiles) {
      stdout.writeln('Wrote $output');
    }
  } on ArgumentError catch (error) {
    stderr.writeln(error.message ?? error.toString());
    exitCode = 64;
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

_Arguments _parseArguments(List<String> arguments) {
  String? current;
  String? outputDirectory;
  final candidates = <String>[];
  for (var index = 0; index < arguments.length; index++) {
    if (index + 1 == arguments.length)
      throw ArgumentError('Missing value for ${arguments[index]}.');
    final value = arguments[++index];
    switch (arguments[index - 1]) {
      case '--current':
        current = value;
      case '--candidate':
        candidates.add(value);
      case '--output-dir':
        outputDirectory = value;
      default:
        throw ArgumentError('Unknown argument: ${arguments[index - 1]}.');
    }
  }
  if (current == null || outputDirectory == null || candidates.length != 3) {
    throw ArgumentError(
      'Usage: dart run tool/build_icon_review.dart --current <png> '
      '--candidate <png> --candidate <png> --candidate <png> --output-dir <directory>',
    );
  }
  return _Arguments(current, candidates, outputDirectory);
}

final class _Arguments {
  const _Arguments(
    this.currentPath,
    this.candidatePaths,
    this.outputDirectoryPath,
  );
  final String currentPath;
  final List<String> candidatePaths;
  final String outputDirectoryPath;
}
