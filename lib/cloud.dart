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
import 'storage.dart';

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

  /// Firebase initialized successfully, even if this device is intentionally
  /// staying local-only. This lets the UI distinguish an opt-out from offline.
  bool available = false;
  bool optedIn = false;
  static const _cloudEnabledKey = 'emberkeep_cloud_enabled';

  /// Human-readable status for the Me page's YOUR DATA panel.
  String status = 'connecting…';
  DateTime? lastSynced;

  String? _uid;
  Timer? _debounce;
  Timer? _roomDebounce;
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

  Future<void> init() async {
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
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
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
        final cred = await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 8),
        );
        _uid = cred.user?.uid;
        optedIn = true;
      } else {
        _uid = null;
        optedIn = false;
      }
      _refreshAccountEmail();
      ready = _uid != null && optedIn;
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
    if (!available) return 'Cloud is out of reach right now.';
    if (ready) return null;
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
    if (socialReady) return true;
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously().timeout(
        const Duration(seconds: 8),
      );
      _uid = cred.user?.uid;
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
  Future<String?> linkAccount(String email, String password) async {
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
  Future<String?> signIn(String email, String password) async {
    if (!available) return 'Cloud is offline right now.';
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
  Future<void> signOut({bool saveAccount = true}) async {
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
    } catch (e) {
      debugPrint('signOut failed: $e');
    }
  }

  /// Permanently removes the signed-in Firebase account and its cloud data.
  /// The on-device keep is intentionally left intact; the caller detaches its
  /// share code and persists it under the fresh anonymous session.
  Future<String?> deleteAccount(String password, {String? roomCode}) async {
    if (!ready) return 'Cloud is offline right now.';
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || user.isAnonymous || email == null) {
      return 'No signed-in account to delete.';
    }
    cancelPending();
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      if (roomCode != null && roomCode.isNotEmpty) {
        await _rooms.doc(roomCode).delete();
      }
      await _doc.delete();
      await user.delete();
      final fresh = await FirebaseAuth.instance.signInAnonymously();
      _uid = fresh.user?.uid;
      _savePushHeld = false;
      _refreshAccountEmail();
      ready = _uid != null;
      status = ready ? _statusForUser() : 'off';
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _friendlyAuth(e);
    } catch (e) {
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
  final _rng = Random();

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
    _roomDebounce?.cancel();
    final snapshot = Map<String, dynamic>.from(display);
    _roomDebounce = Timer(
      const Duration(seconds: 5),
      () => shareRoom(snapshot, code: code),
    );
  }

  void flushRoom(Map<String, dynamic> display, {required String? code}) {
    if (!socialReady || code == null || code.isEmpty) return;
    _roomDebounce?.cancel();
    unawaited(shareRoom(Map<String, dynamic>.from(display), code: code));
  }

  /// Publish (or update) your space's appearance to a public room doc. Pass the
  /// existing [code] to refresh it in place; otherwise a fresh short code is
  /// reserved (retrying on the astronomically-rare collision). Returns the
  /// share code, or null if the cloud is offline / it failed.
  Future<String?> shareRoom(
    Map<String, dynamic> display, {
    String? code,
  }) async {
    if (!socialReady || _uid == null) return null;
    final data = {
      ...display,
      'uid': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      if (code != null && code.isNotEmpty) {
        await _rooms.doc(code).set(data);
        return code;
      }
      for (var i = 0; i < 6; i++) {
        final c = _genCode();
        try {
          // set() on an ABSENT doc is a create (allowed); on someone else's
          // it's an update → permission-denied → try another code.
          await _rooms.doc(c).set(data);
          return c;
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') continue;
          rethrow;
        }
      }
      return null;
    } catch (e) {
      debugPrint('shareRoom failed: $e');
      return null;
    }
  }

  /// Read a shared space by code (case-insensitive). Null = not found / error.
  Future<Map<String, dynamic>?> fetchRoom(String code) async {
    if (!available) return null;
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
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
  Future<bool> unshareRoom(String code) async {
    if (!socialReady || code.isEmpty) return false;
    try {
      await _rooms.doc(code).delete();
      return true;
    } catch (e) {
      debugPrint('unshareRoom failed: $e');
      return false;
    }
  }

  /// Send one fixed, text-free encouragement. The security rules key the
  /// pending spark by sender uid, so one person cannot stack spam; the keeper
  /// must collect it before that sender can kindle them again.
  Future<bool> sendSpark(String code, {String kind = 'kindle'}) async {
    if (!socialReady || _uid == null) return false;
    const allowed = {'kindle', 'steady', 'cheer'};
    final safeKind = allowed.contains(kind) ? kind : 'kindle';
    try {
      await _rooms
          .doc(code.trim().toUpperCase())
          .collection('sparks')
          .doc(_uid)
          .set({
            'sender': _uid,
            'kind': safeKind,
            'sentAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('sendSpark failed: $e');
      return false;
    }
  }

  /// Only the owner of [code] may read these under firestore.rules.
  Future<List<Map<String, dynamic>>> fetchSparks(String code) async {
    if (!socialReady || _uid == null || code.isEmpty) return const [];
    try {
      final snap = await _rooms
          .doc(code.trim().toUpperCase())
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

  Future<bool> collectSparks(String code, Iterable<String> ids) async {
    if (!socialReady || _uid == null || code.isEmpty) return false;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in ids.take(20)) {
        batch.delete(
          _rooms.doc(code.trim().toUpperCase()).collection('sparks').doc(id),
        );
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('collectSparks failed: $e');
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
  Future<bool> resetProfile({String? roomCode}) async {
    if (!ready) return false;
    _debounce?.cancel();
    _roomDebounce?.cancel();
    var fullyErased = true;

    if (roomCode != null && roomCode.isNotEmpty) {
      try {
        await _rooms.doc(roomCode).delete();
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
    if (user?.isAnonymous == true) {
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
