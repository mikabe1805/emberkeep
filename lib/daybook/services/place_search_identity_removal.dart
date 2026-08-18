import 'dart:async';

import '../data/daybook_preferences.dart';
import 'place_search_authorization.dart';

/// The Firebase identity currently cached by the service layer.
enum ServiceIdentityKind { none, anonymous, linked }

/// Server-backed room discovery used only by the scoped anonymous-identity
/// removal path. Implementations must query with the immutable owner uid and
/// must not return cached results.
abstract interface class OwnedRoomCleanupDirectory<T> {
  Future<void> verifyIdentity({required String ownerUid});
  Future<List<T>> listOwnedRooms({required String ownerUid});
  Future<void> deleteOwnedRoom({required String ownerUid, required T room});
}

/// Per-room server operations that make private child cleanup race-free.
abstract interface class OwnedRoomDeletionSteps {
  Future<void> createServerDeletionFence();
  Future<void> drainPrivateChildren();
  Future<void> deleteParentAndFenceAtomically();
}

Future<void> deleteOwnedRoomWithServerFence(
  OwnedRoomDeletionSteps steps,
) async {
  await steps.createServerDeletionFence();
  await steps.drainPrivateChildren();
  await steps.deleteParentAndFenceAtomically();
}

/// Deletes owner-query pages until a fresh server query proves zero remain.
/// Room writes are fenced by the caller before this starts. Identity checks
/// surround every page and destructive operation so an Auth swap fails closed.
Future<void> deleteAllOwnedRoomsAndConfirmEmpty<T>({
  required String ownerUid,
  required OwnedRoomCleanupDirectory<T> directory,
  int maxPasses = 1000,
}) async {
  for (var pass = 0; pass < maxPasses; pass++) {
    await directory.verifyIdentity(ownerUid: ownerUid);
    final rooms = await directory.listOwnedRooms(ownerUid: ownerUid);
    await directory.verifyIdentity(ownerUid: ownerUid);
    if (rooms.isEmpty) return;
    for (final room in rooms) {
      await directory.verifyIdentity(ownerUid: ownerUid);
      await directory.deleteOwnedRoom(ownerUid: ownerUid, room: room);
      await directory.verifyIdentity(ownerUid: ownerUid);
    }
  }
  throw StateError('Owned-room cleanup did not reach an empty server query.');
}

/// Small, behavior-testable lock shared by anonymous sign-in and every Auth
/// mutation. An identity deletion can therefore never race an in-flight
/// service sign-in and accidentally delete one user while caching another.
final class FirebaseIdentityMutationQueue {
  Future<bool>? _serviceIdentityFuture;
  Future<void>? _authChangeFuture;
  int _serviceIdentityGeneration = 0;
  int _serviceIdentityCreationHolds = 0;

  Future<bool> ensureServiceIdentity({
    required bool Function() hasIdentity,
    required Future<bool> Function() startIdentity,
    Duration? feedbackTimeout,
  }) {
    final requestGeneration = _serviceIdentityGeneration;
    final operation = _ensureServiceIdentity(
      requestGeneration: requestGeneration,
      hasIdentity: hasIdentity,
      startIdentity: startIdentity,
    );
    final timeout = feedbackTimeout;
    if (timeout == null) return operation;
    return operation.timeout(timeout, onTimeout: () => false);
  }

  Future<bool> _ensureServiceIdentity({
    required int requestGeneration,
    required bool Function() hasIdentity,
    required Future<bool> Function() startIdentity,
  }) async {
    while (true) {
      if (!_serviceIdentityRequestAllowed(requestGeneration)) return false;
      final authChange = _authChangeFuture;
      if (authChange != null) {
        await authChange;
        continue;
      }
      if (!_serviceIdentityRequestAllowed(requestGeneration)) return false;
      if (hasIdentity()) return true;
      final active = _serviceIdentityFuture;
      if (active != null) {
        final result = await active;
        return result && _serviceIdentityRequestAllowed(requestGeneration);
      }
      if (!_serviceIdentityRequestAllowed(requestGeneration)) return false;
      final attempt = Future<bool>.sync(startIdentity);
      _serviceIdentityFuture = attempt;
      try {
        final result = await attempt;
        return result && _serviceIdentityRequestAllowed(requestGeneration);
      } finally {
        if (identical(_serviceIdentityFuture, attempt)) {
          _serviceIdentityFuture = null;
        }
      }
    }
  }

  ServiceIdentityCreationHold holdServiceIdentityCreation() {
    _serviceIdentityGeneration += 1;
    _serviceIdentityCreationHolds += 1;
    return ServiceIdentityCreationHold._(this);
  }

  bool _serviceIdentityRequestAllowed(int requestGeneration) =>
      _serviceIdentityCreationHolds == 0 &&
      requestGeneration == _serviceIdentityGeneration;

  void _releaseServiceIdentityCreationHold() {
    if (_serviceIdentityCreationHolds > 0) {
      _serviceIdentityCreationHolds -= 1;
    }
  }

  Future<T> runAuthChange<T>(Future<T> Function() action) async {
    while (true) {
      final authChange = _authChangeFuture;
      if (authChange != null) {
        await authChange;
        continue;
      }
      final serviceIdentity = _serviceIdentityFuture;
      if (serviceIdentity != null) {
        await serviceIdentity;
        continue;
      }
      final completer = Completer<void>();
      final lock = completer.future;
      _authChangeFuture = lock;
      try {
        return await action();
      } finally {
        completer.complete();
        if (identical(_authChangeFuture, lock)) _authChangeFuture = null;
      }
    }
  }
}

final class ServiceIdentityCreationHold {
  ServiceIdentityCreationHold._(this._queue);

  FirebaseIdentityMutationQueue? _queue;

  void release() {
    final queue = _queue;
    if (queue == null) return;
    _queue = null;
    queue._releaseServiceIdentityCreationHold();
  }
}

const identityRemovalStillFinishingMessage =
    'Removal is still finishing securely. Place search is off. Close and '
    'reopen Room of Days to check the identity before trying again.';

/// Gives the UI bounded feedback without abandoning a destructive Auth
/// mutation. The underlying operation stays coalesced and keeps its queue lock
/// until it settles, so a late successful delete can clear cached identity
/// state before any later Auth change begins.
final class CoalescedIdentityDeletionOperation {
  Future<String?>? _active;
  bool _feedbackTimedOut = false;
  bool _lateSuccessNeedsAcknowledgement = false;

  bool get requiresRestart => _active != null && _feedbackTimedOut;

  Future<String?> run({
    required Future<String?> Function() start,
    Duration feedbackTimeout = const Duration(seconds: 8),
    bool Function()? acceptLateSuccess,
  }) {
    if (_lateSuccessNeedsAcknowledgement) {
      _lateSuccessNeedsAcknowledgement = false;
      if (acceptLateSuccess == null || acceptLateSuccess()) {
        return Future.value(null);
      }
    }
    final active = _active;
    if (active != null) return _boundedFeedback(active, feedbackTimeout);

    _feedbackTimedOut = false;
    late final Future<String?> operation;
    operation = Future<String?>.sync(start)
        .then((result) {
          if (_feedbackTimedOut && result == null) {
            _lateSuccessNeedsAcknowledgement = true;
          }
          return result;
        })
        .whenComplete(() {
          if (identical(_active, operation)) _active = null;
        });
    _active = operation;
    return _boundedFeedback(operation, feedbackTimeout);
  }

  Future<String?> _boundedFeedback(
    Future<String?> operation,
    Duration timeout,
  ) async {
    try {
      final result = await operation.timeout(timeout);
      if (result == null) _lateSuccessNeedsAcknowledgement = false;
      return result;
    } on TimeoutException {
      _feedbackTimedOut = true;
      return identityRemovalStillFinishingMessage;
    }
  }
}

/// Remote operations needed to remove an anonymous service identity without
/// touching the person's on-device Room of Days save.
abstract interface class AnonymousServiceIdentityDeletionDelegate {
  ServiceIdentityKind get identityKind;
  bool get backupEnabled;

  Future<bool> preparePendingRoomCleanup({String? roomCode});
  void cancelPendingWork();
  void releasePendingWorkFence();
  Future<bool> deletePreparedRooms();
  Future<void> deleteSaveDocument();
  Future<void> deleteAuthIdentity();
  void clearCachedIdentity();
}

/// Orders the destructive remote steps while leaving the current credential
/// intact whenever room ownership or a remote acknowledgement is uncertain.
final class AnonymousServiceIdentityDeletionCoordinator {
  const AnonymousServiceIdentityDeletionCoordinator({required this.delegate});

  final AnonymousServiceIdentityDeletionDelegate delegate;

  Future<String?> delete({String? roomCode}) async {
    switch (delegate.identityKind) {
      case ServiceIdentityKind.none:
        return 'There is no private service identity to remove.';
      case ServiceIdentityKind.linked:
        return 'This is a linked account. Use Delete account instead.';
      case ServiceIdentityKind.anonymous:
        break;
    }
    if (delegate.backupEnabled) {
      return 'Turn off cloud backup before removing this private service identity.';
    }

    final cleanRoomCode = roomCode?.trim();
    final requestedRoom = cleanRoomCode != null && cleanRoomCode.isNotEmpty
        ? cleanRoomCode
        : null;
    var pendingWorkFenced = false;
    var identityCleared = false;
    try {
      delegate.cancelPendingWork();
      pendingWorkFenced = true;
      final prepared = await delegate.preparePendingRoomCleanup(
        roomCode: requestedRoom,
      );
      if (!prepared) {
        return 'Your shared room is still being removed. Stay online and try again.';
      }
      if (!await delegate.deletePreparedRooms()) {
        return 'Couldn’t confirm that your shared room was removed. Your '
            'private service identity was kept so you can retry.';
      }

      await delegate.deleteSaveDocument();
      await delegate.deleteAuthIdentity();
      delegate.clearCachedIdentity();
      identityCleared = true;
      return null;
    } on TimeoutException {
      return 'The private service took too long to answer. Place search is '
          'off; try removing the identity again.';
    } catch (_) {
      return 'Couldn’t finish removing the private service identity. Place '
          'search is off; try again.';
    } finally {
      if (pendingWorkFenced && !identityCleared) {
        delegate.releasePendingWorkFence();
      }
    }
  }
}

abstract interface class AnonymousServiceIdentityDeletion {
  Future<String?> deleteAnonymousServiceIdentity({String? roomCode});
}

/// Clears the local opt-in first. If that durable write fails, no remote Auth
/// deletion begins. If the remote step fails, consent remains off and the same
/// action is safe to retry.
final class PlaceSearchIdentityRemoval {
  PlaceSearchIdentityRemoval({
    required this.preferences,
    required this.remote,
    PlaceSearchAuthorization? authorization,
  }) : authorization = authorization ?? PlaceSearchAuthorization.shared;

  final PlaceSearchPreferences preferences;
  final AnonymousServiceIdentityDeletion remote;
  final PlaceSearchAuthorization authorization;

  Future<String?> remove({String? roomCode}) async {
    try {
      final consentCleared = await authorization.revoke(
        () => preferences.savePlaceSearchConsent(null),
      );
      if (!consentCleared) {
        return 'Couldn’t turn off place search on this device. The private '
            'service identity was not removed; try again.';
      }
    } catch (_) {
      return 'Couldn’t turn off place search on this device. The private '
          'service identity was not removed; try again.';
    }

    try {
      return await remote.deleteAnonymousServiceIdentity(roomCode: roomCode);
    } catch (_) {
      return 'Couldn’t finish removing the private service identity. Place '
          'search is off; try again.';
    }
  }
}
