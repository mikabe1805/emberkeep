import 'dart:convert';
import 'dart:io';

const _buildRoot = 'build/web';
const _manifestName = 'offline-assets.json';
const _workerName = 'room_of_days_service_worker.js';
const _maximumCacheBytes = 96 * 1024 * 1024;
const _canvasKitRuntime = <String>{
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
};

Future<void> main(List<String> args) async {
  if (args.length > 1 || (args.isNotEmpty && args.single != '--check')) {
    stderr.writeln('Usage: dart run tool/prepare_web_offline.dart [--check]');
    exitCode = 64;
    return;
  }

  try {
    final checkOnly = args.isNotEmpty;
    final root = Directory(_buildRoot).absolute;
    if (!root.existsSync()) {
      throw StateError(
        'Missing ${root.path}; run flutter build web --release.',
      );
    }

    _verifyFreshBuild(root);
    final release = await _releaseManifest(root);
    final output = File('${root.path}${Platform.pathSeparator}$_manifestName');
    final encoded =
        '${const JsonEncoder.withIndent('  ').convert(release.json)}\n';

    if (checkOnly) {
      if (!output.existsSync() || await output.readAsString() != encoded) {
        throw StateError(
          '$_manifestName is missing or stale; run '
          'dart run tool/prepare_web_offline.dart.',
        );
      }
      stdout.writeln(
        'PASS: ${release.assetCount} offline files '
        '(${_mib(release.bytes)} MiB) are complete and current.',
      );
      return;
    }

    await output.writeAsString(encoded, flush: true);
    stdout.writeln(
      'Prepared ${output.path}: ${release.assetCount} files, '
      '${_mib(release.bytes)} MiB.',
    );
  } on Object catch (error) {
    stderr.writeln('FAIL: web offline release preparation failed: $error');
    exitCode = 1;
  }
}

void _verifyFreshBuild(Directory root) {
  final critical = <String>[
    'index.html',
    'flutter_bootstrap.js',
    'main.dart.js',
    'manifest.json',
    'assets/AssetManifest.bin',
    'assets/FontManifest.json',
    _workerName,
    ..._canvasKitRuntime,
  ];
  for (final relative in critical) {
    if (!File(_join(root.path, relative)).existsSync()) {
      throw StateError('Release build is missing $relative.');
    }
  }

  final sourceWorker = File('web/$_workerName').readAsStringSync();
  final builtWorker = File(_join(root.path, _workerName)).readAsStringSync();
  if (sourceWorker != builtWorker) {
    throw StateError('Built $_workerName is stale; rebuild the web release.');
  }

  final bootstrap = File(
    _join(root.path, 'flutter_bootstrap.js'),
  ).readAsStringSync();
  for (final expected in const [
    'registerRoomOfDaysServiceWorker',
    'room_of_days_service_worker.js',
    "canvasKitBaseUrl: 'canvaskit/'",
  ]) {
    if (!bootstrap.contains(expected)) {
      throw StateError('Built flutter_bootstrap.js is missing $expected.');
    }
  }
  if (bootstrap.contains('{{')) {
    throw StateError(
      'Built flutter_bootstrap.js still contains template tokens.',
    );
  }

  final mainBuild = File(_join(root.path, 'main.dart.js')).lastModifiedSync();
  final dartSources = <File>[
    File('pubspec.yaml'),
    ...Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ];
  final newestDartSource = dartSources
      .map((file) => file.lastModifiedSync())
      .reduce((a, b) => a.isAfter(b) ? a : b);
  if (mainBuild.isBefore(newestDartSource)) {
    throw StateError(
      'main.dart.js predates Dart or pubspec source; rebuild before deploy.',
    );
  }

  final webRoot = Directory('web').absolute;
  for (final source in webRoot.listSync(recursive: true).whereType<File>()) {
    final relative = source.path
        .substring(webRoot.path.length + 1)
        .replaceAll('\\', '/');
    final built = File(_join(root.path, relative));
    if (!built.existsSync() ||
        built.lastModifiedSync().isBefore(source.lastModifiedSync())) {
      throw StateError('Built web shell predates web/$relative; rebuild.');
    }
  }
}

Future<_ReleaseManifest> _releaseManifest(Directory root) async {
  final files = <({String relative, File file})>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = entity.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/');
    if (_cacheable(relative)) files.add((relative: relative, file: entity));
  }
  files.sort((a, b) => a.relative.compareTo(b.relative));

  final bytes = files.fold<int>(
    0,
    (sum, entry) => sum + entry.file.lengthSync(),
  );
  if (bytes > _maximumCacheBytes) {
    throw StateError(
      'Offline cache would be ${_mib(bytes)} MiB; '
      'limit is ${_mib(_maximumCacheBytes)} MiB.',
    );
  }

  final assets = <String>[
    './',
    for (final entry in files) './${Uri(path: entry.relative)}',
    './$_manifestName',
  ];
  return _ReleaseManifest(
    json: {'schema': 1, 'assets': assets},
    assetCount: assets.length,
    bytes: bytes,
  );
}

bool _cacheable(String relative) {
  if (relative == '.last_build_id' ||
      relative == _manifestName ||
      relative == _workerName ||
      relative == 'flutter_service_worker.js' ||
      relative.endsWith('.map') ||
      relative.endsWith('.symbols')) {
    return false;
  }
  if (relative.startsWith('canvaskit/')) {
    return _canvasKitRuntime.contains(relative);
  }
  return true;
}

String _join(String root, String relative) =>
    '$root${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

String _mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

final class _ReleaseManifest {
  const _ReleaseManifest({
    required this.json,
    required this.assetCount,
    required this.bytes,
  });

  final Map<String, Object> json;
  final int assetCount;
  final int bytes;
}
