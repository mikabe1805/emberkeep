import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// A deliberately explicit production smoke for Room of Days sharing rules.
///
/// This creates two temporary anonymous Firebase identities, exercises the
/// public room, private receipt, Spark, and visitor-photo boundaries, then
/// removes every object and identity it created. It refuses to run unless the
/// caller passes `--confirm-production`.
Future<void> main(List<String> arguments) async {
  if (!arguments.contains('--confirm-production')) {
    stderr.writeln(
      'Refusing to touch production. Re-run with --confirm-production after '
      'checking the project named below.',
    );
    stderr.writeln('Expected project: emberkeep-5b33b');
    exitCode = 64;
    return;
  }

  final config = _readFirebaseConfig();
  if (config.projectId != 'emberkeep-5b33b') {
    throw StateError(
      'Refusing unexpected Firebase project ${config.projectId}.',
    );
  }

  final includeStorage = !arguments.contains('--firestore-only');
  final smoke = _ProductionSmoke(config, includeStorage: includeStorage);
  try {
    await smoke.run();
    stdout.writeln(
      includeStorage
          ? 'PASS: production sharing, Spark, Circle, and photo rules.'
          : 'PASS: production sharing, Spark, and Circle rules. '
                'Storage was intentionally skipped.',
    );
  } finally {
    await smoke.cleanup();
  }
}

class _ProductionSmoke {
  _ProductionSmoke(this.config, {required this.includeStorage});

  final _FirebaseConfig config;
  final bool includeStorage;
  final _Http http = _Http();
  final Random _random = Random.secure();

  _Identity? owner;
  _Identity? visitor;
  String? roomCode;
  bool roomCreated = false;
  bool profileImageUploaded = false;

  String get _documentsBase =>
      'https://firestore.googleapis.com/v1/projects/${config.projectId}'
      '/databases/(default)/documents';

  String get _databaseName =>
      'projects/${config.projectId}/databases/(default)';

  Future<void> run() async {
    _step('Create two temporary anonymous identities');
    owner = await _createAnonymousIdentity();
    visitor = await _createAnonymousIdentity();

    roomCode = await _unusedRoomCode();
    final code = roomCode!;

    _step('Publish a version 5 room as its owner');
    final create = await _commitDocument(
      path: 'rooms/$code',
      token: owner!.idToken,
      fields: _roomFields(owner!.uid, code),
      serverTimestampField: 'updatedAt',
      exists: false,
    );
    _expect(create, 200, 'owner v5 room create');
    roomCreated = true;

    _step('Read the exact code publicly and reject room enumeration');
    final exact = await http.get(Uri.parse('$_documentsBase/rooms/$code'));
    _expect(exact, 200, 'public exact-code read');
    final exactJson = jsonDecode(exact.text) as Map<String, dynamic>;
    final displayName =
        ((exactJson['fields'] as Map<String, dynamic>)['displayName']
            as Map<String, dynamic>)['stringValue'];
    if (displayName != 'Release keeper') {
      throw StateError('Exact-code read returned the wrong display name.');
    }
    final list = await http.get(Uri.parse('$_documentsBase/rooms?pageSize=1'));
    _expect(list, 403, 'public room listing');

    _step('Accept versioned visitor-photo paths and reject arbitrary ones');
    const profileRevision = 'releaseSmokePhoto00001';
    const seasonRevision = 'releaseSmokeSeason0001';
    final mediaFields = _roomFields(
      owner!.uid,
      code,
      profilePhotoPath:
          'shared_rooms/${owner!.uid}/$code/profile/$profileRevision',
      seasonPhotoPath:
          'shared_rooms/${owner!.uid}/$code/season/$seasonRevision',
    );
    final mediaUpdate = await _commitDocument(
      path: 'rooms/$code',
      token: owner!.idToken,
      fields: mediaFields,
      serverTimestampField: 'updatedAt',
      exists: true,
    );
    _expect(mediaUpdate, 200, 'valid deterministic media paths');

    final badMediaFields = Map<String, Object?>.from(mediaFields)
      ..['profilePhotoPath'] =
          'shared_rooms/${owner!.uid}/$code/not-a-public-slot';
    final badMedia = await _commitDocument(
      path: 'rooms/$code',
      token: owner!.idToken,
      fields: badMediaFields,
      serverTimestampField: 'updatedAt',
      exists: true,
    );
    _expect(badMedia, 403, 'arbitrary media path');

    _step('Reject an owner downgrade from schema v5 to v4');
    final downgradeFields = Map<String, Object?>.from(mediaFields)
      ..remove('profilePhotoPath')
      ..remove('seasonPhotoPath')
      ..['v'] = 4;
    final downgrade = await _commitDocument(
      path: 'rooms/$code',
      token: owner!.idToken,
      fields: downgradeFields,
      serverTimestampField: 'updatedAt',
      exists: true,
    );
    _expect(downgrade, 403, 'schema downgrade');

    _step('Deliver one Circle receipt and one fixed Spark from the visitor');
    final circle = await _commitDocument(
      path: 'rooms/$code/circleAdds/${visitor!.uid}',
      token: visitor!.idToken,
      fields: {'sender': visitor!.uid, 'kind': 'circle_added'},
      serverTimestampField: 'sentAt',
      exists: false,
    );
    _expect(circle, 200, 'visitor Circle receipt');
    final spark = await _commitDocument(
      path: 'rooms/$code/sparks/${visitor!.uid}',
      token: visitor!.idToken,
      fields: {'sender': visitor!.uid, 'kind': 'steady'},
      serverTimestampField: 'sentAt',
      exists: false,
    );
    _expect(spark, 200, 'visitor Spark');

    _step('Keep receipts owner-only and reject duplicate pending support');
    final ownerSparkRead = await _getDocument(
      'rooms/$code/sparks/${visitor!.uid}',
      token: owner!.idToken,
    );
    _expect(ownerSparkRead, 200, 'owner Spark read');
    final visitorSparkRead = await _getDocument(
      'rooms/$code/sparks/${visitor!.uid}',
      token: visitor!.idToken,
    );
    _expect(visitorSparkRead, 403, 'visitor Spark read');
    final ownerCircleRead = await _getDocument(
      'rooms/$code/circleAdds/${visitor!.uid}',
      token: owner!.idToken,
    );
    _expect(ownerCircleRead, 200, 'owner Circle receipt read');
    final duplicateSpark = await _commitDocument(
      path: 'rooms/$code/sparks/${visitor!.uid}',
      token: visitor!.idToken,
      fields: {'sender': visitor!.uid, 'kind': 'cheer'},
      serverTimestampField: 'sentAt',
      exists: true,
    );
    _expect(duplicateSpark, 403, 'duplicate pending Spark');

    _step('Reject self-sent Sparks and self-added Circle receipts');
    final selfSpark = await _commitDocument(
      path: 'rooms/$code/sparks/${owner!.uid}',
      token: owner!.idToken,
      fields: {'sender': owner!.uid, 'kind': 'kindle'},
      serverTimestampField: 'sentAt',
      exists: false,
    );
    _expect(selfSpark, 403, 'self-sent Spark');
    final selfCircle = await _commitDocument(
      path: 'rooms/$code/circleAdds/${owner!.uid}',
      token: owner!.idToken,
      fields: {'sender': owner!.uid, 'kind': 'circle_added'},
      serverTimestampField: 'sentAt',
      exists: false,
    );
    _expect(selfCircle, 403, 'self-added Circle receipt');

    if (includeStorage) await _exerciseStorage(code);
  }

  Future<void> _exerciseStorage(String code) async {
    final objectPath =
        'shared_rooms/${owner!.uid}/$code/profile/releaseSmokePhoto00001';
    final seasonPath =
        'shared_rooms/${owner!.uid}/$code/season/releaseSmokeSeason0001';
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

    _step('Upload one bounded image as the owner');
    final upload = await http.request(
      'POST',
      Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/${config.storageBucket}/o',
        {'uploadType': 'media', 'name': objectPath},
      ),
      headers: {
        HttpHeaders.authorizationHeader: 'Firebase ${owner!.idToken}',
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      bytes: base64Decode(onePixelPng),
    );
    _expect(upload, 200, 'owner visitor-photo upload');
    profileImageUploaded = true;

    _step('Allow exact image fetches but reject media listing');
    final fetch = await http.get(
      Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/'
        '${config.storageBucket}/o/${Uri.encodeComponent(objectPath)}?alt=media',
      ),
    );
    _expect(fetch, 200, 'public exact image fetch');
    if (fetch.bytes.isEmpty) {
      throw StateError('Public image fetch returned an empty object.');
    }
    final list = await http.get(
      Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/${config.storageBucket}/o',
        {'prefix': 'shared_rooms/${owner!.uid}/$code/'},
      ),
    );
    _expect(list, 403, 'public media listing');

    _step('Reject non-owner uploads and unsupported content types');
    final nonOwner = await http.request(
      'POST',
      Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/${config.storageBucket}/o',
        {'uploadType': 'media', 'name': objectPath},
      ),
      headers: {
        HttpHeaders.authorizationHeader: 'Firebase ${visitor!.idToken}',
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      bytes: base64Decode(onePixelPng),
    );
    _expect(nonOwner, 403, 'non-owner image upload');
    final wrongType = await http.request(
      'POST',
      Uri.https(
        'firebasestorage.googleapis.com',
        '/v0/b/${config.storageBucket}/o',
        {'uploadType': 'media', 'name': seasonPath},
      ),
      headers: {
        HttpHeaders.authorizationHeader: 'Firebase ${owner!.idToken}',
        HttpHeaders.contentTypeHeader: 'text/plain',
      },
      bytes: Uint8List.fromList(utf8.encode('not an image')),
    );
    _expect(wrongType, 403, 'unsupported image content type');
  }

  Future<void> cleanup() async {
    final code = roomCode;
    final ownerIdentity = owner;
    final visitorIdentity = visitor;
    if (profileImageUploaded && code != null && ownerIdentity != null) {
      await _deleteStorageObject(
        'shared_rooms/${ownerIdentity.uid}/$code/profile/'
        'releaseSmokePhoto00001',
        ownerIdentity.idToken,
      );
      profileImageUploaded = false;
    }
    if (roomCreated && code != null && ownerIdentity != null) {
      if (visitorIdentity != null) {
        await _deleteDocument(
          'rooms/$code/sparks/${visitorIdentity.uid}',
          ownerIdentity.idToken,
        );
        await _deleteDocument(
          'rooms/$code/circleAdds/${visitorIdentity.uid}',
          ownerIdentity.idToken,
        );
      }
      await _deleteDocument('rooms/$code', ownerIdentity.idToken);
      roomCreated = false;
    }
    if (visitorIdentity != null) await _deleteIdentity(visitorIdentity);
    if (ownerIdentity != null) await _deleteIdentity(ownerIdentity);
    http.close();
    stdout.writeln('Cleanup complete.');
  }

  Future<_Identity> _createAnonymousIdentity() async {
    final result = await http.request(
      'POST',
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp'
        '?key=${config.apiKey}',
      ),
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      bytes: Uint8List.fromList(utf8.encode('{"returnSecureToken":true}')),
    );
    _expect(result, 200, 'anonymous sign-in');
    final decoded = jsonDecode(result.text) as Map<String, dynamic>;
    return _Identity(
      uid: decoded['localId'] as String,
      idToken: decoded['idToken'] as String,
    );
  }

  Future<void> _deleteIdentity(_Identity identity) async {
    final result = await http.request(
      'POST',
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:delete'
        '?key=${config.apiKey}',
      ),
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      bytes: Uint8List.fromList(
        utf8.encode(jsonEncode({'idToken': identity.idToken})),
      ),
    );
    if (result.statusCode != 200 && result.statusCode != 400) {
      stderr.writeln(
        'Warning: temporary identity cleanup returned '
        '${result.statusCode}.',
      );
    }
  }

  Future<String> _unusedRoomCode() async {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = List.generate(
        6,
        (_) => alphabet[_random.nextInt(alphabet.length)],
      ).join();
      final existing = await http.get(Uri.parse('$_documentsBase/rooms/$code'));
      if (existing.statusCode == 404) return code;
      if (existing.statusCode != 200) {
        _expect(existing, 404, 'room collision check');
      }
    }
    throw StateError('Could not reserve an unused room code.');
  }

  Map<String, Object?> _roomFields(
    String ownerUid,
    String code, {
    String profilePhotoPath = '',
    String seasonPhotoPath = '',
  }) => {
    'uid': ownerUid,
    'name': 'Fellow keeper',
    'title': 'STEADY FLAME',
    'level': 12,
    'furniture': <String>['rug', 'plant', 'hearth'],
    'wall': 'wall_walnut',
    'floor': 'floor_oak',
    'skin': 'ember_amber',
    'window': 'moon',
    'awake': true,
    'memories': 8,
    'weather': 'steady',
    'todayLit': true,
    'focusKind': 'quiet',
    'focusUntil': 0,
    'profileVisible': true,
    'displayName': 'Release keeper',
    'about': 'Temporary release smoke.',
    'featuredGoals': <String>['Keep one small thing'],
    'cardOrder': <String>['about', 'rightNow', 'thisSeason'],
    'pinnedMoments': <Map<String, Object?>>[],
    'season': 'Testing the room we share.',
    'profilePhotoPath': profilePhotoPath,
    'seasonPhotoPath': seasonPhotoPath,
    'v': 5,
  };

  Future<_HttpResult> _commitDocument({
    required String path,
    required String token,
    required Map<String, Object?> fields,
    required String serverTimestampField,
    required bool exists,
  }) {
    final documentName = '$_databaseName/documents/$path';
    return http.request(
      'POST',
      Uri.parse('$_documentsBase:commit'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      bytes: Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'writes': [
              {
                'update': {
                  'name': documentName,
                  'fields': {
                    for (final entry in fields.entries)
                      entry.key: _firestoreValue(entry.value),
                  },
                },
                'updateTransforms': [
                  {
                    'fieldPath': serverTimestampField,
                    'setToServerValue': 'REQUEST_TIME',
                  },
                ],
                'currentDocument': {'exists': exists},
              },
            ],
          }),
        ),
      ),
    );
  }

  Future<_HttpResult> _getDocument(String path, {required String token}) =>
      http.get(
        Uri.parse('$_documentsBase/$path'),
        headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
      );

  Future<void> _deleteDocument(String path, String token) async {
    final result = await http.request(
      'DELETE',
      Uri.parse('$_documentsBase/$path'),
      headers: {HttpHeaders.authorizationHeader: 'Bearer $token'},
    );
    if (result.statusCode != 200 && result.statusCode != 404) {
      stderr.writeln(
        'Warning: cleanup of $path returned ${result.statusCode}.',
      );
    }
  }

  Future<void> _deleteStorageObject(String objectPath, String token) async {
    final result = await http.request(
      'DELETE',
      Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/'
        '${config.storageBucket}/o/${Uri.encodeComponent(objectPath)}',
      ),
      headers: {HttpHeaders.authorizationHeader: 'Firebase $token'},
    );
    if (result.statusCode != 200 &&
        result.statusCode != 204 &&
        result.statusCode != 404) {
      stderr.writeln('Warning: image cleanup returned ${result.statusCode}.');
    }
  }

  void _step(String label) => stdout.writeln('• $label');

  void _expect(_HttpResult result, int expected, String label) {
    if (result.statusCode == expected) return;
    final safeBody = result.text.length > 600
        ? '${result.text.substring(0, 600)}…'
        : result.text;
    throw StateError(
      '$label returned ${result.statusCode}; expected $expected. $safeBody',
    );
  }
}

Map<String, Object?> _firestoreValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {
        if (value.isNotEmpty)
          'values': [for (final item in value) _firestoreValue(item)],
      },
    };
  }
  if (value is Map) {
    return {
      'mapValue': {
        'fields': {
          for (final entry in value.entries)
            entry.key.toString(): _firestoreValue(entry.value),
        },
      },
    };
  }
  throw ArgumentError('Unsupported Firestore value ${value.runtimeType}.');
}

class _Http {
  final HttpClient _client = HttpClient();

  Future<_HttpResult> get(Uri uri, {Map<String, String> headers = const {}}) =>
      request('GET', uri, headers: headers);

  Future<_HttpResult> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? bytes,
  }) async {
    final request = await _client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (bytes != null) {
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final body = await response.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (builder, chunk) => builder..add(chunk),
    );
    return _HttpResult(response.statusCode, body.takeBytes());
  }

  void close() => _client.close(force: true);
}

class _HttpResult {
  const _HttpResult(this.statusCode, this.bytes);

  final int statusCode;
  final Uint8List bytes;

  String get text => utf8.decode(bytes, allowMalformed: true);
}

class _Identity {
  const _Identity({required this.uid, required this.idToken});

  final String uid;
  final String idToken;
}

class _FirebaseConfig {
  const _FirebaseConfig({
    required this.apiKey,
    required this.projectId,
    required this.storageBucket,
  });

  final String apiKey;
  final String projectId;
  final String storageBucket;
}

_FirebaseConfig _readFirebaseConfig() {
  final script = File.fromUri(Platform.script);
  final root = script.parent.parent;
  final source = File(
    '${root.path}${Platform.pathSeparator}lib'
    '${Platform.pathSeparator}firebase_options.dart',
  ).readAsStringSync();
  final webBlock = RegExp(
    r'static const FirebaseOptions web = FirebaseOptions\((.*?)\);',
    dotAll: true,
  ).firstMatch(source)?.group(1);
  if (webBlock == null) {
    throw StateError('Could not find the web Firebase options.');
  }
  String value(String field) {
    final match = RegExp("$field: '([^']+)'").firstMatch(webBlock);
    if (match == null) throw StateError('Missing Firebase $field.');
    return match.group(1)!;
  }

  return _FirebaseConfig(
    apiKey: value('apiKey'),
    projectId: value('projectId'),
    storageBucket: value('storageBucket'),
  );
}
