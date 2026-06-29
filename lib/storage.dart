import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'models.dart';
import 'tokens.dart';

/// Local-first persistence (zero-cost infra): one JSON blob in
/// shared_preferences (localStorage on web). Graduates to Drift/SQLite in
/// Phase 1 when history outgrows a blob.
abstract final class Storage {
  static const _key = 'liferpg_save_v1';

  /// Save-format version. BUMP whenever new persisted fields are added so the
  /// cloud-merge can refuse to adopt an OLDER build's save that would have
  /// silently stripped fields it doesn't know about (bug-hunt §5).
  static const schema = 4; // r24: + per-domain notes, goal journals, quest logs

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

  // ── local usage log (round-21: "data taking agents") ──────────────────
  // A privacy-first, on-device event log the owner can EXPORT and hand to
  // Claude to find improvement ideas. Kept in a SEPARATE shared_preferences
  // key — NOT in the save blob — so it is never mirrored to the cloud
  // (CloudSync only pushes [_key]) and never inflates the Firestore doc.
  static const _usageKey = 'emberkeep_usage_v1';
  static const usageSchema = 1;
  static const _usageCap = 2000; // ~capped ring; oldest fall off first
  static List<dynamic>? _usage; // in-memory cache (lazy)

  /// FNV-1a 32-bit — a stable, non-reversible hash so a CUSTOM quest's title
  /// (which can hold personal text) never leaves the device in the clear.
  static String hashTitle(String t) {
    var h = 0x811c9dc5;
    for (final c in t.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'c#${h.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<List<dynamic>> _usageList() async {
    if (_usage != null) return _usage!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_usageKey);
      _usage = raw == null
          ? <dynamic>[]
          : (((jsonDecode(raw) as Map)['events'] as List?)?.toList() ??
              <dynamic>[]);
    } catch (_) {
      _usage = <dynamic>[];
    }
    return _usage!;
  }

  /// Append one compact event: [dayKey, hour, type, ...payload]. Coarse time
  /// (day + hour, never an exact timestamp) keeps the export low-stakes to
  /// share. Fire-and-forget; a logging failure never affects gameplay.
  static Future<void> logEvent(String type, [List<Object?> payload = const []]) async {
    try {
      final now = DateTime.now();
      final buf = await _usageList();
      buf.add(<Object?>[Days.key(now), now.hour, type, ...payload]);
      if (buf.length > _usageCap) {
        buf.removeRange(0, buf.length - _usageCap);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _usageKey, jsonEncode({'schema': usageSchema, 'events': buf}));
    } catch (e) {
      debugPrint('Storage.logEvent failed: $e');
    }
  }

  /// A self-describing export of the usage log — the JSON the owner copies and
  /// hands to Claude. Includes the legend so it's interpretable on its own.
  static Future<String?> usageExport() async {
    try {
      final buf = await _usageList();
      return const JsonEncoder.withIndent('  ').convert({
        'app': 'emberkeep-usage',
        'schema': usageSchema,
        'note':
            'On-device only — nothing was sent anywhere. Each event is '
                '[dayKey, hour(0-23), type, ...payload]. Custom quest titles '
                'are hashed (c#…) for privacy; catalog/default titles are plain.',
        'statLabels': [for (final s in Stat.values) s.abbr],
        'typeLegend': const {
          'open': 'app opened/resumed',
          'done': '[title|hash, statIndex, difficulty, verified(0/1)]',
          'snooze': '[title|hash] — hidden just for today',
          'undo': '[title|hash] — a completion undone',
          'goalAdd': '[goalTitle]',
        },
        'events': buf,
      });
    } catch (e) {
      debugPrint('Storage.usageExport failed: $e');
      return null;
    }
  }

  /// Wipes the usage log (called on "start over" — reset means erase me).
  static Future<void> clearUsage() async {
    _usage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usageKey);
    } catch (_) {/* best effort */}
  }
}
