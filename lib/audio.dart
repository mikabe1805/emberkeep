import 'dart:async' show unawaited;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// Event-typed sound palette (DESIGN.md §8). Sounds are always paired with
/// visuals, so every call is fire-and-forget and failure-tolerant — a muted
/// or audio-broken device loses nothing.
///
/// Native wavs are pooled (preloaded + decoded) so rare, high-magnitude events
/// land frame-synced with their visual beat. Browsers warm each event sound on
/// first use instead of competing with the first interactive room frame.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  static const _all = [
    'tick',
    'tick_warm',
    'tick_lift',
    'complete',
    'streak',
    'crit',
    'loot',
    'levelup',
    'boing',
    'hearth',
    'stat_0',
    'stat_1',
    'stat_2',
    'stat_3',
    'stat_4',
    'stat_5',
  ];

  /// Per-sound volume — the palette plays SOFT (owner feedback: it felt harsh).
  /// The press 'tick' fires on every tap, so it stays quiet; reward beats sit
  /// gently above it; only the rare big moments approach full.
  ///
  /// The everyday tick is now a very short tactile tap rather than the former
  /// single-frequency sine blip. Its softened contact transient gives a button
  /// physical presence, while a warm low resonance and fast tail keep repeated
  /// navigation from becoming metallic or tiring. See assets/sfx/SOURCES.md.
  static const _volume = <String, double>{
    'tick': 0.16,
    'complete': 0.55,
    'streak': 0.55,
    'boing': 0.4,
    // Full volume marks a genuinely revived hearth. Room navigation reuses the
    // cue once at a much quieter scale; it never starts a background loop.
    'hearth': 0.68,
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
  final Map<String, Future<AudioPool?>> _poolLoads = {};

  // Everyday taps form a tiny six-beat cadence: neutral and warmer contacts
  // alternate, then the sixth interaction gets a barely brighter lift. It is
  // deterministic rather than random, so clicking around feels alive without
  // the interface becoming musically noisy or unpredictable.
  static const _tickCadence = [
    'tick',
    'tick_warm',
    'tick',
    'tick_warm',
    'tick',
    'tick_lift',
  ];
  int _tickBeat = 0;

  String _assetFor(String name) {
    if (name != 'tick') return name;
    final asset = _tickCadence[_tickBeat];
    _tickBeat = (_tickBeat + 1) % _tickCadence.length;
    return asset;
  }

  /// Sound enabled flag — set from GameState.soundEnabled.
  bool soundEnabled = true;

  Future<void> init() async {
    // Some embedded/automation WebKit builds expose CanvasKit but no Web Audio
    // constructor. Treat sound as an unavailable enhancement there instead of
    // throwing once per tap and repeatedly attempting pools that cannot load.
    if (kIsWeb && !browserAudioAvailable) return;

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

    // A browser cannot play before a gesture anyway. Eagerly constructing all
    // sixteen pools made a first visit fetch every wav (and several byte-range
    // copies) while Flutter was decoding the room and accepting the first tap.
    // Native keeps its frame-synchronous preload; web warms only sounds the
    // person actually reaches.
    if (kIsWeb) return;

    // Parallel loads; each pool becomes playable as soon as it lands, and
    // one failed asset never mutes the others.
    await Future.wait(_all.map(_loadPool));
  }

  Future<AudioPool?> _loadPool(String name) {
    final loaded = _pools[name];
    if (loaded != null) return Future.value(loaded);
    final active = _poolLoads[name];
    if (active != null) return active;

    late final Future<AudioPool?> attempt;
    attempt = () async {
      try {
        final pool = await AudioPool.createFromAsset(
          path: 'sfx/$name.wav',
          maxPlayers: 4,
        );
        _pools[name] = pool;
        return pool;
      } catch (e) {
        debugPrint('Sfx pool "$name" failed (continuing silent): $e');
        return null;
      } finally {
        _poolLoads.remove(name);
      }
    }();
    _poolLoads[name] = attempt;
    return attempt;
  }

  /// names: tick, complete, streak, crit, loot, levelup, boing, hearth,
  /// stat_0..5. [volumeScale] lets ambient echoes reuse a sound without
  /// competing with the user's music; event calls normally leave it at 1.
  void play(String name, {double volumeScale = 1}) {
    if (!soundEnabled || (kIsWeb && !browserAudioAvailable)) return;
    try {
      final vol = (_volFor(name) * volumeScale).clamp(0.0, 1.0);
      final asset = _assetFor(name);
      final pool = _pools[asset];
      if (pool != null) {
        pool.start(volume: vol).catchError((Object e) {
          debugPrint('Sfx "$name" ($asset) failed: $e');
          return () async {};
        });
      } else {
        // Pool missing (failed, still loading, or intentionally lazy on web):
        // best-effort one-shot now, and keep a pool warm for the next use.
        unawaited(_loadPool(asset));
        final p = AudioPlayer();
        p.onPlayerComplete.first.then((_) => p.dispose());
        p.play(AssetSource('sfx/$asset.wav'), volume: vol).catchError((
          Object e,
        ) {
          debugPrint('Sfx "$name" ($asset) fallback failed: $e');
          p.dispose();
        });
      }
    } catch (e) {
      debugPrint('Sfx "$name" failed: $e');
    }
  }
}
