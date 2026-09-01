import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/discovery.dart';
import 'package:emberkeep/journal_media.dart' as journal_media;
import 'package:emberkeep/engine.dart';
import 'package:emberkeep/models.dart';
import 'package:emberkeep/room_photo.dart';
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

const _revision = 'ABCDEFGHIJKLMNOPQRSTUV';
const _opaqueOwnerKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

SharedRoomMediaService _service({
  SharedRoomMediaLocalReader? readLocal,
  SharedRoomMediaUploadWriter? upload,
  SharedRoomMediaObjectDeleter? deleteObject,
  SharedRoomMediaUrlResolver? resolveUrl,
  SharedRoomMediaDataReader? downloadData,
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
  downloadData: downloadData,
);

Matcher _failure(SharedRoomMediaFailure failure) =>
    isA<SharedRoomMediaException>().having(
      (error) => error.failure,
      'failure',
      failure,
    );

void main() {
  group('shared room media paths', () {
    test(
      'keeps legacy profile and season paths distinct from room objects',
      () {
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
            generation: _revision,
          ),
          'shared_rooms/owner_123/ABC234/season/$_revision',
        );
        expect(
          sharedRoomMediaObjectPath(
            ownerUid: _opaqueOwnerKey,
            roomCode: 'ABC234',
            slot: 'room',
            generation: _revision,
          ),
          'shared_rooms/$_opaqueOwnerKey/ABC234/room/$_revision',
        );
      },
    );

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
        'shared_rooms/owner_123/ABC234/season/$_revision',
      );
      expect(location.ownerUid, 'owner_123');
      expect(location.roomCode, 'ABC234');
      expect(location.slot, SharedRoomMediaSlot.season);
      expect(location.generation, _revision);

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
      'uploads both immutable revisions with explicit safe metadata',
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

        expect(paths.keys, const [
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.season,
        ]);
        expect(writes.map((write) => write.slot), const [
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.season,
        ]);
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
            'generation': write.objectPath.split('/').last,
          });
          expect(write.objectPath, paths[write.slot]);
          final location = SharedRoomMediaLocation.fromObjectPath(
            write.objectPath,
          );
          expect(
            location.generation,
            hasLength(sharedRoomMediaGenerationLength),
          );
        }
        expect(paths.values, everyElement(startsWith('shared_rooms/')));
        expect(paths.values, everyElement(isNot(startsWith('http'))));
      },
    );

    test('cleans every new revision when a later upload fails', () async {
      final writes = <String>[];
      final deletes = <String>[];
      final service = _service(
        readLocal: (filename) async => journal_media.JournalMediaUploadData(
          filename: filename,
          bytes: _jpeg(),
        ),
        upload: (request) async {
          writes.add(request.objectPath);
          if (request.slot == SharedRoomMediaSlot.season) {
            throw StateError('connection dropped after write');
          }
        },
        deleteObject: (path) async => deletes.add(path),
      );

      await expectLater(
        service.syncSelected(
          ownerUid: 'owner',
          roomCode: 'ABC234',
          selectedLocalFilenames: const {
            SharedRoomMediaSlot.profile: 'profile.jpg',
            SharedRoomMediaSlot.season: 'season.jpg',
          },
        ),
        throwsA(_failure(SharedRoomMediaFailure.uploadFailed)),
      );
      expect(writes, hasLength(2));
      expect(deletes.toSet(), writes.toSet());
    });

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

  group('shared fireplace photo', () {
    RoomPhotoData photo() => RoomPhotoData(
      bytes: _png(),
      fillFrame: true,
      alignment: const Alignment(.25, -.2),
      pixelWidth: 640,
      pixelHeight: 480,
    );

    GameState roomState({bool share = true, String path = ''}) => GameState()
      ..roomCode = 'ABC234'
      ..shareRoomPhoto = share
      ..spaceRoomPhotoPath = path;

    RoomPublicationClient publication({
      required List<Map<String, dynamic>> displays,
      required List<String> events,
      required RoomPublishResult Function(int call, String? requestedCode)
      publishResult,
      Map<String, dynamic>? liveRoom,
    }) {
      var calls = 0;
      return RoomPublicationClient(
        ensureAvailable: () async => true,
        ensureSocialSession: () async => true,
        ownerUid: () => 'firebase-owner-uid',
        fetchRoom: (_) async => liveRoom,
        publishRoom: (display, {code}) async {
          displays.add(Map<String, dynamic>.from(display));
          events.add('publish:${displays.length}');
          return publishResult(++calls, code);
        },
        unshareRoom: (code) async {
          events.add('unshare:$code');
          return true;
        },
      );
    }

    test('uploads a bounded PNG to an opaque room revision', () async {
      final writes = <SharedRoomMediaUploadRequest>[];
      final bytes = Uint8List(800 * 1024)..setRange(0, 8, _png());
      final path =
          await _service(
            upload: (request) async => writes.add(request),
          ).uploadRoomPhoto(
            ownerKey: _opaqueOwnerKey,
            roomCode: 'abc234',
            bytes: bytes,
          );

      final write = writes.single;
      final location = SharedRoomMediaLocation.fromObjectPath(path);
      expect(location.ownerKey, _opaqueOwnerKey);
      expect(location.roomCode, 'ABC234');
      expect(location.slot, SharedRoomMediaSlot.room);
      expect(location.generation, hasLength(sharedRoomMediaGenerationLength));
      expect(write.bytes, same(bytes));
      expect(write.contentType, 'image/png');
      expect(write.customMetadata, {
        'ownerKey': _opaqueOwnerKey,
        'roomCode': 'ABC234',
        'slot': 'room',
        'generation': location.generation,
      });
    });

    test('room download accepts only a bounded, valid transient PNG', () async {
      final path = sharedRoomMediaObjectPath(
        ownerUid: _opaqueOwnerKey,
        roomCode: 'ABC234',
        slot: 'room',
        generation: _revision,
      );
      var requestedMax = 0;
      final service = _service(
        downloadData: (objectPath, maxBytes) async {
          expect(objectPath, path);
          requestedMax = maxBytes;
          return _png();
        },
      );

      final bytes = await service.downloadData(path, maxBytes: 800 * 1024);
      expect(requestedMax, 800 * 1024);
      expect(bytes, orderedEquals(_png()));
      expect(() => bytes[0] = 0, throwsUnsupportedError);

      await expectLater(
        service.downloadData(path, maxBytes: 800 * 1024 + 1),
        throwsA(_failure(SharedRoomMediaFailure.downloadUrlFailed)),
      );
    });

    test(
      'opt-in reserves the room, uploads, then publishes the pointer',
      () async {
        final target = roomState();
        final current = roomState(share: false);
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];
        final uploads = <SharedRoomMediaUploadRequest>[];
        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          roomPhoto: photo(),
          syncRoomPhoto: true,
          mediaService: _service(
            upload: (request) async {
              uploads.add(request);
              events.add('upload');
            },
          ),
          publicationClient: publication(
            displays: displays,
            events: events,
            publishResult: (_, code) => RoomPublishResult.success(code!),
          ),
        );

        expect(result.ok, isTrue);
        expect(events, ['publish:1', 'upload', 'publish:2']);
        expect(displays.first['roomPhotoPath'], isEmpty);
        expect(displays.last['roomPhotoPath'], uploads.single.objectPath);
        expect(displays.last['roomPhotoFill'], isTrue);
        expect(displays.last['roomPhotoX'], .25);
        expect(displays.last['roomPhotoY'], -.2);
        expect(displays.last['roomPhotoWidth'], 640);
        expect(displays.last['roomPhotoHeight'], 480);
        expect(target.spaceRoomPhotoPath, uploads.single.objectPath);
        expect(target.shareRoomPhoto, isTrue);
        // The only bytes involved are the explicit transient argument above;
        // GameState persists a pointer and presentation metadata, never pixels.
        expect(target.toJson().containsKey('roomPhoto'), isFalse);
        expect(target.toJson().containsKey('roomPhotoBytes'), isFalse);
      },
    );

    test(
      'opt-out publishes an empty pointer before deleting the old revision',
      () async {
        final prior = sharedRoomMediaObjectPath(
          ownerUid: discoveryOwnerKey('firebase-owner-uid'),
          roomCode: 'ABC234',
          slot: SharedRoomMediaSlot.room.wireName,
          generation: _revision,
        );
        final current = roomState(path: prior);
        final target = GameState.fromJson(current.toJson())
          ..setRoomPhotoSharing(false);
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];
        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: _service(
            deleteObject: (path) async => events.add('delete:$path'),
          ),
          publicationClient: publication(
            displays: displays,
            events: events,
            publishResult: (_, code) => RoomPublishResult.success(code!),
          ),
        );

        expect(result.ok, isTrue);
        expect(displays.single['roomPhotoPath'], isEmpty);
        expect(events, ['publish:1', 'delete:$prior']);
        expect(target.shareRoomPhoto, isFalse);
        expect(target.spaceRoomPhotoPath, isEmpty);
      },
    );

    test(
      'a removed live pointer cannot be resurrected by stale state',
      () async {
        final prior = sharedRoomMediaObjectPath(
          ownerUid: discoveryOwnerKey('firebase-owner-uid'),
          roomCode: 'ABC234',
          slot: SharedRoomMediaSlot.room.wireName,
          generation: _revision,
        );
        final current = roomState(path: prior);
        final target = GameState.fromJson(current.toJson());
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: _service(),
          publicationClient: publication(
            displays: displays,
            events: events,
            publishResult: (_, code) => RoomPublishResult.success(code!),
          ),
        );

        expect(result.ok, isTrue);
        expect(displays.single['roomPhotoPath'], isEmpty);
        expect(target.shareRoomPhoto, isFalse);
        expect(target.spaceRoomPhotoPath, isEmpty);
      },
    );

    test(
      'background refresh adopts the live acknowledged projection',
      () async {
        final oldPath = sharedRoomMediaObjectPath(
          ownerUid: discoveryOwnerKey('firebase-owner-uid'),
          roomCode: 'ABC234',
          slot: SharedRoomMediaSlot.room.wireName,
          generation: _revision,
        );
        final newPath = sharedRoomMediaObjectPath(
          ownerUid: discoveryOwnerKey('firebase-owner-uid'),
          roomCode: 'ABC234',
          slot: SharedRoomMediaSlot.room.wireName,
          generation: 'abcdefghijklmnopqrstuv',
        );
        final current = roomState(path: oldPath);
        final target = GameState.fromJson(current.toJson());
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: _service(),
          publicationClient: publication(
            displays: displays,
            events: events,
            liveRoom: {
              'v': 8,
              'ownerKey': discoveryOwnerKey('firebase-owner-uid'),
              'roomPhotoPath': newPath,
              'roomPhotoFill': true,
              'roomPhotoX': -.4,
              'roomPhotoY': .6,
              'roomPhotoWidth': 720,
              'roomPhotoHeight': 540,
            },
            publishResult: (_, code) => RoomPublishResult.success(code!),
          ),
        );

        expect(result.ok, isTrue);
        expect(displays.single['roomPhotoPath'], newPath);
        expect(target.shareRoomPhoto, isTrue);
        expect(target.spaceRoomPhotoPath, newPath);
        expect(target.spaceRoomPhotoFill, isTrue);
        expect(target.spaceRoomPhotoX, -.4);
        expect(target.spaceRoomPhotoY, .6);
      },
    );

    test(
      'upload failure removes its revision and abandons a fresh reservation',
      () async {
        final target = roomState();
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];
        final result = await publishSpaceRoomState(
          target,
          current: roomState(share: false),
          code: 'ABC234',
          roomPhoto: photo(),
          syncRoomPhoto: true,
          mediaService: _service(
            upload: (request) async {
              events.add('upload');
              throw StateError('offline');
            },
            deleteObject: (path) async => events.add('delete:$path'),
          ),
          publicationClient: publication(
            displays: displays,
            events: events,
            publishResult: (_, _) => const RoomPublishResult.success('NEW234'),
          ),
        );

        expect(result.failure, RoomPublishFailure.media);
        expect(events.first, 'publish:1');
        expect(events, contains('upload'));
        expect(
          events.where((event) => event.startsWith('delete:')),
          hasLength(1),
        );
        expect(events, contains('unshare:NEW234'));
        expect(target.spaceRoomPhotoPath, isEmpty);
      },
    );

    test(
      'final publication failure removes the uploaded revision and reservation',
      () async {
        final target = roomState();
        final displays = <Map<String, dynamic>>[];
        final events = <String>[];
        final result = await publishSpaceRoomState(
          target,
          current: roomState(share: false),
          code: 'ABC234',
          roomPhoto: photo(),
          syncRoomPhoto: true,
          mediaService: _service(
            upload: (request) async => events.add('upload'),
            deleteObject: (path) async => events.add('delete:$path'),
          ),
          publicationClient: publication(
            displays: displays,
            events: events,
            publishResult: (call, _) => call == 1
                ? const RoomPublishResult.success('NEW234')
                : const RoomPublishResult.failed(RoomPublishFailure.network),
          ),
        );

        expect(result.failure, RoomPublishFailure.network);
        expect(events, [
          'publish:1',
          'upload',
          'publish:2',
          startsWith('delete:'),
          'unshare:NEW234',
        ]);
        expect(target.spaceRoomPhotoPath, isEmpty);
      },
    );
  });

  group('acknowledged visitor-photo replacement', () {
    (GameState, GameState) states() {
      final oldPhoto = Note(
        at: DateTime(2026, 8, 1),
        text: 'old',
        images: const ['old.jpg'],
      );
      final newPhoto = Note(
        at: DateTime(2026, 8, 2),
        text: 'new',
        images: const ['new.jpg'],
      );
      final current = GameState()
        ..roomCode = 'ABC234'
        ..journal = [oldPhoto, newPhoto]
        ..shareSpaceProfile = true
        ..shareSpaceProfilePhoto = true
        ..spaceProfilePhotoNoteId = oldPhoto.id
        ..spaceProfilePhotoPath =
            'shared_rooms/owner/ABC234/profile/$_revision';
      final target = GameState.fromJson(current.toJson())
        ..spaceProfilePhotoNoteId = newPhoto.id;
      return (current, target);
    }

    RoomPublicationClient client({
      required List<Map<String, dynamic>> publishes,
      required bool failFinal,
    }) {
      var calls = 0;
      return RoomPublicationClient(
        ensureAvailable: () async => true,
        ensureSocialSession: () async => true,
        ownerUid: () => 'owner',
        fetchRoom: (code) async => {
          'uid': 'owner',
          'profilePhotoPath': 'shared_rooms/owner/ABC234/profile/$_revision',
          'seasonPhotoPath': '',
        },
        publishRoom: (display, {code}) async {
          publishes.add(Map<String, dynamic>.from(display));
          calls++;
          if (failFinal && calls == 2) {
            return const RoomPublishResult.failed(RoomPublishFailure.network);
          }
          return RoomPublishResult.success(code ?? 'ABC234');
        },
        unshareRoom: (code) async => true,
      );
    }

    test(
      'v1 publication clears photo intent without touching Storage',
      () async {
        final (current, target) = states();
        target
          ..playerName = 'PRIVATE-NAME-SENTINEL'
          ..spaceIntro = 'PRIVATE-INTRO-SENTINEL'
          ..spaceSeasonText = 'PRIVATE-SEASON-SENTINEL'
          ..shareSpaceSeasonPhoto = true
          ..spaceSeasonPhotoPath =
              'shared_rooms/owner/ABC234/season/$_revision';
        target.featuredGoalTitles.add('PRIVATE-GOAL-SENTINEL');
        target.visitorSpaceCards.addAll(SpaceCardKind.values);
        target.memoryPins.add(target.journal.last.id);
        final publishes = <Map<String, dynamic>>[];
        var mediaCalls = 0;
        final service = _service(
          readLocal: (_) async {
            mediaCalls++;
            throw StateError('Storage must stay dormant');
          },
          upload: (_) async {
            mediaCalls++;
          },
          deleteObject: (_) async {
            mediaCalls++;
          },
        );

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: service,
          publicationClient: client(publishes: publishes, failFinal: false),
          visitorProfileSharingEnabled: false,
        );

        expect(result.ok, isTrue);
        expect(mediaCalls, 0);
        expect(publishes, hasLength(1));
        expect(publishes.single['profileVisible'], isFalse);
        expect(publishes.single['displayName'], isEmpty);
        expect(publishes.single['about'], isEmpty);
        expect(publishes.single['featuredGoals'], isEmpty);
        expect(publishes.single['cardOrder'], isEmpty);
        expect(publishes.single['pinnedMoments'], isEmpty);
        expect(publishes.single['season'], isEmpty);
        expect(publishes.single['profilePhotoPath'], isEmpty);
        expect(publishes.single['seasonPhotoPath'], isEmpty);
        expect(target.shareSpaceProfile, isFalse);
        expect(target.visitorSpaceCards, isEmpty);
        expect(target.shareSpaceProfilePhoto, isFalse);
        expect(target.shareSpaceSeasonPhoto, isFalse);
        expect(target.spaceProfilePhotoPath, isEmpty);
        expect(target.spaceSeasonPhotoPath, isEmpty);
        expect(target.playerName, 'PRIVATE-NAME-SENTINEL');
        expect(target.spaceIntro, 'PRIVATE-INTRO-SENTINEL');
        expect(target.spaceSeasonText, 'PRIVATE-SEASON-SENTINEL');
        expect(target.featuredGoalTitles, ['PRIVATE-GOAL-SENTINEL']);
      },
    );

    test(
      'an enabled pre-release photo flag still never starts a Storage upload',
      () async {
        final (current, target) = states();
        final publishes = <Map<String, dynamic>>[];
        final uploaded = <String>[];
        final deleted = <String>[];
        final service = _service(
          upload: (request) async => uploaded.add(request.objectPath),
          deleteObject: (path) async => deleted.add(path),
        );

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: service,
          publicationClient: client(publishes: publishes, failFinal: true),
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        );

        expect(result.ok, isTrue);
        expect(uploaded, isEmpty);
        expect(deleted, isEmpty);
        expect(publishes, hasLength(1));
        expect(publishes.single['profilePhotoPath'], isEmpty);
        expect(publishes.single['seasonPhotoPath'], isEmpty);
        expect(target.shareSpaceProfile, isTrue);
        expect(target.shareSpaceProfilePhoto, isFalse);
        expect(target.spaceProfilePhotoPath, isEmpty);
      },
    );

    test(
      'dormant photo publication clears stale handles only after acknowledgement',
      () async {
        final (current, target) = states();
        final publishes = <Map<String, dynamic>>[];
        final uploaded = <String>[];
        final deleted = <String>[];
        final service = _service(
          upload: (request) async => uploaded.add(request.objectPath),
          deleteObject: (path) async => deleted.add(path),
        );

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: service,
          publicationClient: client(publishes: publishes, failFinal: false),
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        );

        expect(result.ok, isTrue);
        expect(uploaded, isEmpty);
        expect(deleted, isEmpty);
        expect(publishes, hasLength(1));
        expect(target.spaceProfilePhotoPath, isEmpty);
        expect(target.shareSpaceProfilePhoto, isFalse);
        expect(publishes.single['profilePhotoPath'], isEmpty);
      },
    );

    test(
      'a failed room publish preserves stale photo intent for retry',
      () async {
        final (current, target) = states();
        var mediaCalls = 0;
        final service = _service(
          upload: (_) async => mediaCalls++,
          deleteObject: (_) async => mediaCalls++,
        );
        final publication = RoomPublicationClient(
          ensureAvailable: () async => true,
          ensureSocialSession: () async => true,
          ownerUid: () => 'owner',
          fetchRoom: (_) async => null,
          publishRoom: (_, {code}) async =>
              const RoomPublishResult.failed(RoomPublishFailure.network),
          unshareRoom: (_) async => true,
        );

        final result = await publishSpaceRoomState(
          target,
          current: current,
          code: 'ABC234',
          mediaService: service,
          publicationClient: publication,
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        );

        expect(result.ok, isFalse);
        expect(mediaCalls, 0);
        expect(target.shareSpaceProfilePhoto, isTrue);
        expect(
          target.spaceProfilePhotoPath,
          'shared_rooms/owner/ABC234/profile/$_revision',
        );
      },
    );

    test('clearing the room code also clears persisted public handles', () {
      final state = GameState()
        ..roomCode = 'ABC234'
        ..spaceProfilePhotoPath = 'shared_rooms/owner/ABC234/profile/$_revision'
        ..spaceSeasonPhotoPath = 'shared_rooms/owner/ABC234/season/$_revision';

      state.setRoomCode(null);

      expect(state.spaceProfilePhotoPath, isEmpty);
      expect(state.spaceSeasonPhotoPath, isEmpty);
    });
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
        await service.downloadUrl(
          'shared_rooms/owner/ABC234/profile/$_revision',
        ),
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
              objectPath: 'shared_rooms/owner/ABC234/profile/$_revision',
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
    expect(
      rules,
      contains('match /shared_rooms/{ownerUid}/{roomCode}/{slot}/{generation}'),
    );
    expect(
      rules,
      contains('match /shared_rooms/{ownerKey}/{roomCode}/{slot}/{generation}'),
    );
    expect(rules, contains("return slot == 'room';"));
    expect(
      rules,
      contains(
        r'firestore.get(/databases/(default)/documents/roomOwners/$(roomCode)).data.ownerKey == ownerKey',
      ),
    );
    expect(rules, contains('allow get:'));
    expect(rules, contains('allow list: if false;'));
    expect(rules, contains('request.auth.uid == ownerUid'));
    expect(
      rules,
      contains(
        r'!firestore.exists(/databases/(default)/documents/'
        r'serviceIdentityDeletionTombstones/$(ownerUid))',
      ),
    );
    expect(rules, contains('request.resource.size <= 3 * 1024 * 1024'));
    expect(
      rules,
      contains(
        "request.resource.contentType.matches('^image/(jpeg|png|webp)\$')",
      ),
    );
    expect(rules, contains('request.resource.size <= 800 * 1024'));
    expect(rules, contains("request.resource.contentType == 'image/png'"));
    expect(rules, contains('livePublicRoomReferencesPhoto'));
    expect(rules, contains('data.roomPhotoPath'));
    expect(rules, contains("'shared_rooms/' + ownerKey"));
    expect(rules, contains('match /{allPaths=**}'));

    final functions = File('functions/src/index.ts').readAsStringSync();
    expect(functions, contains('{document: "rooms/{code}", retry: true}'));
    expect(functions, contains('code === 404'));

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
        selectedSharedRoomPhotoFiles(
          withBothPhotos(),
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        ).keys,
        containsAll(<SharedRoomMediaSlot>[
          SharedRoomMediaSlot.profile,
          SharedRoomMediaSlot.season,
        ]),
      );
    });

    test('turning off one photo consent drops only that slot', () {
      final s = withBothPhotos()..shareSpaceProfilePhoto = false;
      final selected = selectedSharedRoomPhotoFiles(
        s,
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      );
      expect(selected, isNot(contains(SharedRoomMediaSlot.profile)));
      expect(selected, contains(SharedRoomMediaSlot.season));
    });

    test('closing the visitor page drops every photo', () {
      final s = withBothPhotos()..shareSpaceProfile = false;
      expect(
        selectedSharedRoomPhotoFiles(
          s,
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        ),
        isEmpty,
      );
    });

    test('hiding This season from visitors drops its photo', () {
      final s = withBothPhotos()
        ..visitorSpaceCards.remove(SpaceCardKind.thisSeason);
      final selected = selectedSharedRoomPhotoFiles(
        s,
        visitorPhotoSharingEnabled: true,
        visitorProfileSharingEnabled: true,
      );
      expect(selected, isNot(contains(SharedRoomMediaSlot.season)));
      expect(selected, contains(SharedRoomMediaSlot.profile));
    });

    test('deselecting the source note drops its photo', () {
      final s = withBothPhotos()..spaceSeasonPhotoNoteId = null;
      expect(
        selectedSharedRoomPhotoFiles(
          s,
          visitorPhotoSharingEnabled: true,
          visitorProfileSharingEnabled: true,
        ),
        isNot(contains(SharedRoomMediaSlot.season)),
      );
    });
  });
}
