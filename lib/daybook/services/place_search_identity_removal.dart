import 'dart:async';

import '../data/daybook_preferences.dart';

/// The Firebase identity currently cached by the service layer.
enum ServiceIdentityKind { none, anonymous, linked }

/// Small, behavior-testable lock shared by anonymous sign-in and every Auth
/// mutation. An identity deletion can therefore never race an in-flight
/// service sign-in and accidentally delete one user while caching another.
final class FirebaseIdentityMutationQueue {
  Future<bool>? _serviceIdentityFuture;
  Future<void>? _authChangeFuture;

  Future<bool> ensureServiceIdentity({
    required bool Function() hasIdentity,
    required Future<bool> Function() startIdentity,
  }) async {
    while (true) {
      final authChange = _authChangeFuture;
      if (authChange != null) {
        await authChange;
        continue;
      }
      if (hasIdentity()) return true;
      final active = _serviceIdentityFuture;
      if (active != null) return active;
      final attempt = startIdentity();
      _serviceIdentityFuture = attempt;
      try {
        return await attempt;
      } finally {
        if (identical(_serviceIdentityFuture, attempt)) {
          _serviceIdentityFuture = null;
        }
      }
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

/// Gives the UI bounded feedback without abandoning a destructive Auth
/// mutation. The underlying operation stays coalesced and keeps its queue lock
/// until it settles, so a late successful delete can clear cached identity
/// state before any later Auth change begins.
final class CoalescedIdentityDeletionOperation {
  Future<String?>? _active;
  bool _feedbackTimedOut = false;
  bool _lateSuccessNeedsAcknowledgement = false;

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
      return 'Removal is still finishing securely. Place search is off; try '
          'this control again to check it.';
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
      final prepared = await delegate.preparePendingRoomCleanup(
        roomCode: requestedRoom,
      );
      if (!prepared) {
        return 'Your shared room is still being removed. Stay online and try again.';
      }
      delegate.cancelPendingWork();
      pendingWorkFenced = true;

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
  const PlaceSearchIdentityRemoval({
    required this.preferences,
    required this.remote,
  });

  final PlaceSearchPreferences preferences;
  final AnonymousServiceIdentityDeletion remote;

  Future<String?> remove({String? roomCode}) async {
    try {
      final consentCleared = await preferences.savePlaceSearchConsent(null);
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
