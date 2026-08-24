import 'dart:io';

import 'package:image/image.dart' as img;

final class _Asset {
  const _Asset(this.source, this.destination, this.width, this.height);

  final String source;
  final String destination;
  final int width;
  final int height;
}

const _assets = <_Asset>[
  _Asset(
    'test/goldens/store_01_quests_1290x2796.png',
    'store-assets/screenshots/app-store/01-quests-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_02_reward_1290x2796.png',
    'store-assets/screenshots/app-store/02-reward-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_03_daybook_1290x2796.png',
    'store-assets/screenshots/app-store/03-plans-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_14_my_space_cards_1290x2796.png',
    'store-assets/screenshots/app-store/04-my-space-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_03b_conservatory_preview_1290x2796.png',
    'store-assets/screenshots/app-store/05-change-space-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_06_insights_1290x2796.png',
    'store-assets/screenshots/app-store/06-journal-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/store_07_discover_1290x2796.png',
    'store-assets/screenshots/app-store/07-discover-1290x2796.png',
    1290,
    2796,
  ),
  _Asset(
    'test/goldens/play_01_quests_1080x1920.png',
    'store-assets/screenshots/google-play/01-quests-1080x1920.png',
    1080,
    1920,
  ),
  _Asset(
    'test/goldens/play_02_reward_1080x1920.png',
    'store-assets/screenshots/google-play/02-reward-1080x1920.png',
    1080,
    1920,
  ),
  _Asset(
    'test/goldens/play_03_my_space_1080x1920.png',
    'store-assets/screenshots/google-play/03-my-space-1080x1920.png',
    1080,
    1920,
  ),
  _Asset(
    'test/goldens/play_04_change_space_1080x1920.png',
    'store-assets/screenshots/google-play/04-change-space-1080x1920.png',
    1080,
    1920,
  ),
  _Asset(
    'test/goldens/play_05_journal_1080x1920.png',
    'store-assets/screenshots/google-play/05-journal-1080x1920.png',
    1080,
    1920,
  ),
];

const _legacyScreenshots = <String>[
  'store-assets/screenshots/app-store/03-my-space-1290x2796.png',
  'store-assets/screenshots/app-store/04-change-space-1290x2796.png',
  'store-assets/screenshots/app-store/05-journal-1290x2796.png',
  'store-assets/screenshots/01-quests-1290x2796.png',
  'store-assets/screenshots/02-reward-1290x2796.png',
  'store-assets/screenshots/03-tapestry-room-1290x2796.png',
  'store-assets/screenshots/04-shop-1290x2796.png',
  'store-assets/screenshots/05-insights-1290x2796.png',
];

void main(List<String> arguments) {
  if (arguments.isNotEmpty &&
      !(arguments.length == 1 && arguments.single == '--ios-only')) {
    stderr.writeln(
      'Usage: dart run tool/export_store_screenshots.dart [--ios-only]',
    );
    exitCode = 64;
    return;
  }
  final iosOnly = arguments.isNotEmpty;
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this command from the app repository root.');
    exitCode = 64;
    return;
  }

  final selectedAssets = iosOnly
      ? _assets.where((asset) => asset.destination.contains('/app-store/'))
      : _assets;
  for (final asset in selectedAssets) {
    final source = File(asset.source);
    if (!source.existsSync()) {
      throw StateError(
        'Missing ${asset.source}. Regenerate the screenshot story first.',
      );
    }

    final decoded = img.decodePng(source.readAsBytesSync());
    if (decoded == null) {
      throw StateError('Could not decode ${asset.source}.');
    }
    if (decoded.width != asset.width || decoded.height != asset.height) {
      throw StateError(
        '${asset.source} is ${decoded.width}x${decoded.height}; expected '
        '${asset.width}x${asset.height}.',
      );
    }
    if (decoded.hasAlpha &&
        decoded.any((pixel) => pixel.a != decoded.maxChannelValue)) {
      throw StateError(
        '${asset.source} contains transparent pixels and cannot be flattened '
        'without a visual decision.',
      );
    }

    final rgb = decoded.convert(format: img.Format.uint8, numChannels: 3);
    final destination = File(asset.destination);
    destination.parent.createSync(recursive: true);
    final temporary = File('${asset.destination}.tmp');
    temporary.writeAsBytesSync(img.encodePng(rgb, level: 6));

    final verification = img.decodePng(temporary.readAsBytesSync());
    if (verification == null ||
        verification.width != asset.width ||
        verification.height != asset.height ||
        verification.hasAlpha) {
      temporary.deleteSync();
      throw StateError('Store export verification failed for ${asset.source}.');
    }
    if (destination.existsSync()) destination.deleteSync();
    temporary.renameSync(destination.path);
    stdout.writeln('Exported ${asset.destination}');
  }

  for (final path in _legacyScreenshots) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
