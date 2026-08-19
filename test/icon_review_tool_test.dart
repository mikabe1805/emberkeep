import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../tool/build_icon_review.dart' as review;

void main() {
  test(
    'renders fixed-order rows and every requested review size as RGB',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'icon-review-tool-',
      );
      addTearDown(() => temporary.delete(recursive: true));

      final inputPaths = <String>[];
      for (final color in <int>[
        0xff5b3524,
        0xffa16c2e,
        0xff33546b,
        0xff8c7a54,
      ]) {
        final path =
            '${temporary.path}${Platform.pathSeparator}${inputPaths.length}.png';
        File(path).writeAsBytesSync(
          img.encodePng(
            (img.Image(width: 1024, height: 1024, numChannels: 4)..clear(
              img.ColorRgba8(
                (color >> 16) & 0xff,
                (color >> 8) & 0xff,
                color & 0xff,
                255,
              ),
            )),
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
      expect(review.smallSizeSheetDimensions.width, 1756);
      expect(review.smallSizeSheetDimensions.height, 4502);
      expect(review.platformMaskSheetDimensions.width, 2292);
      expect(review.platformMaskSheetDimensions.height, 1782);
      for (final output in result.outputFiles) {
        final decoded = img.decodePng(File(output).readAsBytesSync());
        expect(decoded, isNotNull);
        expect(decoded!.width, output.endsWith('1024.png') ? 1756 : 2292);
        expect(decoded.height, output.endsWith('1024.png') ? 4502 : 1782);
        expect(decoded.numChannels, 3);
      }
      final small = img.decodePng(
        File(result.outputFiles.first).readAsBytesSync(),
      )!;
      for (final x in <int>[332, 1388, 1600, 1692]) {
        expect(small.getPixel(x, 166).r, 91);
      }
    },
  );

  test('accepts masters larger than 1024 pixels', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'icon-review-large-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final paths = List<String>.generate(4, (index) {
      final path = '${temporary.path}${Platform.pathSeparator}$index.png';
      File(
        path,
      ).writeAsBytesSync(img.encodePng(img.Image(width: 1254, height: 1254)));
      return path;
    });
    expect(
      () => review.buildIconReview(
        currentPath: paths.first,
        candidatePaths: paths.skip(1).toList(),
        outputDirectoryPath: '${temporary.path}${Platform.pathSeparator}review',
      ),
      returnsNormally,
    );
  });

  test('renders a selected-candidate review with a custom label', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'icon-review-selected-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final paths = List<String>.generate(2, (index) {
      final path = '${temporary.path}${Platform.pathSeparator}$index.png';
      File(
        path,
      ).writeAsBytesSync(img.encodePng(img.Image(width: 1024, height: 1024)));
      return path;
    });

    final result = review.buildIconReview(
      currentPath: paths.first,
      candidatePaths: <String>[paths.last],
      candidateLabels: const <String>['Approved - Day Ledger'],
      outputDirectoryPath: '${temporary.path}${Platform.pathSeparator}review',
    );

    expect(result.rowLabels, <String>['Current', 'Approved - Day Ledger']);
    final small = img.decodePng(
      File(result.outputFiles.first).readAsBytesSync(),
    );
    final masks = img.decodePng(
      File(result.outputFiles.last).readAsBytesSync(),
    );
    expect(small, isNotNull);
    expect(small!.width, 1756);
    expect(small.height, 2310);
    expect(masks, isNotNull);
    expect(masks!.width, 2292);
    expect(masks.height, 950);
  });

  test(
    'rejects wrong input count, undersized, and non-square masters',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'icon-review-invalid-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final valid = File('${temporary.path}${Platform.pathSeparator}valid.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 1024, height: 1024)));
      final small = File('${temporary.path}${Platform.pathSeparator}small.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 1023, height: 1023)));
      final rectangle = File(
        '${temporary.path}${Platform.pathSeparator}rectangle.png',
      )..writeAsBytesSync(img.encodePng(img.Image(width: 1024, height: 1025)));
      expect(
        () => review.buildIconReview(
          currentPath: valid.path,
          candidatePaths: const [],
          outputDirectoryPath: temporary.path,
        ),
        throwsArgumentError,
      );
      expect(
        () => review.buildIconReview(
          currentPath: valid.path,
          candidatePaths: <String>[valid.path],
          candidateLabels: const <String>[],
          outputDirectoryPath: temporary.path,
        ),
        throwsArgumentError,
      );
      expect(
        () => review.buildIconReview(
          currentPath: small.path,
          candidatePaths: List.filled(3, valid.path),
          outputDirectoryPath: temporary.path,
        ),
        throwsArgumentError,
      );
      expect(
        () => review.buildIconReview(
          currentPath: rectangle.path,
          candidatePaths: List.filled(3, valid.path),
          outputDirectoryPath: temporary.path,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'platform previews preserve the square source and overlay the safe guide',
    () {
      final source = img.Image(width: 360, height: 360, numChannels: 3)
        ..setPixelRgba(0, 0, 12, 34, 56, 255)
        ..setPixelRgba(15, 180, 12, 34, 56, 255)
        ..setPixelRgba(180, 180, 210, 40, 20, 255);
      final previews = review.buildPlatformPreviews(source);
      expect(previews, hasLength(5));
      expect(previews[0].getPixel(0, 0).r, 12);
      expect(previews[4].getPixel(0, 0).r, previews[4].getPixel(0, 0).g);
      expect(source.getPixel(0, 0).r, 12);
      expect(previews[3].getPixel(0, 0).r, 12);
      expect(previews[3].getPixel(180, 180).r, 210);
      expect(previews[1].getPixel(0, 0).r, isNot(12));
      expect(previews[1].getPixel(15, 180).r, 12);
    },
  );

  test('refuses a review directory inside a shipping asset path', () {
    for (final protected in <String>[
      'ios/review',
      'android/review',
      'windows/review',
      'store-assets/review',
      'web/icons/review',
      'assets/brand/review',
    ]) {
      expect(
        () => review.validateOutputDirectory(protected),
        throwsArgumentError,
      );
    }
    expect(
      () => review.validateOutputDirectory('web/temporary/../icons/review'),
      throwsArgumentError,
    );
    expect(
      () => review.validateOutputDirectory('design/icon-exploration/review'),
      returnsNormally,
    );
  });

  test(
    'rejects a path whose nearest existing ancestor resolves into shipping',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'icon-review-link-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final protected = Directory(
        '${temporary.path}${Platform.pathSeparator}ios',
      )..createSync();
      final link = Link(
        '${temporary.path}${Platform.pathSeparator}review-link',
      );
      try {
        await link.create(protected.path);
        expect(
          () => review.validateOutputDirectory(
            '${link.path}${Platform.pathSeparator}nested',
          ),
          throwsArgumentError,
        );
      } on FileSystemException {
        expect(
          review.canonicalOutputDirectoryPath(
            '${protected.path}${Platform.pathSeparator}nested',
          ),
          contains('${Platform.pathSeparator}ios${Platform.pathSeparator}'),
        );
      }
    },
  );
}
