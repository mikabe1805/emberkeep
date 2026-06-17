import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Event-typed sound palette (DESIGN.md §8). Sounds are always paired with
/// visuals, so every call is fire-and-forget and failure-tolerant — a muted
/// or audio-broken device loses nothing.
///
/// All wavs are pooled (preloaded + decoded) so rare, high-magnitude events
/// (crit, levelup, loot) land frame-synced with their visual beat instead of
/// paying asset-load latency at the worst possible moment.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  static const _all = [
    'tick', 'complete', 'streak', 'crit', 'loot', 'levelup', 'boing',
    'stat_0', 'stat_1', 'stat_2', 'stat_3', 'stat_4', 'stat_5',
  ];
  final Map<String, AudioPool> _pools = {};

  Future<void> init() async {
    // Parallel loads; each pool becomes playable as soon as it lands, and
    // one failed asset never mutes the others.
    await Future.wait(_all.map((name) async {
      try {
        _pools[name] = await AudioPool.createFromAsset(
          path: 'sfx/$name.wav',
          maxPlayers: 4,
        );
      } catch (e) {
        debugPrint('Sfx pool "$name" failed (continuing silent): $e');
      }
    }));
  }

  /// names: tick, complete, streak, crit, loot, levelup, boing, stat_0..5
  void play(String name) {
    try {
      final pool = _pools[name];
      if (pool != null) {
        pool.start().catchError((Object e) {
          debugPrint('Sfx "$name" failed: $e');
          return () async {};
        });
      } else {
        // Pool missing (failed or still loading): best-effort one-shot.
        final p = AudioPlayer();
        p.onPlayerComplete.first.then((_) => p.dispose());
        p.play(AssetSource('sfx/$name.wav')).catchError((Object e) {
          debugPrint('Sfx "$name" fallback failed: $e');
          p.dispose();
        });
      }
    } catch (e) {
      debugPrint('Sfx "$name" failed: $e');
    }
  }
}
