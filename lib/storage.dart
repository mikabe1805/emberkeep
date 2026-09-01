import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'clock.dart';
import 'content/goal_catalog.dart';
import 'models.dart';
import 'tokens.dart';

/// The only safe outcomes after comparing a local save with its cloud mirror.
enum CloudMergeDecision { adoptRemote, pushLocal, hold }

/// Local-first persistence (zero-cost infra): one JSON blob in
/// shared_preferences (localStorage on web). Graduates to Drift/SQLite in
/// Phase 1 when history outgrows a blob.
abstract final class Storage {
  static const _key = 'liferpg_save_v1';

  /// Save-format version. BUMP whenever new persisted fields are added so the
  /// cloud-merge can refuse to adopt an OLDER build's save that would have
  /// silently stripped fields it doesn't know about (bug-hunt §5).
  static const schema = 28; // retains the bounded legacy room field

  /// Where an unparseable save is quarantined before a fresh start, so a
  /// corrupt blob is never silently destroyed (it may be hand-recoverable).
  static const _corruptKey = 'liferpg_save_corrupt';

  /// Top-level marker so [importRaw] can reject foreign/garbage JSON that
  /// happens to parse — a bad paste must never silently replace a real save.
  static const _marker = 'emberkeep';

  /// Returns false when the platform declined the write. Callers must not
  /// publish or export an older blob as though this state had been saved.
  static Future<bool> save(
    GameState state,
    List<Quest> quests, {
    bool freshBootstrap = false,
  }) async {
    try {
      // Capture synchronously. The live state may mutate while the preferences
      // plugin resolves, and a save request must represent one coherent frame.
      final raw = jsonEncode({
        'app': _marker,
        'schema': schema,
        'state': state.toJson(),
        'quests': [for (final q in quests) q.toJson()],
        if (freshBootstrap) 'freshBootstrap': true,
      });
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_key, raw);
    } catch (e) {
      debugPrint('Storage.save failed: $e');
      return false;
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
        if (!_hasRequiredStateFields(j)) {
          throw const FormatException('save is missing required state fields');
        }
        final state = GameState.fromJson(
          (j['state'] as Map).cast<String, dynamic>(),
        );
        final quests = [
          for (final q in (j['quests'] as List? ?? const []))
            Quest.fromJson((q as Map).cast<String, dynamic>()),
        ];
        for (final quest in quests) {
          enrichLegacyCuratedJournalQuest(quest);
        }
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

  static Future<bool> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_key);
    } catch (e) {
      debugPrint('Storage.clear failed: $e');
      return false;
    }
  }

  /// Does [raw] decode as a real Room of Days save? Used to refuse mirroring a
  /// corrupt/foreign blob to the cloud (same gates as [importRaw]).
  static bool isValidSave(String raw) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (j['app'] != _marker) return false;
      final encodedSchema = j['schema'];
      if (encodedSchema != null &&
          (encodedSchema is! int || encodedSchema < 0)) {
        return false;
      }
      if (!_hasRequiredStateFields(j)) return false;
      final state = (j['state'] as Map).cast<String, dynamic>();
      GameState.fromJson(state);
      for (final q in (j['quests'] as List? ?? const [])) {
        Quest.fromJson((q as Map).cast<String, dynamic>());
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pure last-write-wins decision for the cloud mirror, with schema safety.
  ///
  /// A newer remote may be adopted only when its schema is at least as new as
  /// the local blob's. This deliberately lets two legacy-schema saves merge
  /// (the adopted one is migrated by the caller), while holding an ambiguous
  /// newer-remote conflict such as local schema 19 versus remote schema 18.
  /// Neither side may overwrite an unreadable or future-format save.
  static CloudMergeDecision decideCloudMerge({
    required String? localRaw,
    required String? remoteRaw,
  }) {
    if (localRaw == null || !isValidSave(localRaw)) {
      return CloudMergeDecision.hold;
    }
    final localSchema = schemaOf(localRaw);
    if (localSchema > schema) return CloudMergeDecision.hold;

    if (remoteRaw == null) return CloudMergeDecision.pushLocal;
    if (!isValidSave(remoteRaw)) return CloudMergeDecision.hold;
    final remoteSchema = schemaOf(remoteRaw);
    if (remoteSchema > schema) return CloudMergeDecision.hold;

    final localModified = lastModifiedOf(localRaw);
    final remoteModified = lastModifiedOf(remoteRaw);
    if (remoteModified > localModified) {
      return remoteSchema >= localSchema
          ? CloudMergeDecision.adoptRemote
          : CloudMergeDecision.hold;
    }
    return localSchema >= remoteSchema
        ? CloudMergeDecision.pushLocal
        : CloudMergeDecision.hold;
  }

  /// A fresh installation writes a syntactically valid bootstrap save before
  /// cloud startup. It has no user history, so a valid remote is allowed to
  /// win even when it predates this schema. Once any ordinary local save lands,
  /// the marker disappears and [decideCloudMerge] again protects local work.
  static CloudMergeDecision decideInitialCloudMerge({
    required String? localRaw,
    required String? remoteRaw,
  }) {
    if (!isFreshBootstrapSave(localRaw)) {
      return decideCloudMerge(localRaw: localRaw, remoteRaw: remoteRaw);
    }
    if (remoteRaw == null) return CloudMergeDecision.pushLocal;
    if (!isValidSave(remoteRaw) || schemaOf(remoteRaw) > schema) {
      return CloudMergeDecision.hold;
    }
    return CloudMergeDecision.adoptRemote;
  }

  /// True only for the one local placeholder created before first cloud pull.
  /// Imported saves are normalized to remove this marker, so a backup can
  /// never make a later cloud pull discard deliberate local work.
  static bool isFreshBootstrapSave(String? raw) {
    if (raw == null || !isValidSave(raw)) return false;
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return j['freshBootstrap'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Clears a quarantined corrupt save once the user has dealt with it.
  static Future<bool> clearCorruptBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_corruptKey);
    } catch (e) {
      debugPrint('Storage.clearCorruptBackup failed: $e');
      return false;
    }
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

  static bool _hasRequiredStateFields(Map<String, dynamic> save) {
    final state = (save['state'] as Map?)?.cast<String, dynamic>();
    if (state == null || state['stats'] is! List) return false;
    final encodedSchema = save['schema'];
    final saveSchema = encodedSchema is int ? encodedSchema : 0;
    // Schema 28 distinguishes an explicit legacy field from a truncated state
    // map. Earlier backups predate it and migrate to an empty list.
    return saveSchema < 28 || state['roomKeepsakes'] is List;
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
        debugPrint('Storage.importRaw rejected: not a Room of Days backup');
        return false;
      }
      final encodedSchema = j['schema'];
      if (encodedSchema != null &&
          (encodedSchema is! int || encodedSchema < 0)) {
        debugPrint('Storage.importRaw rejected: invalid schema');
        return false;
      }
      // Never accept data a newer app understands better than this one. The
      // next ordinary save would otherwise rewrite the backup and lose its
      // unknown fields.
      if (encodedSchema is int && encodedSchema > schema) {
        debugPrint('Storage.importRaw rejected: backup needs a newer build');
        return false;
      }
      // gate 2: the state must actually carry a save (a real character has
      // a stats array; an empty {} does not)
      if (!_hasRequiredStateFields(j)) {
        debugPrint('Storage.importRaw rejected: missing state');
        return false;
      }
      final state = (j['state'] as Map).cast<String, dynamic>();
      // gate 3: full decode must succeed for every quest, or reject wholesale
      GameState.fromJson(state);
      for (final q in (j['quests'] as List? ?? const [])) {
        Quest.fromJson((q as Map).cast<String, dynamic>());
      }
      final prefs = await SharedPreferences.getInstance();
      // A hand-held backup is a deliberate local choice, never a fresh-device
      // placeholder. Strip the internal marker before it can reach cloud
      // merge on the next launch.
      final normalized = Map<String, dynamic>.from(j)..remove('freshBootstrap');
      await prefs.setString(_key, jsonEncode(normalized));
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
  static Future<void> logEvent(
    String type, [
    List<Object?> payload = const [],
  ]) async {
    try {
      final now = Clock.now();
      final buf = await _usageList();
      buf.add(<Object?>[Days.key(now), now.hour, type, ...payload]);
      if (buf.length > _usageCap) {
        buf.removeRange(0, buf.length - _usageCap);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _usageKey,
        jsonEncode({'schema': usageSchema, 'events': buf}),
      );
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
  static Future<bool> clearUsage() async {
    _usage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_usageKey);
    } catch (e) {
      debugPrint('Storage.clearUsage failed: $e');
      return false;
    }
  }
}
