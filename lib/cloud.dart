import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
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

  /// Human-readable status for the Me page's YOUR DATA panel.
  String status = 'connecting…';
  DateTime? lastSynced;

  String? _uid;
  Timer? _debounce;

  /// Cached signed-in email (null = anonymous). Cached rather than read from
  /// FirebaseAuth live, so the UI can query it safely before Firebase init.
  String? _accountEmail;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 8));
      // Server-ack-only writes: don't let cached writes masquerade as synced.
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
      // Reuse an existing session (a linked account, or a prior anonymous
      // one) — NEVER blindly re-sign-in anonymously, which would orphan a
      // linked account on every relaunch.
      final existing = FirebaseAuth.instance.currentUser;
      if (existing != null) {
        _uid = existing.uid;
      } else {
        final cred = await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 8));
        _uid = cred.user?.uid;
      }
      _refreshAccountEmail();
      ready = _uid != null;
      status = ready ? _statusForUser() : 'off';
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
      final cred =
          EmailAuthProvider.credential(email: email.trim(), password: password);
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
    if (!ready) return 'Cloud is offline right now.';
    // Drop any pending anonymous push — it must NOT land on the account's
    // document after the uid swaps and clobber the real save.
    cancelPending();
    try {
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      _uid = c.user?.uid;
      _refreshAccountEmail();
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
  Future<void> signOut() async {
    _debounce?.cancel();
    try {
      final raw = await Storage.exportRaw();
      if (raw != null && Storage.isValidSave(raw)) {
        await _doc.set({
          'data': raw,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('signOut final flush failed: $e');
    }
    try {
      await FirebaseAuth.instance.signOut();
      final cred = await FirebaseAuth.instance.signInAnonymously();
      _uid = cred.user?.uid;
      _refreshAccountEmail();
      status = _statusForUser();
      notifyListeners();
    } catch (e) {
      debugPrint('signOut failed: $e');
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
    if (!ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), _pushNow);
  }

  /// Push immediately, skipping the debounce — for app-pause/close, where a
  /// scheduled timer would be killed before it fires (the iOS-PWA data-lag
  /// trap). Fire-and-forget: the OS may suspend us mid-flight, but the
  /// request is at least dispatched.
  void flush() {
    if (!ready) return;
    _debounce?.cancel();
    _pushNow();
  }

  /// Cancel any pending push (used around a reset that will re-push fresh).
  void cancelPending() => _debounce?.cancel();

  Future<void> _pushNow() async {
    if (!ready) return;
    try {
      final raw = await Storage.exportRaw();
      if (raw == null) return;
      // NEVER mirror a corrupt/foreign blob — that would overwrite the one
      // good cloud backup with garbage, defeating disaster recovery exactly
      // when it matters.
      if (!Storage.isValidSave(raw)) {
        debugPrint('CloudSync: refusing to push an invalid save');
        return;
      }
      await _doc.set({
        'data': raw,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      lastSynced = DateTime.now();
      status = _statusForUser();
      notifyListeners();
    } catch (e) {
      status = 'on (last push failed)';
      notifyListeners();
      debugPrint('CloudSync push failed: $e');
    }
  }

  /// Wipe the cloud copy (an intentional reset should not be resurrectable).
  Future<void> deleteRemote() async {
    if (!ready) return;
    _debounce?.cancel();
    try {
      await _doc.delete();
    } catch (e) {
      debugPrint('CloudSync delete failed: $e');
    }
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
