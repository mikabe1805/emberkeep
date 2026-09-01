import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../tool/export_app_icons.dart' as icons;

void main() {
  test('exports every deterministic platform source and a hash manifest', () {
    final temporary = Directory.systemTemp.createTempSync('app-icon-export-');
    addTearDown(() => temporary.deleteSync(recursive: true));
    _createAppRoot(temporary);
    final master = _writeMaster(temporary);
    final chroma = _writeChroma(temporary);

    final result = icons.exportAppIcons(
      appRootPath: temporary.path,
      selectedMasterPath: master.path,
      adaptiveChromaPath: chroma.path,
    );

    expect(result.outputFiles, hasLength(10));
    final masterOutput = _decodePng(temporary, 'web/icons/Icon-1024.png');
    expect(masterOutput.width, 1024);
    expect(masterOutput.height, 1024);
    expect(masterOutput.numChannels, 3);
    final adaptive = _decodePng(
      temporary,
      'assets/brand/room-of-days-adaptive-foreground-v1.png',
    );
    expect(adaptive.numChannels, 4);
    expect(adaptive.getPixel(0, 0).a, 0);
    expect(adaptive.getPixel(512, 512).a, 255);
    expect(adaptive.getPixel(512, 512).g, lessThanOrEqualTo(90));
    final monochrome = _decodePng(
      temporary,
      'assets/brand/room-of-days-monochrome-v2.png',
    );
    expect(monochrome.getPixel(0, 0).a, 0);
    expect(monochrome.getPixel(512, 512).a, greaterThan(0));
    expect(monochrome.getPixel(512, 512).r, 255);

    final maskable = _decodePng(temporary, 'web/icons/Icon-maskable-512.png');
    expect(maskable.numChannels, 3);
    expect(maskable.getPixel(0, 0).r, 20);
    expect(maskable.getPixel(256, 256).r, greaterThan(20));
    final icoBytes = File(
      _path(temporary, 'windows/runner/resources/app_icon.ico'),
    ).readAsBytesSync();
    final ico = img.decodeIco(icoBytes);
    expect(ico, isNotNull);
    expect(icoBytes[4] | (icoBytes[5] << 8), 7);

    final manifest = jsonDecode(result.manifestFile.readAsStringSync());
    expect(manifest['identity'], 'Room of Days - Open Door of Light');
    expect(manifest['sources'], hasLength(2));
    final sources = (manifest['sources'] as List).cast<Map>();
    expect(sources.map((source) => source['path']), <String>[
      'master.png',
      'chroma.png',
    ]);
    for (final source in sources) {
      expect(source['path'], isNot(startsWith(temporary.path)));
      expect(source['path'], isNot(matches(RegExp(r'^[A-Za-z]:[/\\]'))));
    }
    expect(manifest['outputs'], hasLength(10));
    expect(
      manifest['outputs'][0]['sha256'],
      matches(RegExp(r'^[0-9A-F]{64}$')),
    );
  });

  test('green extraction keeps the brown subject and removes the field', () {
    final source = img.Image(width: 32, height: 32, numChannels: 3)
      ..clear(img.ColorRgb8(4, 248, 18));
    img.fillRect(
      source,
      x1: 8,
      y1: 8,
      x2: 23,
      y2: 23,
      color: img.ColorRgb8(120, 70, 35),
    );

    final cutout = icons.removeGreenScreenForTest(source);

    expect(cutout.getPixel(0, 0).a, 0);
    expect(cutout.getPixel(16, 16).a, 255);
    expect(cutout.getPixel(16, 16).r, 120);
    expect(cutout.getPixel(16, 16).g, 70);
  });

  test('rejects a non-app root before writing', () {
    final temporary = Directory.systemTemp.createTempSync('app-icon-invalid-');
    addTearDown(() => temporary.deleteSync(recursive: true));
    final master = _writeMaster(temporary);
    final chroma = _writeChroma(temporary);
    expect(
      () => icons.exportAppIcons(
        appRootPath: temporary.path,
        selectedMasterPath: master.path,
        adaptiveChromaPath: chroma.path,
      ),
      throwsArgumentError,
    );
  });
}

void _createAppRoot(Directory root) {
  File(_path(root, 'pubspec.yaml')).writeAsStringSync('name: icon_test\n');
  for (final relative in <String>[
    'web/icons',
    'assets/brand',
    'windows/runner/resources',
  ]) {
    Directory(_path(root, relative)).createSync(recursive: true);
  }
}

File _writeMaster(Directory root) {
  final image = img.Image(
    width: 1024,
    height: 1024,
    numChannels: 3,
    backgroundColor: img.ColorRgb8(20, 12, 10),
  )..clear(img.ColorRgb8(20, 12, 10));
  img.fillRect(
    image,
    x1: 220,
    y1: 220,
    x2: 803,
    y2: 803,
    color: img.ColorRgb8(180, 120, 60),
  );
  return File(_path(root, 'master.png'))
    ..writeAsBytesSync(img.encodePng(image));
}

File _writeChroma(Directory root) {
  final image = img.Image(
    width: 1024,
    height: 1024,
    numChannels: 3,
    backgroundColor: img.ColorRgb8(4, 248, 18),
  )..clear(img.ColorRgb8(4, 248, 18));
  img.fillRect(
    image,
    x1: 220,
    y1: 220,
    x2: 803,
    y2: 803,
    color: img.ColorRgb8(120, 70, 35),
  );
  return File(_path(root, 'chroma.png'))
    ..writeAsBytesSync(img.encodePng(image));
}

img.Image _decodePng(Directory root, String relative) =>
    img.decodePng(File(_path(root, relative)).readAsBytesSync())!;

String _path(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}'
    '${relative.replaceAll('/', Platform.pathSeparator)}';
