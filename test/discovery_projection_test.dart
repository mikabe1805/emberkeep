import 'package:emberkeep/discovery.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const code = 'ABC234';

  test('directory projection is an allowlist with no private activity', () {
    final display = discoverableSpaceDisplay({
      'title': 'MIGHTY MAKER',
      'level': 42,
      'wall': 'wall_archive',
      'floor': 'floor_cherry',
      'skin': 'ember_amber',
      'window': 'aurora',
      'ownerKey': discoveryOwnerKey('owner-one'),
      'uid': 'private-uid',
      'name': 'private name',
      'email': 'private@example.com',
      'presence': true,
      'todayLit': true,
      'weather': 'bright',
      'focusKind': 'study',
      'focusUntil': 999999,
      'memories': 500,
      'quests': ['private quest'],
      'journal': ['private journal'],
      'streak': 20,
      'profileVisible': true,
      'roomKeepsakes': ['keepsake_books', 'keepsake_books', 'private_note'],
    }, roomCode: code);

    expect(display.keys, {
      'v',
      'title',
      'level',
      'wall',
      'floor',
      'skin',
      'window',
      'roomKeepsakes',
      'bucket',
      'ownerKey',
      'publicName',
    });
    expect(display['v'], discoverableSpaceVersion);
    expect(display['title'], 'MIGHTY MAKER');
    expect(display['wall'], 'wall_archive');
    expect(display['bucket'], discoverableSpaceBucket(code));
    expect(display['ownerKey'], discoveryOwnerKey('owner-one'));
    expect(display['publicName'], isEmpty);
    expect(display['roomKeepsakes'], ['keepsake_books']);
    expect(display.values.join(' '), isNot(contains('private')));
  });

  test('public names normalize locally without borrowing private identity', () {
    expect(
      sanitizeDiscoveryPublicName('  José\u00a0  O’Neil  '),
      'José O’Neil',
    );
    expect(sanitizeDiscoveryPublicName('A\nB'), 'A B');
    expect(
      sanitizeDiscoveryPublicName(List.filled(40, 'x').join()).runes.length,
      discoveryPublicNameMaxLength,
    );
    expect(
      discoverableSpaceDisplay({
        'ownerKey': discoveryOwnerKey('owner-one'),
        'playerName': 'PRIVATE MIKA',
        'displayName': 'ALSO PRIVATE',
      }, roomCode: code)['publicName'],
      isEmpty,
    );
  });

  test('authored space themes survive the strict wall projection', () {
    expect(
      discoverableSpaceDisplay({
        'ownerKey': discoveryOwnerKey('owner-one'),
        'wall': 'wall_archive',
      }, roomCode: code)['wall'],
      'wall_archive',
    );
    expect(
      discoverableSpaceDisplay({
        'ownerKey': discoveryOwnerKey('owner-one'),
        'wall': 'wall_conservatory',
      }, roomCode: code)['wall'],
      'wall_conservatory',
    );
    expect(
      discoverableSpaceDisplay({
        'ownerKey': discoveryOwnerKey('owner-one'),
        'wall': 'wall_listening',
      }, roomCode: code)['wall'],
      'wall_listening',
    );
  });

  test('equipped found flame survives the visual-only projection', () {
    expect(
      discoverableSpaceDisplay({
        'ownerKey': discoveryOwnerKey('owner-one'),
        'skin': 'found_moss',
      }, roomCode: code)['skin'],
      'found_moss',
    );
  });

  test(
    'directory v4 carries only catalogued keepsakes while v3 reads empty',
    () {
      final now = DateTime.utc(2026, 8, 22);
      final v4 = DiscoverableSpaceSummary.fromDocument(code, {
        'v': 4,
        'title': 'KEEPER',
        'level': 1,
        'wall': 'wall_rain',
        'floor': 'floor_oak',
        'skin': 'ember_amber',
        'window': 'rain',
        'roomKeepsakes': ['keepsake_teapot', 'private_note', 'keepsake_teapot'],
        'bucket': 1,
        'ownerKey': discoveryOwnerKey('owner-one'),
        'publicName': '',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'journal': 'must not become a summary field',
      }, now: now);
      expect(v4?.roomKeepsakes, ['keepsake_teapot']);

      final v3 = DiscoverableSpaceSummary.fromDocument(code, {
        'v': 3,
        'title': 'KEEPER',
        'level': 1,
        'wall': 'wall_walnut',
        'floor': 'floor_oak',
        'skin': 'ember_amber',
        'window': 'moon',
        'bucket': 1,
        'ownerKey': discoveryOwnerKey('owner-one'),
        'publicName': '',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      }, now: now);
      expect(v3?.roomKeepsakes, isEmpty);
    },
  );
  test('directory summary retains an equipped found flame', () {
    final now = DateTime.utc(2026, 8, 22);
    final summary = DiscoverableSpaceSummary.fromDocument(code, {
      'v': 3,
      'title': 'KEEPER',
      'level': 1,
      'wall': 'wall_listening',
      'floor': 'floor_oak',
      'skin': 'found_moss',
      'window': 'moon',
      'bucket': 1,
      'ownerKey': discoveryOwnerKey('owner-one'),
      'publicName': '',
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
    }, now: now);

    expect(summary?.skin, 'found_moss');
  });

  test('bucket is stable, bounded, and rejects non-room codes', () {
    expect(discoverableSpaceBucket('abc234'), discoverableSpaceBucket(code));
    expect(discoverableSpaceBucket(code), inInclusiveRange(0, 999999));
    expect(() => discoverableSpaceBucket('A0C234'), throwsArgumentError);
  });

  test('summary rejects incompatible documents and safely renders bad ids', () {
    final now = DateTime.utc(2026, 8, 22);
    final summary = DiscoverableSpaceSummary.fromDocument('abc234', {
      'v': 3,
      'title': '  DEEP CURRENT  ',
      'level': 0,
      'wall': 'unknown_wall',
      'floor': 'unknown_floor',
      'skin': 'unknown_skin',
      'window': 'unknown_window',
      'bucket': 9,
      'ownerKey': discoveryOwnerKey('owner-one'),
      'publicName': '  Rowan  ',
      'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      'uid': 'never accepted into the model',
    }, now: now);

    expect(summary, isNotNull);
    expect(summary!.code, code);
    expect(summary.buildTitle, 'DEEP CURRENT');
    expect(summary.level, 1);
    expect(summary.wall, 'wall_walnut');
    expect(summary.floor, 'floor_oak');
    expect(summary.skin, 'ember_amber');
    expect(summary.window, 'moon');
    expect(summary.publicName, 'Rowan');
    expect(
      DiscoverableSpaceSummary.fromDocument(code, {
        'v': 1,
        'bucket': 1,
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      }, now: now),
      isNull,
    );
    expect(
      DiscoverableSpaceSummary.fromDocument(code, {
        'v': 3,
        'bucket': -1,
        'ownerKey': discoveryOwnerKey('owner-one'),
        'publicName': '',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      }, now: now),
      isNull,
    );
    expect(
      DiscoverableSpaceSummary.fromDocument('invalid', {
        'v': 3,
        'bucket': 1,
        'ownerKey': discoveryOwnerKey('owner-one'),
        'publicName': '',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
      }, now: now),
      isNull,
    );
    expect(
      DiscoverableSpaceSummary.fromDocument(code, {
        'v': 3,
        'bucket': 1,
        'ownerKey': discoveryOwnerKey('owner-one'),
        'publicName': '',
        'expiresAt': Timestamp.fromDate(now),
      }, now: now),
      isNull,
    );
  });
}
