import 'dart:async';

import 'package:emberkeep/cloud.dart';
import 'package:emberkeep/daybook/data/daybook_preferences.dart';
import 'package:emberkeep/daybook/services/place_search_identity_removal.dart';
import 'package:emberkeep/daybook/services/place_search_authorization.dart';
import 'package:emberkeep/daybook/services/place_search_service.dart';
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
  Future<bool> Function()? roomsAction;
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
    final action = roomsAction;
    if (action != null) return action();
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

final class _OwnedRoomDirectory implements OwnedRoomCleanupDirectory<String> {
  _OwnedRoomDirectory({
    required this.liveOwnerUid,
    Iterable<String> rooms = const [],
  }) : rooms = Set<String>.of(rooms);

  String liveOwnerUid;
  final Set<String> rooms;
  int pageSize = 100;
  int listCalls = 0;
  Object? listFailure;
  Object? deleteFailure;
  String? swapOwnerAfterList;
  final List<String> observedOwners = [];

  @override
  Future<void> verifyIdentity({required String ownerUid}) async {
    observedOwners.add(ownerUid);
    if (ownerUid != liveOwnerUid) throw StateError('identity changed');
  }

  @override
  Future<List<String>> listOwnedRooms({required String ownerUid}) async {
    observedOwners.add(ownerUid);
    listCalls += 1;
    final failure = listFailure;
    if (failure != null) throw failure;
    final result = rooms.take(pageSize).toList(growable: false);
    liveOwnerUid = swapOwnerAfterList ?? liveOwnerUid;
    return result;
  }

  @override
  Future<void> deleteOwnedRoom({
    required String ownerUid,
    required String room,
  }) async {
    observedOwners.add(ownerUid);
    final failure = deleteFailure;
    if (failure != null) throw failure;
    rooms.remove(room);
  }
}

final class _RoomDeletionRace implements OwnedRoomDeletionSteps {
  bool parentExists = true;
  bool deletionFence = false;
  bool failNextDrain = false;
  final Set<String> privateChildren = {'before-lock'};
  final List<String> operations = [];

  bool tryCreatePrivateChild(String id) {
    if (!parentExists || deletionFence) return false;
    privateChildren.add(id);
    return true;
  }

  @override
  Future<void> createServerDeletionFence() async {
    operations.add('fence');
    deletionFence = true;
    expect(tryCreatePrivateChild('after-lock'), isFalse);
  }

  @override
  Future<void> drainPrivateChildren() async {
    operations.add('drain');
    if (failNextDrain) {
      failNextDrain = false;
      throw StateError('connection dropped after server fence');
    }
    privateChildren.clear();
  }

  @override
  Future<void> deleteParentAndFenceAtomically() async {
    operations.add('delete-parent-and-fence');
    parentExists = false;
    deletionFence = false;
    expect(tryCreatePrivateChild('after-parent-delete'), isFalse);
  }
}

void main() {
  group('anonymous service identity deletion', () {
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

    test(
      'publish feedback timeout keeps the unsettled server write in the queue',
      () async {
        final queue = RoomPublishQueue();
        final writeStarted = Completer<void>();
        final writeGate = Completer<String>();
        var laterWriteStarted = false;

        final first = queue.runWriteWithFeedbackTimeout(
          () async {
            writeStarted.complete();
            return writeGate.future;
          },
          timeout: const Duration(milliseconds: 5),
          onTimeout: () => 'timed-out-feedback',
        );
        await writeStarted.future;
        expect(await first, 'timed-out-feedback');

        final later = queue.runWrite(() async {
          laterWriteStarted = true;
          return 'later';
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(laterWriteStarted, isFalse);

        writeGate.complete('server-acknowledged');
        expect(await later, 'later');
        expect(laterWriteStarted, isTrue);
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
          'cancel',
          'prepare:ABC234',
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
        'cancel',
        'prepare:-',
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
        'cancel',
        'prepare:ABC234',
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
      expect(delegate.operations, ['cancel', 'prepare:ABC234', 'release']);
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

    test(
      'fenced owner query sees an active fresh-room publish with no local handle',
      () async {
        final queue = RoomPublishQueue();
        final directory = _OwnedRoomDirectory(liveOwnerUid: 'U1');
        final writeStarted = Completer<void>();
        final writeGate = Completer<void>();

        final activePublish = queue.runWrite(() async {
          writeStarted.complete();
          await writeGate.future;
          directory.rooms.add('ABC234');
          return 'ABC234';
        });
        await writeStarted.future;
        queue.holdWrites();
        final cleanup = queue.run(
          () => deleteAllOwnedRoomsAndConfirmEmpty(
            ownerUid: 'U1',
            directory: directory,
          ),
        );

        writeGate.complete();
        expect(await activePublish, 'ABC234');
        await cleanup;
        expect(directory.rooms, isEmpty);
        expect(directory.listCalls, 2);
        expect(directory.observedOwners, everyElement('U1'));
      },
    );

    test(
      'server owner query finds crash-lost, legacy, and paged rooms then proves zero',
      () async {
        final directory = _OwnedRoomDirectory(
          liveOwnerUid: 'U1',
          rooms: ['crash-lost', 'private-legacy', 'another-room'],
        )..pageSize = 2;

        await deleteAllOwnedRoomsAndConfirmEmpty(
          ownerUid: 'U1',
          directory: directory,
        );

        expect(directory.rooms, isEmpty);
        expect(directory.listCalls, 3);
        expect(directory.observedOwners, everyElement('U1'));
      },
    );

    test(
      'owner-query or Auth-swap failure keeps save and Auth identity intact',
      () async {
        for (final directory in [
          _OwnedRoomDirectory(liveOwnerUid: 'U1')
            ..listFailure = StateError('permission-denied'),
          _OwnedRoomDirectory(liveOwnerUid: 'U1', rooms: ['ABC234'])
            ..deleteFailure = StateError('unavailable'),
          _OwnedRoomDirectory(liveOwnerUid: 'U1', rooms: ['ABC234'])
            ..swapOwnerAfterList = 'U2',
        ]) {
          final delegate = _DeletionDelegate()
            ..roomsAction = () async {
              await deleteAllOwnedRoomsAndConfirmEmpty(
                ownerUid: 'U1',
                directory: directory,
              );
              return true;
            };

          expect(
            await AnonymousServiceIdentityDeletionCoordinator(
              delegate: delegate,
            ).delete(),
            isNotNull,
          );
          expect(delegate.operations, [
            'cancel',
            'prepare:-',
            'rooms',
            'release',
          ]);
          expect(delegate.operations, isNot(contains('save')));
          expect(delegate.operations, isNot(contains('auth')));
        }
      },
    );

    test(
      'server tombstone closes private-child creation during deletion',
      () async {
        final race = _RoomDeletionRace();
        expect(race.tryCreatePrivateChild('before-start'), isTrue);

        await deleteOwnedRoomWithServerFence(race);

        expect(race.privateChildren, isEmpty);
        expect(race.operations, ['fence', 'drain', 'delete-parent-and-fence']);
      },
    );

    test(
      'server tombstone survives a failed drain and makes retry race-free',
      () async {
        final race = _RoomDeletionRace()..failNextDrain = true;

        await expectLater(
          deleteOwnedRoomWithServerFence(race),
          throwsA(isA<StateError>()),
        );
        expect(race.parentExists, isTrue);
        expect(race.deletionFence, isTrue);
        expect(race.tryCreatePrivateChild('between-attempts'), isFalse);

        await deleteOwnedRoomWithServerFence(race);

        expect(race.parentExists, isFalse);
        expect(race.privateChildren, isEmpty);
        expect(race.operations, [
          'fence',
          'drain',
          'fence',
          'drain',
          'delete-parent-and-fence',
        ]);
      },
    );

    test(
      'deletion hold invalidates ensures queued before and started during deletion',
      () async {
        final serializer = FirebaseIdentityMutationQueue();
        final authGate = Completer<void>();
        var identityPresent = false;
        var signInStarts = 0;

        final blockingAuthChange = serializer.runAuthChange(() async {
          await authGate.future;
        });
        await Future<void>.delayed(Duration.zero);
        final queuedBeforeDelete = serializer.ensureServiceIdentity(
          hasIdentity: () => identityPresent,
          startIdentity: () async {
            signInStarts += 1;
            identityPresent = true;
            return true;
          },
        );
        await Future<void>.delayed(Duration.zero);

        final hold = serializer.holdServiceIdentityCreation();
        final duringDelete = serializer.ensureServiceIdentity(
          hasIdentity: () => identityPresent,
          startIdentity: () async {
            signInStarts += 1;
            identityPresent = true;
            return true;
          },
        );
        expect(await duringDelete, isFalse);

        authGate.complete();
        await blockingAuthChange;
        expect(await queuedBeforeDelete, isFalse);
        expect(signInStarts, 0);

        hold.release();
        expect(
          await serializer.ensureServiceIdentity(
            hasIdentity: () => identityPresent,
            startIdentity: () async {
              signInStarts += 1;
              identityPresent = true;
              return true;
            },
          ),
          isTrue,
        );
        expect(signInStarts, 1);
      },
    );

    test(
      'timed-out sign-in remains serialized and is reconciled before delete',
      () async {
        final serializer = FirebaseIdentityMutationQueue();
        final signInGate = Completer<bool>();
        var identityPresent = false;
        final operations = <String>[];

        final signIn = serializer.ensureServiceIdentity(
          hasIdentity: () => identityPresent,
          startIdentity: () async {
            operations.add('sign-in-start');
            final result = await signInGate.future;
            identityPresent = result;
            operations.add('sign-in-reconciled');
            return result;
          },
          feedbackTimeout: const Duration(milliseconds: 5),
        );
        expect(await signIn, isFalse);

        final hold = serializer.holdServiceIdentityCreation();
        final deletion = serializer.runAuthChange(() async {
          operations.add('delete:${identityPresent ? 'U1' : 'none'}');
          identityPresent = false;
        });
        await Future<void>.delayed(Duration.zero);
        expect(operations, ['sign-in-start']);

        signInGate.complete(true);
        await deletion;
        hold.release();
        expect(operations, [
          'sign-in-start',
          'sign-in-reconciled',
          'delete:U1',
        ]);
        expect(identityPresent, isFalse);
      },
    );

    test(
      'never-settling delete keeps the actor locked and requires restart',
      () async {
        final serializer = FirebaseIdentityMutationQueue();
        final deletion = CoalescedIdentityDeletionOperation();
        final never = Completer<void>();
        var starts = 0;
        var laterMutationRan = false;

        Future<String?> start() => serializer.runAuthChange(() async {
          starts += 1;
          await never.future;
          return null;
        });

        expect(
          await deletion.run(
            start: start,
            feedbackTimeout: const Duration(milliseconds: 5),
          ),
          identityRemovalStillFinishingMessage,
        );
        expect(deletion.requiresRestart, isTrue);

        unawaited(
          serializer.runAuthChange(() async {
            laterMutationRan = true;
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(laterMutationRan, isFalse);

        expect(
          await deletion.run(
            start: start,
            feedbackTimeout: const Duration(milliseconds: 5),
          ),
          identityRemovalStillFinishingMessage,
        );
        expect(starts, 1);
      },
    );
  });

  group('place-search removal coordinator', () {
    test('consent write failure prevents remote Auth deletion', () async {
      final preferences = _Preferences()..allowConsentWrite = false;
      final remote = _RemoteDeletion();
      final authorization = PlaceSearchAuthorization();
      final lease = await _authorize(authorization);
      final result = await PlaceSearchIdentityRemoval(
        preferences: preferences,
        remote: remote,
        authorization: authorization,
      ).remove();

      expect(result, isNotNull);
      expect(preferences.consent, PlaceSearchConsent.acceptedV1);
      expect(remote.deletions, 0);
      expect(lease.isValid, isTrue);
    });

    test(
      'remote deletion failure revokes existing provider access immediately',
      () async {
        final preferences = _Preferences();
        final remote = _RemoteDeletion()..outcomes.add('Auth unavailable.');
        final authorization = PlaceSearchAuthorization();
        final lease = await _authorize(authorization);
        final delegate = _CountingPlaceSearchService();
        final service = AuthorizedPlaceSearchService(
          delegate: delegate,
          authorization: lease,
        );

        await service.autocomplete(
          query: 'Rutgers',
          sessionToken: '11111111-1111-4111-8111-111111111111',
          installId: 'stable-install-id',
          locale: 'en-US',
        );
        expect(delegate.calls, 1);

        final result = await PlaceSearchIdentityRemoval(
          preferences: preferences,
          remote: remote,
          authorization: authorization,
        ).remove();
        expect(result, isNotNull);
        expect(preferences.consent, isNull);
        expect(lease.isValid, isFalse);
        await expectLater(
          service.autocomplete(
            query: 'Library',
            sessionToken: '22222222-2222-4222-8222-222222222222',
            installId: 'stable-install-id',
            locale: 'en-US',
          ),
          throwsA(isA<PlaceSearchUnavailable>()),
        );
        expect(delegate.calls, 1);
      },
    );

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

Future<PlaceSearchAuthorizationLease> _authorize(
  PlaceSearchAuthorization authorization,
) async {
  final lease = await authorization.authorize(
    attempt: authorization.beginConsentAttempt(),
    persistConsent: () async => true,
  );
  if (lease == null) throw StateError('test authorization was rejected');
  return lease;
}

final class _CountingPlaceSearchService implements PlaceSearchService {
  int calls = 0;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
    required String installId,
    required String locale,
  }) async {
    calls += 1;
    return const [];
  }

  @override
  Future<PlaceSelection> details({
    required PlaceSuggestion suggestion,
    required String originalQuery,
    required String sessionToken,
    required String installId,
    required String locale,
  }) {
    throw UnimplementedError();
  }
}
