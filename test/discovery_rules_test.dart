import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _rules() => File('firestore.rules').readAsStringSync();

String _block(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(
    endIndex,
    greaterThan(startIndex),
    reason: 'missing $end after $start',
  );
  return source.substring(startIndex, endIndex);
}

void main() {
  test('discoverable spaces are a strict minimal projection', () {
    final rules = _rules();
    final schema = _block(
      rules,
      'function validDiscoverableSpaceShape(code, d)',
      'function ownsRoom(code)',
    );

    for (final field in const [
      'v',
      'title',
      'level',
      'wall',
      'floor',
      'skin',
      'window',
      'bucket',
      'publicName',
      'ownerKey',
      'updatedAt',
      'expiresAt',
    ]) {
      expect(schema, contains("'$field'"));
    }
    expect(schema, contains('d.keys().hasOnly(['));
    expect(schema, contains('d.v == 3'));
    expect(schema, contains('validBuildTitle(d.title)'));
    expect(
      schema,
      contains('d.bucket is int && d.bucket >= 0 && d.bucket <= 999999'),
    );
    expect(schema, contains('d.updatedAt is timestamp'));
    expect(schema, contains('d.expiresAt is timestamp'));
    expect(schema, contains('d.expiresAt > request.time'));
    expect(
      schema,
      contains('d.publicName is string && d.publicName.size() <= 32'),
    );
    expect(
      schema,
      contains(r"d.ownerKey is string && d.ownerKey.matches('^[a-f0-9]{64}$')"),
    );
    expect(
      schema,
      contains(
        'request.resource.data.ownerKey == ownerKeyFor(request.auth.uid)',
      ),
    );
    expect(schema, contains('request.resource.data.updatedAt == request.time'));
    expect(schema, contains("request.time + duration.value(31, 'd')"));

    for (final privateField in const [
      'uid',
      'name',
      'memories',
      'weather',
      'todayLit',
      'focusKind',
      'profileVisible',
      'displayName',
      'about',
      'featuredGoals',
      'pinnedMoments',
      'profilePhotoPath',
      'seasonPhotoPath',
    ]) {
      expect(schema, isNot(contains("'$privateField'")));
    }
  });

  test('directory browsing is authenticated and intentionally bounded', () {
    final directory = _block(
      _rules(),
      'match /discoverableSpaces/{code}',
      'match /serviceIdentityDeletionTombstones/{uid}',
    );

    expect(directory, contains('allow get: if request.auth != null'));
    expect(
      RegExp(
        r'validDiscoverableSpaceShape\(code, resource\.data\)',
      ).allMatches(directory).length,
      1,
    );
    expect(directory, contains('resource.data.expiresAt > request.time'));
    expect(directory, contains('|| ownsRoom(code)'));
    expect(
      directory,
      matches(
        RegExp(
          r'allow list: if request\.auth != null\s*'
          r'&& request\.query\.limit != null\s*'
          r'&& request\.query\.limit > 0\s*'
          r'&& request\.query\.limit <= 12\s*'
          r'&& resource\.data\.expiresAt > request\.time;',
        ),
      ),
    );
    expect(directory, isNot(contains('allow get, list: if true')));
  });

  test(
    'only the matching room owner can publish or remove a directory card',
    () {
      final directory = _block(
        _rules(),
        'match /discoverableSpaces/{code}',
        'match /serviceIdentityDeletionTombstones/{uid}',
      );

      expect(directory, contains('allow create: if ownsRoom(code)'));
      expect(directory, contains('allow update: if ownsRoom(code)'));
      expect(
        directory,
        contains('!serviceIdentityDeletionStarted(request.auth.uid)'),
      );
      expect(directory, contains('validDiscoverableSpace(code)'));
      expect(directory, contains("request.resource.data.publicName == ''"));
      expect(
        directory,
        contains(
          'request.resource.data.publicName == resource.data.publicName',
        ),
      );
      expect(directory, contains('allow delete: if ownsRoom(code)'));
      expect(directory, contains('normalRoomRemovalAllowed(code)'));
      expect(directory, contains('fencedRoomRemovalAllowed(code)'));

      final ownership = _block(
        _rules(),
        'function ownsRoom(code)',
        'function normalRoomRemovalAllowed(code)',
      );
      expect(
        ownership,
        contains(r'exists(/databases/$(database)/documents/rooms/$(code))'),
      );
      expect(
        ownership,
        contains(
          r'get(/databases/$(database)/documents/rooms/$(code)).data.uid',
        ),
      );
      expect(ownership, contains('== request.auth.uid'));
    },
  );

  test('directory rules do not weaken private room listing', () {
    final rules = _rules();
    final rooms = _block(
      rules,
      'match /rooms/{code}',
      'match /roomDeletionLocks/{code}',
    );

    expect(rooms, contains('allow get: if resource.data.v == 5'));
    expect(rooms, contains('allow list: if request.auth != null'));
    expect(rooms, contains('resource.data.uid == request.auth.uid'));
    expect(rooms, contains('request.query.limit <= 100'));
    expect(rooms, isNot(contains('allow list: if true')));
  });

  test('moderation and rate-limit records are Admin-only', () {
    final rules = _rules();
    final internals = _block(
      rules,
      'match /discoveryNameChanges/{uid}',
      'match /serviceIdentityDeletionTombstones/{uid}',
    );
    expect(internals, contains('allow read, write: if false;'));
    expect(internals, contains('match /discoveryReports/{code}/{document=**}'));
  });
}
