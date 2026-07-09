import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../content/creature_skins.dart' show creatureSkinById;
import '../tokens.dart';
import 'portrait.dart';

/// Declares which pre-rendered ember sprite frame-sets have shipped. All
/// eleven creature skins — seven palette skins (amber + the six paid recolors)
/// plus four costumed outfit sets — ship stages 0–5 in idle+happy, on one path
/// convention: `assets/mascot/<skinId>/s<stage>_<mood>_00.png`. Amber frames
/// come from the locked FLUX ember (SDXL per-stage, rembg cutout); the six
/// paid skins are deterministic palette-remaps of those
/// (tools/remap_mascot_skins.py) so they match creature_skins.dart colors
/// exactly. Anything outside the shipped set falls back to the procedural
/// [Portrait]; a missing file also falls back via the Image errorBuilder —
/// nothing ever renders blank.
abstract final class MascotFrames {
  static const _skins = {
    'ember_amber', 'rose_quartz', 'mint_glass', 'periwinkle',
    'lilac', 'slate', 'gilded',
    // outfit variants (round-60): whole costumed frame-sets, not remaps
    'adventurer', 'healer', 'knight', 'wizard',
  };
  static const _moods = {'idle', 'happy'};

  static List<String>? framesFor(String skinId, int stage, String mood) {
    if (!_skins.contains(skinId) || stage < 0 || stage > 5) return null;
    // an undrawn mood plays the skin's idle set (the widget adds a happy pop)
    final m = _moods.contains(mood) ? mood : 'idle';
    return ['assets/mascot/$skinId/s${stage}_${m}_00.png'];
  }
}

/// The mascot as pre-rendered sprite frames when they exist, otherwise the
/// procedural [Portrait] (round-53, the sprite-set lane). Two rules bake in the
/// integration plan:
///  • Below [minSpriteSize] (tiny HUD dots, shop swatches) it ALWAYS uses the
///    procedural ember — the painterly frames don't read when small, the vector
///    one is built to.
///  • If no frame-set is declared/loads for this (skin, stage, mood), it falls
///    back to the procedural ember too. Nothing ever renders blank.
class MascotSprite extends StatefulWidget {
  const MascotSprite({
    super.key,
    required this.size,
    required this.skinId,
    this.mood = PortraitMood.idle,
    this.level = 1,
    this.aura,
    this.skin,
    this.badge = false,
    this.trait,
    this.fps = 7,
    this.minSpriteSize = 72,
    this.lively = true,
  });

  final double size;

  /// Which skin's frame-set to use (creature_skins id, e.g. 'ember_amber').
  final String skinId;
  final PortraitMood mood;
  final int level;
  final Color? aura;

  /// The four body-gradient colours — used by the procedural fallback so a
  /// not-yet-drawn skin still recolours correctly.
  final List<Color>? skin;
  final bool badge;
  final Stat? trait;

  /// Idle-loop playback rate.
  final double fps;

  /// Sprites only kick in at/above this px size; smaller stays procedural.
  final double minSpriteSize;

  /// The idle behaviour loop — an occasional hop, a curious tilt, a little
  /// shuffle, ember motes rising off the crest. Pass `!state.reduceMotion`;
  /// the OS-level disable-animations switch is honoured regardless.
  final bool lively;

  @override
  State<MascotSprite> createState() => _MascotSpriteState();
}

class _MascotSpriteState extends State<MascotSprite>
    with TickerProviderStateMixin {
  // one slow loop drives the idle breath (+ flipbook when >1 frame). Repaint-
  // bounded and quantized so a still frame still feels alive for almost nothing.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  // a much slower loop schedules the BEHAVIOURS — hop, tilt, shuffle — so the
  // creature acts on its own rhythm instead of a metronome. Created up front
  // and only stopped when not lively (a stopped ticker is free): disposing it
  // mid-life would yank a listenable out from under the AnimatedBuilder that
  // is still subscribed through the merged animation below.
  late final AnimationController _behave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 11000),
  );

  // the mood beat: one short controller kicked on idle↔happy, driving a
  // cross-fade between the outgoing and incoming frame plus a tiny
  // squash-and-settle so the pop lands with weight instead of teleporting.
  late final AnimationController _mood = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  // merged ONCE — rebuilding Listenable.merge every build made the
  // AnimatedBuilder resubscribe to a fresh listenable on every frame.
  late final Listenable _listenable = Listenable.merge([_life, _behave, _mood]);

  List<String>? _frames;

  // the frame we're fading away from during a mood swap (sprite path only —
  // the procedural fallback repaints its own face, there's nothing to fade)
  String? _outgoing;

  // mirrors of the OS reduce-motion switch and the effective liveliness,
  // kept fresh by _syncAnimations (didChangeDependencies/didUpdateWidget)
  var _still = false;
  var _lively = false;

  // per-instance phase offset so two mascots on screen never move in sync
  double get _phase =>
      ((widget.skinId.hashCode ^ (widget.level * 37)) % 997) / 997.0;

  Widget _fallback() => Portrait(
        size: widget.size,
        mood: widget.mood,
        aura: widget.aura,
        level: widget.level,
        badge: widget.badge,
        trait: widget.trait,
        skin: widget.skin,
      );

  List<String>? _resolve() {
    // outfits have no procedural costume — below the sprite floor the painter
    // would silently strip a 340-400 ember knight back to a plain ember. A
    // slightly-soft costume beats the wrong creature, so outfits keep their
    // frame down to a lower threshold; only truly tiny (HUD-dot) sizes drop
    // them to the painter.
    final isOutfit = creatureSkinById(widget.skinId)?.outfit ?? false;
    final floor = isOutfit ? 44.0 : widget.minSpriteSize;
    if (widget.size < floor) return null; // tiny → procedural
    final stage = frameTierForLevel(widget.level);
    final mood = widget.mood == PortraitMood.happy ? 'happy' : 'idle';
    final f = MascotFrames.framesFor(widget.skinId, stage, mood);
    return (f != null && f.isNotEmpty) ? f : null;
  }

  @override
  void initState() {
    super.initState();
    _frames = _resolve();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations();
    _precacheMoods();
  }

  @override
  void didUpdateWidget(MascotSprite old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level ||
        old.mood != widget.mood ||
        old.skinId != widget.skinId ||
        old.size != widget.size) {
      final wasShowing = _frames?.first;
      setState(() => _frames = _resolve());
      _precacheMoods();
      if (old.mood != widget.mood && _lively) {
        // both moods are already warm in the image cache (_precacheMoods), so
        // instead of a hard swap the old frame melts into the new one — and
        // the happy pop gets its little squash-and-settle beat too
        _outgoing = (wasShowing != null && wasShowing != _frames?.first)
            ? wasShowing
            : null;
        _mood.forward(from: 0);
      }
    }
    if (old.lively != widget.lively) _syncAnimations();
  }

  /// Start/stop the loops to match reality. The OS disable-animations switch
  /// parks EVERYTHING at the resting pose — a stopped controller is truly
  /// free (no ticks, no repaints) — and the behaviour loop only spins when
  /// the caller wants a lively creature.
  void _syncAnimations() {
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _lively = widget.lively && !_still;
    // park the breath loop whenever motion is OFF — whether by the OS switch
    // OR the in-app reduce-motion setting (lively:false). Gating only on the OS
    // switch left the creature breathing on top of a frozen room on the Me
    // screen, since HomeRoom parks on the same lively flag.
    if (!_lively) {
      _life.stop();
      _life.value = 0;
      _mood.stop();
      _mood.value = 1; // any in-flight mood fade completes instantly
      _behave.stop();
      _behave.value = 0;
    } else {
      if (!_life.isAnimating) _life.repeat();
      if (!_behave.isAnimating) _behave.repeat();
    }
  }

  // warm BOTH moods of the current stage into the image cache, so the
  // idle→happy swap on a completion never pops in a beat late
  void _precacheMoods() {
    if (widget.size < widget.minSpriteSize) return;
    final stage = frameTierForLevel(widget.level);
    for (final mood in const ['idle', 'happy']) {
      for (final f in MascotFrames.framesFor(widget.skinId, stage, mood) ??
          const <String>[]) {
        precacheImage(AssetImage(f), context);
      }
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _behave.dispose();
    _mood.dispose();
    super.dispose();
  }

  /// 0→1 progress through the [a]..[z] slice of the behaviour loop, else 0.
  static double _seg(double b, double a, double z) =>
      (b < a || b > z) ? 0.0 : (b - a) / (z - a);

  /// The happy pop's squash-and-settle: a breath of anticipation (scaleY dips
  /// to ~0.96), a springy overshoot (~1.04), then home at exactly 1. One
  /// beat, cozy — nothing rubber-hose.
  static double _settle(double v) {
    if (v < 0.28) return 1 - 0.04 * sin(v / 0.28 * pi);
    final w = (v - 0.28) / 0.72;
    return 1 + 0.05 * sin(w * pi) * (1 - 0.25 * w);
  }

  // where the crest tip sits per growth stage, as a fraction of box height —
  // a new ember burns low in its frame, Everflame's crest reaches near the
  // top. Eyeballed against the shipped s0..s5 frames; the motes and the crest
  // glow both anchor here so the fire effects track the art as it grows.
  static const _crestAnchor = [0.30, 0.26, 0.22, 0.18, 0.14, 0.10];

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    final hasFrames = frames != null && frames.isNotEmpty;
    final happy = widget.mood == PortraitMood.happy;
    final aura = widget.aura;
    final stage = frameTierForLevel(widget.level).clamp(0, 5);
    final anchor = _crestAnchor[stage];
    // the skin's honey stop — the same tint source for motes and crest glow
    final emberTint = (widget.skin != null && widget.skin!.length > 1)
        ? widget.skin![1]
        : const Color(0xFFF2CD93);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _listenable,
        builder: (_, _) {
          // reduce-motion parks the loop at 0 — hold the true resting pose
          // rather than a frozen mid-breath offset
          final animating = _life.isAnimating;
          final t = animating ? (_life.value * 60).round() / 60 : 0.0; // ~20fps
          final breathe = animating ? sin(t * 2 * pi) : 0.0;
          final bob = animating ? sin(t * 2 * pi + 1.2) : 0.0;
          // a gentle breath + bob; a happy beat sits a touch bigger + livelier.
          // ONLY the frame image gets these — the procedural fallback breathes
          // and bobs inside its own painter, and stacking ours on top would
          // double-breathe the poor thing.
          final scale =
              hasFrames ? (happy ? 1.05 : 1.0) * (1 + 0.022 * breathe) : 1.0;
          var dy =
              hasFrames ? -bob * widget.size * (happy ? 0.028 : 0.016) : 0.0;

          // ── the behaviour loop: once per ~11s the creature does a thing —
          // a hop with squash-and-stretch, a curious tilt, a little shuffle
          // out and back. Phase-offset per instance so no two sync up. These
          // wrap WHICHEVER child renders, so the fallback ember gets to hop
          // and smolder just like the painted one. ──
          var dx = 0.0, lean = 0.0, squash = 1.0;
          if (_lively) {
            final b = (((_behave.value * 220).round() / 220) + _phase) % 1.0;
            final hop = _seg(b, 0.20, 0.26);
            if (hop > 0) {
              dy -= sin(hop * pi) * widget.size * 0.07;
              squash = 1.0 + 0.06 * sin(hop * 2 * pi);
            }
            final tilt = _seg(b, 0.42, 0.52);
            if (tilt > 0) lean += sin(tilt * 2 * pi) * 0.035;
            final walk = _seg(b, 0.60, 0.88);
            if (walk > 0) {
              final dir = _phase < 0.5 ? 1.0 : -1.0;
              dx = sin(walk * pi) * widget.size * 0.055 * dir;
              // lean into the motion — WINDOWED by sin(walk*pi) so the tilt
              // eases in and out with the step instead of snapping ±0.05 at
              // the segment edges (cos alone is ±1 there — a visible twitch)
              lean += cos(walk * pi) * sin(walk * pi) * 0.06 * dir;
            }
          }
          // the mood beat's squash rides the same scaleY slot as the hop's;
          // only the pop TO happy gets the spring (back to idle just fades)
          if (happy && _mood.isAnimating) squash *= _settle(_mood.value);

          Widget core;
          if (hasFrames) {
            // flipbook index in real SECONDS (t is the 0..1 loop fraction), so
            // [fps] means frames per second — not frames per loop
            final secs = t * _life.duration!.inMilliseconds / 1000;
            final i = frames.length < 2
                ? 0
                : (secs * widget.fps).floor() % frames.length;
            // the cross-fade lives in the first ~180ms of the 420ms mood beat
            final fade = _mood.isAnimating
                ? Curves.easeOut
                    .transform((_mood.value / 0.43).clamp(0.0, 1.0))
                : 1.0;
            final fading = _outgoing != null && fade < 1.0;
            core = Stack(children: [
              if (aura != null)
                // your build's colour pooling behind you — parity with the
                // procedural ember's aura (and what a cosmetic preview previews)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.52,
                          colors: [
                            aura.withValues(alpha: happy ? 0.38 : 0.24),
                            aura.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // the PNG crest is a still photograph of a fire — a soft
              // skin-tinted pool of light BEHIND the art (never over it),
              // wandering on the same two-harmonic flicker as the procedural
              // flame, puts the heat back into it
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CrestGlowPainter(
                      t: t,
                      color: emberTint,
                      anchor: anchor,
                      stage: stage,
                      happy: happy,
                    ),
                  ),
                ),
              ),
              if (fading)
                Opacity(opacity: 1 - fade, child: _frameImage(_outgoing!)),
              if (fading)
                Opacity(opacity: fade, child: _frameImage(frames[i]))
              else
                _frameImage(frames[i]),
            ]);
          } else {
            core = _fallback();
          }
          if (_lively) {
            // ember motes drifting up off the crest — the "it's really
            // burning" tell. Deterministic from the loop, so it costs a
            // repaint we were already paying for. Layered over the fallback
            // too, so a procedural creature smolders like a painted one.
            core = Stack(children: [
              core,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MotesPainter(
                      t: t,
                      color: emberTint,
                      happy: happy,
                      anchor: anchor,
                      stage: stage,
                    ),
                  ),
                ),
              ),
            ]);
          }
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: lean,
              child: Transform.scale(
                scaleX: scale,
                scaleY: scale * squash,
                child: core,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _frameImage(String asset) => Image.asset(
        asset,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        // frames ship at 448–512px and usually display near 100px — medium
        // turns on mipmaps so the downscale stays soft instead of shimmery
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true, // no flicker on frame swap
        // a missing/broken asset can never blank the mascot — drop to procedural
        errorBuilder: (_, _, _) => _fallback(),
      );
}

/// A soft pool of the skin's honey light sitting BEHIND the frame, centred on
/// the crest, its reach and strength wandering on the same two-harmonic
/// flicker as portrait.dart's flame. Gradient-shaded (no mask blur), so it
/// costs one cheap shader circle; fully deterministic in [t].
class _CrestGlowPainter extends CustomPainter {
  _CrestGlowPainter({
    required this.t,
    required this.color,
    required this.anchor,
    required this.stage,
    required this.happy,
  });
  final double t;
  final Color color;

  /// Crest-tip height fraction for this growth stage (see _crestAnchor).
  final double anchor;
  final int stage;
  final bool happy;

  @override
  void paint(Canvas canvas, Size size) {
    // two harmonics so the glow breathes and stumbles like firelight,
    // never a metronome — same recipe as the procedural flame's flick
    final flick = 1 +
        0.08 * sin(t * 2 * pi * 1.7) +
        0.04 * sin(t * 2 * pi * 3.3 + 1.1);
    // centred a whisker below the tip so the pool hugs the crest, drifting
    // a hair sideways like heat shimmer
    final c = Offset(
      size.width * (0.5 + 0.008 * sin(t * 2 * pi + 0.7)),
      size.height * (anchor + 0.06),
    );
    final r = size.width * (0.20 + 0.014 * stage) * flick;
    final a = (happy ? 0.30 : 0.20) * (0.75 + 0.25 * flick);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: a * 0.4),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_CrestGlowPainter old) =>
      old.t != t ||
      old.color != color ||
      old.anchor != anchor ||
      old.stage != stage ||
      old.happy != happy;
}

/// A handful of ember motes rising off the flame crest, looping with the idle
/// breath — born at [anchor] (where THIS stage's crest tip actually is), with
/// a couple more, slightly plumper motes per stage so Everflame smolders
/// harder than a fresh ember. Fully deterministic in [t] — no state, no
/// Random — so goldens stay stable and the paint is as cheap as the transform
/// it rides on.
class _MotesPainter extends CustomPainter {
  _MotesPainter({
    required this.t,
    required this.color,
    required this.happy,
    required this.anchor,
    required this.stage,
  });
  final double t;
  final Color color;
  final bool happy;

  /// Crest-tip height fraction for this growth stage (see _crestAnchor).
  final double anchor;
  final int stage;

  // cheap per-mote hash: stable pseudo-randoms in 0..1
  static double _h(int i, int salt) {
    final v = sin((i * 127.1 + salt * 311.7)) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = (happy ? 6 : 4) + stage ~/ 2;
    final grow = 1 + stage * 0.05;
    for (var i = 0; i < n; i++) {
      final cycle = (t + _h(i, 1)) % 1.0;
      // born just above the crest, rising ~a quarter of the box and fading
      final x = size.width * (0.5 + (_h(i, 2) - 0.5) * 0.16) +
          sin((cycle + _h(i, 3)) * 2 * pi) * size.width * 0.02;
      final y = size.height * (anchor - cycle * 0.16);
      final fade = cycle < 0.25
          ? cycle / 0.25
          : cycle > 0.7
              ? (1 - cycle) / 0.3
              : 1.0;
      final r = size.width *
          (0.008 + 0.008 * _h(i, 4)) *
          (happy ? 1.25 : 1.0) *
          grow;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Color.lerp(color, const Color(0xFFFFF4D9), 0.4)!
              .withValues(alpha: 0.75 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_MotesPainter old) =>
      old.t != t ||
      old.color != color ||
      old.happy != happy ||
      old.anchor != anchor ||
      old.stage != stage;
}
