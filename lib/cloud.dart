import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class CloudSync extends ChangeNotifier {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  bool ready = false;

  /// A lightweight anonymous Firebase session may exist for explicitly-used
  /// social features while backup remains off. This distinction keeps
  /// visiting and sharing from silently opting a device into cloud saves.
  bool get socialReady => _uid != null;

  /// The anonymous owner ID is exposed only at the validated sharing boundary.
  /// It is never displayed as profile identity or included in invite copy.
  String? get socialUid => _uid;

  /// Firebase initialized successfully, even if this device is intentionally
  /// staying local-only. This lets the UI distinguish an opt-out from offline.
  bool available = false;
  bool optedIn = false;
  static const _cloudEnabledKey = 'emberkeep_cloud_enabled';
  static const _pendingRoomCleanupKey = 'emberkeep_pending_room_cleanup';

  /// Human-readable status for the Me page's YOUR DATA panel.
  String status = 'connecting…';
  DateTime? lastSynced;

  String? _uid;
  Future<void>? _initFuture;
  Future<FirebaseApp>? _firebaseBootstrapFuture;
  Future<bool>? _socialSessionFuture;
  Future<void>? _authChangeFuture;
  Timer? _debounce;
  Timer? _roomDebounce;
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
  Future<String?> enable() async {
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
    while (true) {
      final authChange = _authChangeFuture;
      if (authChange != null) {
        await authChange;
        continue;
      }
      if (socialReady) return true;
      final active = _socialSessionFuture;
      if (active != null) return active;
      final attempt = _startSocialSession();
      _socialSessionFuture = attempt;
      try {
        return await attempt;
      } finally {
        if (identical(_socialSessionFuture, attempt)) {
          _socialSessionFuture = null;
        }
      }
    }
  }

  /// Serializes every Firebase identity mutation with anonymous social-session
  /// startup. This keeps FirebaseAuth.currentUser and [_uid] from ever being
  /// assigned by two competing sign-in completions.
  Future<T> _runAuthChange<T>(Future<T> Function() action) async {
    while (true) {
      final authChange = _authChangeFuture;
      if (authChange != null) {
        await authChange;
        continue;
      }
      final socialSession = _socialSessionFuture;
      if (socialSession != null) {
        await socialSession;
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

  Future<bool> _startSocialSession() async {
    if (socialReady) return true;
    try {
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        _uid = existing.uid;
      } else {
        final cred = await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 8),
        );
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
  String? get accountEmail => _accountEmail;

  bool get isSignedIn => _accountEmail != null;

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
  Future<String?> linkAccount(String email, String password) =>
      _runAuthChange(() => _linkAccount(email, password));

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
  Future<String?> signIn(String email, String password) =>
      _runAuthChange(() => _signIn(email, password));

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
  Future<bool> signOut({bool saveAccount = true}) =>
      _runAuthChange(() => _signOut(saveAccount: saveAccount));

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
      _runAuthChange(() => _deleteAccount(password, roomCode: roomCode));

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

  /// Keep an already-published appearance card fresh without writing on every
  /// tap. Saves remain the source of truth; this is a separate, privacy-safe
  /// five-second debounce for Circle presence and room progress only.
  void queueRoomUpdate(Map<String, dynamic> display, {required String? code}) {
    if (!socialReady || code == null || code.isEmpty) return;
    final clean = _cleanRoomCode(code);
    if (clean == null) return;
    _roomDebounce?.cancel();
    final snapshot = Map<String, dynamic>.from(display);
    _roomDebounce = Timer(
      const Duration(seconds: 5),
      () => shareRoom(snapshot, code: clean),
    );
  }

  void flushRoom(Map<String, dynamic> display, {required String? code}) {
    if (!socialReady || code == null || code.isEmpty) return;
    final clean = _cleanRoomCode(code);
    if (clean == null) return;
    _roomDebounce?.cancel();
    unawaited(shareRoom(Map<String, dynamic>.from(display), code: clean));
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
  }) {
    final snapshot = Map<String, dynamic>.from(display);
    return _roomPublishQueue.run(
      () => _publishRoomNow(
        snapshot,
        code: code,
        skipCurrentVersion: skipCurrentVersion,
      ),
    );
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
              await _rooms
                  .doc(clean)
                  .set(data)
                  .timeout(const Duration(seconds: 8));
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
          await _rooms
              .doc(candidateCode)
              .set(newRoomData)
              .timeout(const Duration(seconds: 8));
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
    final parent = await room.get().timeout(const Duration(seconds: 8));
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
    for (final collectionName in const ['sparks', 'circleAdds']) {
      while (true) {
        final page = await room
            .collection(collectionName)
            .limit(400)
            .get()
            .timeout(const Duration(seconds: 8));
        if (page.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit().timeout(const Duration(seconds: 8));
        if (page.docs.length < 400) break;
      }
    }
    await room.delete().timeout(const Duration(seconds: 8));
    return _OwnedRoomDeleteResult.deleted;
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
      if (record != null) records.add(record);
    }
    return records;
  }

  Future<void> _writePendingRoomCleanups(
    SharedPreferences prefs,
    List<_PendingRoomCleanup> records,
  ) async {
    if (records.isEmpty) {
      await prefs.remove(_pendingRoomCleanupKey);
      return;
    }
    await prefs.setStringList(_pendingRoomCleanupKey, [
      for (final record in records) record.encoded,
    ]);
  }

  Future<void> _rememberPendingRoomCleanup(
    SharedPreferences prefs,
    String code,
  ) async {
    final owner = _uid;
    if (owner == null) return;
    final records = _pendingRoomCleanups(prefs);
    if (!records.any(
      (record) => record.owner == owner && record.code == code,
    )) {
      records.add(_PendingRoomCleanup(owner: owner, code: code));
      await _writePendingRoomCleanups(prefs, records);
    }
  }

  Future<void> _forgetPendingRoomCleanup(
    SharedPreferences prefs,
    String code,
  ) async {
    final owner = _uid;
    final records = _pendingRoomCleanups(
      prefs,
    ).where((record) => record.owner != owner || record.code != code).toList();
    await _writePendingRoomCleanups(prefs, records);
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
        if (result == _OwnedRoomDeleteResult.notOwned) {
          // Never discard the only evidence of a room that could still be
          // public. This identity cannot remove it, so a later auth change
          // must stop rather than falsely calling cleanup complete.
          remaining.add(record);
          debugPrint('CloudSync pending room cleanup is owned by another uid');
        }
      } catch (e) {
        remaining.add(record);
        debugPrint('CloudSync pending room cleanup will retry: $e');
      }
    }
    await _writePendingRoomCleanups(prefs, remaining);
    return !remaining.any((record) => record.owner == owner);
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
  Future<bool> resetProfile({String? roomCode}) =>
      _runAuthChange(() => _resetProfile(roomCode: roomCode));

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
          await _rememberPendingRoomCleanup(cleanupPrefs, cleanRoomCode);
        }
        final removed = await _deleteOwnedRoom(cleanRoomCode);
        if (removed == _OwnedRoomDeleteResult.deleted ||
            removed == _OwnedRoomDeleteResult.absent) {
          if (cleanupPrefs != null) {
            await _forgetPendingRoomCleanup(cleanupPrefs, cleanRoomCode);
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
