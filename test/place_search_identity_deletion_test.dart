import 'dart:async';
import 'dart:io';

import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/daybook/data/daybook_preferences.dart';
import 'package:emberkeep/daybook/services/place_search_identity_removal.dart';
import 'package:emberkeep/daybook/services/directions_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

final class _DeletionDelegate
    implements AnonymousServiceIdentityDeletionDelegate {
  _DeletionDelegate({
    this.identityKind = ServiceIdentityKind.anonymous,
    this.backupEnabled = false,
    this.roomsDeleted = true,
  });

  @override
  ServiceIdentityKind identityKind;

  @override
  bool backupEnabled;

  bool roomsDeleted;
  bool prepareResult = true;
  Object? authFailure;
  Future<void>? authFuture;
  final operations = <String>[];

  @override
  Future<bool> preparePendingRoomCleanup({String? roomCode}) async {
    operations.add('prepare:${roomCode ?? '-'}');
    return prepareResult;
  }

  @override
  void cancelPendingWork() => operations.add('cancel');

  @override
  void releasePendingWorkFence() => operations.add('release');

  @override
  Future<bool> deletePreparedRooms() async {
    operations.add('rooms');
    return roomsDeleted;
  }

  @override
  Future<void> deleteSaveDocument() async => operations.add('save');

  @override
  Future<void> deleteAuthIdentity() async {
    operations.add('auth');
    final pending = authFuture;
    if (pending != null) await pending;
    final failure = authFailure;
    if (failure != null) throw failure;
  }

  @override
  void clearCachedIdentity() {
    operations.add('clear');
    identityKind = ServiceIdentityKind.none;
  }
}

final class _Preferences implements PlaceSearchPreferences {
  _Preferences();

  PlaceSearchConsent? consent = PlaceSearchConsent.acceptedV1;
  String? installId = 'stable-install-id';
  MapProvider? mapProvider = MapProvider.google;
  String daybookSentinel = 'Tuesday lecture in SEC 111';
  bool allowConsentWrite = true;
  bool throwOnConsentWrite = false;
  int consentWrites = 0;

  @override
  Future<PlaceSearchConsent?> loadPlaceSearchConsent() async => consent;

  @override
  Future<bool> savePlaceSearchConsent(PlaceSearchConsent? value) async {
    consentWrites++;
    if (throwOnConsentWrite) throw StateError('preferences unavailable');
    if (!allowConsentWrite) return false;
    consent = value;
    return true;
  }

  @override
  Future<String?> loadPlaceSearchInstallId() async => installId;

  @override
  Future<bool> savePlaceSearchInstallId(String value) async {
    installId = value;
    return true;
  }
}

final class _RemoteDeletion implements AnonymousServiceIdentityDeletion {
  final outcomes = <String?>[];
  int deletions = 0;
  int replacementSignIns = 0;

  @override
  Future<String?> deleteAnonymousServiceIdentity({String? roomCode}) async {
    deletions++;
    return outcomes.isEmpty ? null : outcomes.removeAt(0);
  }
}

void main() {
  group('anonymous service identity deletion', () {
    test('CloudSync wires service deletion through the Auth mutation lock', () {
      final cloud = File('lib/cloud.dart').readAsStringSync();
      final start = cloud.indexOf(
        'Future<String?> deleteAnonymousServiceIdentity',
      );
      final end = cloud.indexOf('static String _friendlyAuth', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final deletion = cloud.substring(start, end);

      expect(deletion, contains('_anonymousIdentityDeletion.run'));
      expect(deletion, contains('start: () => _runAuthChange'));
      expect(deletion, isNot(contains('signInAnonymously')));
      expect(cloud, contains('_savePushQueue.holdWrites()'));
      expect(cloud, contains('_roomPublishQueue.holdWrites()'));
      expect(cloud, contains('_savePushQueue.run(() => _cloud._doc.delete())'));
      expect(
        cloud,
        matches(
          RegExp(
            r'_roomPublishQueue\.run\(\s*\(\) => _cloud\._retryPendingRoomCleanup',
          ),
        ),
      );
      expect(cloud, contains('Future<bool> _rememberPendingRoomCleanup'));
      expect(
        cloud,
        contains(
          'return _cloud._rememberPendingRoomCleanup(preferences, clean)',
        ),
      );
    });

    test(
      'write fences drain active work and block stale queued writes',
      () async {
        for (final surface in ['save', 'room']) {
          final queue = RoomPublishQueue();
          final started = Completer<void>();
          final gate = Completer<void>();
          final operations = <String>[];

          final activeWrite = queue.runWrite(() async {
            operations.add('$surface-write-start');
            started.complete();
            await gate.future;
            operations.add('$surface-write-finish');
            return true;
          });
          await started.future;
          queue.holdWrites();
          final deletion = queue.run(() async {
            operations.add('$surface-delete');
            return true;
          });
          final staleWrite = queue.runWrite(() async {
            operations.add('$surface-stale-write');
            return true;
          });

          gate.complete();
          expect(await activeWrite, isTrue);
          expect(await deletion, isTrue);
          expect(await staleWrite, isNull);
          expect(operations, [
            '$surface-write-start',
            '$surface-write-finish',
            '$surface-delete',
          ]);

          queue.releaseWrites();
          expect(await queue.runWrite(() async => true), isTrue);
        }
      },
    );

    test(
      'writes enqueued behind a held fence stay rejected after release',
      () async {
        final queue = RoomPublishQueue();
        final deleteGate = Completer<void>();
        final operations = <String>[];

        queue.holdWrites();
        final deletion = queue.run(() async {
          operations.add('delete-start');
          await deleteGate.future;
          operations.add('delete-finish');
        });
        final fencedWrite = queue.runWrite(() async {
          operations.add('stale-write');
          return true;
        });

        queue.releaseWrites();
        deleteGate.complete();
        await deletion;
        expect(await fencedWrite, isNull);
        expect(operations, ['delete-start', 'delete-finish']);
        expect(await queue.runWrite(() async => true), isTrue);
      },
    );

    test('rejects linked identities and any identity with backup on', () async {
      final linked = _DeletionDelegate(
        identityKind: ServiceIdentityKind.linked,
      );
      final linkedResult = await AnonymousServiceIdentityDeletionCoordinator(
        delegate: linked,
      ).delete();
      expect(linkedResult, isNotNull);
      expect(linked.operations, isEmpty);

      final backedUp = _DeletionDelegate(backupEnabled: true);
      final backupResult = await AnonymousServiceIdentityDeletionCoordinator(
        delegate: backedUp,
      ).delete();
      expect(backupResult, isNotNull);
      expect(backedUp.operations, isEmpty);
    });

    test(
      'prepares cleanup, removes remote data and identity, and never signs in a replacement',
      () async {
        final delegate = _DeletionDelegate();
        final result = await AnonymousServiceIdentityDeletionCoordinator(
          delegate: delegate,
        ).delete(roomCode: 'ABC234');

        expect(result, isNull);
        expect(delegate.identityKind, ServiceIdentityKind.none);
        expect(delegate.operations, [
          'prepare:ABC234',
          'cancel',
          'rooms',
          'save',
          'auth',
          'clear',
        ]);
        expect(delegate.operations, isNot(contains('signIn')));
      },
    );

    test('Auth deletion failure leaves identity retryable', () async {
      final delegate = _DeletionDelegate()
        ..authFailure = StateError('Auth is unavailable');
      final result = await AnonymousServiceIdentityDeletionCoordinator(
        delegate: delegate,
      ).delete();

      expect(result, isNotNull);
      expect(delegate.identityKind, ServiceIdentityKind.anonymous);
      expect(delegate.operations, [
        'prepare:-',
        'cancel',
        'rooms',
        'save',
        'auth',
        'release',
      ]);
    });

    test('unconfirmed prepared rooms keep the identity for retry', () async {
      final delegate = _DeletionDelegate(roomsDeleted: false);
      final result = await AnonymousServiceIdentityDeletionCoordinator(
        delegate: delegate,
      ).delete(roomCode: 'ABC234');

      expect(result, isNotNull);
      expect(delegate.operations, [
        'prepare:ABC234',
        'cancel',
        'rooms',
        'release',
      ]);
      expect(delegate.identityKind, ServiceIdentityKind.anonymous);
    });

    test(
      'bounded feedback keeps the Auth lock through late success and coalesces retry',
      () async {
        final serializer = FirebaseIdentityMutationQueue();
        final deletion = CoalescedIdentityDeletionOperation();
        final authGate = Completer<void>();
        final order = <String>[];
        var cachedIdentityPresent = true;
        var deletionStarts = 0;

        Future<String?> startDeletion() => serializer.runAuthChange(() async {
          deletionStarts++;
          order.add('delete-start');
          await authGate.future;
          order.add('auth-deleted');
          cachedIdentityPresent = false;
          order.add('cache-cleared');
          return null;
        });

        final first = deletion.run(
          start: startDeletion,
          feedbackTimeout: const Duration(milliseconds: 10),
        );
        expect(await first, isNotNull);
        expect(deletionStarts, 1);

        final laterMutation = serializer.runAuthChange(() async {
          expect(cachedIdentityPresent, isFalse);
          order.add('later-auth-change');
        });
        await Future<void>.delayed(Duration.zero);
        expect(deletionStarts, 1);
        expect(order, ['delete-start']);

        authGate.complete();
        await laterMutation;
        expect(order, [
          'delete-start',
          'auth-deleted',
          'cache-cleared',
          'later-auth-change',
        ]);

        final retry = deletion.run(
          start: startDeletion,
          feedbackTimeout: const Duration(seconds: 1),
        );
        expect(await retry, isNull);
        expect(deletionStarts, 1);
        expect(order, isNot(contains('signIn')));
      },
    );

    test('failed pending-room acknowledgement stops before deletion', () async {
      final delegate = _DeletionDelegate()..prepareResult = false;
      final result = await AnonymousServiceIdentityDeletionCoordinator(
        delegate: delegate,
      ).delete(roomCode: 'ABC234');

      expect(result, isNotNull);
      expect(delegate.operations, ['prepare:ABC234']);
      expect(delegate.identityKind, ServiceIdentityKind.anonymous);
    });

    test('auth deletion waits behind an in-flight anonymous sign-in', () async {
      final serializer = FirebaseIdentityMutationQueue();
      final signInGate = Completer<bool>();
      final order = <String>[];

      final signIn = serializer.ensureServiceIdentity(
        hasIdentity: () => false,
        startIdentity: () async {
          order.add('sign-in-start');
          final result = await signInGate.future;
          order.add('sign-in-finish');
          return result;
        },
      );
      await Future<void>.delayed(Duration.zero);
      final deletion = serializer.runAuthChange(() async {
        order.add('delete');
        return 'done';
      });
      await Future<void>.delayed(Duration.zero);

      expect(order, ['sign-in-start']);
      signInGate.complete(true);
      expect(await signIn, isTrue);
      expect(await deletion, 'done');
      expect(order, ['sign-in-start', 'sign-in-finish', 'delete']);
    });
  });

  group('place-search removal coordinator', () {
    test('consent write failure prevents remote Auth deletion', () async {
      final preferences = _Preferences()..allowConsentWrite = false;
      final remote = _RemoteDeletion();
      final result = await PlaceSearchIdentityRemoval(
        preferences: preferences,
        remote: remote,
      ).remove();

      expect(result, isNotNull);
      expect(preferences.consent, PlaceSearchConsent.acceptedV1);
      expect(remote.deletions, 0);
    });

    test('remote failure is retryable while consent stays off', () async {
      final preferences = _Preferences();
      final remote = _RemoteDeletion()
        ..outcomes.addAll(['Service is out of reach.', null]);
      final removal = PlaceSearchIdentityRemoval(
        preferences: preferences,
        remote: remote,
      );

      expect(await removal.remove(roomCode: 'ABC234'), isNotNull);
      expect(preferences.consent, isNull);
      expect(remote.deletions, 1);

      expect(await removal.remove(roomCode: 'ABC234'), isNull);
      expect(preferences.consent, isNull);
      expect(remote.deletions, 2);
    });

    test('success retains install ID, map choice, and Daybook data', () async {
      final preferences = _Preferences();
      final remote = _RemoteDeletion();
      final result = await PlaceSearchIdentityRemoval(
        preferences: preferences,
        remote: remote,
      ).remove();

      expect(result, isNull);
      expect(preferences.consent, isNull);
      expect(preferences.installId, 'stable-install-id');
      expect(preferences.mapProvider, MapProvider.google);
      expect(preferences.daybookSentinel, 'Tuesday lecture in SEC 111');
      expect(remote.replacementSignIns, 0);
    });
  });
}
