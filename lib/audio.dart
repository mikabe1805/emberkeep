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
    'tick',
    'complete',
    'streak',
    'crit',
    'loot',
    'levelup',
    'boing',
    'stat_0',
    'stat_1',
    'stat_2',
    'stat_3',
    'stat_4',
    'stat_5',
  ];

  /// Per-sound volume — the palette plays SOFT (owner feedback: it felt harsh).
  /// The press 'tick' fires on every tap, so it's nearly a whisper; reward
  /// beats sit gently above it; only the rare big moments approach full.
  /// (round-53: the assets are now rendered from REAL recorded notes — soft
  /// Marimba + Glockenspiel from VCSL, the CC0 Versilian Community Sample
  /// Library (github.com/sgossner/VCSL) — trimmed, enveloped and lightly
  /// reverbed by tools/gen_sfx_samples.py. Real wood/bell timbre is warm in a
  /// way synth sines never were; softness now comes from the sound itself, not
  /// just these multipliers. Superseded round-51's synthesized tones.)
  static const _volume = <String, double>{
    'tick': 0.3,
    'complete': 0.55,
    'streak': 0.55,
    'boing': 0.4,
    'stat_0': 0.45,
    'stat_1': 0.45,
    'stat_2': 0.45,
    'stat_3': 0.45,
    'stat_4': 0.45,
    'stat_5': 0.45,
    'crit': 0.75,
    'loot': 0.65,
    'levelup': 0.7,
  };
  static double _volFor(String name) => _volume[name] ?? 0.55;

  final Map<String, AudioPool> _pools = {};

  Future<void> init() async {
    // FIRST, before any pool ever activates the audio session: make our SFX
    // mix WITH the user's own music instead of evicting it. audioplayers
    // defaults the iOS AVAudioSession to `.playback` (non-mixable), so the
    // first sound at launch was stopping the user's Spotify/Apple Music.
    // `ambient` is the canonical category for incidental game sound: it mixes
    // over other audio and respects the hardware Ring/Silent switch (we lose
    // nothing if muted — see the class doc). On Android we never grab audio
    // focus, so background music is never ducked or paused.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            // Do NOT pass mixWithOthers explicitly here: for the `ambient`
            // category iOS mixes implicitly, and AudioContextIOS asserts in
            // debug if options are combined with a non-playback category.
            options: const {},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Sfx audio context (continuing): $e');
    }

    // Parallel loads; each pool becomes playable as soon as it lands, and
    // one failed asset never mutes the others.
    await Future.wait(
      _all.map((name) async {
        try {
          _pools[name] = await AudioPool.createFromAsset(
            path: 'sfx/$name.wav',
            maxPlayers: 4,
          );
        } catch (e) {
          debugPrint('Sfx pool "$name" failed (continuing silent): $e');
        }
      }),
    );
  }

  /// names: tick, complete, streak, crit, loot, levelup, boing, stat_0..5
  void play(String name) {
    try {
      final vol = _volFor(name);
      final pool = _pools[name];
      if (pool != null) {
        pool.start(volume: vol).catchError((Object e) {
          debugPrint('Sfx "$name" failed: $e');
          return () async {};
        });
      } else {
        // Pool missing (failed or still loading): best-effort one-shot.
        final p = AudioPlayer();
        p.onPlayerComplete.first.then((_) => p.dispose());
        p.play(AssetSource('sfx/$name.wav'), volume: vol).catchError((
          Object e,
        ) {
          debugPrint('Sfx "$name" fallback failed: $e');
          p.dispose();
        });
      }
    } catch (e) {
      debugPrint('Sfx "$name" failed: $e');
    }
  }
}
