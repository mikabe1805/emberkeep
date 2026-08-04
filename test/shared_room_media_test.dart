import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:emberkeep/journal_media.dart' as journal_media;
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/shared_room_media.dart';
import 'package:emberkeep/social.dart';
import 'package:emberkeep/widgets/visitor_shared_room_photo.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _jpeg([int length = 3]) {
  final bytes = Uint8List(length);
  bytes.setRange(0, 3, const [0xFF, 0xD8, 0xFF]);
  return bytes;
}

Uint8List _png() =>
    Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

SharedRoomMediaService _service({
  SharedRoomMediaLocalReader? readLocal,
  SharedRoomMediaUploadWriter? upload,
  SharedRoomMediaObjectDeleter? deleteObject,
  SharedRoomMediaUrlResolver? resolveUrl,
}) => SharedRoomMediaService(
  readLocal:
      readLocal ??
      (filename) async => journal_media.JournalMediaUploadData(
        filename: filename,
        bytes: _jpeg(),
      ),
  upload: upload ?? (request) async {},
  deleteObject: deleteObject ?? (path) async {},
  resolveUrl: resolveUrl ?? (path) async => 'https://example.test/photo',
);

Matcher _failure(SharedRoomMediaFailure failure) =>
    isA<SharedRoomMediaException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

void main() {
  group('shared room media paths', () {
    test('forms only canonical profile and season objects', () {
      expect(
        sharedRoomMediaObjectPath(
          ownerUid: 'owner_123',
          roomCode: 'abc234',
          slot: 'profile',
        ),
        'shared_rooms/owner_123/ABC234/profile',
      );
      expect(
        sharedRoomMediaObjectPath(
          ownerUid: 'owner_123',
          roomCode: 'ABC234',
          slot: 'season',
        ),
        'shared_rooms/owner_123/ABC234/season',
      );
    });

    test('rejects unsafe segments before forming an object path', () {
      expect(
        () => sharedRoomMediaObjectPath(
          ownerUid: '../owner',
          roomCode: 'ABC234',
          slot: 'profile',
        ),
        throwsA(_failure(SharedRoomMediaFailure.invalidOwnerUid)),
      );
      expect(
        () => sharedRoomMediaObjectPath(
          ownerUid: 'owner',
          roomCode: 'BAD10I',
          slot: 'profile',
        ),
        throwsA(_failure(SharedRoomMediaFailure.invalidRoomCode)),
      );
      expect(
        () => sharedRoomMediaObjectPath(
          ownerUid: 'owner',
          roomCode: 'ABC234',
          slot: 'gallery',
        ),
        throwsA(_failure(SharedRoomMediaFailure.invalidSlot)),
      );
    });

    test('visitor paths must be exact and canonical', () {
      final location = SharedRoomMediaLocation.fromObjectPath(
        'shared_rooms/owner_123/ABC234/season',
      );
      expect(location.ownerUid, 'owner_123');
      expect(location.roomCode, 'ABC234');
      expect(location.slot, SharedRoomMediaSlot.season);

      for (final path in [
        'shared_rooms/owner_123/abc234/season',
        'shared_rooms/owner_123/ABC234/gallery',
        'shared_rooms/owner_123/ABC234/profile/extra',
        'other/owner_123/ABC234/profile',
      ]) {
        expect(
          () => SharedRoomMediaLocation.fromObjectPath(path),
          throwsA(_failure(SharedRoomMediaFailure.invalidObjectPath)),
        );
      }
    });
  });

  group('shared room media sync', () {
    test(
      'uploads both deterministic slots with explicit safe metadata',
      () async {
        final writes = <SharedRoomMediaUploadRequest>[];
        final service = _service(
          readLocal: (filename) async => journal_media.JournalMediaUploadData(
            filename: filename,
            bytes: filename.endsWith('.png') ? _png() : _jpeg(),
          ),
          upload: (request) async => writes.add(request),
        );

        final paths = await service.syncSelected(
          ownerUid: 'owner_123',
          roomCode: 'abc234',
          selectedLocalFilenames: const {
            SharedRoomMediaSlot.profile: 'profile.jpg',
            SharedRoomMediaSlot.season: 'season.png',
          },
        );

        expect(paths, {
          SharedRoomMediaSlot.profile: 'shared_rooms/owner_123/ABC234/profile',
          SharedRoomMediaSlot.season: 'shared_rooms/owner_123/ABC234/season',
        });
        expect(writes.map((write) => write.slot), SharedRoomMediaSlot.values);
        expect(writes.map((write) => write.contentType), [
          'image/jpeg',
          'image/png',
        ]);
        for (final write in writes) {
          expect(write.cacheControl, sharedRoomPhotoCacheControl);
          expect(write.customMetadata, {
            'ownerUid': 'owner_123',
            'roomCode': 'ABC234',
            'slot': write.slot.wireName,
          });
          expect(write.objectPath, paths[write.slot]);
        }
        expect(paths.values, everyElement(startsWith('shared_rooms/')));
        expect(paths.values, everyElement(isNot(startsWith('http'))));
      },
    );

    test('accepts exactly 3 MB and rejects anything larger', () async {
      var uploads = 0;
      final accepted = _service(
        readLocal: (filename) async => journal_media.JournalMediaUploadData(
          filename: 'photo.jpeg',
          bytes: _jpeg(maxSharedRoomPhotoBytes),
        ),
        upload: (request) async => uploads++,
      );
      await accepted.syncSelected(
        ownerUid: 'owner',
        roomCode: 'ABC234',
        selectedLocalFilenames: const {
          SharedRoomMediaSlot.profile: 'photo.jpeg',
        },
      );
      expect(uploads, 1);

      final rejected = _service(
        readLocal: (filename) async => journal_media.JournalMediaUploadData(
          filename: 'photo.jpeg',
          bytes: _jpeg(maxSharedRoomPhotoBytes + 1),
        ),
        upload: (request) async => uploads++,
      );
      await expectLater(
        rejected.syncSelected(
          ownerUid: 'owner',
          roomCode: 'ABC234',
          selectedLocalFilenames: const {
            SharedRoomMediaSlot.profile: 'photo.jpeg',
          },
        ),
        throwsA(_failure(SharedRoomMediaFailure.fileTooLarge)),
      );
      expect(uploads, 1);
    });

    test('preflights every local file before beginning uploads', () async {
      final writes = <SharedRoomMediaUploadRequest>[];
      final service = _service(
        readLocal: (filename) async => journal_media.JournalMediaUploadData(
          filename: filename,
          bytes: filename.endsWith('.gif')
              ? Uint8List.fromList(const [0x47, 0x49, 0x46])
              : _jpeg(),
        ),
        upload: (request) async => writes.add(request),
      );

      await expectLater(
        service.syncSelected(
          ownerUid: 'owner',
          roomCode: 'ABC234',
          selectedLocalFilenames: const {
            SharedRoomMediaSlot.profile: 'valid.jpg',
            SharedRoomMediaSlot.season: 'unsupported.gif',
          },
        ),
        throwsA(_failure(SharedRoomMediaFailure.unsupportedFileType)),
      );
      expect(writes, isEmpty);
    });

    test(
      'rejects empty, missing, and extension-mismatched files clearly',
      () async {
        Future<void> expectReadFailure(
          SharedRoomMediaLocalReader reader,
          SharedRoomMediaFailure failure,
        ) async {
          final service = _service(readLocal: reader);
          await expectLater(
            service.syncSelected(
              ownerUid: 'owner',
              roomCode: 'ABC234',
              selectedLocalFilenames: const {
                SharedRoomMediaSlot.profile: 'photo.jpg',
              },
            ),
            throwsA(_failure(failure)),
          );
        }

        await expectReadFailure(
          (filename) async => journal_media.JournalMediaUploadData(
            filename: filename,
            bytes: Uint8List(0),
          ),
          SharedRoomMediaFailure.emptyFile,
        );
        await expectReadFailure(
          (filename) async =>
              throw const journal_media.JournalMediaReadException(
                journal_media.JournalMediaReadFailure.missing,
                'The selected photo is no longer on this device.',
              ),
          SharedRoomMediaFailure.localFileUnavailable,
        );
        await expectReadFailure(
          (filename) async => journal_media.JournalMediaUploadData(
            filename: filename,
            bytes: _png(),
          ),
          SharedRoomMediaFailure.unsupportedFileType,
        );
      },
    );
  });

  group('delete and visitor resolution', () {
    test('deduplicates slots and treats object-not-found as success', () async {
      final deletes = <String>[];
      final service = _service(
        deleteObject: (path) async {
          deletes.add(path);
          if (path.endsWith('/profile')) {
            throw FirebaseException(
              plugin: 'firebase_storage',
              code: 'object-not-found',
            );
          }
        },
      );

      await service.deleteSlots(
        ownerUid: 'owner',
        roomCode: 'ABC234',
        slots: const [
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.season,
        ],
      );
      expect(deletes, [
        'shared_rooms/owner/ABC234/profile',
        'shared_rooms/owner/ABC234/season',
      ]);
    });

    test('validates an object path before asking Storage for a URL', () async {
      var calls = 0;
      final service = _service(
        resolveUrl: (path) async {
          calls++;
          return 'https://example.test/photo';
        },
      );

      await expectLater(
        service.downloadUrl('shared_rooms/owner/abc234/profile'),
        throwsA(_failure(SharedRoomMediaFailure.invalidObjectPath)),
      );
      expect(calls, 0);
      expect(
        await service.downloadUrl('shared_rooms/owner/ABC234/profile'),
        'https://example.test/photo',
      );
      expect(calls, 1);
    });

    testWidgets('visitor renderer fails into a warm accessible placeholder', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorSharedRoomPhoto(
              objectPath: 'shared_rooms/owner/ABC234/profile',
              semanticLabel: 'Mika progress photo',
              urlLoader: (path) async => throw StateError('offline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Mika progress photo')),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  test('Storage wiring and rules keep discovery closed', () {
    final firebase =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(firebase['storage'], {'rules': 'storage.rules'});

    final rules = File('storage.rules').readAsStringSync();
    expect(rules, contains('match /shared_rooms/{ownerUid}/{roomCode}/{slot}'));
    expect(rules, contains('allow get:'));
    expect(rules, contains('allow list: if false;'));
    expect(rules, contains('request.auth.uid == ownerUid'));
    expect(rules, contains('request.resource.size <= 3 * 1024 * 1024'));
    expect(
      rules,
      contains(
        "request.resource.contentType.matches('^image/(jpeg|png|webp)\$')",
      ),
    );
    expect(rules, contains('match /{allPaths=**}'));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('firebase_storage: ^13.4.5'));
    final service = File('lib/shared_room_media.dart').readAsStringSync();
    expect(service, isNot(contains("import 'engine.dart'")));
    expect(service, isNot(contains("import 'storage.dart'")));
  });

  test('journal media facade exposes the transient upload reader', () {
    final Future<journal_media.JournalMediaUploadData> Function(String) reader =
        journal_media.readForUpload;
    expect(reader, isNotNull);
  });

  // Which slots are "selected" is the whole privacy contract for shared photos:
  // publishSpaceRoomState deletes every previously-published slot that is no
  // longer selected, so anything that fails to drop out here leaves a photo
  // publicly fetchable at its bearer path after the owner revoked it.
  // The publish path itself cannot be exercised from a test — CloudSync's only
  // constructor is library-private, so its `cloudSync:` parameter is not
  // actually injectable — which is exactly why this contract is pinned here.
  group('revoking a shared photo drops it from the published selection', () {
    GameState withBothPhotos() {
      final profile = Note(
        at: DateTime(2026, 7, 20),
        text: 'profile',
        images: const ['profile.jpg'],
      );
      final season = Note(
        at: DateTime(2026, 7, 21),
        text: 'season',
        images: const ['season.jpg'],
      );
      final s = GameState()
        ..journal = [profile, season]
        ..shareSpaceProfile = true
        ..spaceProfilePhotoNoteId = profile.id
        ..spaceSeasonPhotoNoteId = season.id
        ..shareSpaceProfilePhoto = true
        ..shareSpaceSeasonPhoto = true;
      s.visitorSpaceCards.add(SpaceCardKind.thisSeason);
      return s;
    }

    test('both photos publish while every consent bit is on', () {
      expect(
        selectedSharedRoomPhotoFiles(withBothPhotos()).keys,
        containsAll(<SharedRoomMediaSlot>[
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.season,
        ]),
      );
    });

    test('turning off one photo consent drops only that slot', () {
      final s = withBothPhotos()..shareSpaceProfilePhoto = false;
      final selected = selectedSharedRoomPhotoFiles(s);
      expect(selected, isNot(contains(SharedRoomMediaSlot.profile)));
      expect(selected, contains(SharedRoomMediaSlot.season));
    });

    test('closing the visitor page drops every photo', () {
      final s = withBothPhotos()..shareSpaceProfile = false;
      expect(selectedSharedRoomPhotoFiles(s), isEmpty);
    });

    test('hiding This season from visitors drops its photo', () {
      final s = withBothPhotos()
        ..visitorSpaceCards.remove(SpaceCardKind.thisSeason);
      final selected = selectedSharedRoomPhotoFiles(s);
      expect(selected, isNot(contains(SharedRoomMediaSlot.season)));
      expect(selected, contains(SharedRoomMediaSlot.profile));
    });

    test('deselecting the source note drops its photo', () {
      final s = withBothPhotos()..spaceSeasonPhotoNoteId = null;
      expect(
        selectedSharedRoomPhotoFiles(s),
        isNot(contains(SharedRoomMediaSlot.season)),
      );
    });
  });
}
