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
const _skwasmRuntime = <String>{
  'canvaskit/skwasm.js',
  'canvaskit/skwasm.wasm',
  'canvaskit/skwasm_heavy.js',
  'canvaskit/skwasm_heavy.wasm',
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
        'Missing ${root.path}; run flutter build web --release --wasm.',
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
        'PASS: ${release.assetCount} offline files are current; '
        '${_mib(release.coreBytes)} MiB starts the app and '
        '${_mib(release.deferredBytes)} MiB warms later.',
      );
      return;
    }

    await output.writeAsString(encoded, flush: true);
    stdout.writeln(
      'Prepared ${output.path}: ${release.assetCount} files, '
      '${_mib(release.coreBytes)} MiB core + '
      '${_mib(release.deferredBytes)} MiB deferred.',
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
    'main.dart.mjs',
    'main.dart.wasm',
    'manifest.json',
    'version.json',
    'assets/AssetManifest.bin',
    'assets/FontManifest.json',
    _workerName,
    ..._canvasKitRuntime,
    ..._skwasmRuntime,
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

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final packageVersion = RegExp(
    r'^version:\s*([^+\s]+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (packageVersion == null) {
    throw StateError('pubspec.yaml has no version name and build number.');
  }
  final builtVersion =
      jsonDecode(File(_join(root.path, 'version.json')).readAsStringSync())
          as Map<String, dynamic>;
  if (builtVersion['version'] != packageVersion.group(1) ||
      builtVersion['build_number'].toString() != packageVersion.group(2)) {
    throw StateError(
      'Built version.json does not match pubspec.yaml; rebuild before deploy.',
    );
  }

  final mainBuild = File(_join(root.path, 'main.dart.js')).lastModifiedSync();
  final dartSources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  final newestDartSource = dartSources
      .map((file) => file.lastModifiedSync())
      .reduce((a, b) => a.isAfter(b) ? a : b);
  if (mainBuild.isBefore(newestDartSource)) {
    throw StateError(
      'main.dart.js predates Dart source; rebuild before deploy.',
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

  final canvasKit = files
      .where(
        (entry) =>
            entry.relative == 'main.dart.js' ||
            _canvasKitRuntime.contains(entry.relative),
      )
      .toList();
  final skwasm = files
      .where(
        (entry) =>
            entry.relative == 'main.dart.mjs' ||
            entry.relative == 'main.dart.wasm' ||
            _skwasmRuntime.contains(entry.relative),
      )
      .toList();
  final rendererPaths = <String>{
    for (final entry in [...canvasKit, ...skwasm]) entry.relative,
  };
  final shared = files
      .where(
        (entry) =>
            !rendererPaths.contains(entry.relative) &&
            _sharedCore(entry.relative),
      )
      .toList();
  final sharedPaths = {for (final entry in shared) entry.relative};
  final deferred = files
      .where(
        (entry) =>
            !rendererPaths.contains(entry.relative) &&
            !sharedPaths.contains(entry.relative),
      )
      .toList();

  List<String> urls(Iterable<({String relative, File file})> entries) => [
    for (final entry in entries) './${Uri(path: entry.relative)}',
  ];

  final sharedAssets = <String>['./', ...urls(shared), './$_manifestName'];
  final canvasKitAssets = urls(canvasKit);
  final skwasmAssets = urls(skwasm);
  final deferredAssets = urls(deferred);
  final canvasKitBytes = canvasKit.fold<int>(
    0,
    (sum, entry) => sum + entry.file.lengthSync(),
  );
  final skwasmBytes = skwasm.fold<int>(
    0,
    (sum, entry) => sum + entry.file.lengthSync(),
  );
  final coreBytes =
      shared.fold<int>(0, (sum, entry) => sum + entry.file.lengthSync()) +
      (canvasKitBytes > skwasmBytes ? canvasKitBytes : skwasmBytes);
  final deferredBytes = deferred.fold<int>(
    0,
    (sum, entry) => sum + entry.file.lengthSync(),
  );
  return _ReleaseManifest(
    json: {
      'schema': 2,
      'sharedAssets': sharedAssets,
      'rendererAssets': {'canvaskit': canvasKitAssets, 'skwasm': skwasmAssets},
      'deferredAssets': deferredAssets,
    },
    assetCount:
        sharedAssets.length +
        canvasKitAssets.length +
        skwasmAssets.length +
        deferredAssets.length,
    coreBytes: coreBytes,
    deferredBytes: deferredBytes,
  );
}

bool _sharedCore(String relative) {
  if (relative == 'assets/NOTICES') return false;
  if (!relative.startsWith('assets/assets/')) return true;
  if (relative.startsWith('assets/assets/google_fonts/')) return true;
  if (relative.startsWith('assets/assets/quest/')) return true;
  if (relative.startsWith('assets/assets/rooms/quest-')) return true;
  if (relative == 'assets/assets/rooms/wall_walnut-fireless-v3.webp' ||
      relative == 'assets/assets/rooms/wall_walnut-clean-v2.webp') {
    return true;
  }
  if (relative.startsWith('assets/assets/sfx/room/ordinary/')) return true;
  if (relative.startsWith('assets/assets/sfx/room/paired_return/')) return true;
  return relative ==
      'assets/assets/sfx/room/completion/completion-composite.wav';
}

bool _cacheable(String relative) {
  if (relative == '.last_build_id' ||
      relative == _manifestName ||
      relative == _workerName ||
      relative == 'flutter_service_worker.js' ||
      // Continuous room ambience was removed on every platform. Keep the old
      // loop asset out of new offline releases so stale clients cannot fetch it.
      relative == 'assets/assets/sfx/hearth_room.wav' ||
      relative.endsWith('.map') ||
      relative.endsWith('.symbols')) {
    return false;
  }
  // The marketing page and Android release handoff publish independently from
  // the installable app shell. Never retain either in the app's offline cache:
  // a stale copy could hide the introduction or serve a superseded APK link.
  if (relative == 'android.html' ||
      relative == 'introduction.html' ||
      relative.startsWith('introduction/')) {
    return false;
  }
  if (relative.startsWith('canvaskit/')) {
    return _canvasKitRuntime.contains(relative) ||
        _skwasmRuntime.contains(relative);
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
    required this.coreBytes,
    required this.deferredBytes,
  });

  final Map<String, Object> json;
  final int assetCount;
  final int coreBytes;
  final int deferredBytes;
}
