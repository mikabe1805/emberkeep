import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daybook/services/place_search_identity_removal.dart';
import 'daybook/services/place_search_access.dart';
import 'discovery.dart';
import 'firebase_options.dart';
import 'platform/test_environment_stub.dart'
    if (dart.library.io) 'platform/test_environment_io.dart';
import 'shared_room_media.dart';
import 'release_features.dart';
import 'storage.dart';

enum RoomPublishFailure {
  unavailable,
  permissionDenied,
  timedOut,
  network,
  media,
  exhaustedCodes,
  unknown,
}

/// How a spark send landed. [alreadyWaiting] is the rules refusing a second
/// pending note from the same sender — a fact worth telling honestly, and
/// distinct from a connection that simply failed.
enum SparkSendResult { sent, alreadyWaiting, failed }

enum DiscoveryPublicNameUpdate { saved, rejected, rateLimited, unavailable }

enum _OwnedRoomDeleteResult { deleted, absent, notOwned, invalid }

class _PendingRoomCleanup {
  const _PendingRoomCleanup({required this.owner, required this.code});

  final String owner;
  final String code;

  String get encoded => '$owner|$code';

  static _PendingRoomCleanup? decode(String raw) {
    final split = raw.lastIndexOf('|');
    if (split <= 0 || split == raw.length - 1) return null;
    return _PendingRoomCleanup(
      owner: raw.substring(0, split),
      code: raw.substring(split + 1),
    );
  }
}

class RoomPublishResult {
  const RoomPublishResult.success(this.code, {this.rotatedStaleCode = false})
    : failure = null;

  const RoomPublishResult.failed(this.failure)
    : code = null,
      rotatedStaleCode = false;

  final String? code;
  final RoomPublishFailure? failure;
  final bool rotatedStaleCode;

  bool get ok => code != null;
}

/// The small account-state surface rendered by Me. Keeping it injectable makes
/// privacy controls testable without booting Firebase or changing app data.
abstract interface class CloudAccountView implements Listenable {
  String? get accountEmail;
  bool get ready;
  bool get available;
  bool get optedIn;
  bool get socialReady;
  bool get canDeleteAnonymousServiceIdentity;
}

/// Reserves a fresh bearer code by attempting the create directly. Firestore
/// rules deliberately hide missing/private room documents, so probing with a
/// read first cannot distinguish an available code from a forbidden one.
///
/// A denied write can be a real collision; retry a bounded number of fresh
/// codes. If every attempt is denied, preserve the final error so the caller
/// reports a rules/policy failure instead of pretending six collisions
/// happened.
@visibleForTesting
Future<String> reserveFreshRoomCode({
  required String Function() generateCode,
  required Future<void> Function(String code) writeCode,
  required bool Function(Object error) shouldRetry,
  int attempts = 6,
}) async {
  if (attempts < 1) {
    throw ArgumentError.value(attempts, 'attempts', 'must be at least one');
  }
  for (var attempt = 0; attempt < attempts; attempt++) {
    final code = generateCode();
    try {
      await writeCode(code);
      return code;
    } catch (error, stackTrace) {
      if (!shouldRetry(error) || attempt == attempts - 1) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }
  throw StateError('Room-code reservation ended without a result.');
}

/// Serializes public-room writes so an older launch refresh cannot land after
/// a newer privacy edit. The recovered tail is deliberately separate from the
/// caller's result: a failed action still fails for that caller but never
/// poisons later room updates.
@visibleForTesting
class RoomPublishQueue {
  Future<void> _tail = Future.value();
  bool _writesHeld = false;
  int _writeFenceEpoch = 0;

  bool get writesHeld => _writesHeld;

  void holdWrites() {
    if (_writesHeld) return;
    _writesHeld = true;
    _writeFenceEpoch++;
  }

  void releaseWrites() => _writesHeld = false;

  /// Queues an ordinary write and checks the deletion fence only when the
  /// write reaches the head. Work queued just before a deletion is therefore
  /// blocked unless it had already started; already-started work finishes
  /// before the queued destructive operation runs.
  Future<T?> runWrite<T>(Future<T> Function() action) {
    final enqueuedWhileHeld = _writesHeld;
    final enqueueEpoch = _writeFenceEpoch;
    final result = _tail.then<T?>((_) async {
      if (enqueuedWhileHeld ||
          enqueueEpoch != _writeFenceEpoch ||
          _writesHeld) {
        return null;
      }
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  /// Gives the caller bounded feedback without shortening queue ownership.
  /// Firebase writes cannot be cancelled: the recovered tail therefore keeps
  /// tracking the original action after this wrapper reports a timeout.
  Future<T?> runWriteWithFeedbackTimeout<T>(
    Future<T> Function() action, {
    required Duration timeout,
    required T Function() onTimeout,
  }) {
    final operation = runWrite(action);
    return operation.timeout(timeout, onTimeout: onTimeout);
  }

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}

/// Cloud backup (round-9): an anonymous-auth Firestore mirror of the local
/// save. Local is ALWAYS the source of truth — the cloud exists so a purged
/// browser or lost phone can't erase a life. Fully failure-tolerant: if
/// Firebase is unreachable or anonymous sign-in is disabled, the app runs
/// local-only and says so quietly.
///
/// Honesty note: offline Firestore persistence is DISABLED here so that a
/// write's Future only completes on real server acknowledgement — the
/// "synced" status never lies about data sitting in a local cache. We keep
/// our own shared_preferences copy, so Firestore's cache would be redundant
/// anyway.
class CloudSync extends ChangeNotifier
    implements CloudAccountView, AnonymousServiceIdentityDeletion {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  @override
  bool ready = false;

  /// A lightweight anonymous Firebase session may exist for explicitly-used
  /// social features while backup remains off. This distinction keeps
  /// visiting and sharing from silently opting a device into cloud saves.
  @override
  bool get socialReady => _uid != null;

  /// The anonymous owner ID is exposed only at the validated sharing boundary.
  /// It is never displayed as profile identity or included in invite copy.
  String? get socialUid => _uid;

  /// Firebase initialized successfully, even if this device is intentionally
  /// staying local-only. This lets the UI distinguish an opt-out from offline.
  @override
  bool available = false;
  @override
  bool optedIn = false;
  static const _cloudEnabledKey = 'emberkeep_cloud_enabled';
  static const _pendingRoomCleanupKey = 'emberkeep_pending_room_cleanup';

  /// Human-readable status for the Me page's YOUR DATA panel.
  String status = 'connecting…';
  DateTime? lastSynced;

  String? _uid;
  Future<void>? _initFuture;
  Future<FirebaseApp>? _firebaseBootstrapFuture;
  final FirebaseIdentityMutationQueue _identityMutationQueue =
      FirebaseIdentityMutationQueue();
  static const ServiceIdentityTransitionGuard _identityTransitionGuard =
      ServiceIdentityTransitionGuard();
  final CoalescedIdentityDeletionOperation _anonymousIdentityDeletion =
      CoalescedIdentityDeletionOperation();
  final FirebasePlaceSearchAppCheck _discoveryAppCheck =
      FirebasePlaceSearchAppCheck();
  Timer? _debounce;
  Timer? _roomDebounce;
  final RoomPublishQueue _savePushQueue = RoomPublishQueue();
  final RoomPublishQueue _roomPublishQueue = RoomPublishQueue();
  bool _savePushHeld = false;

  /// A merge conflict keeps local play available but freezes only save
  /// mirroring, so a later local mutation cannot overwrite the remote copy.
  bool get savePushHeld => _savePushHeld;

  void holdSavePushes({bool report = true}) {
    _savePushHeld = true;
    _debounce?.cancel();
    if (report) {
      status = 'paused · cloud copy kept safe';
      notifyListeners();
    }
  }

  void releaseSavePushes() {
    if (!_savePushHeld) return;
    _savePushHeld = false;
    if (ready) status = _statusForUser();
    notifyListeners();
  }

  /// Cached signed-in email (null = anonymous). Cached rather than read from
  /// FirebaseAuth live, so the UI can query it safely before Firebase init.
  String? _accountEmail;

  /// Initialize Firebase once at a time. A timeout leaves the local app fully
  /// usable, while a later explicit Share/Visit action can safely retry this
  /// same guarded path instead of requiring a process restart.
  Future<void> init() {
    final active = _initFuture;
    if (active != null) return active;
    late final Future<void> attempt;
    attempt = _initOnce().whenComplete(() {
      if (identical(_initFuture, attempt)) _initFuture = null;
    });
    _initFuture = attempt;
    return attempt;
  }

  Future<bool> ensureAvailable() async {
    if (available) return true;
    await init();
    return available;
  }

  /// Initializes only the shared default Firebase app. It deliberately does
  /// not read cloud-backup preferences, inspect FirebaseAuth, create an
  /// identity, configure Firestore, or change CloudSync's backup state.
  ///
  /// Places calls this after explicit consent so App Check can activate before
  /// Places asks the separately serialized service-identity seam for auth.
  Future<bool> ensureCoreAvailable() async {
    if (isFlutterTest) return false;
    try {
      await _ensureFirebaseCore();
      return true;
    } on TimeoutException {
      debugPrint('Firebase Core bootstrap timed out');
      return false;
    } catch (e) {
      debugPrint('Firebase Core bootstrap failed: $e');
      return false;
    }
  }

  Future<void> _ensureFirebaseCore() async {
    if (Firebase.apps.isNotEmpty) return;
    final bootstrap = _firebaseBootstrapFuture ??= Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      await bootstrap.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Future.timeout cannot cancel Firebase.initializeApp. Retain the same
      // underlying future so a retry cannot race a duplicate default app.
      rethrow;
    } catch (_) {
      if (identical(_firebaseBootstrapFuture, bootstrap)) {
        _firebaseBootstrapFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initOnce() async {
    // Widget tests must remain deterministic and cannot service Firebase's
    // network timers. Real debug/release apps never receive FLUTTER_TEST=true.
    if (isFlutterTest) {
      ready = false;
      available = false;
      optedIn = false;
      status = 'off · test';
      return;
    }
    try {
      await _ensureFirebaseCore();
      // Server-ack-only writes: don't let cached writes masquerade as synced.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      available = true;
      final prefs = await SharedPreferences.getInstance();
      final cloudEnabled = prefs.getBool(_cloudEnabledKey) ?? false;
      // Reuse an existing session (a linked account, or a prior anonymous
      // one) — NEVER blindly re-sign-in anonymously, which would orphan a
      // linked account on every relaunch.
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        _uid = existing.uid;
        optedIn = cloudEnabled || !existing.isAnonymous;
        if (optedIn) await prefs.setBool(_cloudEnabledKey, true);
      } else if (cloudEnabled) {
        // Use the same in-flight session as Share/Visit. The shell is already
        // interactive while init runs, so a quick backup tap must not start a
        // second anonymous sign-in and strand the first uid.
        await ensureSocialSession();
        optedIn = true;
      } else {
        _uid = null;
        optedIn = false;
      }
      _refreshAccountEmail();
      ready = _uid != null && optedIn;
      if (_uid != null) await _retryPendingRoomCleanup(prefs);
      status = ready ? _statusForUser() : 'off · device only';
    } on TimeoutException {
      status = 'off (offline)';
      debugPrint('CloudSync init timed out (local-only)');
    } on FirebaseAuthException catch (e) {
      status = e.code == 'operation-not-allowed'
          ? 'needs Anonymous sign-in enabled in the Firebase console'
          : 'off (${e.code})';
      debugPrint('CloudSync auth failed: $e');
    } catch (e) {
      status = 'off';
      debugPrint('CloudSync init failed (local-only): $e');
    }
    notifyListeners();
  }

  /// Explicitly start optional cloud backup for the current local keep.
  /// Fresh installs never create a Firebase identity until this is called (or
  /// the person signs into an existing account).
  Future<String?> enable() => _runUnlessServiceIdentityDeletionStarted(
    blockedValue: serviceIdentityDeletionBlocksIdentityChangeMessage,
    transition: _enable,
  );

  Future<String?> _enable() async {
    if (!available && !await ensureAvailable()) {
      return 'Cloud is out of reach right now.';
    }
    if (ready) return null;
    try {
      // Share, Visit, startup refresh, and this button all converge on one
      // session Future. Double taps therefore await the same uid assignment.
      if (!await ensureSocialSession()) {
        return 'Couldn\u2019t start cloud backup right now.';
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cloudEnabledKey, true);
      optedIn = true;
      _refreshAccountEmail();
      ready = _uid != null;
      status = ready ? _statusForUser() : 'off';
      notifyListeners();
      return ready ? null : 'Couldn’t start cloud backup right now.';
    } on FirebaseAuthException catch (e) {
      return _friendlyAuth(e);
    } on TimeoutException {
      return 'Cloud took too long to answer — try again.';
    } catch (e) {
      debugPrint('CloudSync enable failed: $e');
      return 'Couldn’t start cloud backup right now.';
    }
  }

  /// Creates only the anonymous identity required to own a shared room or
  /// send a fixed spark. It does not enable save backup or change the person's
  /// device-only preference.
  Future<bool> ensureSocialSession() async {
    if (!available) return false;
    return _ensureSerializedServiceIdentity();
  }

  /// Reuses the same FirebaseAuth actor and locks as Share/Visit/account work,
  /// but requires only an already-completed Core bootstrap. This is the auth
  /// seam for consented services that must activate App Check before they
  /// create or reuse an identity; it never performs full CloudSync init.
  Future<bool> ensureServiceIdentity() async {
    if (isFlutterTest) return false;
    try {
      if (Firebase.apps.isEmpty) return false;
    } catch (_) {
      return false;
    }
    return _ensureSerializedServiceIdentity();
  }

  Future<bool> _ensureSerializedServiceIdentity() async {
    return _identityMutationQueue.ensureServiceIdentity(
      hasIdentity: () => socialReady,
      startIdentity: _startSocialSession,
      feedbackTimeout: const Duration(seconds: 8),
    );
  }

  /// Serializes every Firebase identity mutation with anonymous social-session
  /// startup. This keeps FirebaseAuth.currentUser and [_uid] from ever being
  /// assigned by two competing sign-in completions.
  Future<T> _runAuthChange<T>(Future<T> Function() action) async {
    return _identityMutationQueue.runAuthChange(action);
  }

  Future<T> _runUnlessServiceIdentityDeletionStarted<T>({
    required T blockedValue,
    required Future<T> Function() transition,
  }) => _identityTransitionGuard.run(
    ownerUid: _uid,
    isDeletionStarted: _serviceIdentityDeletionStarted,
    blockedValue: blockedValue,
    transition: transition,
  );

  Future<bool> _serviceIdentityDeletionStarted(String ownerUid) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || current.uid != ownerUid) {
      throw StateError('The current Firebase identity changed.');
    }
    final snapshot = await _serviceIdentityDeletionTombstones
        .doc(ownerUid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    return snapshot.exists;
  }

  Future<bool> _startSocialSession() async {
    if (socialReady) return true;
    try {
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        _uid = existing.uid;
      } else {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        _uid = cred.user?.uid;
      }
      _refreshAccountEmail();
      notifyListeners();
      return socialReady;
    } catch (e) {
      debugPrint('Social session failed: $e');
      return false;
    }
  }

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('saves').doc(_uid);

  // ── account state ────────────────────────────────────────────────
  /// The signed-in account email, or null if still anonymous. Reads a cached
  /// value (safe before Firebase init / in tests).
  @override
  String? get accountEmail => _accountEmail;

  bool get isSignedIn => _accountEmail != null;

  @override
  bool get canDeleteAnonymousServiceIdentity {
    if (!kAnonymousServiceIdentityRemovalEnabled) return false;
    if (!socialReady || ready || optedIn || _accountEmail != null) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user != null && user.isAnonymous && user.uid == _uid;
    } catch (_) {
      return false;
    }
  }

  String _statusForUser() => isSignedIn ? 'synced · $_accountEmail' : 'on';

  /// Refresh the cached email from the current Firebase user. Safe to call
  /// even if Firebase isn't initialized (falls back to null).
  void _refreshAccountEmail() {
    try {
      final u = FirebaseAuth.instance.currentUser;
      _accountEmail = (u != null && u.isAnonymous == false) ? u.email : null;
    } catch (_) {
      _accountEmail = null;
    }
  }

  /// Link an email+password to the CURRENT (anonymous) session — keeps the
  /// same uid, so all existing data stays attached. Returns null on success
  /// or a friendly error string.
  Future<String?> linkAccount(String email, String password) => _runAuthChange(
    () => _runUnlessServiceIdentityDeletionStarted(
      blockedValue: serviceIdentityDeletionBlocksIdentityChangeMessage,
      transition: () => _linkAccount(email, password),
    ),
  );

  Future<String?> _linkAccount(String email, String password) async {
    if (!ready) return 'Cloud is offline right now.';
    try {
      final cred = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await FirebaseAuth.instance.currentUser!.linkWithCredential(cred);
      _uid = FirebaseAuth.instance.currentUser?.uid;
      _refreshAccountEmail();
      status = _statusForUser();
      notifyListeners();
      flush(); // make sure the account's cloud copy is current
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuth(e);
    } catch (e) {
      debugPrint('linkAccount failed: $e');
      return 'Something went wrong — try again.';
    }
  }

  /// Sign in to an existing account on this device. Swaps the uid to the
  /// account's; the caller then adopts the account's cloud save. Returns
  /// null on success or a friendly error.
  Future<String?> signIn(String email, String password) => _runAuthChange(
    () => _runUnlessServiceIdentityDeletionStarted(
      blockedValue: serviceIdentityDeletionBlocksIdentityChangeMessage,
      transition: () => _signIn(email, password),
    ),
  );

  Future<String?> _signIn(String email, String password) async {
    if (!available) return 'Cloud is offline right now.';
    if (!await _prepareIdentityChange()) {
      return 'Your shared room is still being removed. Stay online and try '
          'signing in again.';
    }
    // Drop any pending anonymous push — it must NOT land on the account's
    // document after the uid swaps and clobber the real save.
    cancelPending();
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _uid = c.user?.uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cloudEnabledKey, true);
      optedIn = true;
      _refreshAccountEmail();
      // The caller still has to pull and adopt this account's save. Keep the
      // new uid guarded until that read finishes so no local timer can race it.
      _savePushHeld = true;
      status = _statusForUser();
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuth(e);
    } catch (e) {
      debugPrint('signIn failed: $e');
      return 'Something went wrong — try again.';
    }
  }

  /// Sign out → back to a fresh anonymous session. Local data stays on the
  /// device (now detached from the account until signed in again). Flushes
  /// the final state to the ACCOUNT'S doc first, so a just-completed quest
  /// reaches the account before the uid swaps away.
  Future<bool> signOut({bool saveAccount = true}) => _runAuthChange(
    () => _runUnlessServiceIdentityDeletionStarted(
      blockedValue: false,
      transition: () => _signOut(saveAccount: saveAccount),
    ),
  );

  Future<bool> _signOut({required bool saveAccount}) async {
    if (!await _prepareIdentityChange()) return false;
    _debounce?.cancel();
    if (saveAccount && !_savePushHeld) {
      try {
        final raw = await Storage.exportRaw();
        if (!_savePushHeld && raw != null && Storage.isValidSave(raw)) {
          await _doc.set({
            'data': raw,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('signOut final flush failed: $e');
      }
    }
    try {
      await FirebaseAuth.instance.signOut();
      final cred = await FirebaseAuth.instance.signInAnonymously();
      _uid = cred.user?.uid;
      _savePushHeld = false; // fresh uid: no held remote conflict follows it
      _refreshAccountEmail();
      status = _statusForUser();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('signOut failed: $e');
      return false;
    }
  }

  /// Permanently removes the signed-in Firebase account and its cloud data.
  ///
  /// Success deliberately leaves Firebase signed out and cloud backup off. The
  /// caller replaces the on-device keep with a fresh local one. A later Share,
  /// Spark, or explicit backup action can create a new anonymous session, but
  /// account deletion itself must not silently opt the person back into cloud.
  Future<String?> deleteAccount(String password, {String? roomCode}) =>
      _runAuthChange(
        () => _runUnlessServiceIdentityDeletionStarted(
          blockedValue: serviceIdentityDeletionBlocksIdentityChangeMessage,
          transition: () => _deleteAccount(password, roomCode: roomCode),
        ),
      );

  Future<String?> _deleteAccount(String password, {String? roomCode}) async {
    if (!ready) return 'Cloud is offline right now.';
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || user.isAnonymous || email == null) {
      return 'No signed-in account to delete.';
    }
    if (!await _prepareIdentityChange()) {
      return 'Your shared room is still being removed. Stay online and try '
          'deleting the account again.';
    }
    cancelPending();
    SharedPreferences? prefs;
    var backupPreferenceDisabled = false;
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      if (roomCode != null && roomCode.isNotEmpty) {
        final removed = await _deleteOwnedRoom(roomCode);
        if (removed != _OwnedRoomDeleteResult.deleted &&
            removed != _OwnedRoomDeleteResult.absent) {
          return 'Couldnâ€™t confirm that the shared room was removed. Your '
              'account has not been deleted; stay signed in and try again.';
        }
      }
      await _doc.delete();
      // Clear the durable opt-in before deleting the only credential. If the
      // preference store cannot acknowledge this write, stop while the account
      // still exists so a later launch cannot silently create a new backed-up
      // anonymous identity after an apparently successful deletion.
      prefs = await SharedPreferences.getInstance();
      backupPreferenceDisabled = await prefs.setBool(_cloudEnabledKey, false);
      if (!backupPreferenceDisabled) {
        return 'Couldn\u2019t turn off cloud backup on this device. Your account '
            'has not been deleted; try again.';
      }
      await user.delete();
      _uid = null;
      _savePushHeld = false;
      optedIn = false;
      _refreshAccountEmail();
      ready = false;
      status = 'off \u00b7 device only';
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      if (backupPreferenceDisabled) {
        await prefs?.setBool(_cloudEnabledKey, true);
      }
      return _friendlyAuth(e);
    } catch (e) {
      if (backupPreferenceDisabled &&
          FirebaseAuth.instance.currentUser != null) {
        await prefs?.setBool(_cloudEnabledKey, true);
      }
      debugPrint('deleteAccount failed: $e');
      return 'Couldn’t finish deleting the account. Some cloud data may '
          'already be gone — retry, or open Delete help in Me.';
    }
  }

  /// Removes an anonymous identity used by optional protected services while
  /// leaving the on-device Room of Days save, place fields, preferences, and
  /// retained random installation ID untouched. It is deliberately separate
  /// from Start over and linked-account deletion and never signs in a
  /// replacement user.
  @override
  Future<String?> deleteAnonymousServiceIdentity({String? roomCode}) {
    if (!kAnonymousServiceIdentityRemovalEnabled) {
      return Future.value(
        'Private service identity removal is not available in this build.',
      );
    }
    return _anonymousIdentityDeletion.run(
      start: () {
        final identityCreationHold = _identityMutationQueue
            .holdServiceIdentityCreation();
        return _runAuthChange(
          () => _deleteAnonymousServiceIdentity(roomCode: roomCode),
        ).whenComplete(identityCreationHold.release);
      },
      acceptLateSuccess: () {
        try {
          return _uid == null && FirebaseAuth.instance.currentUser == null;
        } catch (_) {
          return _uid == null;
        }
      },
    );
  }

  Future<String?> _deleteAnonymousServiceIdentity({String? roomCode}) async {
    final user = FirebaseAuth.instance.currentUser;
    final delegate = _CloudAnonymousIdentityDeletionDelegate(this, user);
    final result = await AnonymousServiceIdentityDeletionCoordinator(
      delegate: delegate,
    ).delete(roomCode: roomCode);
    if (result != null) {
      debugPrint('deleteAnonymousServiceIdentity did not complete: $result');
    }
    return result;
  }

  void _verifyAnonymousCleanupIdentity({
    required String ownerUid,
    required User expectedUser,
  }) {
    final current = FirebaseAuth.instance.currentUser;
    if (!expectedUser.isAnonymous ||
        expectedUser.uid != ownerUid ||
        current == null ||
        !current.isAnonymous ||
        current.uid != ownerUid ||
        _uid != ownerUid ||
        ready ||
        optedIn ||
        _accountEmail != null) {
      throw StateError('The anonymous cleanup identity changed.');
    }
  }

  void _clearAnonymousServiceIdentityCache() {
    _uid = null;
    _accountEmail = null;
    _savePushHeld = false;
    ready = false;
    optedIn = false;
    lastSynced = null;
    status = 'off · device only';
    _savePushQueue.releaseWrites();
    _roomPublishQueue.releaseWrites();
    notifyListeners();
  }

  static String _friendlyAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'That email already has an account — sign in instead.';
      case 'invalid-email':
        return 'That doesn’t look like an email address.';
      case 'weak-password':
        return 'Password needs at least 6 characters.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'user-not-found':
        return 'No account with that email yet.';
      case 'user-disabled':
        return 'That account is disabled.';
      case 'too-many-requests':
        return 'Too many tries — wait a moment.';
      case 'network-request-failed':
        return 'No connection — try again.';
      default:
        return 'Couldn’t do that (${e.code}).';
    }
  }

  /// Schedule a push of the CURRENT save (read at fire time, so rapid
  /// completions collapse into one write).
  void push() {
    if (!ready || _savePushHeld) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), _pushNow);
  }

  /// Push immediately, skipping the debounce — for app-pause/close, where a
  /// scheduled timer would be killed before it fires (the iOS-PWA data-lag
  /// trap). Fire-and-forget: the OS may suspend us mid-flight, but the
  /// request is at least dispatched.
  void flush() {
    if (!ready || _savePushHeld) return;
    _debounce?.cancel();
    _pushNow();
  }

  /// Cancel any pending push (used around a reset that will re-push fresh).
  void cancelPending() {
    _debounce?.cancel();
    _roomDebounce?.cancel();
  }

  Future<void> _pushNow() async {
    await _savePushQueue.runWrite(_pushNowQueued);
  }

  Future<void> _pushNowQueued() async {
    if (!ready || _savePushHeld) return;
    try {
      final raw = await Storage.exportRaw();
      if (raw == null || _savePushHeld) return;
      // NEVER mirror a corrupt/foreign blob — that would overwrite the one
      // good cloud backup with garbage, defeating disaster recovery exactly
      // when it matters.
      if (!Storage.isValidSave(raw)) {
        debugPrint('CloudSync: refusing to push an invalid save');
        return;
      }
      // Firestore caps a doc at 1 MiB and the journal is the only unbounded
      // text in the blob — a prolific journaler can cross it. Surface a real
      // status instead of failing silently forever (local saves keep working;
      // only the cloud mirror pauses).
      if (raw.length > 900 * 1024) {
        status = 'paused (save too large to back up)';
        notifyListeners();
        debugPrint('CloudSync: save is ${raw.length}B, over the safe limit');
        return;
      }
      if (_savePushHeld) return;
      await _doc.set({'data': raw, 'updatedAt': FieldValue.serverTimestamp()});
      lastSynced = DateTime.now();
      status = _statusForUser();
      notifyListeners();
    } catch (e) {
      status = 'on (last sync didn’t go through)';
      notifyListeners();
      debugPrint('CloudSync push failed: $e');
    }
  }

  // ── shared spaces (round-52, social) ─────────────────────────────
  static const _codeAlpha = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no I/O/0/1
  static final _roomCodePattern = RegExp(
    r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
  );
  final _rng = Random();

  String? _cleanRoomCode(String raw) {
    final clean = raw.trim().toUpperCase();
    return _roomCodePattern.hasMatch(clean) ? clean : null;
  }

  String _genCode() => List.generate(
    6,
    (_) => _codeAlpha[_rng.nextInt(_codeAlpha.length)],
  ).join();

  CollectionReference<Map<String, dynamic>> get _rooms =>
      FirebaseFirestore.instance.collection('rooms');

  CollectionReference<Map<String, dynamic>> get _discoverableSpaces =>
      FirebaseFirestore.instance.collection('discoverableSpaces');

  CollectionReference<Map<String, dynamic>> get _roomDeletionLocks =>
      FirebaseFirestore.instance.collection('roomDeletionLocks');

  CollectionReference<Map<String, dynamic>>
  get _serviceIdentityDeletionTombstones => FirebaseFirestore.instance
      .collection('serviceIdentityDeletionTombstones');

  /// Keep an already-published appearance card fresh without writing on every
  /// tap. Saves remain the source of truth; this is a separate, privacy-safe
  /// five-second debounce for Circle presence and room progress only.
  void queueRoomUpdate(
    Map<String, dynamic> display, {
    required String? code,
    bool discoverable = false,
  }) {
    if (_roomPublishQueue.writesHeld ||
        !socialReady ||
        code == null ||
        code.isEmpty) {
      return;
    }
    final clean = _cleanRoomCode(code);
    if (clean == null) return;
    _roomDebounce?.cancel();
    final snapshot = Map<String, dynamic>.from(display);
    _roomDebounce = Timer(
      const Duration(seconds: 5),
      () => unawaited(
        _refreshRoomAndDirectory(
          snapshot,
          code: clean,
          discoverable: discoverable,
        ),
      ),
    );
  }

  void flushRoom(
    Map<String, dynamic> display, {
    required String? code,
    bool discoverable = false,
  }) {
    if (_roomPublishQueue.writesHeld ||
        !socialReady ||
        code == null ||
        code.isEmpty) {
      return;
    }
    final clean = _cleanRoomCode(code);
    if (clean == null) return;
    _roomDebounce?.cancel();
    unawaited(
      _refreshRoomAndDirectory(
        Map<String, dynamic>.from(display),
        code: clean,
        discoverable: discoverable,
      ),
    );
  }

  Future<void> _refreshRoomAndDirectory(
    Map<String, dynamic> display, {
    required String code,
    required bool discoverable,
  }) async {
    final published = await publishRoom(display, code: code);
    if (!published.ok || published.code != code || !discoverable) return;
    await setRoomDiscoverable(code, display, discoverable: true);
  }

  /// Publish (or update) your space's appearance to a public room doc. Pass the
  /// existing [code] to refresh it in place; otherwise a fresh short code is
  /// reserved (retrying on the astronomically-rare collision). Returns the
  /// share code, or null if the cloud is offline / it failed.
  Future<String?> shareRoom(
    Map<String, dynamic> display, {
    String? code,
  }) async => (await publishRoom(display, code: code)).code;

  /// Publishes a room with enough failure detail for the UI to be honest. An
  /// imported/restored code owned by a different anonymous identity is never
  /// overwritten: it is detached and a fresh code is reserved instead.
  Future<RoomPublishResult> publishRoom(
    Map<String, dynamic> display, {
    String? code,
    bool skipCurrentVersion = false,
  }) async {
    final snapshot = Map<String, dynamic>.from(display);
    final result = await _roomPublishQueue.runWriteWithFeedbackTimeout(
      () => _publishRoomNow(
        snapshot,
        code: code,
        skipCurrentVersion: skipCurrentVersion,
      ),
      timeout: const Duration(seconds: 8),
      onTimeout: () =>
          const RoomPublishResult.failed(RoomPublishFailure.timedOut),
    );
    if (_roomPublishQueue.writesHeld) {
      return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
    }
    return result ??
        const RoomPublishResult.failed(RoomPublishFailure.unavailable);
  }

  Future<RoomPublishResult> _publishRoomNow(
    Map<String, dynamic> display, {
    String? code,
    required bool skipCurrentVersion,
  }) async {
    if (!socialReady || _uid == null) {
      return const RoomPublishResult.failed(RoomPublishFailure.unavailable);
    }
    final data = {
      ...display,
      'uid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    var rotatedStaleCode = false;
    try {
      if (code != null && code.isNotEmpty) {
        final clean = _cleanRoomCode(code);
        if (clean != null) {
          try {
            final existing = await _rooms
                .doc(clean)
                .get()
                .timeout(const Duration(seconds: 8));
            final existingData = existing.data();
            final owner = existingData?['uid'];
            if (!existing.exists || owner == _uid) {
              if (existing.exists &&
                  skipCurrentVersion &&
                  existingData?['v'] == display['v']) {
                return RoomPublishResult.success(clean);
              }
              await _rooms.doc(clean).set(data);
              return RoomPublishResult.success(clean);
            }
          } on FirebaseException catch (error) {
            // A missing document and a private pre-release document are both
            // intentionally unreadable under the production rules. Rotate
            // either stale local handle instead of stranding sharing forever.
            if (error.code != 'permission-denied') rethrow;
          }
        }
        // A malformed restored value or a valid code owned by a lost Firebase
        // identity is stale. Never form a nested document path from it and
        // never try to overwrite somebody else's room.
        rotatedStaleCode = true;
      }
      final freshCode = await reserveFreshRoomCode(
        generateCode: _genCode,
        writeCode: (candidateCode) async {
          final newRoomData = Map<String, dynamic>.from(data);
          // Deterministic media paths include the room code. A restored code
          // owned by another anonymous session must not carry its old path into
          // the freshly reserved document; the media coordinator uploads and
          // republishes under [candidateCode] after this reservation succeeds.
          if (newRoomData.containsKey('profilePhotoPath')) {
            newRoomData['profilePhotoPath'] = '';
          }
          if (newRoomData.containsKey('seasonPhotoPath')) {
            newRoomData['seasonPhotoPath'] = '';
          }
          await _rooms.doc(candidateCode).set(newRoomData);
        },
        shouldRetry: (error) =>
            error is FirebaseException && error.code == 'permission-denied',
      );
      return RoomPublishResult.success(
        freshCode,
        rotatedStaleCode: rotatedStaleCode,
      );
    } on TimeoutException {
      debugPrint(
        'publishRoom failed: timeout v=${display['v']} existing=${code != null}',
      );
      return const RoomPublishResult.failed(RoomPublishFailure.timedOut);
    } on FirebaseException catch (e) {
      debugPrint(
        'publishRoom failed: firebase=${e.code} v=${display['v']} '
        'existing=${code != null} signedIn=${_uid != null}',
      );
      if (e.code == 'permission-denied') {
        return const RoomPublishResult.failed(
          RoomPublishFailure.permissionDenied,
        );
      }
      if (const {
        'unavailable',
        'network-request-failed',
        'deadline-exceeded',
      }.contains(e.code)) {
        return const RoomPublishResult.failed(RoomPublishFailure.network);
      }
      return const RoomPublishResult.failed(RoomPublishFailure.unknown);
    } catch (e) {
      debugPrint(
        'publishRoom failed: ${e.runtimeType} v=${display['v']} '
        'existing=${code != null}',
      );
      return const RoomPublishResult.failed(RoomPublishFailure.unknown);
    }
  }

  /// Adds or removes the deliberately tiny discovery projection. This is an
  /// acknowledged privacy boundary: unlike background room refreshes it does
  /// not use a feedback timeout, because a timed-out create could later land
  /// while the local toggle still claimed the room was private.
  Future<bool> setRoomDiscoverable(
    String code,
    Map<String, dynamic> room, {
    required bool discoverable,
  }) async {
    if (!socialReady || _uid == null) return false;
    final clean = _cleanRoomCode(code);
    if (clean == null) return false;
    _roomDebounce?.cancel();
    _roomDebounce = null;
    final projection = discoverable
        ? discoverableSpaceDisplay(room, roomCode: clean)
        : const <String, dynamic>{};
    try {
      final result = await _roomPublishQueue.runWrite<bool>(() async {
        if (!socialReady || _uid == null) return false;
        final document = _discoverableSpaces.doc(clean);
        if (discoverable) {
          // The owner may refresh generated visuals, but cannot author the
          // public name directly. Preserve the server-approved name exactly;
          // a missing v1 value migrates to anonymous v2.
          await FirebaseFirestore.instance
              .runTransaction((transaction) async {
                final existing = await transaction.get(document);
                final existingName = existing.data()?['publicName'];
                transaction.set(document, {
                  ...projection,
                  'publicName': existingName is String ? existingName : '',
                  'updatedAt': FieldValue.serverTimestamp(),
                  'expiresAt': Timestamp.fromDate(
                    DateTime.now().toUtc().add(discoverableSpaceLease),
                  ),
                });
              })
              .timeout(const Duration(seconds: 8));
        } else {
          await document.delete();
        }
        return true;
      });
      return result ?? false;
    } catch (error) {
      debugPrint('setRoomDiscoverable failed: $error');
      return false;
    }
  }

  Future<bool> _prepareProtectedDiscoveryCall() async {
    // Activate attestation after Core but before this operation creates or
    // reuses an anonymous identity. Callable enforcement is a rollout flag on
    // the server, so pre-release monitor builds use the same real providers.
    if (!await ensureCoreAvailable() || !await _discoveryAppCheck.activate()) {
      return false;
    }
    if (!await ensureAvailable()) return false;
    return ensureSocialSession();
  }

  Future<DiscoveryPublicNameUpdate> setDiscoveryPublicName(
    String code,
    String name,
  ) async {
    final clean = _cleanRoomCode(code);
    if (clean == null || !await _prepareProtectedDiscoveryCall()) {
      return DiscoveryPublicNameUpdate.unavailable;
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'setDiscoveryPublicName',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );
      await callable.call<void>({
        'code': clean,
        'publicName': sanitizeDiscoveryPublicName(name),
      });
      return DiscoveryPublicNameUpdate.saved;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('setDiscoveryPublicName failed: ${error.code}');
      return switch (error.code) {
        'invalid-argument' ||
        'failed-precondition' => DiscoveryPublicNameUpdate.rejected,
        'resource-exhausted' => DiscoveryPublicNameUpdate.rateLimited,
        _ => DiscoveryPublicNameUpdate.unavailable,
      };
    } catch (error) {
      debugPrint('setDiscoveryPublicName failed: $error');
      return DiscoveryPublicNameUpdate.unavailable;
    }
  }

  Future<bool> reportDiscoverableSpace(String code, String category) async {
    final clean = _cleanRoomCode(code);
    if (clean == null ||
        !const {
          'inappropriate_name',
          'impersonation',
          'other',
        }.contains(category) ||
        !await _prepareProtectedDiscoveryCall()) {
      return false;
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'reportDiscoverableSpace',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
      );
      await callable.call<void>({'code': clean, 'category': category});
      return true;
    } catch (error) {
      debugPrint('reportDiscoverableSpace failed: $error');
      return false;
    }
  }

  /// Fetches one finite, shuffled handful. Null means the directory could not
  /// be reached; an empty list is a real empty directory.
  Future<List<DiscoverableSpaceSummary>?> fetchDiscoverableSpaces({
    int limit = 8,
  }) async {
    final take = limit.clamp(1, 12);
    if (!await ensureAvailable() || !await ensureSocialSession()) return null;
    final pivot = _rng.nextInt(discoverableSpaceBucketCount);
    try {
      final freshAfter = Timestamp.fromDate(
        DateTime.now().toUtc().add(discoverableSpaceQuerySafetyMargin),
      );
      final page = await _discoverableSpaces
          .where('expiresAt', isGreaterThan: freshAfter)
          .orderBy('expiresAt', descending: true)
          .limit(12)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      final summaries = <DiscoverableSpaceSummary>[];
      for (final document in page.docs) {
        final summary = DiscoverableSpaceSummary.fromDocument(
          document.id,
          document.data(),
        );
        if (summary != null) summaries.add(summary);
      }
      summaries.sort((a, b) {
        final aDistance =
            (a.bucket - pivot + discoverableSpaceBucketCount) %
            discoverableSpaceBucketCount;
        final bDistance =
            (b.bucket - pivot + discoverableSpaceBucketCount) %
            discoverableSpaceBucketCount;
        return aDistance.compareTo(bDistance);
      });
      return summaries.take(take).toList(growable: false);
    } catch (error) {
      debugPrint('fetchDiscoverableSpaces failed: $error');
      return null;
    }
  }

  /// Read a shared space by code (case-insensitive). Null = not found / error.
  Future<Map<String, dynamic>?> fetchRoom(String code) async {
    if (!available) return null;
    final c = _cleanRoomCode(code);
    if (c == null) return null;
    try {
      final snap = await _rooms
          .doc(c)
          .get()
          .timeout(const Duration(seconds: 8));
      return snap.data();
    } catch (e) {
      debugPrint('fetchRoom failed: $e');
      return null;
    }
  }

  /// Take your space down (only your own — the rules enforce it).
  Future<bool> unshareRoom(String code) {
    if (!socialReady || code.isEmpty) return Future.value(false);
    // A five-second appearance refresh must never outlive Stop Sharing. Queue
    // the delete behind any refresh whose timer already fired; otherwise that
    // stale write could recreate the room after the UI cleared its code.
    _roomDebounce?.cancel();
    _roomDebounce = null;
    return _roomPublishQueue.run(() async {
      try {
        final removed = await _deleteOwnedRoom(code);
        return removed == _OwnedRoomDeleteResult.deleted ||
            removed == _OwnedRoomDeleteResult.absent;
      } catch (e) {
        debugPrint('unshareRoom failed: $e');
        return false;
      }
    });
  }

  /// Firestore does not cascade-delete subcollections. Clear every private
  /// sender receipt while the parent room still exists (and its owner rule can
  /// be evaluated), then remove the public room itself.
  Future<_OwnedRoomDeleteResult> _deleteOwnedRoom(String code) async {
    final clean = _cleanRoomCode(code);
    if (clean == null) return _OwnedRoomDeleteResult.invalid;
    final room = _rooms.doc(clean);
    late final DocumentSnapshot<Map<String, dynamic>> parent;
    try {
      parent = await room.get().timeout(const Duration(seconds: 8));
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      // Legacy/private parents cannot be read through the bearer-get rule.
      // Attempt the owner-only destructive path, but propagate every denial:
      // permission failure is not proof that this identity did not own it.
      await _deleteRoomPrivateChildren(room);
      final batch = FirebaseFirestore.instance.batch()
        ..delete(_discoverableSpaces.doc(clean))
        ..delete(room);
      await batch.commit().timeout(const Duration(seconds: 8));
      return _OwnedRoomDeleteResult.deleted;
    }
    if (!parent.exists) return _OwnedRoomDeleteResult.absent;
    if (parent.data()?['uid'] != _uid) {
      return _OwnedRoomDeleteResult.notOwned;
    }
    final parentData = parent.data();
    final mediaPaths = <String>[
      for (final key in const ['profilePhotoPath', 'seasonPhotoPath'])
        if (parentData?[key] is String &&
            (parentData![key] as String).isNotEmpty)
          parentData[key] as String,
    ];
    if (kVisitorPhotoSharingEnabled && mediaPaths.isNotEmpty) {
      await SharedRoomMediaService.instance.deleteObjectPaths(mediaPaths);
    }
    await _deleteRoomPrivateChildren(room);
    final batch = FirebaseFirestore.instance.batch()
      ..delete(_discoverableSpaces.doc(clean))
      ..delete(room);
    await batch.commit().timeout(const Duration(seconds: 8));
    return _OwnedRoomDeleteResult.deleted;
  }

  Future<void> _deleteRoomPrivateChildren(
    DocumentReference<Map<String, dynamic>> room, {
    Future<void> Function()? verifyIdentity,
  }) async {
    for (final collectionName in const ['sparks', 'circleAdds']) {
      while (true) {
        if (verifyIdentity != null) await verifyIdentity();
        final page = await room
            .collection(collectionName)
            .limit(400)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
        if (verifyIdentity != null) await verifyIdentity();
        if (page.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        if (verifyIdentity != null) await verifyIdentity();
        final deletion = batch.commit();
        if (verifyIdentity == null) {
          await deletion.timeout(const Duration(seconds: 8));
        } else {
          // The strong anonymous-identity path cannot abandon an
          // uncancellable destructive commit. Its outer operation provides
          // bounded UI feedback while this queue stays fenced until settle.
          await deletion;
        }
        if (verifyIdentity != null) await verifyIdentity();
        if (page.docs.length < 400) break;
      }
    }
  }

  /// A reset may lose connectivity after it has already cleared local state.
  /// Keep the old owner uid and opaque code long enough to retry, rather than
  /// deleting the only identity that can ever remove the public room.
  List<_PendingRoomCleanup> _pendingRoomCleanups(SharedPreferences prefs) {
    final raw = prefs.get(_pendingRoomCleanupKey);
    if (raw is String) {
      final owner = _uid;
      final clean = _cleanRoomCode(raw);
      return owner == null || clean == null
          ? const []
          : [_PendingRoomCleanup(owner: owner, code: clean)];
    }
    if (raw is! List<String>) return const [];
    final records = <_PendingRoomCleanup>[];
    for (final value in raw) {
      final record = _PendingRoomCleanup.decode(value);
      if (record == null) continue;
      final clean = _cleanRoomCode(record.code);
      if (clean != null) {
        records.add(_PendingRoomCleanup(owner: record.owner, code: clean));
      }
    }
    return records;
  }

  Future<bool> _writePendingRoomCleanups(
    SharedPreferences prefs,
    List<_PendingRoomCleanup> records,
  ) async {
    if (records.isEmpty) {
      return prefs.remove(_pendingRoomCleanupKey);
    }
    return prefs.setStringList(_pendingRoomCleanupKey, [
      for (final record in records) record.encoded,
    ]);
  }

  Future<bool> _rememberPendingRoomCleanup(
    SharedPreferences prefs,
    String code,
  ) async {
    final owner = _uid;
    if (owner == null) return false;
    final records = _pendingRoomCleanups(prefs);
    if (!records.any(
      (record) => record.owner == owner && record.code == code,
    )) {
      records.add(_PendingRoomCleanup(owner: owner, code: code));
      return _writePendingRoomCleanups(prefs, records);
    }
    return true;
  }

  Future<bool> _forgetPendingRoomCleanup(
    SharedPreferences prefs,
    String code,
  ) async {
    final owner = _uid;
    final records = _pendingRoomCleanups(
      prefs,
    ).where((record) => record.owner != owner || record.code != code).toList();
    return _writePendingRoomCleanups(prefs, records);
  }

  /// Returns whether every pending room owned by the current identity is now
  /// gone. Records for other identities remain owner-tagged and untouched.
  Future<bool> _retryPendingRoomCleanup(SharedPreferences prefs) async {
    final owner = _uid;
    if (owner == null) return true;
    final records = _pendingRoomCleanups(prefs);
    if (records.isEmpty) return true;
    final remaining = <_PendingRoomCleanup>[];
    for (final record in records) {
      if (record.owner != owner) {
        remaining.add(record);
        continue;
      }
      try {
        final result = await _deleteOwnedRoom(record.code);
        if (result == _OwnedRoomDeleteResult.notOwned ||
            result == _OwnedRoomDeleteResult.invalid) {
          // A malformed handle or room owned by another uid is stale local
          // state, not work this credential can ever complete.
          debugPrint('CloudSync dropped stale pending room cleanup: $result');
        }
      } catch (e) {
        remaining.add(record);
        debugPrint('CloudSync pending room cleanup will retry: $e');
      }
    }
    final acknowledged = await _writePendingRoomCleanups(prefs, remaining);
    return acknowledged && !remaining.any((record) => record.owner == owner);
  }

  Future<bool> _prepareIdentityChange() async {
    if (_uid == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return _retryPendingRoomCleanup(prefs);
  }

  /// Send one fixed, text-free encouragement. The security rules key the
  /// pending spark by sender uid, so one person cannot stack spam; the keeper
  /// must collect it before that sender can kindle them again.
  ///
  /// The outcome distinguishes the rules rejecting a second pending note
  /// (permission-denied — the honest "already waiting" case) from a network
  /// or auth failure, so the UI never blames a person's earlier note for a
  /// dead connection.
  Future<SparkSendResult> sendSpark(
    String code, {
    String kind = 'kindle',
  }) async {
    if (!socialReady || _uid == null) return SparkSendResult.failed;
    final clean = _cleanRoomCode(code);
    if (clean == null) return SparkSendResult.failed;
    const allowed = {'kindle', 'steady', 'cheer'};
    final safeKind = allowed.contains(kind) ? kind : 'kindle';
    try {
      await _rooms.doc(clean).collection('sparks').doc(_uid).set({
        'sender': _uid,
        'kind': safeKind,
        'sentAt': FieldValue.serverTimestamp(),
      });
      return SparkSendResult.sent;
    } on FirebaseException catch (e) {
      debugPrint('sendSpark failed: $e');
      return e.code == 'permission-denied'
          ? SparkSendResult.alreadyWaiting
          : SparkSendResult.failed;
    } catch (e) {
      debugPrint('sendSpark failed: $e');
      return SparkSendResult.failed;
    }
  }

  /// Leave a fixed, text-free receipt when a visitor keeps this room in their
  /// Circle. Delivery is best-effort; the local bookmark remains useful while
  /// offline, and only the room owner can read or clear the receipt.
  Future<bool> sendCircleAdd(String code) async {
    if (!socialReady || _uid == null) return false;
    final clean = _cleanRoomCode(code);
    if (clean == null) return false;
    try {
      await _rooms.doc(clean).collection('circleAdds').doc(_uid).set({
        'sender': _uid,
        'kind': 'circle_added',
        'sentAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('sendCircleAdd failed: $e');
      return false;
    }
  }

  /// Only the owner of [code] may read these under firestore.rules.
  Future<List<Map<String, dynamic>>> fetchSparks(String code) async {
    if (!socialReady || _uid == null || code.isEmpty) return const [];
    final clean = _cleanRoomCode(code);
    if (clean == null) return const [];
    try {
      final snap = await _rooms
          .doc(clean)
          .collection('sparks')
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 8));
      return [
        for (final doc in snap.docs) {...doc.data(), 'id': doc.id},
      ];
    } catch (e) {
      debugPrint('fetchSparks failed: $e');
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCircleAdds(String code) async {
    if (!socialReady || _uid == null || code.isEmpty) return const [];
    final clean = _cleanRoomCode(code);
    if (clean == null) return const [];
    try {
      final snap = await _rooms
          .doc(clean)
          .collection('circleAdds')
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 8));
      return [
        for (final doc in snap.docs) {...doc.data(), 'id': doc.id},
      ];
    } catch (e) {
      debugPrint('fetchCircleAdds failed: $e');
      return const [];
    }
  }

  Future<bool> collectSparks(String code, Iterable<String> ids) async {
    if (!socialReady || _uid == null || code.isEmpty) return false;
    final clean = _cleanRoomCode(code);
    if (clean == null) return false;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.take(20)) {
        batch.delete(_rooms.doc(clean).collection('sparks').doc(id));
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('collectSparks failed: $e');
      return false;
    }
  }

  Future<bool> collectCircleAdds(String code, Iterable<String> ids) async {
    if (!socialReady || _uid == null || code.isEmpty) return false;
    final clean = _cleanRoomCode(code);
    if (clean == null) return false;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.take(20)) {
        batch.delete(_rooms.doc(clean).collection('circleAdds').doc(id));
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('collectCircleAdds failed: $e');
      return false;
    }
  }

  /// Permanently erase the current cloud save and any published room.
  ///
  /// Anonymous Firebase users are real backend identities even though the
  /// person never chose a sign-in. A full reset therefore deletes that guest
  /// identity too, then creates a fresh blank guest so cloud backup can keep
  /// working. A linked account is deliberately retained here; its separate
  /// password-confirmed deletion flow removes the sign-in itself.
  ///
  /// Returns whether every requested remote deletion succeeded. The caller
  /// still completes the local reset when offline; the fresh local save will
  /// replace the cloud copy when connectivity returns.
  Future<bool> resetProfile({String? roomCode}) => _runAuthChange(
    () => _runUnlessServiceIdentityDeletionStarted(
      blockedValue: false,
      transition: () => _resetProfile(roomCode: roomCode),
    ),
  );

  Future<bool> _resetProfile({String? roomCode}) async {
    if (!ready) return false;
    _debounce?.cancel();
    _roomDebounce?.cancel();
    var fullyErased = true;
    SharedPreferences? cleanupPrefs;

    try {
      cleanupPrefs = await SharedPreferences.getInstance();
      if (!await _retryPendingRoomCleanup(cleanupPrefs)) fullyErased = false;
    } catch (e) {
      fullyErased = false;
      debugPrint('CloudSync cleanup queue unavailable: $e');
    }

    final cleanRoomCode = _cleanRoomCode(roomCode ?? '');
    if (cleanRoomCode != null) {
      try {
        // Write the retry record first. It is removed only after the server
        // confirms the room and its private receipt collections are gone.
        if (cleanupPrefs != null) {
          if (!await _rememberPendingRoomCleanup(cleanupPrefs, cleanRoomCode)) {
            fullyErased = false;
          }
        }
        final removed = await _deleteOwnedRoom(cleanRoomCode);
        if (removed == _OwnedRoomDeleteResult.deleted ||
            removed == _OwnedRoomDeleteResult.absent) {
          if (cleanupPrefs != null) {
            if (!await _forgetPendingRoomCleanup(cleanupPrefs, cleanRoomCode)) {
              fullyErased = false;
            }
          } else {
            // The room is gone, but without durable local preferences this
            // session must keep its identity rather than claim a complete reset.
            fullyErased = false;
          }
        } else {
          fullyErased = false;
          debugPrint('CloudSync room reset not confirmed: $removed');
        }
      } catch (e) {
        fullyErased = false;
        debugPrint('CloudSync room reset failed: $e');
      }
    }

    try {
      await _doc.delete();
      // The conflicted copy no longer exists, so an explicit successful reset
      // may start mirroring the fresh local profile again.
      _savePushHeld = false;
    } catch (e) {
      fullyErased = false;
      debugPrint('CloudSync save reset failed: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    // Never destroy the only credential capable of retrying a failed room or
    // save cleanup. The fresh local reset still completes; the guest identity
    // rotates only after every requested remote deletion is acknowledged.
    if (user?.isAnonymous == true && fullyErased) {
      try {
        await user!.delete();
        _uid = null;
        ready = false;
        _refreshAccountEmail();
        status = 'off · starting fresh';
        notifyListeners();
        final fresh = await FirebaseAuth.instance.signInAnonymously();
        _uid = fresh.user?.uid;
        _refreshAccountEmail();
        ready = _uid != null;
        status = ready ? _statusForUser() : 'off';
        notifyListeners();
      } catch (e) {
        fullyErased = false;
        debugPrint('CloudSync guest reset failed: $e');
      }
    }

    return fullyErased;
  }

  /// The cloud copy of the save. Returns ([ok], [data]):
  ///   ok=true,  data=String → a save exists in the cloud
  ///   ok=true,  data=null   → the cloud doc is genuinely ABSENT (safe to
  ///                           push a first save)
  ///   ok=false              → the read FAILED (timeout/error) — callers must
  ///                           NOT push, or they'd clobber an unread cloud
  ///                           save (the account-overwrite trap).
  Future<({bool ok, String? data})> pull() async {
    if (!ready) return (ok: false, data: null);
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 8));
      return (ok: true, data: snap.data()?['data'] as String?);
    } catch (e) {
      debugPrint('CloudSync pull failed: $e');
      return (ok: false, data: null);
    }
  }
}

final class _CloudAnonymousIdentityDeletionDelegate
    implements AnonymousServiceIdentityDeletionDelegate {
  _CloudAnonymousIdentityDeletionDelegate(this._cloud, this._user);

  final CloudSync _cloud;
  final User? _user;
  String? _ownerUid;
  bool? _saveWritesWereHeld;
  bool? _roomWritesWereHeld;

  @override
  ServiceIdentityKind get identityKind {
    final user = _user;
    final cachedUid = _cloud._uid;
    if (user == null || cachedUid == null || user.uid != cachedUid) {
      return ServiceIdentityKind.none;
    }
    return user.isAnonymous
        ? ServiceIdentityKind.anonymous
        : ServiceIdentityKind.linked;
  }

  @override
  bool get backupEnabled => _cloud.ready || _cloud.optedIn;

  @override
  Future<bool> createUidDeletionTombstone() async {
    final user = _user;
    final ownerUid = user?.uid;
    if (user == null || ownerUid == null || !user.isAnonymous) return false;
    try {
      _cloud._verifyAnonymousCleanupIdentity(
        ownerUid: ownerUid,
        expectedUser: user,
      );
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'beginServiceIdentityDeletion',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 8)),
        );
        await callable.call<void>(const <String, Object?>{});
      } catch (_) {
        // A lost callable response may follow a committed tombstone. The
        // server-only read below is the authoritative reconciliation path.
      }
      final snapshot = await _cloud._serviceIdentityDeletionTombstones
          .doc(ownerUid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      _cloud._verifyAnonymousCleanupIdentity(
        ownerUid: ownerUid,
        expectedUser: user,
      );
      final data = snapshot.data();
      return snapshot.exists &&
          data?['uid'] == ownerUid &&
          data?['state'] == 'deleting' &&
          data?['expiresAt'] is Timestamp;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> preparePendingRoomCleanup({String? roomCode}) async {
    final user = _user;
    final ownerUid = user?.uid;
    if (user == null || ownerUid == null || !user.isAnonymous) return false;
    final preferences = await SharedPreferences.getInstance();
    final directory = _CloudOwnedRoomCleanupDirectory(_cloud, user);
    // This destructive queue action runs after every already-active publish.
    // The following server-only owner query therefore discovers even a room
    // whose publish callback never persisted its bearer code locally.
    return _cloud._roomPublishQueue.run(() async {
      await directory.verifyIdentity(ownerUid: ownerUid);
      if (!await preferences.setBool(CloudSync._cloudEnabledKey, false)) {
        return false;
      }
      _ownerUid = ownerUid;
      return true;
    });
  }

  @override
  void cancelPendingWork() {
    _saveWritesWereHeld = _cloud._savePushQueue.writesHeld;
    _roomWritesWereHeld = _cloud._roomPublishQueue.writesHeld;
    _cloud._savePushQueue.holdWrites();
    _cloud._roomPublishQueue.holdWrites();
    _cloud.cancelPending();
  }

  @override
  void releasePendingWorkFence() {
    if (_saveWritesWereHeld == false) _cloud._savePushQueue.releaseWrites();
    if (_roomWritesWereHeld == false) {
      _cloud._roomPublishQueue.releaseWrites();
    }
    _saveWritesWereHeld = null;
    _roomWritesWereHeld = null;
  }

  @override
  Future<bool> deletePreparedRooms() {
    final ownerUid = _ownerUid;
    final user = _user;
    if (ownerUid == null || user == null) {
      throw StateError('Owned-room cleanup was not prepared.');
    }
    final directory = _CloudOwnedRoomCleanupDirectory(_cloud, user);
    return _cloud._roomPublishQueue.run(() async {
      await deleteAllOwnedRoomsAndConfirmEmpty(
        ownerUid: ownerUid,
        directory: directory,
      );
      return true;
    });
  }

  @override
  Future<void> deleteSaveDocument() =>
      _cloud._savePushQueue.run(() => _cloud._doc.delete());

  @override
  Future<void> deleteAuthIdentity() => deleteAnonymousAuthIdentitySafely(
    _CloudAnonymousAuthDeletionSteps(_user),
  );

  @override
  void clearCachedIdentity() => _cloud._clearAnonymousServiceIdentityCache();
}

final class _CloudAnonymousAuthDeletionSteps
    implements AnonymousAuthDeletionSteps {
  _CloudAnonymousAuthDeletionSteps(this._expectedUser);

  final User? _expectedUser;
  User? _verifiedUser;

  @override
  Future<void> reloadAndVerifyAnonymous() async {
    final expected = _expectedUser;
    var current = FirebaseAuth.instance.currentUser;
    if (expected == null || current == null || current.uid != expected.uid) {
      throw StateError('The current Firebase identity changed.');
    }
    await current.reload();
    current = FirebaseAuth.instance.currentUser;
    if (current == null ||
        current.uid != expected.uid ||
        !current.isAnonymous) {
      throw StateError('The current Firebase identity is no longer anonymous.');
    }
    _verifiedUser = current;
  }

  @override
  Future<void> deleteIdentity() async {
    final user = _verifiedUser;
    if (user == null) {
      throw StateError('The anonymous Firebase identity was not verified.');
    }
    final deletion = user.delete();
    try {
      await deletion.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Future.timeout cannot cancel Auth deletion. Keep the Auth actor locked
      // until the SDK future settles, then reconcile its real outcome.
      await deletion;
    }
  }

  @override
  Future<bool> confirmAuthoritativeAbsence(Object failure) async {
    if (failure is FirebaseAuthException && failure.code == 'user-not-found') {
      return true;
    }
    final expectedUid = _expectedUser?.uid;
    var current = FirebaseAuth.instance.currentUser;
    if (current == null) return true;
    if (expectedUid == null || current.uid != expectedUid) return false;
    try {
      await current.reload();
    } on FirebaseAuthException catch (error) {
      return error.code == 'user-not-found';
    } catch (_) {
      return false;
    }
    current = FirebaseAuth.instance.currentUser;
    return current == null;
  }
}

final class _CloudOwnedRoomCleanupDirectory
    implements
        OwnedRoomCleanupDirectory<DocumentSnapshot<Map<String, dynamic>>> {
  const _CloudOwnedRoomCleanupDirectory(this._cloud, this._expectedUser);

  final CloudSync _cloud;
  final User _expectedUser;

  @override
  Future<void> verifyIdentity({required String ownerUid}) async {
    _cloud._verifyAnonymousCleanupIdentity(
      ownerUid: ownerUid,
      expectedUser: _expectedUser,
    );
  }

  @override
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> listOwnedRooms({
    required String ownerUid,
  }) async {
    final page = await _cloud._rooms
        .where('uid', isEqualTo: ownerUid)
        .limit(100)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
    for (final room in page.docs) {
      if (room.data()['uid'] != ownerUid) {
        throw StateError('Owner query returned a room for another identity.');
      }
    }
    return List<DocumentSnapshot<Map<String, dynamic>>>.unmodifiable(page.docs);
  }

  @override
  Future<void> deleteOwnedRoom({
    required String ownerUid,
    required DocumentSnapshot<Map<String, dynamic>> room,
  }) => deleteOwnedRoomWithServerFence(
    _CloudOwnedRoomDeletionSteps(
      _cloud,
      _expectedUser,
      ownerUid: ownerUid,
      room: room,
    ),
  );
}

final class _CloudOwnedRoomDeletionSteps implements OwnedRoomDeletionSteps {
  const _CloudOwnedRoomDeletionSteps(
    this._cloud,
    this._expectedUser, {
    required this.ownerUid,
    required this.room,
  });

  final CloudSync _cloud;
  final User _expectedUser;
  final String ownerUid;
  final DocumentSnapshot<Map<String, dynamic>> room;

  DocumentReference<Map<String, dynamic>> get _lock =>
      _cloud._roomDeletionLocks.doc(room.id);

  Future<void> _verify() async {
    _cloud._verifyAnonymousCleanupIdentity(
      ownerUid: ownerUid,
      expectedUser: _expectedUser,
    );
    if (room.data()?['uid'] != ownerUid) {
      throw StateError('The room owner changed during identity cleanup.');
    }
  }

  @override
  Future<void> createServerDeletionFence() async {
    await _verify();
    await _lock.set({
      'uid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _verify();
  }

  @override
  Future<void> drainPrivateChildren() async {
    await _verify();
    final roomData = room.data();
    final mediaPaths = <String>[
      for (final key in const ['profilePhotoPath', 'seasonPhotoPath'])
        if (roomData?[key] is String && (roomData![key] as String).isNotEmpty)
          roomData[key] as String,
    ];
    if (kVisitorPhotoSharingEnabled && mediaPaths.isNotEmpty) {
      await SharedRoomMediaService.instance.deleteObjectPaths(mediaPaths);
      await _verify();
    }
    await _cloud._deleteRoomPrivateChildren(
      room.reference,
      verifyIdentity: _verify,
    );
    await _verify();
  }

  @override
  Future<void> deleteParentAndFenceAtomically() async {
    await _verify();
    final batch = FirebaseFirestore.instance.batch()
      ..delete(_cloud._discoverableSpaces.doc(room.id))
      ..delete(room.reference)
      ..delete(_lock);
    await batch.commit();
    await _verify();
  }
}
