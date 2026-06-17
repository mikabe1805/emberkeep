import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'models.dart';

/// Local-first persistence (zero-cost infra): one JSON blob in
/// shared_preferences (localStorage on web). Graduates to Drift/SQLite in
/// Phase 1 when history outgrows a blob.
abstract final class Storage {
  static const _key = 'liferpg_save_v1';

  /// Save-format version. BUMP whenever new persisted fields are added so the
  /// cloud-merge can refuse to adopt an OLDER build's save that would have
  /// silently stripped fields it doesn't know about (bug-hunt §5).
  static const schema = 2;

  /// Where an unparseable save is quarantined before a fresh start, so a
  /// corrupt blob is never silently destroyed (it may be hand-recoverable).
  static const _corruptKey = 'liferpg_save_corrupt';

  /// Top-level marker so [importRaw] can reject foreign/garbage JSON that
  /// happens to parse — a bad paste must never silently replace a real save.
  static const _marker = 'emberkeep';

  static Future<void> save(GameState state, List<Quest> quests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'app': _marker,
          'schema': schema,
          'state': state.toJson(),
          'quests': [for (final q in quests) q.toJson()],
        }),
      );
    } catch (e) {
      debugPrint('Storage.save failed: $e');
    }
  }

  /// Returns null on first run (or unreadable save → fresh start). If a save
  /// EXISTS but won't parse, it's quarantined to [_corruptKey] first so the
  /// user's bytes aren't lost to a transient/partial-write corruption.
  static Future<(GameState, List<Quest>)?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      try {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final state =
            GameState.fromJson((j['state'] as Map).cast<String, dynamic>());
        final quests = [
          for (final q in (j['quests'] as List? ?? const []))
            Quest.fromJson((q as Map).cast<String, dynamic>()),
        ];
        return (state, quests);
      } catch (parseErr) {
        // a save existed but is unreadable — preserve it, don't destroy it.
        // Keep the FIRST quarantine (most likely to hold real history); a
        // later corruption must not clobber the better recoverable copy.
        debugPrint('Storage.load: save unparseable, quarantining: $parseErr');
        if (prefs.getString(_corruptKey) == null) {
          await prefs.setString(_corruptKey, raw);
        }
        return null;
      }
    } catch (e) {
      debugPrint('Storage.load failed (fresh start): $e');
      return null;
    }
  }

  /// A quarantined corrupt save, if one exists (for recovery tooling).
  static Future<String?> corruptBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_corruptKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('Storage.clear failed: $e');
    }
  }

  /// Does [raw] decode as a real Emberkeep save? Used to refuse mirroring a
  /// corrupt/foreign blob to the cloud (same gates as [importRaw]).
  static bool isValidSave(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (j['app'] != _marker) return false;
      final state = (j['state'] as Map?)?.cast<String, dynamic>();
      return state != null && state['stats'] is List;
    } catch (_) {
      return false;
    }
  }

  /// Clears a quarantined corrupt save once the user has dealt with it.
  static Future<void> clearCorruptBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_corruptKey);
    } catch (_) {/* best effort */}
  }

  /// The save-format version of a raw blob (0 = absent/oldest). Lets cloud
  /// merge refuse to adopt an older-schema save even if its timestamp is newer.
  static int schemaOf(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return (j['schema'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// The wall-clock ms a raw save was last written (cloud-sync newness
  /// signal). 0 if absent/unparseable.
  static int lastModifiedOf(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final state = (j['state'] as Map?)?.cast<String, dynamic>();
      return (state?['lastModified'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// The raw save blob, for user-held backups (round-8: your data is yours).
  static Future<String?> exportRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (e) {
      debugPrint('Storage.exportRaw failed: $e');
      return null;
    }
  }

  /// Restores a pasted backup. Validates by marker AND full decode before
  /// writing — a bad paste (even structurally-valid-but-foreign JSON) never
  /// destroys the current save.
  static Future<bool> importRaw(String raw) async {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      // gate 1: our marker — rejects {} / {state:{},quests:[]} / foreign JSON
      if (j['app'] != _marker) {
        debugPrint('Storage.importRaw rejected: not an Emberkeep save');
        return false;
      }
      // gate 2: the state must actually carry a save (a real character has
      // a stats array; an empty {} does not)
      final state = (j['state'] as Map?)?.cast<String, dynamic>();
      if (state == null || state['stats'] is! List) {
        debugPrint('Storage.importRaw rejected: missing state');
        return false;
      }
      // gate 3: full decode must succeed for every quest, or reject wholesale
      GameState.fromJson(state);
      for (final q in (j['quests'] as List? ?? const [])) {
        Quest.fromJson((q as Map).cast<String, dynamic>());
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, raw);
      return true;
    } catch (e) {
      debugPrint('Storage.importRaw rejected: $e');
      return false;
    }
  }
}
