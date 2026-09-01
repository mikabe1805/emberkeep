import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

const _maskableScale = 0.92;
const _greenOpaqueDominance = 36;
const _greenTransparentDominance = 150;

final class AppIconExportResult {
  const AppIconExportResult(this.outputFiles, this.manifestFile);

  final List<File> outputFiles;
  final File manifestFile;
}

AppIconExportResult exportAppIcons({
  required String appRootPath,
  required String selectedMasterPath,
  required String adaptiveChromaPath,
}) {
  final requestedRoot = Directory(appRootPath).absolute;
  _validateAppRoot(requestedRoot);
  final appRoot = Directory(requestedRoot.resolveSymbolicLinksSync());
  final masterFile = File(selectedMasterPath).absolute;
  final chromaFile = File(adaptiveChromaPath).absolute;
  final master = _loadSquare(masterFile, requireOpaque: true);
  final chroma = _loadSquare(chromaFile, requireOpaque: true);
  final canonicalMaster = _resizeRgb(master, 1024);
  final adaptiveForeground = _resizeRgba(_removeGreenScreen(chroma), 1024);
  _validateForeground(adaptiveForeground);
  final monochrome = createMonochromeForeground(adaptiveForeground);

  final generated = <String, List<int>>{
    'web/icons/Icon-1024.png': _encodeRgbPng(canonicalMaster),
    'web/icons/Icon-512.png': _encodeRgbPng(_resizeRgb(canonicalMaster, 512)),
    'web/icons/Icon-192.png': _encodeRgbPng(_resizeRgb(canonicalMaster, 192)),
    'web/icons/Icon-maskable-512.png': _encodeRgbPng(
      createMaskableIcon(canonicalMaster, 512),
    ),
    'web/icons/Icon-maskable-192.png': _encodeRgbPng(
      createMaskableIcon(canonicalMaster, 192),
    ),
    'web/icons/apple-touch-icon.png': _encodeRgbPng(
      _resizeRgb(canonicalMaster, 180),
    ),
    'web/favicon.png': _encodeRgbPng(_resizeRgb(canonicalMaster, 48)),
    'assets/brand/room-of-days-adaptive-foreground-v1.png': _encodeRgbaPng(
      adaptiveForeground,
    ),
    'assets/brand/room-of-days-monochrome-v2.png': _encodeRgbaPng(monochrome),
    'windows/runner/resources/app_icon.ico': _encodeWindowsIco(canonicalMaster),
  };

  final outputFiles = <File>[];
  for (final entry in generated.entries) {
    final file = File(_underRoot(appRoot, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value, flush: true);
    outputFiles.add(file);
  }

  final manifestFile = File(
    _underRoot(appRoot, 'assets/brand/room-of-days-icon-manifest-v1.json'),
  );
  final manifest = _buildManifest(
    appRoot: appRoot,
    selectedMaster: masterFile,
    adaptiveChroma: chromaFile,
    generatedFiles: outputFiles,
  );
  manifestFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    flush: true,
  );
  return AppIconExportResult(
    List<File>.unmodifiable(outputFiles),
    manifestFile,
  );
}

img.Image removeGreenScreenForTest(img.Image source) =>
    _removeGreenScreen(source);

img.Image createMaskableIcon(img.Image source, int size) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  final rgb = source.convert(format: img.Format.uint8, numChannels: 3);
  final background = _averageBorderColor(rgb);
  final result = img.Image(
    width: size,
    height: size,
    numChannels: 3,
    backgroundColor: background,
  )..clear(background);
  final innerSize = (size * _maskableScale).round();
  final inset = (size - innerSize) ~/ 2;
  img.compositeImage(
    result,
    _resizeRgb(rgb, innerSize),
    dstX: inset,
    dstY: inset,
  );
  return result;
}

img.Image createMonochromeForeground(img.Image foreground) {
  final source = foreground.convert(format: img.Format.uint8, numChannels: 4);
  final output = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (final pixel in source) {
    final sourceAlpha = pixel.a.toInt();
    if (sourceAlpha == 0) continue;
    final luminance =
        0.2126 * pixel.r.toInt() +
        0.7152 * pixel.g.toInt() +
        0.0722 * pixel.b.toInt();
    final detailWeight = 0.18 + 0.82 * math.pow(luminance / 255, 0.8);
    final alpha = (sourceAlpha * detailWeight).round().clamp(0, 255);
    output.setPixelRgba(pixel.x, pixel.y, 255, 255, 255, alpha);
  }
  return output;
}

void _validateAppRoot(Directory appRoot) {
  if (!appRoot.existsSync() ||
      !File(_underRoot(appRoot, 'pubspec.yaml')).existsSync()) {
    throw ArgumentError.value(
      appRoot.path,
      'appRootPath',
      'Expected a Flutter app root containing pubspec.yaml.',
    );
  }
  for (final relative in <String>[
    'web/icons',
    'assets/brand',
    'windows/runner/resources',
  ]) {
    if (!Directory(_underRoot(appRoot, relative)).existsSync()) {
      throw StateError('Missing required icon output directory: $relative');
    }
  }
}

img.Image _loadSquare(File file, {required bool requireOpaque}) {
  if (!file.existsSync()) throw StateError('Missing icon source: ${file.path}');
  final decoded = img.decodePng(file.readAsBytesSync());
  if (decoded == null ||
      decoded.width != decoded.height ||
      decoded.width < 1024) {
    throw ArgumentError.value(
      file.path,
      'source',
      'Icon sources must be square PNGs at least 1024 pixels wide.',
    );
  }
  if (requireOpaque && decoded.hasAlpha) {
    for (final pixel in decoded) {
      if (pixel.a.toInt() != 255) {
        throw ArgumentError.value(
          file.path,
          'source',
          'This export source must be fully opaque.',
        );
      }
    }
  }
  return decoded;
}

img.Image _removeGreenScreen(img.Image source) {
  final rgba = source.convert(format: img.Format.uint8, numChannels: 4);
  final output = img.Image(
    width: rgba.width,
    height: rgba.height,
    numChannels: 4,
  );
  for (final pixel in rgba) {
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    final other = math.max(red, blue);
    final dominance = green - other;
    final alpha = switch (dominance) {
      <= _greenOpaqueDominance => 255,
      >= _greenTransparentDominance => 0,
      _ =>
        (255 *
                (_greenTransparentDominance - dominance) /
                (_greenTransparentDominance - _greenOpaqueDominance))
            .round(),
    };
    if (alpha <= 2) continue;
    final despilledGreen = math.min(green, other);
    output.setPixelRgba(pixel.x, pixel.y, red, despilledGreen, blue, alpha);
  }
  return output;
}

void _validateForeground(img.Image foreground) {
  var transparent = 0;
  var opaque = 0;
  var greenLeak = 0;
  for (final pixel in foreground) {
    final alpha = pixel.a.toInt();
    if (alpha == 0) transparent++;
    if (alpha == 255) opaque++;
    if (alpha > 20 &&
        pixel.g.toInt() - math.max(pixel.r.toInt(), pixel.b.toInt()) > 48) {
      greenLeak++;
    }
  }
  final area = foreground.width * foreground.height;
  if (transparent < area * 0.18 || opaque < area * 0.25) {
    throw StateError(
      'Adaptive extraction lacks a credible transparent background or subject '
      '(transparent=$transparent opaque=$opaque area=$area).',
    );
  }
  if (greenLeak > area * 0.001) {
    throw StateError('Adaptive extraction retained too much chroma green.');
  }
}

img.Image _resizeRgb(img.Image source, int size) => img.copyResize(
  source.convert(format: img.Format.uint8, numChannels: 3),
  width: size,
  height: size,
  interpolation: img.Interpolation.cubic,
);

img.Image _resizeRgba(img.Image source, int size) => img.copyResize(
  source.convert(format: img.Format.uint8, numChannels: 4),
  width: size,
  height: size,
  interpolation: img.Interpolation.cubic,
);

img.ColorRgb8 _averageBorderColor(img.Image source) {
  var red = 0;
  var green = 0;
  var blue = 0;
  var count = 0;
  final border = math.max(1, (source.width * 0.012).round());
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (x >= border &&
          x < source.width - border &&
          y >= border &&
          y < source.height - border) {
        continue;
      }
      final pixel = source.getPixel(x, y);
      red += pixel.r.toInt();
      green += pixel.g.toInt();
      blue += pixel.b.toInt();
      count++;
    }
  }
  return img.ColorRgb8(red ~/ count, green ~/ count, blue ~/ count);
}

List<int> _encodeRgbPng(img.Image image) => img.encodePng(
  image.convert(format: img.Format.uint8, numChannels: 3),
  level: 9,
);

List<int> _encodeRgbaPng(img.Image image) => img.encodePng(
  image.convert(format: img.Format.uint8, numChannels: 4),
  level: 9,
);

List<int> _encodeWindowsIco(img.Image source) {
  const sizes = <int>[16, 24, 32, 48, 64, 128, 256];
  final icon = _resizeRgba(source, sizes.first);
  for (final size in sizes.skip(1)) {
    icon.addFrame(_resizeRgba(source, size));
  }
  return img.encodeIco(icon);
}

Map<String, Object> _buildManifest({
  required Directory appRoot,
  required File selectedMaster,
  required File adaptiveChroma,
  required List<File> generatedFiles,
}) {
  final nativeFiles = <File>[
    ..._pngFilesUnder(
      Directory(
        _underRoot(appRoot, 'ios/Runner/Assets.xcassets/AppIcon.appiconset'),
      ),
    ),
    ..._pngFilesUnder(
      Directory(_underRoot(appRoot, 'android/app/src/main/res')),
      name: 'ic_launcher.png',
    ),
    ..._pngFilesUnder(
      Directory(_underRoot(appRoot, 'android/app/src/main/res')),
      name: 'ic_launcher_foreground.png',
    ),
    ..._pngFilesUnder(
      Directory(_underRoot(appRoot, 'android/app/src/main/res')),
      name: 'ic_launcher_monochrome.png',
    ),
  ];
  final outputs = <File>{...generatedFiles, ...nativeFiles}.toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return <String, Object>{
    'schemaVersion': 1,
    'selectionDate': '2026-09-01',
    'identity': 'Room of Days - Open Door of Light',
    'sources': <Map<String, Object>>[
      _sourceRecord(appRoot, selectedMaster, 'selected opaque icon artwork'),
      _sourceRecord(
        appRoot,
        adaptiveChroma,
        'ImageGen chroma-key derivative for adaptive foreground extraction',
      ),
    ],
    'postprocessing': <String, Object>{
      'tool': 'tool/export_app_icons.dart',
      'masterResize': 'cubic interpolation to opaque RGB platform sizes',
      'adaptiveForeground':
          'green-dominance alpha extraction, despill, then cubic resize',
      'androidAdaptiveInset':
          '8 percent XML inset applied by flutter_launcher_icons',
      'maskableWeb': '92 percent master over the average source border color',
      'monochrome': 'white foreground with luminance-weighted alpha detail',
    },
    'outputs': outputs.map((file) => _outputRecord(appRoot, file)).toList(),
  };
}

Map<String, Object> _sourceRecord(Directory appRoot, File file, String role) {
  final decoded = img.decodePng(file.readAsBytesSync())!;
  return <String, Object>{
    'path': _relativeToRoot(appRoot, file),
    'sha256': sha256.convert(file.readAsBytesSync()).toString().toUpperCase(),
    'width': decoded.width,
    'height': decoded.height,
    'channels': decoded.numChannels,
    'role': role,
  };
}

Map<String, Object> _outputRecord(Directory appRoot, File file) {
  final bytes = file.readAsBytesSync();
  final record = <String, Object>{
    'path': _relativeToRoot(appRoot, file),
    'sha256': sha256.convert(bytes).toString().toUpperCase(),
  };
  if (file.path.toLowerCase().endsWith('.png')) {
    final decoded = img.decodePng(bytes)!;
    record
      ..['width'] = decoded.width
      ..['height'] = decoded.height
      ..['channels'] = decoded.numChannels;
  } else {
    final decoded = img.decodeIco(bytes);
    record
      ..['format'] = 'ico'
      ..['frames'] = decoded == null ? 0 : _icoFrameCount(bytes);
  }
  return record;
}

int _icoFrameCount(List<int> bytes) {
  if (bytes.length < 6) return 0;
  return bytes[4] | (bytes[5] << 8);
}

List<File> _pngFilesUnder(Directory directory, {String? name}) {
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where(
        (file) =>
            file.path.toLowerCase().endsWith('.png') &&
            (name == null ||
                _fileName(file.path).toLowerCase() == name.toLowerCase()),
      )
      .toList();
}

String _underRoot(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';

String _relativeToRoot(Directory root, File file) {
  final rootPrefix = '${root.path}${Platform.pathSeparator}'.toLowerCase();
  final absolute = file.absolute.path;
  if (!absolute.toLowerCase().startsWith(rootPrefix)) {
    return absolute.replaceAll('\\', '/');
  }
  return absolute
      .substring(rootPrefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}

String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

void main(List<String> arguments) {
  try {
    final parsed = _parseArguments(arguments);
    final result = exportAppIcons(
      appRootPath: parsed.appRoot,
      selectedMasterPath: parsed.master,
      adaptiveChromaPath: parsed.adaptiveChroma,
    );
    for (final file in result.outputFiles) {
      stdout.writeln('Wrote ${file.path}');
    }
    stdout.writeln('Wrote ${result.manifestFile.path}');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

_Arguments _parseArguments(List<String> arguments) {
  String? appRoot;
  String? master;
  String? adaptiveChroma;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw ArgumentError('Missing value for ${arguments[index]}.');
    }
    final value = arguments[index + 1];
    switch (arguments[index]) {
      case '--app-root':
        appRoot = value;
      case '--master':
        master = value;
      case '--adaptive-chroma':
        adaptiveChroma = value;
      default:
        throw ArgumentError('Unknown argument: ${arguments[index]}.');
    }
  }
  if (appRoot == null || master == null || adaptiveChroma == null) {
    throw ArgumentError(
      'Usage: dart run tool/export_app_icons.dart --app-root <directory> '
      '--master <png> --adaptive-chroma <png>',
    );
  }
  return _Arguments(appRoot, master, adaptiveChroma);
}

final class _Arguments {
  const _Arguments(this.appRoot, this.master, this.adaptiveChroma);

  final String appRoot;
  final String master;
  final String adaptiveChroma;
}
