import 'dart:async' show unawaited;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'platform/audio_support_stub.dart'
    if (dart.library.js_interop) 'platform/audio_support_web.dart';

/// Surface materials. Originally a legacy bridge that collapsed into the verb
/// grammar; as of the owner's 2026-08-21 texture direction ("interactable
/// surfaces [should] feel like different 'textures' of sound") a material is
/// a real routing axis again: each names a SHADING of the one approved Room
/// mechanism — same contact master, same reflection fingerprint, same pitch
/// walk, only the struck body changes. Never unrelated Foley.
///
/// wood = the shipped clasp (the everyday baseline, untouched);
/// stone = the weighted slate "dak" for faceted option chips and commits;
/// parchment = the page flick for travel between tabs/pages/modes;
/// glass = the small damped pair for switches and translucent surfaces;
/// brass = the felt-muted dyad, exclusive to gold.
enum MaterialSound { wood, stone, parchment, brass, glass }

/// Everyday interaction verbs. Every role inherits the same phone-approved X
/// contact/body/clasp; role changes are small weight changes inside that one
/// mechanism, never unrelated Foley.
enum InteractionSound { open, select, navigate, place }

/// The physically approved rare return. D5 appears twice in the four-note
/// cell, so only the three immutable note identities need production masters.
enum PairedReturnToken { d5, a5, e5 }

InteractionSound interactionForMaterial(MaterialSound material) =>
    switch (material) {
      MaterialSound.wood => InteractionSound.open,
      MaterialSound.stone => InteractionSound.navigate,
      MaterialSound.parchment => InteractionSound.open,
      MaterialSound.brass => InteractionSound.place,
      MaterialSound.glass => InteractionSound.select,
    };

class InteractionSoundSelection {
  const InteractionSoundSelection(
    this.asset,
    this.gain, {
    this.pairedReturnToken,
  });

  final String asset;
  final double gain;
  final PairedReturnToken? pairedReturnToken;
}

/// Global, deterministic routing for the approved five-take X family.
///
/// The variant walk crosses widget and role boundaries so clicking around feels
/// alive without turning each control into its own instrument. Runtime never
/// pitch-shifts a master. Fast legitimate taps retain their contacts but soften
/// by the exact cadence used in the physical-phone study. Plain X remains the
/// default; the phone-approved Paired Return can appear only after a bounded,
/// screen-scoped eligibility run.
class InteractionSoundRouter {
  InteractionSoundRouter();

  static const allAssets = <String>[
    'room/ordinary/open/1',
    'room/ordinary/open/2',
    'room/ordinary/open/3',
    'room/ordinary/open/4',
    'room/ordinary/open/5',
    'room/ordinary/select/1',
    'room/ordinary/select/2',
    'room/ordinary/select/3',
    'room/ordinary/select/4',
    'room/ordinary/select/5',
    'room/ordinary/navigate/1',
    'room/ordinary/navigate/2',
    'room/ordinary/navigate/3',
    'room/ordinary/navigate/4',
    'room/ordinary/navigate/5',
    'room/ordinary/place/1',
    'room/ordinary/place/2',
    'room/ordinary/place/3',
    'room/ordinary/place/4',
    'room/ordinary/place/5',
  ];

  static const _folders = <InteractionSound, String>{
    InteractionSound.open: 'open',
    InteractionSound.select: 'select',
    InteractionSound.navigate: 'navigate',
    InteractionSound.place: 'place',
  };
  static const _variantWalk = <int>[0, 2, 1, 3, 1, 4, 2, 0, 3, 4, 1, 2, 4, 0];
  static const _rapidGains = <double>[1, 0.93, 0.93, 0.885];
  static const pairedReturnPhrase = <PairedReturnToken>[
    PairedReturnToken.d5,
    PairedReturnToken.a5,
    PairedReturnToken.e5,
    PairedReturnToken.d5,
  ];
  static const _pairedReturnAssetTokens = <PairedReturnToken>[
    PairedReturnToken.d5,
    PairedReturnToken.a5,
    PairedReturnToken.e5,
  ];
  static final List<String> pairedReturnAssets = List<String>.unmodifiable([
    for (final token in _pairedReturnAssetTokens)
      for (final folder in _folders.values)
        for (var take = 1; take <= 5; take++)
          'room/paired_return/${token.name}/$folder/$take',
  ]);
  static const duplicateWindow = Duration(milliseconds: 18);
  static const rapidWindow = Duration(milliseconds: 180);
  static const pairedReturnEligibleMax = Duration(milliseconds: 700);
  static const pairedReturnCooldown = Duration(seconds: 90);
  static const pairedReturnAfterActions = 4;
  static final Object _fallbackScreen = Object();

  int _beat = 0;
  int _rapidBeat = 0;
  int? _lastVariant;
  DateTime? _lastAt;
  int _pairedReturnEligibleRun = 0;
  int? _pairedReturnIndex;
  Object? _pairedReturnScreen;
  DateTime? _lastPairedReturnAt;
  final Expando<bool> _pairedReturnEmitted = Expando<bool>(
    'Room Paired Return emitted',
  );

  InteractionSoundSelection? next(
    InteractionSound role, {
    DateTime? at,
    Object? screenId,
  }) {
    final now = at ?? DateTime.now();
    final previous = _lastAt;
    Duration? gap;
    if (previous != null) {
      gap = now.difference(previous);
      if (!gap.isNegative && gap < duplicateWindow) return null;
      _rapidBeat = !gap.isNegative && gap < rapidWindow ? _rapidBeat + 1 : 0;
    } else {
      _rapidBeat = 0;
    }
    _lastAt = now;

    var variant = _variantWalk[_beat % _variantWalk.length] + 1;
    _beat = (_beat + 1) % _variantWalk.length;
    if (variant == _lastVariant) {
      variant = _variantWalk[_beat % _variantWalk.length] + 1;
      _beat = (_beat + 1) % _variantWalk.length;
    }
    _lastVariant = variant;
    final folder = _folders[role]!;
    final gain =
        _rapidGains[_rapidBeat.clamp(0, _rapidGains.length - 1).toInt()];
    final token = _nextPairedReturnToken(
      now: now,
      gap: gap,
      screenId: screenId ?? _fallbackScreen,
    );
    final asset = token == null
        ? 'room/ordinary/$folder/$variant'
        : 'room/paired_return/${token.name}/$folder/$variant';
    return InteractionSoundSelection(asset, gain, pairedReturnToken: token);
  }

  PairedReturnToken? _nextPairedReturnToken({
    required DateTime now,
    required Duration? gap,
    required Object screenId,
  }) {
    var eligibleGap = gap;
    if (!identical(_pairedReturnScreen, screenId)) {
      _pairedReturnScreen = screenId;
      interruptPairedReturn();
      eligibleGap = null;
    }

    if (eligibleGap == null ||
        eligibleGap.isNegative ||
        eligibleGap > pairedReturnEligibleMax) {
      _pairedReturnIndex = null;
      _pairedReturnEligibleRun = 1;
      return null;
    }

    // Duplicate callbacks returned before reaching this method. A real rapid
    // interaction still sounds, but it breaks both an eligibility run and an
    // active phrase so later taps never catch up melodically.
    if (eligibleGap < rapidWindow) {
      interruptPairedReturn();
      return null;
    }

    final activeIndex = _pairedReturnIndex;
    if (activeIndex != null) {
      final token = pairedReturnPhrase[activeIndex];
      _pairedReturnEmitted[screenId] = true;
      final nextIndex = activeIndex + 1;
      if (nextIndex >= pairedReturnPhrase.length) {
        _pairedReturnIndex = null;
        _pairedReturnEligibleRun = 0;
      } else {
        _pairedReturnIndex = nextIndex;
      }
      return token;
    }

    if (_pairedReturnEmitted[screenId] == true || _cooldownActive(now)) {
      _pairedReturnEligibleRun = 0;
      return null;
    }

    if (_pairedReturnEligibleRun >= pairedReturnAfterActions) {
      final token = pairedReturnPhrase.first;
      _pairedReturnEmitted[screenId] = true;
      _lastPairedReturnAt = now;
      _pairedReturnIndex = 1;
      _pairedReturnEligibleRun = 0;
      return token;
    }

    _pairedReturnEligibleRun += 1;
    return null;
  }

  bool _cooldownActive(DateTime now) {
    final previous = _lastPairedReturnAt;
    if (previous == null) return false;
    final age = now.difference(previous);
    return age.isNegative || age < pairedReturnCooldown;
  }

  /// Clears unfinished eligibility and phrase state. Rarity history and the
  /// global cooldown remain intact, so an interruption cannot retrigger or
  /// produce delayed melodic catch-up.
  void interruptPairedReturn() {
    _pairedReturnEligibleRun = 0;
    _pairedReturnIndex = null;
  }

  void resetBurst() {
    _lastAt = null;
    _rapidBeat = 0;
    interruptPairedReturn();
  }
}

/// Rejects duplicate ownership of the same completed state transition without
/// swallowing a legitimately fast completion of a different quest.
class CompletionSoundGate {
  CompletionSoundGate({this.window = const Duration(seconds: 2)});

  final Duration window;
  final Map<Object, DateTime> _claimedAt = <Object, DateTime>{};

  bool claim(Object? transitionId, {DateTime? at}) {
    if (transitionId == null) return true;
    final now = at ?? DateTime.now();
    _claimedAt.removeWhere((_, claimedAt) {
      final age = now.difference(claimedAt);
      return !age.isNegative && age >= window;
    });
    final previous = _claimedAt[transitionId];
    if (previous != null) {
      final gap = now.difference(previous);
      if (!gap.isNegative && gap < window) return false;
    }
    _claimedAt[transitionId] = now;
    return true;
  }
}

/// Non-persisted ownership for the room's welcome ignition. A resumed app,
/// rebuilt page, or tab hop is still the same visit; only a fresh process gets
/// the full fwoosh.
class AppSessionIgnitionGate {
  bool _claimed = false;

  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }

  bool get isClaimed => _claimed;
}

/// Keeps direct legacy sound calls on the same screen identity as semantic
/// Pressables. Navigator routes form a stack; the five long-lived shell tabs
/// replace the current root identity without disturbing that stack.
class RoomSoundNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sfx.instance.pushInteractionScreen(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sfx.instance.removeInteractionScreen(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sfx.instance.removeInteractionScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null || oldRoute == null) return;
    Sfx.instance.replaceInteractionScreen(oldRoute, newRoute);
  }
}

final RoomSoundNavigatorObserver roomSoundNavigatorObserver =
    RoomSoundNavigatorObserver();

/// Event-typed sound palette (DESIGN.md §8). Sounds are always paired with
/// visuals, so every call is fire-and-forget and failure-tolerant — a muted
/// or audio-broken device loses nothing.
///
/// Native wavs are pooled (preloaded + decoded) so rare, high-magnitude events
/// land frame-synced with their visual beat. Browsers warm each event sound on
/// first use instead of competing with the first interactive room frame.
class Sfx {
  Sfx._({
    InteractionSoundRouter? interactions,
    CompletionSoundGate? completions,
  }) : _interactions = interactions ?? InteractionSoundRouter(),
       _completions = completions ?? CompletionSoundGate();

  @visibleForTesting
  Sfx.testing({
    InteractionSoundRouter? interactions,
    CompletionSoundGate? completions,
  }) : this._(interactions: interactions, completions: completions);

  static final Sfx instance = Sfx._();

  static const _coreAssets = [
    ...InteractionSoundRouter.allAssets,
    'room/completion/answered-detent-natural',
    'room/completion/completion-composite',
    'streak',
    'crit',
    'loot',
    'levelup',
    'boing',
    'hearth',
    'fire_ignite',
    'stat_0',
    'stat_1',
    'stat_2',
    'stat_3',
    'stat_4',
    'stat_5',
  ];
  static final List<String> _rareAssets =
      InteractionSoundRouter.pairedReturnAssets;
  static final List<String> _materialAssets = [
    for (final lane in _shippedMaterialLanes)
      for (var take = 1; take <= _materialTakeCount; take++)
        'room/materials/$lane/$take',
  ];

  /// Named legacy/rare-event volumes. Approved Room masters carry their
  /// tested phone level in the files and play at 1.0: as of 2026-08-21 the
  /// event palette (streak/crit/loot/levelup/boing/stat_*) is the phone-
  /// approved room-event-voice-v1 family, calibrated in-file like the clasps.
  static const _volume = <String, double>{
    'streak': 1.0,
    'boing': 1.0,
    // Full volume marks a genuinely revived hearth. Room navigation reuses the
    // cue once at a much quieter scale; it never starts a background loop.
    'hearth': 0.68,
    'fire_ignite': 0.68,
    'stat_0': 1.0,
    'stat_1': 1.0,
    'stat_2': 1.0,
    'stat_3': 1.0,
    'stat_4': 1.0,
    'stat_5': 1.0,
    'crit': 1.0,
    'loot': 1.0,
    'levelup': 1.0,
  };
  static double _volFor(String name) => _volume[name] ?? 0.55;

  /// Folder names for the material-shaded masters under room/materials/.
  static const _materialFolders = <MaterialSound, String>{
    MaterialSound.stone: 'slate',
    MaterialSound.parchment: 'page',
    MaterialSound.glass: 'glass',
    MaterialSound.brass: 'brass',
  };

  /// (materialFolder/verb) lanes whose masters have shipped. A declared
  /// material whose lane is absent falls back to the plain ordinary clasp.
  /// All nine room-material-shading-v1 lanes were phone-approved on
  /// 2026-08-21 ("i like all the candidate stuff best on the phone sound
  /// system, they sound fun") and ship byte-identical to that audition.
  static const _shippedMaterialLanes = <String>{
    'slate/select',
    'slate/navigate',
    'slate/place',
    'page/navigate',
    'page/open',
    'glass/select',
    'glass/place',
    'brass/select',
    'brass/place',
  };

  /// Takes per shipped material lane (the study renders 3 per lane; the
  /// ordinary walk's five variants fold onto them).
  static const _materialTakeCount = 3;

  static const _ordinarySuppressingEvents = <String>{
    'streak',
    'crit',
    'loot',
    'levelup',
    'boing',
    'hearth',
    'fire_ignite',
    'stat_0',
    'stat_1',
    'stat_2',
    'stat_3',
    'stat_4',
    'stat_5',
  };

  final Map<String, AudioPool> _pools = {};
  final Map<String, Future<AudioPool?>> _poolLoads = {};
  final InteractionSoundRouter _interactions;
  final CompletionSoundGate _completions;
  final List<Object?> _interactionScreenHistory = <Object?>[];
  Object? _interactionScreen;
  DateTime? _ordinarySuppressedUntil;

  /// Sound enabled flag — set from GameState.soundEnabled.
  bool soundEnabled = true;

  /// Test-only probe at the final playback boundary. This records only events
  /// that survived mute, duplicate, semantic, and completion gates.
  @visibleForTesting
  ValueChanged<String>? debugOnPlay;

  /// Keeps widget tests out of the native audio plugin after recording a cue.
  @visibleForTesting
  bool debugBypassPlayback = false;

  @visibleForTesting
  void debugResetForTesting() {
    debugOnPlay = null;
    debugBypassPlayback = false;
    soundEnabled = true;
    _ordinarySuppressedUntil = null;
    _interactions.resetBurst();
  }

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
    // eagerly building the whole palette made a first visit fetch every wav
    // copies) while Flutter was decoding the room and accepting the first tap.
    // Native keeps its frame-synchronous preload; web warms only sounds the
    // person actually reaches.
    if (kIsWeb) return;

    // Parallel loads; each pool becomes playable as soon as it lands, and
    // one failed asset never mutes the others.
    await Future.wait([..._coreAssets, ..._materialAssets].map(_loadPool));
    // The rare lane is only reachable after four well-paced accepted actions.
    // Warm it after the everyday set without making sixty tiny easter-egg
    // masters part of first-frame readiness.
    unawaited(_warmRarePools());
  }

  Future<void> _warmRarePools() async {
    // Creating all sixty pools together can briefly contend with native room
    // startup. Four at a time keeps the approved cue ready soon without a
    // large background decode spike.
    const batchSize = 4;
    for (var start = 0; start < _rareAssets.length; start += batchSize) {
      final end = start + batchSize < _rareAssets.length
          ? start + batchSize
          : _rareAssets.length;
      await Future.wait(_rareAssets.sublist(start, end).map(_loadPool));
    }
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
          maxPlayers: name.startsWith('room/paired_return/') ? 1 : 4,
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
    // Completion is a state transition even when audio is unavailable. Route
    // it before the mute gate so it always clears an unfinished rare phrase.
    if (name == 'complete') {
      playCompletionAccepted(volumeScale: volumeScale);
      return;
    }
    final suppressesOrdinary = _ordinarySuppressingEvents.contains(name);
    if (suppressesOrdinary) _interactions.resetBurst();
    if (!soundEnabled || (kIsWeb && !browserAudioAvailable)) return;
    if (name == 'tick') {
      playInteraction(InteractionSound.open, volumeScale: volumeScale);
      return;
    }
    if (name == 'tick_warm') {
      playInteraction(InteractionSound.select, volumeScale: volumeScale);
      return;
    }
    if (name == 'tick_lift') {
      playInteraction(InteractionSound.place, volumeScale: volumeScale);
      return;
    }
    try {
      if (suppressesOrdinary) {
        _ordinarySuppressedUntil = DateTime.now().add(
          const Duration(milliseconds: 140),
        );
      }
      final vol = (_volFor(name) * volumeScale).clamp(0.0, 1.0);
      _playAsset(name, volume: vol, eventName: name);
    } catch (e) {
      debugPrint('Sfx "$name" failed: $e');
    }
  }

  void _playAsset(
    String asset, {
    required double volume,
    required String eventName,
  }) {
    debugOnPlay?.call(eventName);
    if (debugBypassPlayback) return;
    final pool = _pools[asset];
    if (pool != null) {
      pool.start(volume: volume).catchError((Object e) {
        debugPrint('Sfx "$eventName" ($asset) failed: $e');
        return () async {};
      });
      return;
    }

    // Pool missing (failed, still loading, or intentionally lazy on web):
    // best-effort one-shot now, and keep a pool warm for the next use.
    unawaited(_loadPool(asset));
    final player = AudioPlayer();
    player.onPlayerComplete.first.then((_) => player.dispose());
    player.play(AssetSource('sfx/$asset.wav'), volume: volume).catchError((
      Object e,
    ) {
      debugPrint('Sfx "$eventName" ($asset) fallback failed: $e');
      player.dispose();
    });
  }

  /// Plays the selected Room clasp for one accepted ordinary interaction.
  /// [screenId] scopes the physically approved Paired Return to one appearance
  /// per screen. Callers without context use the current Navigator/tab scope.
  /// [material] requests that surface's texture shading; the plain clasp
  /// plays whenever the lane has not shipped, and the Paired Return easter
  /// egg always keeps its own unshaded masters.
  void playInteraction(
    InteractionSound role, {
    double volumeScale = 1,
    DateTime? at,
    Object? screenId,
    MaterialSound? material,
  }) {
    if (!soundEnabled || (kIsWeb && !browserAudioAvailable)) return;
    final now = at ?? DateTime.now();
    final suppressedUntil = _ordinarySuppressedUntil;
    if (suppressedUntil != null && now.isBefore(suppressedUntil)) return;
    final selection = _interactions.next(
      role,
      at: now,
      screenId: screenId ?? _interactionScreen,
    );
    if (selection == null) return;
    _playAsset(
      _shadedAsset(selection, role, material),
      volume: (selection.gain * volumeScale).clamp(0.0, 1.0).toDouble(),
      eventName: role.name,
    );
  }

  /// Resolves the router's ordinary selection onto a shipped material lane.
  /// The router still owns the walk, rapid gains, and Paired Return — a
  /// material only substitutes which body answers, never the grammar.
  String _shadedAsset(
    InteractionSoundSelection selection,
    InteractionSound role,
    MaterialSound? material,
  ) {
    if (material == null || material == MaterialSound.wood) {
      return selection.asset;
    }
    if (selection.pairedReturnToken != null) return selection.asset;
    final folder = _materialFolders[material];
    if (folder == null) return selection.asset;
    final lane = '$folder/${role.name}';
    if (!_shippedMaterialLanes.contains(lane)) return selection.asset;
    final variant = int.parse(selection.asset.split('/').last);
    final take = (variant - 1) % _materialTakeCount + 1;
    return 'room/materials/$lane/$take';
  }

  /// Plays the accepted completion gesture. A completion reached without a
  /// Pressable contact uses the immutable accepted-contact → Answered Detent
  /// composite. When the visible bob already voiced its contact, runtime uses
  /// the locked Answered Detent outcome master instead of striking a second
  /// generic contact over the completion visual.
  void playCompletionAccepted({
    Object? transitionId,
    double volumeScale = 1,
    bool contactAlreadyPlayed = false,
  }) {
    // The state changed even when the phone is muted. Clear a partially armed
    // return before the availability gate so it cannot resume after unmuting.
    _interactions.resetBurst();
    if (!soundEnabled || (kIsWeb && !browserAudioAvailable)) return;
    final now = DateTime.now();
    if (!_completions.claim(transitionId, at: now)) return;
    _ordinarySuppressedUntil = now.add(const Duration(milliseconds: 430));
    _playAsset(
      contactAlreadyPlayed
          ? 'room/completion/answered-detent-natural'
          : 'room/completion/completion-composite',
      volume: volumeScale.clamp(0.0, 1.0).toDouble(),
      eventName: 'complete',
    );
  }

  /// Material-first call: the verb comes from the bridge, the texture from
  /// the material itself once its lane ships.
  void playMaterial(MaterialSound material, {double volumeScale = 1}) {
    playInteraction(
      interactionForMaterial(material),
      volumeScale: volumeScale,
      material: material,
    );
  }

  /// Replaces the current long-lived root screen (for example, a shell tab).
  /// Eligibility is shared across controls within that stable screen. The
  /// router clears unfinished state on the first accepted event after a scope
  /// change, so a phrase can never leak across tabs or routes.
  void setInteractionScreen(Object screenId) {
    _interactionScreen = screenId;
  }

  /// Adds a pushed route while remembering the exact tab/route beneath it.
  void pushInteractionScreen(Object screenId) {
    _interactionScreenHistory.add(_interactionScreen);
    _interactionScreen = screenId;
  }

  /// Replaces a Navigator route without losing the screen below it.
  void replaceInteractionScreen(Object oldScreenId, Object newScreenId) {
    if (identical(_interactionScreen, oldScreenId)) {
      _interactionScreen = newScreenId;
    }
    for (var index = 0; index < _interactionScreenHistory.length; index++) {
      if (identical(_interactionScreenHistory[index], oldScreenId)) {
        _interactionScreenHistory[index] = newScreenId;
      }
    }
  }

  /// Removes a popped route and restores its exact previous tab/route scope.
  void removeInteractionScreen(Object screenId) {
    if (identical(_interactionScreen, screenId)) {
      _interactionScreen = _interactionScreenHistory.isEmpty
          ? null
          : _interactionScreenHistory.removeLast();
      return;
    }
    _interactionScreenHistory.removeWhere(
      (candidate) => identical(candidate, screenId),
    );
  }

  /// Places an earned cue just behind the physical touch acknowledgement.
  /// A fast pointer-up can otherwise start both assets in the same transient,
  /// turning a clean contact and reward into one harsh, flammed hit.
  void playAfterContact(
    String name, {
    Duration delay = const Duration(milliseconds: 65),
    double volumeScale = 1,
  }) {
    unawaited(
      Future<void>.delayed(delay, () => play(name, volumeScale: volumeScale)),
    );
  }
}
