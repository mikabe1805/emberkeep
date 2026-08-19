import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../tool/build_icon_review.dart' as review;

void main() {
  test('builds opaque RGB sheets with the four fixed review rows', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'icon-review-tool-',
    );
    addTearDown(() => temporary.delete(recursive: true));

    final inputPaths = <String>[];
    for (final color in <int>[0xff5b3524, 0xffa16c2e, 0xff33546b, 0xff8c7a54]) {
      final path =
          '${temporary.path}${Platform.pathSeparator}${inputPaths.length}.png';
      File(path).writeAsBytesSync(
        img.encodePng(
          img.Image(
            width: 1024,
            height: 1024,
            numChannels: 4,
            backgroundColor: img.ColorRgba8(
              (color >> 16) & 0xff,
              (color >> 8) & 0xff,
              color & 0xff,
              255,
            ),
          ),
        ),
      );
      inputPaths.add(path);
    }
    final outputDirectory = Directory(
      '${temporary.path}${Platform.pathSeparator}review',
    );

    final result = review.buildIconReview(
      currentPath: inputPaths.first,
      candidatePaths: inputPaths.skip(1).toList(),
      outputDirectoryPath: outputDirectory.path,
    );

    expect(result.rowLabels, <String>[
      'Current',
      'Option 1 - Inhabited Room retry',
      'Option 2 - Completion Latch / Orbit',
      'Option 3 - Daybook / Light',
    ]);
    for (final output in result.outputFiles) {
      final decoded = img.decodePng(File(output).readAsBytesSync());
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(0));
      expect(decoded.height, greaterThan(0));
      expect(decoded.numChannels, 3);
    }
  });

  test('refuses a review directory inside a shipping asset path', () {
    expect(
      () => review.validateOutputDirectory('web/icons/review'),
      throwsArgumentError,
    );
    expect(
      () => review.validateOutputDirectory('web/temporary/../icons/review'),
      throwsArgumentError,
    );
    expect(
      () => review.validateOutputDirectory('design/icon-exploration/review'),
      returnsNormally,
    );
  });
}
